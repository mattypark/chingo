// The same cases as ios/ChinGoDesign/Tests/ChinGoEngineTests. If a number here and a number
// there disagree, one of the two implementations has drifted.

import { describe, expect, it } from "vitest";
import {
  DISCOVERY_RADIUS_M,
  INTERACTION_RADIUS_M,
  K_ANONYMITY_FLOOR,
  RELEASE_RADIUS_M,
  cellId,
  isPlausible,
  livePosition,
  metres,
  regionId,
  type LiveQuery,
} from "../src/rules";

const open = (overrides: Partial<LiveQuery> = {}): LiveQuery => ({
  viewerIsDiscoverable: true,
  subjectIsDiscoverable: true,
  metresApart: 50,
  cellOccupants: K_ANONYMITY_FLOOR,
  ...overrides,
});

describe("cells", () => {
  it("nearby points share a cell, and the id matches the Swift format", () => {
    // Dolores Park, two spots a few metres apart.
    expect(cellId(37.7596, -122.4270)).toBe(cellId(37.7597, -122.4271));
    expect(cellId(37.7596, -122.4270)).toMatch(/^c-?\d+_-?\d+$/);
  });

  it("throws away precision", () => {
    // 37.7596 / 0.00135 = 27970.07 and 37.7598 / 0.00135 = 27970.2: same cell. The obvious
    // "a few metres south" point, 37.7590, is 27969.6 -- across the boundary. Cells are
    // grid squares, not circles around you.
    expect(cellId(37.7596, -122.4270)).toBe(cellId(37.7598, -122.4266));
    expect(cellId(37.7596, -122.4270)).not.toBe(cellId(37.7590, -122.4270));
    expect(cellId(37.7596, -122.4270)).not.toBe(cellId(37.7700, -122.4270));
  });

  it("folds the antimeridian into one place", () => {
    expect(cellId(0, 180)).toBe(cellId(0, -180));
  });

  it("a region holds a 4×4 block of cells", () => {
    // Build positions from the cell grid itself so the test does not depend on where a
    // particular landmark happens to fall inside a region.
    const p = 0.00135;
    const regionStartLat = 6900 * 4 * p; // a region boundary, ~37.26°N
    const lon = -122.427;
    const cellsIn = (n: number) => regionId(regionStartLat + (n + 0.5) * p, lon);
    expect(cellsIn(0)).toBe(cellsIn(3));
    expect(cellsIn(0)).not.toBe(cellsIn(4));
    expect(cellsIn(0)).toMatch(/^r-?\d+_-?\d+$/);
  });
});

describe("distance", () => {
  it("matches known distances", () => {
    // One degree of longitude at the equator is 111.19 km.
    expect(metres({ lat: 0, lon: 0 }, { lat: 0, lon: 1 })).toBeCloseTo(111_195, -2);
    expect(metres({ lat: 37.7596, lon: -122.4270 }, { lat: 37.7596, lon: -122.4270 })).toBe(0);
  });
});

describe("live position — the safety gate", () => {
  it("is precise only when every gate is open", () => {
    expect(livePosition(open())).toBe("precise");
  });

  it("is reciprocal in both directions", () => {
    expect(livePosition(open({ viewerIsDiscoverable: false, cellOccupants: 500 }))).toBe("suppressed");
    expect(livePosition(open({ subjectIsDiscoverable: false, cellOccupants: 500 }))).toBe("suppressed");
  });

  it("keeps the k-anonymity floor", () => {
    expect(livePosition(open({ cellOccupants: K_ANONYMITY_FLOOR - 1 }))).toBe("suppressed");
    expect(livePosition(open({ cellOccupants: K_ANONYMITY_FLOOR }))).toBe("precise");
  });

  it("appears at the discovery ring and stays until the release ring", () => {
    expect(livePosition(open({ metresApart: DISCOVERY_RADIUS_M }))).toBe("precise");
    expect(livePosition(open({ metresApart: DISCOVERY_RADIUS_M + 1 }))).toBe("suppressed");
    expect(livePosition(open({ metresApart: DISCOVERY_RADIUS_M + 1, wasVisible: true }))).toBe("precise");
    expect(livePosition(open({ metresApart: RELEASE_RADIUS_M, wasVisible: true }))).toBe("precise");
    expect(livePosition(open({ metresApart: RELEASE_RADIUS_M + 1, wasVisible: true }))).toBe("suppressed");
  });

  it("a handshake outranks every gate", () => {
    const q = open({
      viewerIsDiscoverable: false,
      subjectIsDiscoverable: false,
      metresApart: 5_000,
      cellOccupants: 1,
      hasMutualHandshake: true,
    });
    expect(livePosition(q)).toBe("precise");
  });

  it("a distance that is not a distance draws nothing", () => {
    expect(livePosition(open({ metresApart: Number.NaN }))).toBe("suppressed");
    expect(livePosition(open({ metresApart: Number.POSITIVE_INFINITY }))).toBe("suppressed");
    expect(livePosition(open({ metresApart: -1 }))).toBe("suppressed");
  });

  it("the radii nest", () => {
    expect(INTERACTION_RADIUS_M).toBeLessThan(DISCOVERY_RADIUS_M);
    expect(DISCOVERY_RADIUS_M).toBeLessThan(RELEASE_RADIUS_M);
  });
});

describe("plausibility", () => {
  it("teleporting is implausible, commuting is not", () => {
    expect(isPlausible(400_000, 60)).toBe(false);
    expect(isPlausible(30_000, 1_800)).toBe(true);
    expect(isPlausible(10, 0)).toBe(false);
  });
});
