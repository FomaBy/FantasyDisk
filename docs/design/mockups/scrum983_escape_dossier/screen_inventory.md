# SCRUM-983 Escape Dossier Runtime Inventory

Read-only inventory from `origin/dev` `23e15aed0`. This file does not authorize
editing shared runtime before SCRUM-981 release.

## Current hierarchy and behavior

- `PauseStatsMenuRoot` → full-screen dim + `EscapeStatsPanelFrame`.
- The outer frame already points at `assets/sprites/ui/meta40/frame_border.png`
  with 160px source texture margins, `draw_center=false` and independently
  scaled content margins.
- `DossierHeader` currently owns `DossierTitleChip` and horizontal
  `PauseControlButtons`: Resume, Settings, End Run, Main Menu.
- `DossierBody` owns `HeroCard`/`HeroCardScroll` and
  `DerivedStatsPanel`/`DerivedStatsScroll`.
- Hero card: portrait/crest, class, weapon, level/XP, ascension, 8 base numeric
  rows, survival numeric rows, equipment sockets.
- Derived area: four group panels and compact numeric chips, followed by
  long-form Arsenal weapon/ultimate descriptions and equipment content.
- Existing base/derived rows are hoverable but not keyboard/gamepad-focusable;
  only the four actions are in the explicit focus ring.
- Existing tooltip text contains name, current value and one short description;
  it omits formula/source and influences even though Jira requests detailed
  explanations on hover/focus.
- Existing button danger is a tint variant on the shared action family; runtime
  tests must prove Resume/Main Menu never inherit that tint in any state.

## Planned migration without node-contract breakage

| Existing node/contract | SCRUM-983 action |
| --- | --- |
| `EscapeStatsPanelFrame` | preserve name/asset; update content geometry to exact SCRUM-981 safe rect |
| `DossierHeader` | keep title/hero summary only |
| `PauseControlButtons` | preserve node/button names and signals; move to fixed footer |
| `HeroCardScroll` | preserve; exact 720p scrollbar lane and focus-follow behavior |
| `BaseStatRow_<id>` | keep icon/name/value; make focusable tooltip target and grid at 1080p/2K |
| `DerivedStatsScroll` | preserve vertical-only scrolling and explicit scrollbar reserve |
| `DerivedStatChip_<id>` | keep compact line; make focusable; tooltip expands to formula/source/influences |
| `ArsenalPanel` / equipment | keep below numeric stats in existing scroll; no always-visible prose may displace the first numeric viewport at 720p |
| action signals | preserve `resume_requested`, `settings_requested`, `end_run_confirmed`, `main_menu_requested` |

## Locked-path boundary

Stage 1 owns only the adjacent SCRUM-983 mockup/reference/preview/task files.
`scripts/pause_stats_menu.gd`, shared tests and system docs remain read-only until
the dispatcher confirms SCRUM-981 has landed and released its locks.
