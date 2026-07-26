"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import clsx from "clsx";
import { useHelpDrawer } from "@/components/HelpDrawerProvider";

const TABS = [
  { href: "/schedule", label: "Schedule" },
  { href: "/drivers", label: "Drivers" },
  { href: "/teams", label: "Teams" },
  { href: "/standings", label: "Standings" },
  { href: "/circuits", label: "Circuits" },
];

export function NavBar() {
  const pathname = usePathname();
  const { toggle: toggleHelp } = useHelpDrawer();
  const isActive = (href: string) => pathname === href || pathname?.startsWith(href + "/");

  return (
    <>
      <header className="sticky top-0 z-20 border-b border-border bg-background/95 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center gap-6 px-4 py-3">
          <Link href="/schedule" className="flex items-center gap-2 font-bold tracking-tight">
            {/* Plain <img>, not next/image: this is a fixed-size static asset and the
                production container doesn't ship `sharp`, so routing it through the
                on-demand /_next/image optimizer is unnecessary risk for no benefit. */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/icon-192.png" alt="" width={28} height={28} className="rounded-md" />
            RaceControl
          </Link>
          <nav className="hidden flex-1 items-center gap-1 overflow-x-auto sm:flex">
            {TABS.map((tab) => (
              <Link
                key={tab.href}
                href={tab.href}
                className={clsx(
                  "whitespace-nowrap rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
                  isActive(tab.href) ? "bg-surface text-foreground" : "text-muted hover:text-foreground",
                )}
              >
                {tab.label}
              </Link>
            ))}
          </nav>
          <Link
            href="/settings"
            className={clsx(
              "ml-auto rounded-md px-3 py-1.5 text-sm font-medium transition-colors sm:ml-0",
              isActive("/settings") ? "bg-surface text-foreground" : "text-muted hover:text-foreground",
            )}
          >
            Settings
          </Link>
          <button
            type="button"
            onClick={toggleHelp}
            aria-label="What am I looking at? Open page help"
            title="What am I looking at?"
            className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-border text-xs font-semibold text-muted transition-colors hover:border-foreground hover:text-foreground"
          >
            ?
          </button>
        </div>
      </header>

      <nav className="fixed inset-x-0 bottom-0 z-20 flex border-t border-border bg-surface pb-[env(safe-area-inset-bottom)] sm:hidden">
        {TABS.map((tab) => (
          <Link
            key={tab.href}
            href={tab.href}
            className={clsx(
              "flex flex-1 flex-col items-center gap-0.5 py-2 text-[11px] font-medium transition-colors",
              isActive(tab.href) ? "text-racing-red" : "text-muted",
            )}
          >
            <span className={clsx("h-1.5 w-1.5 rounded-full", isActive(tab.href) ? "bg-racing-red" : "bg-transparent")} />
            {tab.label}
          </Link>
        ))}
      </nav>
    </>
  );
}
