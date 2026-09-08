// One Durable Object per region: a 4 × 4 block of cells, about 600 m square.
//
// Everything a bear is lives here and only here. Positions sit in memory on the sockets'
// attachments; there is no table, no log, and nothing survives a disconnect. The object
// hibernates between messages, so a region full of people standing still costs nothing and
// a region nobody is in does not exist.
//
// The rule that decides who sees whom is `livePosition` in rules.ts -- the same five gates
// as the Swift engine. Two of them are enforced by the shape of this object rather than by a
// check: you are only here if you connected, and connecting is how you become visible.

import { DurableObject } from "cloudflare:workers";
import type { Env } from "./env";
import { cellId, isPlausible, livePosition, metres } from "./rules";

/** Faster than this and the message is dropped. Walking moves 1.4 m in a second. */
const MIN_INTERVAL_MS = 1_000;
/** No ping and no position for this long and the socket is closed by the sweep. */
const STALE_MS = 90_000;
const SWEEP_MS = 60_000;

/** What travels with a socket through hibernation. Kept small: attachments cap at 2 KB. */
interface Member {
  uid: string;
  handle: string;
  accent: number;
  lat: number;
  lon: number;
  course: number | null;
  /** Wall-clock ms of the last accepted position. */
  at: number;
}

/** What a phone sends. */
interface Fix {
  lat: number;
  lon: number;
  course?: number | null;
}

/** What a phone receives. */
type Outbound =
  | { t: "welcome"; region: string }
  | { t: "pos"; id: string; handle: string; accent: number; lat: number; lon: number; course: number | null; m: number }
  | { t: "gone"; id: string };

export class Region extends DurableObject<Env> {
  /** viewer uid → the uids currently drawn for them. Memory only; see ARCHITECTURE-PRESENCE. */
  private visible = new Map<string, Set<string>>();
  /** uid → everyone they must not see or be seen by. Loaded from storage on demand. */
  private blocks = new Map<string, Set<string>>();

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    // Liveness without waking up: the runtime answers a "ping" with "pong" while hibernated
    // and records when it did, which is what the sweep reads.
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
  }

  // -- connect ---------------------------------------------------------------------------

  async fetch(request: Request): Promise<Response> {
    const uid = request.headers.get("X-Uid");
    const handle = request.headers.get("X-Handle");
    const accent = Number(request.headers.get("X-Accent") ?? "0");
    const lat = Number(request.headers.get("X-Lat"));
    const lon = Number(request.headers.get("X-Lon"));
    const blockList = JSON.parse(request.headers.get("X-Blocks") ?? "[]") as string[];
    if (!uid || !handle || !Number.isFinite(lat) || !Number.isFinite(lon)) {
      return new Response("bad handoff", { status: 400 });
    }

    // One socket per person per region. A reconnect replaces the old one rather than
    // leaving a ghost that keeps being drawn until the sweep.
    for (const old of this.ctx.getWebSockets(uid)) old.close(4000, "replaced");

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair) as [WebSocket, WebSocket];
    this.ctx.acceptWebSocket(server, [uid]);

    const member: Member = { uid, handle, accent, lat, lon, course: null, at: Date.now() };
    server.serializeAttachment(member);

    await this.ctx.storage.put(`blocks:${uid}`, blockList);
    this.blocks.set(uid, new Set(blockList));

    if ((await this.ctx.storage.getAlarm()) === null) {
      await this.ctx.storage.setAlarm(Date.now() + SWEEP_MS);
    }

    this.send(server, { t: "welcome", region: this.ctx.id.name ?? "" });
    // Arriving changes the occupancy of a cell, which can open or close the floor for
    // everyone in it -- a cell-wide refresh. Then the newcomer's own view of the room,
    // which nobody has judged yet.
    await this.refreshCell(cellId(lat, lon));
    await this.refreshPairs(server, member);
    return new Response(null, { status: 101, webSocket: client });
  }

  // -- messages --------------------------------------------------------------------------

  async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (typeof raw !== "string") return;
    let fix: Fix;
    try {
      fix = JSON.parse(raw) as Fix;
    } catch {
      return;
    }
    if (!Number.isFinite(fix.lat) || !Number.isFinite(fix.lon)) return;
    if (Math.abs(fix.lat) > 90 || Math.abs(fix.lon) > 180) return;

    const me = ws.deserializeAttachment() as Member;
    const now = Date.now();
    if (now - me.at < MIN_INTERVAL_MS) return;

    // A teleport is dropped, not punished. Anti-spoofing is best-effort by nature and this
    // must never bite someone whose GPS jumped after a tunnel.
    const moved = metres(me, fix);
    if (!isPlausible(moved, (now - me.at) / 1000)) return;

    const before = cellId(me.lat, me.lon);
    const after = cellId(fix.lat, fix.lon);
    const course = typeof fix.course === "number" && Number.isFinite(fix.course) ? fix.course : null;
    const updated: Member = { ...me, lat: fix.lat, lon: fix.lon, course, at: now };
    ws.serializeAttachment(updated);

    if (before !== after) {
      // Crossing a cell boundary changes two occupancy counts. Refresh both cells.
      await this.refreshCell(before);
      await this.refreshCell(after);
    } else {
      await this.refreshPairs(ws, updated);
    }
  }

  async webSocketClose(ws: WebSocket): Promise<void> {
    await this.leave(ws);
  }

  async webSocketError(ws: WebSocket): Promise<void> {
    await this.leave(ws);
  }

  private async leave(ws: WebSocket): Promise<void> {
    const me = ws.deserializeAttachment() as Member | null;
    try {
      ws.close(1000);
    } catch {
      // Already closed; that is the point.
    }
    if (!me) return;
    // Told to everyone regardless of what memory thinks they were shown. A client ignores a
    // `gone` for a bear it was not drawing; a bear left drawn after its person left is the
    // failure that matters.
    for (const [other] of this.members()) {
      if (other === ws) continue;
      this.send(other, { t: "gone", id: me.uid });
    }
    this.visible.delete(me.uid);
    this.blocks.delete(me.uid);
    await this.ctx.storage.delete(`blocks:${me.uid}`);
    // Leaving can drop a cell below the floor for everyone still in it.
    await this.refreshCell(cellId(me.lat, me.lon));
  }

  // -- the sweep -------------------------------------------------------------------------

  async alarm(): Promise<void> {
    const now = Date.now();
    const sockets = this.ctx.getWebSockets();
    for (const ws of sockets) {
      const me = ws.deserializeAttachment() as Member | null;
      const lastPing = this.ctx.getWebSocketAutoResponseTimestamp(ws)?.getTime() ?? 0;
      const lastSeen = Math.max(me?.at ?? 0, lastPing);
      if (now - lastSeen > STALE_MS) await this.leave(ws);
    }
    if (this.ctx.getWebSockets().length > 0) {
      await this.ctx.storage.setAlarm(now + SWEEP_MS);
    }
  }

  // -- visibility ------------------------------------------------------------------------

  private members(): Array<[WebSocket, Member]> {
    const out: Array<[WebSocket, Member]> = [];
    for (const ws of this.ctx.getWebSockets()) {
      const m = ws.deserializeAttachment() as Member | null;
      if (m) out.push([ws, m]);
    }
    return out;
  }

  private async blocksFor(uid: string): Promise<Set<string>> {
    const cached = this.blocks.get(uid);
    if (cached) return cached;
    const stored = (await this.ctx.storage.get<string[]>(`blocks:${uid}`)) ?? [];
    const set = new Set(stored);
    this.blocks.set(uid, set);
    return set;
  }

  /** Occupancy of each cell in the region, counted once per refresh rather than per pair. */
  private occupancy(all: Array<[WebSocket, Member]>): Map<string, number> {
    const counts = new Map<string, number>();
    for (const [, m] of all) {
      const c = cellId(m.lat, m.lon);
      counts.set(c, (counts.get(c) ?? 0) + 1);
    }
    return counts;
  }

  /** Decide, send, and remember: what `viewer` sees of `subject` right now. */
  private async judge(
    viewerWs: WebSocket,
    viewer: Member,
    subject: Member,
    counts: Map<string, number>,
  ): Promise<void> {
    const seen = this.visible.get(viewer.uid) ?? new Set<string>();
    this.visible.set(viewer.uid, seen);
    const wasVisible = seen.has(subject.uid);

    const viewerBlocks = await this.blocksFor(viewer.uid);
    const subjectBlocks = await this.blocksFor(subject.uid);
    const blocked = viewerBlocks.has(subject.uid) || subjectBlocks.has(viewer.uid);

    const m = metres(viewer, subject);
    const verdict = blocked
      ? "suppressed"
      : livePosition({
          // Both are in the room, and the room is only for the discoverable.
          viewerIsDiscoverable: true,
          subjectIsDiscoverable: true,
          metresApart: m,
          cellOccupants: counts.get(cellId(subject.lat, subject.lon)) ?? 0,
          wasVisible,
        });

    if (verdict === "precise") {
      seen.add(subject.uid);
      this.send(viewerWs, {
        t: "pos",
        id: subject.uid,
        handle: subject.handle,
        accent: subject.accent,
        lat: subject.lat,
        lon: subject.lon,
        course: subject.course,
        m: Math.round(m),
      });
    } else if (wasVisible) {
      seen.delete(subject.uid);
      this.send(viewerWs, { t: "gone", id: subject.uid });
    }
  }

  /** After one person moves within their cell: everyone's view of them, and their view of everyone. */
  private async refreshPairs(ws: WebSocket, me: Member): Promise<void> {
    const all = this.members();
    const counts = this.occupancy(all);
    for (const [otherWs, other] of all) {
      if (otherWs === ws) continue;
      await this.judge(otherWs, other, me, counts);
      await this.judge(ws, me, other, counts);
    }
  }

  /**
   * After a cell's occupancy changes: every viewer's view of everyone in that cell. Only
   * those subjects' verdicts can have changed, because occupancy is a property of the
   * subject's cell, not the viewer's.
   */
  private async refreshCell(cell: string): Promise<void> {
    const all = this.members();
    const counts = this.occupancy(all);
    const inCell = all.filter(([, m]) => cellId(m.lat, m.lon) === cell);
    for (const [viewerWs, viewer] of all) {
      for (const [subjectWs, subject] of inCell) {
        if (subjectWs === viewerWs) continue;
        await this.judge(viewerWs, viewer, subject, counts);
      }
    }
  }

  private send(ws: WebSocket, msg: Outbound): void {
    try {
      ws.send(JSON.stringify(msg));
    } catch {
      // A socket mid-close. The close handler cleans up.
    }
  }
}
