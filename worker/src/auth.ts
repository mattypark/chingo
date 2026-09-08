// Verifying a Supabase access token at the edge, with nothing but Web Crypto.
//
// A phone presents the same JWT it uses against PostgREST. Checking it here means a
// position never reaches a Durable Object from anyone Supabase would not recognise, and it
// costs no round-trip: the project's public keys are fetched once and cached.

import type { Env } from "./env";

export interface Verified {
  /** auth.uid() — the profile id. */
  sub: string;
}

interface Jwk extends JsonWebKey {
  kid?: string;
}

const JWKS_TTL_MS = 10 * 60 * 1000;
let jwksCache: { fetchedAt: number; keys: Jwk[] } | null = null;

function base64UrlDecode(input: string): Uint8Array {
  const padded = input.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(input.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function decodeJson<T>(segment: string): T {
  return JSON.parse(new TextDecoder().decode(base64UrlDecode(segment))) as T;
}

async function jwks(env: Env): Promise<Jwk[]> {
  const now = Date.now();
  if (jwksCache && now - jwksCache.fetchedAt < JWKS_TTL_MS) return jwksCache.keys;
  const res = await fetch(`${env.SUPABASE_URL}/auth/v1/.well-known/jwks.json`);
  if (!res.ok) throw new Error(`jwks ${res.status}`);
  const body = (await res.json()) as { keys: Jwk[] };
  jwksCache = { fetchedAt: now, keys: body.keys };
  return body.keys;
}

async function importKey(header: { alg: string; kid?: string }, env: Env): Promise<CryptoKey> {
  if (header.alg === "HS256") {
    if (!env.SUPABASE_JWT_SECRET) throw new Error("hs256 token but no SUPABASE_JWT_SECRET");
    return crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(env.SUPABASE_JWT_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"],
    );
  }
  const key = (await jwks(env)).find((k) => k.kid === header.kid);
  if (!key) throw new Error("unknown kid");
  if (header.alg === "ES256") {
    return crypto.subtle.importKey("jwk", key, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  }
  if (header.alg === "RS256") {
    return crypto.subtle.importKey("jwk", key, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  }
  throw new Error(`unsupported alg ${header.alg}`);
}

function algorithm(alg: string): AlgorithmIdentifier | EcdsaParams {
  if (alg === "HS256") return { name: "HMAC" };
  if (alg === "ES256") return { name: "ECDSA", hash: "SHA-256" };
  return { name: "RSASSA-PKCS1-v1_5" };
}

/** Throws on anything short of a valid, unexpired, authenticated-role token. */
export async function verifySupabaseJwt(token: string, env: Env): Promise<Verified> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("malformed");
  const [h, p, s] = parts;
  const header = decodeJson<{ alg: string; kid?: string; typ?: string }>(h);
  const payload = decodeJson<{ sub?: string; exp?: number; aud?: string | string[]; role?: string }>(p);

  const key = await importKey(header, env);
  const ok = await crypto.subtle.verify(
    algorithm(header.alg),
    key,
    base64UrlDecode(s),
    new TextEncoder().encode(`${h}.${p}`),
  );
  if (!ok) throw new Error("bad signature");

  const now = Math.floor(Date.now() / 1000);
  if (!payload.exp || payload.exp <= now) throw new Error("expired");
  const aud = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  if (!aud.includes("authenticated") || payload.role !== "authenticated") throw new Error("wrong audience");
  if (!payload.sub) throw new Error("no subject");

  return { sub: payload.sub };
}
