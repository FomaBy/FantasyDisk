# SCRUM-926 — Priest battle-start prayer choice UI

Статус: done
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

Disk cleanup: disposable `.godot/` removed; clean task worktree scheduled for immediate removal after the routing push.

## QA-Вердикт (2026-07-11)

Статус: FAILED

Независимый QA проверил clean-cache `origin/dev` `ec7c77aca`.
Production-код и art layer не изменялись.

Пройдено:

- PixelLab asset `3c4556a9-e19f-42dd-972b-47d572264e66`, seed 926;
  source/runtime SHA-256
  `8eb1406434e8c02ad291fcaf2f39b16ff6d9c87a0781cd4ef190dc750305046c`;
  files byte-identical;
- `scrum926_priest_prayer_choice_test.gd`, `priest_kit_test.gd`,
  `ui_no_overlap_matrix_test.gd`, `gamepad_inrun_ui_test.gd`,
  `gamepad_full_flow_smoke_test.gd`, `runtime_smoke_ui_test.gd` и clean-cache
  `runtime_smoke_test.gd` — PASS;
- 1280×720, 1920×1080, 2560×1440 и live resize: content zones,
  hitboxes/focus внутри пустых card interiors, ornament non-overlap;
  свежие Metal captures проверены вручную;
- canonical IDs/order/effects: `prayer_wrath` +20% all damage,
  `prayer_mending` +2 HP/s, `prayer_aegis` -20% incoming damage; no hidden
  auto-pick, exactly-once selection, elite spawn after selection, non-Priest
  synchronous fast path — PASS;
- physical mouse submit и gamepad B/D-pad/A paths — PASS.

Блокирующий дефект: physical keyboard Escape идёт по ветке
`pause` в `Main._input`; `_can_open_pause_dossier()` срабатывает раньше
`ui_escape_action`, поэтому над mandatory `BattlePrayerChoiceScreen` открывается
`PauseStatsMenuRoot`, а focus уходит на `PauseSettingsButton`.
Штатный focused test ложно-зелёный, потому что вызывает callable
напрямую, а не physical `Main._input` path.

Баг: SCRUM-1044.

## Повторный QA-Вердикт (2026-07-11)

Статус: PASSED

SCRUM-1044 исправлен в `737dd7c20` и независимо принят на fresh
`origin/dev` `855b5e412`. KEY_ESCAPE, keyboard `ui_cancel` и B теперь
сохраняют mandatory prayer modal, его focus и pause без постороннего
Pause dossier. Physical mouse double-click, keyboard Right/Enter и gamepad
D-pad/A применяют exact canonical prayer и продолжают combat ровно
один раз.

Повторно PASS: official SCRUM-926 focused 720p/1080p/2K/live resize,
Priest kit, no-overlap, gamepad in-run/full-flow, runtime UI и clean-cache full
runtime. PixelLab/runtime art остался byte-identical с SHA-256
`8eb1406434e8c02ad291fcaf2f39b16ff6d9c87a0781cd4ef190dc750305046c`; visual,
content-zone, prayer effect/order и non-Priest contracts не изменились.

Баги: нет; SCRUM-1044 — PASSED / Готово.
