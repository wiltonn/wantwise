import { redirect } from "next/navigation";

// Milestone 4 adds /login and /setup in front of this. For now the fixture Display is the whole app.
export default function Home() {
  redirect("/display");
}
