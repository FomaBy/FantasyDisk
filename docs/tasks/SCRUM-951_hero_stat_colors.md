# SCRUM-951 — Hero Select: color-code character attributes by stat identity

Статус: done
Приоритет: medium
Роль: Back-end
Контур: Codex
Owner: `/root/scrum951-hero-stat-colors`
Thread: `/root`
Версия: 0.2.1
Jira: SCRUM-951

## Contract

- Complete the required PixelLab/UI-director mockup and accessible palette
  spec before changing runtime UI.
- Store colors in one shared Hero Select constants map; no class blending and
  no duplicated per-screen literals.
- Color the bar plus visible stat name/value while retaining name, number, bar
  length and concise hover/focus tooltip as non-color signals.
- Preserve current Hero Select geometry and global-frame safe zones at
  1280×720, 1920×1080 and 2560×1440.

## Locked scope

- `scripts/ui/hero_select_constants.gd`
- HS4 stat color application only in `scripts/ui_screens.gd`
- focused SCRUM-951 test and exact Hero Select UI docs/mockup/evidence paths

## Evidence

PixelLab source `395cbafb-358b-4f46-9b95-019b67bf5c48`, seed 951, completed and
was visually accepted as the textless styling reference. Export SHA-256:
`cece86b399e0b2026f988ed3d8d8e122c1c069878398f9484670851da176af02`.
Runtime implementation and verification are now unblocked.

First Metal screenshot review found that legacy 720p ultra-compact mode hid all
stat names/values. A second PixelLab responsive mockup was queued as source
`c02b9d90-d4c0-431d-af5d-560cb4c3625b` (seed 9511), and the contract now uses a
2×4 compact grid so color never becomes the only visible meaning carrier. The
compact export completed and passed visual inspection; SHA-256:
`17e7d490ef014f59e0fee80b45210dd4e9c4bf33dbf671f34502bb2367e68c2c`.

Runtime now uses the shared stat-ID palette and responsive 2×4/1×8 grid.
Focused palette/contrast/tooltip/hero-refresh/safe-zone coverage and the
existing Hero Select layout gate pass at 720p/1080p/2K. Final Metal captures
are stored under `docs/design/previews/scrum951_hero_stat_colors/runtime/`.

Final gates: `scrum951_hero_stat_colors_test`,
`hero_select_pixellab_layout_test`, `ui_no_overlap_matrix_test`,
`runtime_smoke_ui_test`, `gamepad_inrun_ui_test`, and isolated-userdata full
`runtime_smoke_test` — PASS. PixelLab config smoke and both `create_ui_asset`
jobs completed without exposing credentials.

Disk cleanup: task-local `.godot`, isolated userdata, capture scratch,
worktree and local branch are removed after the origin/dev landing; final Jira
comment records the completed cleanup.

## Independent QA verdict — PASS (2026-07-11)

QA owner: `/root/qa_storm_1037`. Verified from clean `origin/dev`
`b509671f4`; production code and runtime assets remained read-only.

- PixelLab MCP live lookup returned `completed` for both recorded source IDs:
  `395cbafb-358b-4f46-9b95-019b67bf5c48` (`448×600`) and
  `c02b9d90-d4c0-431d-af5d-560cb4c3625b` (`688×384`). Names, dimensions,
  source/preview SHA-256 values and manifests all agree; no credentials were
  printed or stored.
- The shared eight-stat map exactly preserves the documented accents. Strength
  keeps canonical bar `#D84A3A` and accessible name/value `#E05B4C`; all text
  colors pass the documented 4.5:1 contrast floor on `#171613`.
- The real carousel refresh path changes values/fill lengths without changing
  stat identity colors. Every row keeps localized name, numeric value, bar
  length and concise hover/focus tooltip as redundant non-color meaning.
- Committed Metal captures and an independent Compatibility/ANGLE Metal
  windowed run on Apple M4 Pro were inspected. 1280×720 uses a readable 2×4
  grid; 1920×1080 and 2560×1440 use 1×8. Stat content stays inside the dossier
  and hollow global-frame safe zones with no ornament overlap. The windowed
  capture lifecycle exited normally after all four hero fixtures.
- PASS gates: `scrum951_hero_stat_colors_test.gd`,
  `hero_select_pixellab_layout_test.gd`, `ui_no_overlap_matrix_test.gd`,
  `runtime_smoke_ui_test.gd`, `gamepad_inrun_ui_test.gd`, and isolated
  `HOME`/`XDG_DATA_HOME`/`--user-data-dir` full `runtime_smoke_test.gd`.
  The known dummy-renderer screenshot warning was non-fatal and both UI/full
  runtime suites reached their success markers.

QA verdict: **PASSED**. No bug issue required.

Disk cleanup: independent Metal capture output was restored to the tracked
baseline; QA scratch userdata, disposable `.godot/`, generated UID sidecars,
worktree and local branch are removed after evidence/routing pushes.
