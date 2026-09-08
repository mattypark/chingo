#!/usr/bin/env node
// End to end, against the real local stack: five fake people in one cell, and the rules.
//
// Needs `./scripts/dev-backend.sh` running. Creates throwaway users in the LOCAL Supabase,
// connects them to the LOCAL worker, asserts what each may see, and deletes them after.
// Zero dependencies; Node 22's WebSocket and fetch are enough.
//
// What it proves, in order:
//   1. a hidden person is refused at the door        (reciprocity, server-enforced)
//   2. four people in a cell see nobody              (k-anonymity floor)
//   3. a fifth arrives and everyone sees everyone    (floor opens)
//   4. a blocked pair never see each other           (blocks, both directions)
//   5. a teleport is dropped                          (plausibility)
//   6. leaving sends `gone`                           (nothing left drawn)

import { execSync } from "node:child_process";

const WORKER = process.env.PRESENCE_URL ?? "ws://127.0.0.1:8787";
const env = Object.fromEntries(
  execSync("supabase status -o env", { encoding: "utf8" })
    .split("\n")
    .filter((l) => l.includes("="))
    .map((l) => {
      const i = l.indexOf("=");
      return [l.slice(0, i), l.slice(i + 1).replace(/^"|"$/g, "")];
    }),
);
const API = env.API_URL;
const SERVICE = env.SERVICE_ROLE_KEY;
const ANON = env.ANON_KEY;
if (!API || !SERVICE || !ANON) throw new Error("supabase status gave no keys -- is it running?");

const service = { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, "Content-Type": "application/json" };

/** Superuser SQL against the local container. Fixtures only; the app never does this. */
const sql = (q) =>
  execSync("docker exec -i supabase_db_chingo psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q", { input: q, encoding: "utf8" });
const created = [];
let failures = 0;

const ok = (cond, label) => {
  console.log(`${cond ? "PASS" : "FAIL"}: ${label}`);
  if (!cond) failures += 1;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// -- fixtures ----------------------------------------------------------------------------

async function user(handle, { discoverable = true } = {}) {
  const email = `smoke-${handle}-${Date.now()}@test.local`;
  const password = "smoke-test-password";
  let res = await fetch(`${API}/auth/v1/admin/users`, {
    method: "POST",
    headers: service,
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (!res.ok) throw new Error(`create user ${res.status}: ${await res.text()}`);
  const { id } = await res.json();
  created.push(id);

  // Seeded as superuser through psql, the same way test-db.sh does: the service role is
  // deliberately not allowed to write profiles, and the test should not need what the
  // server must not have.
  sql(`insert into public.profiles (id, handle, is_16_plus, onboarded_at, discoverable)
       values ('${id}', '${handle}${String(Date.now()).slice(-5)}', true, now(), ${discoverable})`);

  res = await fetch(`${API}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) throw new Error(`sign in ${res.status}: ${await res.text()}`);
  const { access_token } = await res.json();
  return { id, handle, jwt: access_token };
}

async function block(blocker, blocked) {
  sql(`insert into public.blocks (blocker, blocked) values ('${blocker}', '${blocked}')`);
}

// One cell in Dolores Park: lat 37.7596..37.7608, lon -122.42745..-122.4261.
const CELL = { lat: 37.76, lon: -122.427 };
const spot = (i) => ({ lat: CELL.lat + i * 0.0001, lon: CELL.lon + i * 0.00005 });

/** Connect and collect everything received, keyed by sender id. */
function connect(u, pos) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`${WORKER}/v1/presence?lat=${pos.lat}&lon=${pos.lon}`, [`bearer.${u.jwt}`]);
    const seen = new Map();
    const gone = new Set();
    ws.addEventListener("message", (e) => {
      const m = JSON.parse(e.data);
      if (m.t === "pos") seen.set(m.id, m);
      if (m.t === "gone") { seen.delete(m.id); gone.add(m.id); }
    });
    ws.addEventListener("open", () => resolve({ ws, seen, gone, send: (p) => ws.send(JSON.stringify(p)) }));
    ws.addEventListener("error", () => reject(new Error("refused")));
  });
}

// -- the run ------------------------------------------------------------------------------

try {
  const health = await fetch(`${WORKER.replace(/^ws/, "http")}/healthz`).then((r) => r.text()).catch(() => "");
  if (health !== "ok") throw new Error(`worker not reachable at ${WORKER}; run ./scripts/dev-backend.sh`);

  console.log("creating six people...");
  const [ana, bo, cass, dee, eli, hidden] = await Promise.all([
    user("ana"), user("bo"), user("cass"), user("dee"), user("eli"), user("ghost", { discoverable: false }),
  ]);

  // 1. Hidden is refused.
  let refused = false;
  try { await connect(hidden, spot(0)); } catch { refused = true; }
  ok(refused, "a hidden person is refused at the door");

  // 2. Four in the cell: the floor holds.
  const a = await connect(ana, spot(0));
  const b = await connect(bo, spot(1));
  const c = await connect(cass, spot(2));
  const d = await connect(dee, spot(3));
  await sleep(400);
  ok([a, b, c, d].every((p) => p.seen.size === 0), "four people in a cell see nobody (k = 5)");

  // 3. A fifth arrives: everyone sees everyone.
  const e = await connect(eli, spot(4));
  await sleep(600);
  ok([a, b, c, d, e].every((p) => p.seen.size === 4), "a fifth arrives and everyone sees the other four");
  ok(a.seen.get(eli.id)?.handle?.startsWith("eli") === true, "a pos carries the handle and accent");

  // 4. Blocks, both directions. Blocks are read at connect, so bo reconnects.
  await block(ana.id, bo.id);
  b.ws.close();
  await sleep(300);
  const b2 = await connect(bo, spot(1));
  await sleep(600);
  ok(!b2.seen.has(ana.id), "the blocked person cannot see the blocker");
  ok(!a.seen.has(bo.id) || a.gone.has(bo.id), "the blocker cannot see the blocked");
  ok(b2.seen.has(cass.id) && a.seen.has(cass.id), "...and both still see everyone else");

  // 5. A teleport is dropped: cass jumps 5 km in under a second.
  await sleep(1100);
  c.send({ lat: CELL.lat + 0.045, lon: CELL.lon });
  await sleep(500);
  const cassSeenByAna = a.seen.get(cass.id);
  ok(cassSeenByAna && Math.abs(cassSeenByAna.lat - spot(2).lat) < 0.0001, "a 5 km jump in a second is dropped");

  // A walk is not.
  await sleep(1100);
  c.send({ lat: spot(2).lat + 0.00005, lon: spot(2).lon, course: 90 });
  await sleep(500);
  ok(a.seen.get(cass.id)?.course === 90, "a real step is relayed with its course");

  // 6. Leaving sends gone.
  e.ws.close();
  await sleep(500);
  ok(a.gone.has(eli.id) && !a.seen.has(eli.id), "leaving sends `gone` and the bear is removed");
  // ...and the cell is back to four: the floor closes again.
  ok(a.seen.size === 0, "with four left the floor closes and nobody is drawn");

  for (const p of [a, b2, c, d]) p.ws.close();
} catch (err) {
  console.error("ERROR:", err.message);
  failures += 1;
} finally {
  await Promise.all(created.map((id) => fetch(`${API}/auth/v1/admin/users/${id}`, { method: "DELETE", headers: service })));
  console.log(`cleaned up ${created.length} throwaway users`);
}

console.log(failures === 0 ? "\nAll green." : `\n${failures} failing.`);
process.exit(failures === 0 ? 0 : 1);
