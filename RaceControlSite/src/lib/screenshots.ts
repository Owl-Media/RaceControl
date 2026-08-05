// The screenshot manifest.
//
// `src` is null for every entry today: there are no real captures in the repo,
// so <Screenshot> falls back to a hand-built UI illustration and labels it as
// one. Capturing a real set needs an iOS simulator, an Android emulator and a
// browser pointed at a live backend, none of which exist in CI.
//
// TO ADD A REAL SCREENSHOT
//   1. Capture the screen. Use one fixed season + round across ALL platforms so
//      the images are comparable — the same discipline docs/VISUAL_PARITY.md
//      already requires for parity review. Note which fixture you used below.
//   2. Save it to RaceControlSite/public/screenshots/<id>-<platform>.png.
//   3. Set `src` on that entry. The illustration and its "UI illustration"
//      label disappear automatically; no page or component needs editing.

export type ScreenshotMeta = {
  /** Path under /public once a real capture exists. Null means illustration. */
  src: string | null;
  alt: string;
  caption: string;
};

export const SCREENSHOTS = {
  replay: {
    src: null,
    alt: "Race replay showing the running order at a given lap, with position change arrows, tyre compounds and lap times.",
    caption: "Race replay — running order at lap 32",
  },
  schedule: {
    src: null,
    alt: "Season calendar listing rounds with flags, locations, dates and an up-next banner.",
    caption: "Races — the season calendar",
  },
  trackmap: {
    src: null,
    alt: "Circuit detail showing a track outline with numbered corner markers and highlighted DRS zones.",
    caption: "Circuits — track map with numbered corners",
  },
  telemetry: {
    src: null,
    alt: "Telemetry view with speed and throttle traces for two drivers overlaid across lap distance.",
    caption: "Telemetry — two-driver speed trace overlay",
  },
  flags: {
    src: null,
    alt: "Flags timeline listing safety car and yellow flag periods with their lap ranges and reasons.",
    caption: "Flags — safety car and flag periods",
  },
  standings: {
    src: null,
    alt: "Driver championship standings with points, wins and gap-to-leader bars.",
    caption: "Standings — drivers' championship",
  },
  strategy: {
    src: null,
    alt: "Tyre strategy timeline showing each driver's stints coloured by compound.",
    caption: "Tyre strategy — stint timeline",
  },
} satisfies Record<string, ScreenshotMeta>;

export type ScreenshotId = keyof typeof SCREENSHOTS;
