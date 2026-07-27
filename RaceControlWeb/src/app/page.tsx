import { Suspense } from "react";
import { callBackend } from "@/lib/server/backend";
import { HomeDashboard } from "./HomeDashboard";
import { LoadingState } from "@/components/StateViews";

// Depends on live backend data (seasons list) that cannot be resolved at build time.
export const dynamic = "force-dynamic";

export default async function Home() {
  const seasons = await callBackend<number[]>("/api/seasons");
  const defaultYear = seasons[0];
  return (
    <Suspense fallback={<LoadingState />}>
      <HomeDashboard defaultYear={defaultYear} />
    </Suspense>
  );
}
