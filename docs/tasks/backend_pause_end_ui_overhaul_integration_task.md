# Задача Для Back-end-Агента: Подключить SCRUM-330 Pause/Result UI Frame Kit

Статус: done
Приоритет: medium
Роль: Back-end
Версия: 0.1.5
Создано: 2026-06-14
Автор: Design handoff from SCRUM-330
Jira: SCRUM-407

## Dispatch
2026-06-14 — Documentation dispatcher routed to Back-end window
`019eabd9-780b-78a2-9f4b-e7203d659ef2` after SCRUM-406 completed and moved to QA.
Keep reasoning High / no low; Back-end runtime UI integration only. Preserve
existing dirty worktree changes from SCRUM-330/SCRUM-331/SCRUM-332 and complete
pause/result wiring without new Design/asset-generation scope.

## Autonomy / Approval
Пользователь заранее одобрил все in-scope изменения. Не спрашивать подтверждение,
если требования ясны. Соблюдать role boundaries: эта задача только про runtime
UI integration/layout/tests, без нового арта.

## Контекст

Design подготовил SCRUM-330 пакет для кластера «Пауза и финальные экраны»:
pause menu, pause dossier/stats, victory screen и death screen. Design не
менял `scripts/ui_screens.gd`, потому что runtime wiring принадлежит Back-end.

## Что Уже Сделано Design

- OpenAI/skill mockup:
  `docs/design/references/ui_overhaul_pause_end/pause_end_cluster_mockup.png`.
- Mockup/spec:
  `docs/design/mockups/ui_overhaul_pause_end/scrum330_pause_end_mockup_spec.md`.
- Runtime frame candidate:
  `assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png`.
- Result crests already present and accepted as runtime decorative assets:
  `assets/sprites/ui/result_crests/ui_crest_victory.png`,
  `assets/sprites/ui/result_crests/ui_crest_defeat.png`.
- Metadata:
  `docs/design/references/ui_overhaul_pause_end/scrum330_pause_end_metadata.json`.
- Previews:
  `docs/design/previews/ui_overhaul_pause_end_contact.png`,
  `docs/design/previews/ui_overhaul_pause_end_safe_zones.png`,
  `docs/design/previews/ui_overhaul_pause_end_mockup_1920x1080.png`.

## Что Нужно От Back-end

1. Подключить `ui_frame_pause_end_modal.png` к runtime экранам:
   - `scripts/ui_screens.gd::_show_pause_menu` / `_build_run_pause_menu`;
   - `scripts/ui_screens.gd::_show_pause_dossier_menu` или related pause stats UI;
   - `scripts/ui_screens.gd::_show_victory_screen`;
   - `scripts/ui_screens.gd::_show_death_screen`.
2. Сохранить текущую логику, навигацию, pause state, focus, keyboard/gamepad и
   действия кнопок.
3. Не растягивать whole-image frame по одной оси. Предпочтительно:
   пропорциональный `TextureRect` + внутренний `MarginContainer`, либо
   verified `StyleBoxTexture` с texture margins.
4. Runtime content must stay inside Design safe zone:
   - source frame size `1280x1024`;
   - safe rect `Rect2(170, 180, 940, 670)`;
   - content margins `Vector4(170, 180, 170, 174)`.
5. Не класть labels/buttons/icons/focus/click zones на dragon heads, wings, side
   columns, red gems, bottom crest или outer metal.
6. Result crests are decorative header art only in this pass. Do not put runtime
   text/buttons inside their ring openings.

## Files / Assets / IDs

| ID | Path / Value |
| --- | --- |
| `ui_frame_pause_end_modal` | `assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png` |
| `ui_crest_victory` | `assets/sprites/ui/result_crests/ui_crest_victory.png` |
| `ui_crest_defeat` | `assets/sprites/ui/result_crests/ui_crest_defeat.png` |
| modal source size | `1280x1024` |
| modal safe rect | `Rect2(170, 180, 940, 670)` |
| modal content margins | `Vector4(170, 180, 170, 174)` |

## Acceptance Criteria

- [ ] Pause menu uses SCRUM-330 modal frame or a runtime-equivalent layout based
      on the Design safe zones.
- [ ] Pause dossier/stats remains readable and does not overlap frame ornament.
- [ ] Victory/death screens keep decorative crests and actions inside safe zones.
- [ ] No one-axis distortion of decorative frame art.
- [ ] No content on decorative frame border/gems/dragon ornament.
- [ ] Existing navigation/focus/actions still work.
- [ ] UI/no-overlap checks pass at `1280x720`, `1920x1080`, `2560x1440`.
- [ ] Runtime smoke passes.

## Документация

Update `docs/design/systems/menus_ui.md`, `docs/design/current_game_state.md`
and `CHANGELOG.md` only for actual runtime integration changes.

## Result

2026-06-14 — Back-end runtime integration complete. `scripts/ui_screens.gd`
now applies `assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png`
to the run pause menu, victory screen and death screen using scaled
`StyleBoxTexture` margins from the SCRUM-330 safe/content zone. Victory/death
result crests remain decorative header art, and small 720p viewports use
adaptive crest/action button sizing so text/buttons stay inside the modal safe
area. `scripts/pause_stats_menu.gd` now uses the same modal frame for the pause
dossier/stats overlay, with a scrollable safe-zone content area for long stat
lists. Existing pause/resume/settings/end-run/main-menu and victory/death
actions were preserved.

Verification:
- PASS — `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd`
- PASS — `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS — `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
- QA dump — `build/qa/scrum330/pause_end_ui_no_overlap_matrix.md`

## QA-Вердикт (2026-06-14)
Статус: PASSED — live-интеграция SCRUM-330 pause/result modal frame

Проверено (фактически):
- **Рантайм-привязка** (ui_screens.gd `PAUSE_END_MODAL_PATH` + `_pause_end_modal_style`):
  modal-рамка применена к run pause menu, victory, death через scaled `StyleBoxTexture`
  из safe/content зон SCRUM-330; `pause_stats_menu.gd` — та же рамка для досье паузы
  со скроллируемой safe-зоной.
- **No-overlap дамп** `build/qa/scrum330/pause_end_ui_no_overlap_matrix.md`:
  pause_menu (5 кнопок, шаг 68px, без наложений), pause_stats, victory
  (`PauseEndModalPanel_victory` + `ResultCrest` + `VictoryNewRunButton`), death
  (`PauseEndModalPanel_death` + crest + `DeathRetryButton`) — на 5 разрешениях, без
  наложений; кресты — декоративный header, кнопки в safe-зоне.
- **Тесты**: `runtime_smoke_ui_test` + `ui_no_overlap_matrix_test` + `runtime_smoke_test`
  — все passed. Pause/resume/settings/end-run/main-menu + victory/death действия сохранены.

Acceptance:
- [x] Pause menu/dossier/victory/death на SCRUM-330 modal-рамке (scaled StyleBoxTexture).
- [x] Контент в safe-зоне, нет наложений на орнамент/самоцветы/драконов (rect-дамп).
- [x] Кресты декоративные; навигация/фокус целы; без one-axis искажения рамки.
- [x] no-overlap на 1280/1920/2560 + runtime_smoke PASS.

Статус done. Баги: нет. Закрывает live pause/end петлю 330+407.
