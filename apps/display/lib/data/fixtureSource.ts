import fixture from "../../fixtures/wants.json";
import { revisitAfterDays, type DisplaySnapshot, type DisplayWant, type SourceType, type WantStatus } from "../domain";
import type { DisplayDataSource } from "./source";

interface FixtureWant {
  id: string;
  title: string;
  image: string | null;
  sourceType: string;
  priceMinor: number | null;
  currency: string;
  reason: string | null;
  status: string;
  createdDaysAgo: number;
  /** Days from today's 4 pm revisit slot; negative = already past. Null = no waiting period chosen. */
  revisitInDays: number | null;
  decidedDaysAgo?: number;
  isVisibleOnDisplay?: boolean;
  deleted?: boolean;
}

interface FixtureFile {
  child: { displayName: string };
  timeZone: string;
  wants: FixtureWant[];
}

const DAY = 86_400_000;

/** Turns relative fixture offsets into concrete instants, then applies the same privacy filter Supabase will. */
export function materialise(file: FixtureFile, now: Date): DisplaySnapshot {
  const tz = file.timeZone;
  const wants: DisplayWant[] = file.wants
    .filter((w) => w.isVisibleOnDisplay !== false && !w.deleted)
    .map((w) => {
      // Captured a little before now on the given day, so "added earlier today" stays true.
      const createdAt = new Date(now.getTime() - w.createdDaysAgo * DAY - 2 * 3_600_000);
      const revisitAt = w.revisitInDays == null ? null : revisitAfterDays(w.revisitInDays, now, tz);
      return {
        id: w.id,
        title: w.title,
        imageUrl: w.image ? `/fixtures/${w.image}` : null,
        sourceType: w.sourceType as SourceType,
        priceMinor: w.priceMinor,
        currency: w.currency,
        reason: w.reason,
        status: w.status as WantStatus,
        createdAt: createdAt.toISOString(),
        revisitAt: revisitAt?.toISOString() ?? null,
        waitStartedAt: revisitAt ? createdAt.toISOString() : null,
        decidedAt: w.decidedDaysAgo != null ? new Date(now.getTime() - w.decidedDaysAgo * DAY).toISOString() : null,
      };
    });

  return {
    child: { displayName: file.child.displayName },
    timeZone: tz,
    wants,
    generatedAt: now.toISOString(),
  };
}

export const fixtureSource: DisplayDataSource = {
  async getSnapshot(now) {
    return materialise(fixture as FixtureFile, now);
  },
};
