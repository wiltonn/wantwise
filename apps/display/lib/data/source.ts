import type { DisplaySnapshot } from "../domain";

/**
 * Where the Display gets its data. Fixture-backed now; Supabase-backed in Milestone 4 (DECISIONS.md D-012).
 * Implementations must only return display-safe fields and only Wants visible on the Display and not deleted.
 */
export interface DisplayDataSource {
  getSnapshot(now: Date): Promise<DisplaySnapshot>;
}

export async function getDataSource(): Promise<DisplayDataSource> {
  const kind = process.env.WANTWISE_DATA_SOURCE ?? "fixture";
  switch (kind) {
    case "fixture": {
      const { fixtureSource } = await import("./fixtureSource");
      return fixtureSource;
    }
    default:
      throw new Error(`Unknown WANTWISE_DATA_SOURCE "${kind}". Supabase arrives in Milestone 4.`);
  }
}
