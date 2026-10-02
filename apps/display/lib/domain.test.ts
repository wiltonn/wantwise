import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  agoText,
  countdownUntil,
  formatPrice,
  phaseOf,
  revisitAfterDays,
  thinkingAbout,
  waitProgress,
  type DisplayWant,
} from "./domain";
import { materialise } from "./data/fixtureSource";
import fixture from "../fixtures/wants.json";

// The same file WantWiseCore's Swift tests read.
const shared = JSON.parse(readFileSync(join(__dirname, "../../../docs/fixtures/countdown-cases.json"), "utf8")) as {
  countdown: { name: string; timeZone: string; now: string; revisitAt: string; expected: { kind: string; days?: number; text: string } }[];
  ago: { name: string; timeZone: string; createdAt: string; now: string; expected: string }[];
};

describe("shared countdown cases (docs/fixtures/countdown-cases.json)", () => {
  it.each(shared.countdown)("$name", (c) => {
    const result = countdownUntil(new Date(c.revisitAt), new Date(c.now), c.timeZone);
    expect(result.kind).toBe(c.expected.kind);
    expect(result.text).toBe(c.expected.text);
    if (c.expected.days != null) expect(result).toMatchObject({ days: c.expected.days });
  });

  it.each(shared.ago)("ago: $name", (c) => {
    expect(agoText(new Date(c.createdAt), new Date(c.now), c.timeZone)).toBe(c.expected);
  });
});

describe("revisitAfterDays (mirrors RevisitPolicy)", () => {
  it("lands at 4 pm local", () => {
    const now = new Date("2026-10-02T21:45:00-04:00");
    expect(revisitAfterDays(7, now, "America/Toronto").toISOString()).toBe(new Date("2026-10-09T16:00:00-04:00").toISOString());
  });
  it("keeps 4 pm across DST end", () => {
    const now = new Date("2026-10-30T10:00:00-04:00");
    expect(revisitAfterDays(7, now, "America/Toronto").toISOString()).toBe(new Date("2026-11-06T16:00:00-05:00").toISOString());
  });
});

const base: DisplayWant = {
  id: "a",
  title: "Headphones",
  imageUrl: null,
  sourceType: "screenshot",
  priceMinor: 4900,
  currency: "CAD",
  reason: "Mine hurt my ears",
  status: "waiting",
  createdAt: "2026-10-01T20:00:00.000Z",
  revisitAt: "2026-10-11T20:00:00.000Z",
  waitStartedAt: "2026-10-01T20:00:00.000Z",
  decidedAt: null,
};

describe("want helpers", () => {
  it("derives ready-to-reconsider from revisitAt", () => {
    expect(phaseOf(base, new Date("2026-10-11T19:59:59Z"))).toBe("waiting");
    expect(phaseOf(base, new Date("2026-10-11T20:00:00Z"))).toBe("readyToReconsider");
    expect(phaseOf({ ...base, status: "captured", revisitAt: null }, new Date())).toBe("needsReflection");
  });

  it("computes wait progress", () => {
    expect(waitProgress(base, new Date("2026-10-06T20:00:00Z"))).toBe(0.5);
    expect(waitProgress({ ...base, status: "stillWant" }, new Date())).toBeNull();
  });

  it("formats prices in the Want's own currency", () => {
    expect(formatPrice(4900, "CAD")).toBe("$49");
    expect(formatPrice(7999, "CAD")).toBe("$79.99");
    expect(formatPrice(1500, "JPY")).toBe("¥1,500");
    expect(formatPrice(null, "CAD")).toBeNull();
  });

  it("orders ready, then soonest waiting, then just captured; leaves decided out", () => {
    const now = new Date("2026-10-10T12:00:00Z");
    const wants: DisplayWant[] = [
      { ...base, id: "later", revisitAt: "2026-10-30T20:00:00Z" },
      { ...base, id: "decided", status: "noLongerWant" },
      { ...base, id: "captured", status: "captured", revisitAt: null },
      { ...base, id: "soon", revisitAt: "2026-10-11T20:00:00Z" },
      { ...base, id: "ready", revisitAt: "2026-10-09T20:00:00Z" },
    ];
    expect(thinkingAbout(wants, now).map((w) => w.id)).toEqual(["ready", "soon", "later", "captured"]);
  });
});

describe("fixture source privacy filter", () => {
  const snapshot = materialise(fixture, new Date("2026-10-02T14:00:00-04:00"));

  it("omits Wants hidden from the Display and deleted Wants", () => {
    const titles = snapshot.wants.map((w) => w.title);
    expect(titles).not.toContain("Birthday surprise for Mom");
    expect(titles).not.toContain("Deleted test want");
    expect(titles).toContain("Wireless headphones");
  });

  it("exposes only display-safe fields", () => {
    expect(Object.keys(snapshot)).toEqual(["child", "timeZone", "wants", "generatedAt"]);
    expect(Object.keys(snapshot.child)).toEqual(["displayName"]);
    for (const w of snapshot.wants) {
      expect(Object.keys(w).sort()).toEqual(
        ["createdAt", "currency", "decidedAt", "id", "imageUrl", "priceMinor", "reason", "revisitAt", "sourceType", "status", "title", "waitStartedAt"],
      );
    }
  });
});
