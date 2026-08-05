import { type ReactNode } from "react";
import clsx from "clsx";
import { SCREENSHOTS, type ScreenshotId } from "@/lib/screenshots";

/**
 * Renders a product image for a given screen.
 *
 * There are no real screenshots in the repo yet (capturing them needs a device
 * or simulator per platform plus a live backend). Until there are, this renders
 * the hand-built UI illustration passed as `children`, wrapped in a frame and
 * explicitly LABELLED as an illustration — the one thing that must not happen
 * is a drawn mockup quietly reading as a real screenshot.
 *
 * To swap in a real capture: drop the PNG into /public/screenshots/ and add its
 * path to the entry in src/lib/screenshots.ts. This component then renders the
 * image instead, drops the illustration label, and the caller doesn't change.
 */
export function Screenshot({
  id,
  frame = "phone",
  children,
  className,
}: {
  id: ScreenshotId;
  frame?: "phone" | "browser" | "none";
  children: ReactNode;
  className?: string;
}) {
  const meta = SCREENSHOTS[id];
  const hasRealCapture = Boolean(meta.src);

  const body = hasRealCapture ? (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={meta.src!} alt={meta.alt} className="block w-full" />
  ) : (
    children
  );

  return (
    <figure className={clsx("flex flex-col gap-2", className)}>
      <Frame kind={frame}>{body}</Frame>
      <figcaption className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted">
        <span className="font-medium text-foreground">{meta.caption}</span>
        {!hasRealCapture && (
          <span className="rounded-full border border-border bg-surface-raised px-2 py-0.5 text-[11px] text-muted">
            UI illustration
          </span>
        )}
      </figcaption>
    </figure>
  );
}

function Frame({ kind, children }: { kind: "phone" | "browser" | "none"; children: ReactNode }) {
  if (kind === "none") {
    return <div className="overflow-hidden rounded-xl border border-border bg-surface">{children}</div>;
  }

  if (kind === "browser") {
    return (
      <div className="overflow-hidden rounded-xl border border-border bg-surface">
        <div className="flex items-center gap-1.5 border-b border-border bg-surface-raised px-3 py-2">
          <span className="h-2 w-2 rounded-full bg-border" />
          <span className="h-2 w-2 rounded-full bg-border" />
          <span className="h-2 w-2 rounded-full bg-border" />
        </div>
        {children}
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-[280px] overflow-hidden rounded-[28px] border-[6px] border-surface-raised bg-background shadow-none ring-1 ring-border">
      {children}
    </div>
  );
}
