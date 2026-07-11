# SCRUM-926 — Priest battle-start prayer choice UI

Статус: in_progress
Контур: Codex
Owner: `/root/scrum926_prayer`
Jira: SCRUM-926

## Contract

- Only Priest sees a mandatory choice at the start of each combat.
- Exactly three runtime-driven prayers are shown in canonical order:
  `prayer_wrath`, `prayer_mending`, `prayer_aegis`.
- The selection happens before `Player.on_battle_start()` and before elite/boss
  spawning; combat stays paused until one valid prayer is selected.
- Mouse, keyboard and controller share stable focus/hover/pressed geometry.
- Non-Priest combat remains synchronous and never creates the prayer screen.
- Runtime content stays inside the true empty frame zone at 1280×720,
  1920×1080 and 2560×1440, including live resize.

## Architecture decision

Keep the SCRUM-925 data and `Player.select_battle_prayer()` API as the single
source of truth. `CombatDirector` gates final battle-start hooks behind the UI
only when `battle_prayer_choices()` is non-empty and no prayer is active. The
temporary first-prayer auto-selection is removed from `Player.on_battle_start`.

## Evidence

PixelLab MCP asset `3c4556a9-e19f-42dd-972b-47d572264e66` (seed 926) is
accepted as the unchanged runtime frame. Source SHA-256:
`8eb1406434e8c02ad291fcaf2f39b16ff6d9c87a0781cd4ef190dc750305046c`.
All three pre-generation plans report `ready_for_image`; the post-generation
content compositor reports `ok: true` for every declared zone. Source request,
manifest, layouts, guides and reports live under:

- `docs/design/mockups/scrum926_priest_prayer/`
- `docs/design/references/scrum926_priest_prayer/`
- `docs/design/previews/scrum926_priest_prayer/`

Implementation removes the temporary hidden auto-pick, gates
`Player.on_battle_start()` and elite/boss spawn behind the selected prayer, and
keeps non-Priest combat synchronous. `tests/scrum926_priest_prayer_choice_test.gd`
passes 1280×720, 1920×1080, 2560×1440 plus live resize, pause/order, exact ID,
double-submit, focus ring, non-cancellable input and non-Priest isolation.
`tests/priest_kit_test.gd` passes the updated no-auto-pick contract. Real
OpenGL/Metal captures for all three target sizes are committed in the runtime
preview directory.

Disk cleanup: `.godot/` will be removed with the task worktree after independent QA handoff.
