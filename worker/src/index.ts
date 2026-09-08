// The front door. Verifies the phone, asks Postgres two things it is allowed to know, and
// hands the socket to the region the phone is standing in.
//
//   GET /v1/presence?lat=..&lon=..     Upgrade: websocket, Authorization: Bearer <supabase jwt>
//   GET /healthz

import { verifySupabaseJwt } from "./auth";
import type { Env } from "./env";
import { regionId } from "./rules";

export { Region } from "./region";

interface Profile {
  handle: string;
  accent: number;
  discoverable: boolean;
  onboarded_at: string | null;
}

function serviceHeaders(env: Env): HeadersInit {
  return {
    apikey: env.SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
  };
}

async function profileFor(uid: string, env: Env): Promise<Profile | null> {
  const url = `${env.SUPABASE_URL}/rest/v1/profiles?id=eq.${uid}&select=handle,accent,discoverable,onboarded_at`;
  const res = await fetch(url, { headers: serviceHeaders(env) });
  if (!res.ok) throw new Error(`profiles ${res.status}`);
  const rows = (await res.json()) as Profile[];
  return rows[0] ?? null;
}

async function blocksFor(uid: string, env: Env): Promise<string[]> {
  const res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/block_relations_for`, {
    method: "POST",
    headers: serviceHeaders(env),
    body: JSON.stringify({ subject: uid }),
  });
  if (!res.ok) throw new Error(`blocks ${res.status}`);
  const rows = (await res.json()) as Array<string | { block_relations_for: string }>;
  return rows.map((r) => (typeof r === "string" ? r : r.block_relations_for));
}

/**
 * The token comes either as `Authorization: Bearer` or as the WebSocket subprotocol
 * `bearer.<jwt>`. Browsers and Node's WebSocket cannot set headers on an upgrade, and a
 * token in the query string ends up in access logs; the subprotocol is the standard
 * workaround and every client can send it.
 */
function bearer(request: Request): { token: string; protocol: string | null } | null {
  const header = request.headers.get("Authorization") ?? "";
  const fromHeader = /^Bearer\s+(.+)$/i.exec(header)?.[1];
  if (fromHeader) return { token: fromHeader, protocol: null };
  const protocols = (request.headers.get("Sec-WebSocket-Protocol") ?? "").split(",").map((s) => s.trim());
  const proto = protocols.find((s) => s.startsWith("bearer."));
  if (proto) return { token: proto.slice("bearer.".length), protocol: proto };
  return null;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/healthz") return new Response("ok");
    if (url.pathname !== "/v1/presence") return new Response("not found", { status: 404 });
    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("expected websocket", { status: 426 });
    }

    const auth = bearer(request);
    if (!auth) return new Response("unauthorized", { status: 401 });
    let sub: string;
    try {
      ({ sub } = await verifySupabaseJwt(auth.token, env));
    } catch {
      return new Response("unauthorized", { status: 401 });
    }

    const lat = Number(url.searchParams.get("lat"));
    const lon = Number(url.searchParams.get("lon"));
    if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
      return new Response("bad position", { status: 400 });
    }

    const [profile, blocks] = await Promise.all([profileFor(sub, env), blocksFor(sub, env)]);
    // The room is only for people who finished onboarding and switched discovery on. The
    // database's idea of hidden and the room's must agree, or "Hidden" is a client promise.
    if (!profile || !profile.onboarded_at) return new Response("not onboarded", { status: 403 });
    if (!profile.discoverable) return new Response("not discoverable", { status: 403 });

    const region = regionId(lat, lon);
    const stub = env.REGION.get(env.REGION.idFromName(region));
    const handoff = new Request(request.url, {
      headers: {
        Upgrade: "websocket",
        "X-Uid": sub,
        "X-Handle": profile.handle,
        "X-Accent": String(profile.accent),
        "X-Lat": String(lat),
        "X-Lon": String(lon),
        "X-Blocks": JSON.stringify(blocks),
        // Echoed on the 101 so a client that offered a subprotocol sees it accepted.
        ...(auth.protocol ? { "X-Protocol": auth.protocol } : {}),
      },
    });
    return stub.fetch(handoff);
  },
} satisfies ExportedHandler<Env>;
