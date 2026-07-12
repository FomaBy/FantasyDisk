# SCRUM-1075 — PixelLab mockup/spec for Atlas schema-6 3×6 constellation

Статус: done
Версия: 0.2.1
Jira: SCRUM-1075
Контур: Codex
Owner: Design / Codex
Thread/Worker: `/root`
Branch: `codex/scrum1075-atlas-mockup-resume`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1075-atlas-mockup-resume`
Parent implementation: SCRUM-1068

## Locked source-only scope

- `docs/design/mockups/scrum1068_constellation_3x6/**`;
- this task mirror and scoped Jira sync metadata at final routing.

Runtime scripts, production assets and SCRUM-1068/SCRUM-1073 implementation
files are excluded.

## Workflow

UI Director inventory → content-zone plan and `ready_for_image` gate →
PixelLab MCP source mockup → composited preview/debug overlay → seven-size fit
evidence. The accepted Meta40 art family and SCRUM-1070 reset-footer contract
remain the production implementation source; this package defines the new
schema-6 topology without promoting new runtime art.

## Result: ready for independent Design QA

- content inventory and exact 1920×1080 geometry are recorded in
  `docs/design/mockups/scrum1068_constellation_3x6/ui_plan.json`;
- compositor planning gate: `ready_for_image`, `47` elements, `0` errors,
  `0` warnings;
- PixelLab MCP config smoke passed through `get_balance`; no secret was printed,
  and the replenished account reported `2836` generations before this run;
- `create_ui_asset` completed as source ID
  `fde7794d-9f82-404c-8006-213e281a931a`, name
  `scrum1075_constellation_3x6_atlas_mockup`, seed `1075`, cost `40`;
- source export, deterministic checker-matte cleanup and Meta40 `bg_sky`
  assembly are recorded in `provenance.json` and the reference manifest;
- composited preview report: `ok: true`, all `15/15` content zones fit;
- responsive matrix: `1152×648`, `1280×720`, `1366×768`, `1600×900`,
  `1920×1080`, `2560×1440`, `3840×2160` — `7/7 PASS`;
- repository-wide `tests/runtime_smoke_test.gd` through `tools/godot_gate.py`:
  PASS on Godot 4.7 (the existing headless screenshot `texture_2d_get` warning
  remained non-fatal);
- visual inspection of the preview/debug overlay confirms that runtime text
  stays inside the generated calm interiors and does not cover frames,
  sockets, gems, dragon ornament or corner rails.

PixelLab's `create_ui_asset` is an element-kit generator rather than a true
full-screen compositor. The accepted generated sheet was therefore assembled
deterministically over the already accepted Meta40 sky underlay, exactly as the
MCP help recommends; no new frame/card was drawn after generation. Runtime
scripts and production assets remain untouched.

Evidence:

- source: `docs/design/references/scrum1068_constellation_3x6/atlas_schema6_source_688x384.png`;
- transparent postprocess: `docs/design/references/scrum1068_constellation_3x6/atlas_schema6_source_transparent_688x384.png`;
- preview: `docs/design/previews/scrum1068_constellation_3x6/atlas_schema6_preview_1920x1080.png`;
- debug overlay/report: adjacent `atlas_schema6_preview_debug_1920x1080.png`
  and `atlas_schema6_preview_report.json`;
- responsive report/contact sheet: adjacent `responsive_fit_report.json` and
  `responsive_contact_sheet.png`.

Disk cleanup: disposable worktree and `/tmp/scrum1075_*` are removed after
commit, direct push to `origin/dev`, Jira QA routing and scoped sync.
