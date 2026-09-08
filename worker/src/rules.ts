// The presence rules, ported from ChinGoEngine so the server can enforce what the client
// promises. `Presence.swift` and `GeoCell.swift` are the source of truth; this file must
// agree with them, and `test/rules.test.ts` carries the same cases as the Swift tests so a
// drift shows up as a red test on one side or the other.

/** ~150 m at the equator. Matches `GeoCell.degreesPerCell`. */
export const DEGREES_PER_CELL = 0.00135;

/** A region is what one Durable Object owns: a 4 × 4 block of cells, about 600 m square. */
export const CELLS_PER_REGION = 4;

/** Matches `Presence.kAnonymityFloor`. */
export const K_ANONYMITY_FLOOR = 5;

/** Matches `Presence.discoveryRadiusMetres` / `interactionRadiusMetres` / `releaseRadiusMetres`. */
export const DISCOVERY_RADIUS_M = 150;
export const INTERACTION_RADIUS_M = 80;
export const RELEASE_RADIUS_M = 200;

/** Matches `Plausibility.maxSpeedKmH`. Generous on purpose: a train is not a spoofer. */
export const MAX_SPEED_KMH = 900;

/** Fold longitude into −180..<180 so ±180 is one place, not two. Same as the Swift. */
function foldLongitude(lon: number): number {
  return ((((lon + 180) % 360) + 360) % 360) - 180;
}

function quantise(lat: number, lon: number, precision: number): [number, number] {
  const clampedLat = Math.min(Math.max(lat, -90), 90);
  return [
    Math.floor(clampedLat / precision),
    Math.floor(foldLongitude(lon) / precision),
  ];
}

/** The coarse cell a position resolves to. Identical output to `GeoCell(latitude:longitude:)`. */
export function cellId(lat: number, lon: number): string {
  const [a, b] = quantise(lat, lon, DEGREES_PER_CELL);
  return `c${a}_${b}`;
}

/** The region a position belongs to — the Durable Object's name. */
export function regionId(lat: number, lon: number): string {
  const [a, b] = quantise(lat, lon, DEGREES_PER_CELL * CELLS_PER_REGION);
  return `r${a}_${b}`;
}

export interface LatLon {
  lat: number;
  lon: number;
}

/** Haversine metres. Same radius as `Geo.metres`. */
export function metres(a: LatLon, b: LatLon): number {
  const earthRadius = 6_371_000;
  const toRad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * toRad;
  const dLon = (b.lon - a.lon) * toRad;
  const lat1 = a.lat * toRad;
  const lat2 = b.lat * toRad;
  const h =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLon / 2) * Math.sin(dLon / 2) * Math.cos(lat1) * Math.cos(lat2);
  return 2 * earthRadius * Math.asin(Math.min(1, Math.sqrt(h)));
}

export type LiveVisibility = "suppressed" | "precise";

export interface LiveQuery {
  viewerIsDiscoverable: boolean;
  subjectIsDiscoverable: boolean;
  metresApart: number;
  cellOccupants: number;
  hasMutualHandshake?: boolean;
  wasVisible?: boolean;
}

/**
 * Whether one person may be drawn where they actually stand. Every condition is a gate.
 * Port of `Presence.livePosition(for:)`; read the comments there for why each line exists.
 */
export function livePosition(q: LiveQuery): LiveVisibility {
  if (!Number.isFinite(q.metresApart) || q.metresApart < 0) return "suppressed";
  if (q.hasMutualHandshake) return "precise";
  if (!q.viewerIsDiscoverable || !q.subjectIsDiscoverable) return "suppressed";
  if (q.cellOccupants < K_ANONYMITY_FLOOR) return "suppressed";
  const limit = q.wasVisible ? RELEASE_RADIUS_M : DISCOVERY_RADIUS_M;
  return q.metresApart <= limit ? "precise" : "suppressed";
}

/** Port of `Plausibility.isPlausible`. Catches a teleport, not a walk. */
export function isPlausible(metresMoved: number, secondsElapsed: number): boolean {
  if (!(secondsElapsed > 0)) return false;
  const kmh = (metresMoved / secondsElapsed) * 3.6;
  return kmh <= MAX_SPEED_KMH;
}
