import { connection } from "next/server";
import { getDataSource } from "@/lib/data/source";

// Polled by the Display every 60 s.
export async function GET() {
  await connection();
  const source = await getDataSource();
  const snapshot = await source.getSnapshot(new Date());
  return Response.json(snapshot, { headers: { "Cache-Control": "no-store" } });
}
