import { connection } from "next/server";
import { getDataSource } from "@/lib/data/source";
import DisplayClient from "@/components/DisplayClient";

// Sets the 1920×1080 stage scale before first paint so there's no jump on load.
const fitStage = `(function(){var s=Math.min(innerWidth/1920,innerHeight/1080);document.documentElement.style.setProperty('--stage-scale',String(s));})();`;

export default async function DisplayPage({ searchParams }: { searchParams: Promise<{ feature?: string }> }) {
  await connection();
  // ?feature=N starts on a given Want: handy for design review and screenshots.
  const requested = Number((await searchParams).feature);
  const initialFeatured = Number.isInteger(requested) && requested > 0 ? requested : 0;
  const source = await getDataSource();
  const snapshot = await source.getSnapshot(new Date());
  return (
    <>
      <script dangerouslySetInnerHTML={{ __html: fitStage }} />
      <DisplayClient initial={snapshot} initialFeatured={initialFeatured} />
    </>
  );
}
