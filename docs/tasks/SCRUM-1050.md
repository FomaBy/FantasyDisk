# SCRUM-1049 Design: единый UI-kit, PixelLab reference sheet и credits icon

Статус: in_progress
Версия: 0.2.1
Jira: SCRUM-1050
Контур: Codex
Owner: Design main
Thread: /root/ui_unification_design
Locked paths: `docs/design/mockups/scrum1050_ui_unification/**`, `docs/design/references/scrum1050_ui_unification/**`, `docs/design/previews/scrum1050_ui_unification*`, `assets/sprites/ui/icons/credits/**`, design result section in this file

## Scope

- Inventory current screen/button visual families.
- Create and validate `ui_plan.json` before PixelLab generation.
- Create PixelLab UI-kit/reference sheet with common states and documented screen accents, including Codex.
- Create transparent icon-only gratitude asset: two gauntleted hands supporting a glowing heart/spark; no baked text.
- Record exact safe zones, texture/content margins, source IDs/tags and responsive notes.

Runtime code is out of scope for this subtask.

## Design result

- Status: design-ready for Back-end handoff.
- Planning gates: `ui_plan.report.json` and `gratitude_icon_ui_plan.report.json` both `decision: ready_for_image`, `ok: true`, zero errors/warnings; both layout guide reports `ok: true`.
- Inventory/spec: `docs/design/mockups/scrum1050_ui_unification/screen_button_inventory.md`, `docs/design/mockups/scrum1050_ui_unification/spec.md`.
- PixelLab reference board: `docs/design/references/scrum1050_ui_unification/scrum1050_unified_ui_reference_sheet_688x384.png`; preview/debug under `docs/design/previews/scrum1050_ui_unification_reference_sheet_688x384*.png`.
- PixelLab gratitude source: object `c1c1c353-e56e-405b-9adf-f1e6bd993152`; exported raw/alpha sources under `docs/design/references/scrum1050_ui_unification/`; runtime candidate `assets/sprites/ui/icons/credits/ui_icon_gratitude.png`.
- Icon QA: 256x256 RGBA, measured alpha bbox `(55,48)-(201,208)` inside strict x48/y48/w160/h160 safe box; transparent/partial/opaque = `51142/3195/11199`; 32/48/64/96 contact preview visually reviewed.
- Provenance: `docs/design/references/scrum1050_ui_unification/manifest.json`. Config-based PixelLab `get_balance` smoke PASS; no secrets printed/stored. New `create_ui_asset` board job was rejected before generation because the 20-40 generation UI cost exceeded the four-generation balance; approved `existing source reuse` exception used only already accepted PixelLab families. Gratitude icon still originated from PixelLab MCP; no fallback image model.
- Disk cleanup: none created beyond committed design/source/preview/runtime candidate files; no transient cache/worktree created.
- Runtime files/tests: none changed/run in Design scope; Back-end owns resolver, Codex/runtime, credits surface/button wiring and screenshot/smoke verification.

## Acceptance criteria

- Planning gate reports `ready_for_image`.
- PixelLab MCP provenance is recorded; no fallback image model is used.
- Preview/reference sheet and gratitude icon are readable and ready for Back-end handoff.
- No content zone overlaps decorative borders or ornaments.
