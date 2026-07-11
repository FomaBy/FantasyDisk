# SCRUM-984 — QA: gold-frame menu rollout and Escape/map cleanup

Статус: done
Jira: SCRUM-984
Роль: QA
Контур: Codex
Owner / Thread: `/root/qa_loop_983`
Дата проверки: 2026-07-11

## QA-Вердикт (2026-07-11)

Статус: PASSED

Единый gold-shell rollout, compact Escape dossier и удаление устаревших map/manual-stat путей приняты. Контент всех проверенных экранов остаётся внутри пустой зоны рамки; активный бой не получает production gold-shell frame.

## Покрытие и результаты

- `tests/scrum981_gold_menu_shell_test.gd` — PASSED: Main Menu, Rest, Upgrade, Battle Reward, Victory, Defeat и live resize на 1280×720, 1920×1080, 2560×1440.
- `tests/scrum981_route_map_gold_shell_test.gd` — PASSED: Route Map safe/inner zones, hollow final frame, vertical-only navigation, отсутствие manual Attribute Shop FAB на трёх разрешениях.
- `tests/scrum982_987_988_attribute_shop_test.gd` — PASSED: удалён ручной paid-stat вход из Route/Rest/Shop/Event; обязательный post-combat Attribute Shop сохраняет 2/3 карточки в одном ряду, shared hollow shell, семантику и live resize.
- `tests/scrum983_escape_dossier_test.gd` — PASSED: 720p/1080p/2K geometry, content zones, tooltip/focus graph, live resize; Continue нейтральный, End Run danger.
- `tests/scrum993_shop_gold_shell_test.gd` — PASSED: Shop shell/content/tooltips на трёх разрешениях и live resize.
- `tests/ui_no_overlap_matrix_test.gd` — PASSED: Main Menu, Settings, Codex, Atlas, Route Map, Rest, Upgrade, battle/elite rewards, Shop, Attribute Shop, Level Up, Event, active combat HUD и связанные модальные состояния.
- `tests/gamepad_inrun_ui_test.gd` и `tests/gamepad_full_flow_smoke_test.gd` — PASSED: keyboard/gamepad focus и переходы, включая rewards/settings/combat/pause.
- `tests/runtime_smoke_ui_test.gd` и `tests/runtime_smoke_test.gd` — PASSED; runtime duplicate guard: 14,935 файлов.
- Независимый одноразовый runtime-probe — PASSED: после `_start_combat` `combat_active=true`, видимых `meta40/frame_border.png` shell-панелей нет; `UpgradeFabButton` и legacy Route Map right-arrow nodes отсутствуют.

## Визуальная проверка

Проверены runtime PNG без перекрытия орнамента и без выхода контента из safe-зон:

- `build/qa/scrum981/main_menu_1280x720.png`
- `build/qa/scrum981/main_menu_2560x1440.png`
- `build/qa/scrum981/route_map_1920x1080.png`
- `build/qa/scrum981/battle_reward_1280x720.png`
- `build/qa/scrum981/victory_1920x1080.png`
- `build/qa/scrum983/escape_dossier_1280x720.png`
- `docs/design/previews/scrum982_987_988_attribute_shop/runtime/atlas_three_offers_1280x720.png`
- `docs/design/previews/scrum993_shop_gold_shell/runtime/default_1920x1080.png`
- `docs/design/previews/scrum993_shop_gold_shell/runtime/default_2560x1440.png`

## Edge cases

- 720p compact layout, 1080p baseline, 2K wide layout и переход 2K→720p без потери hitbox/focus.
- Mouse, keyboard и gamepad paths; stale manual paid-stat entry недостижим во всех проверенных destination states.
- Active combat остаётся без общей декоративной gold frame; открытие Escape создаёт только dossier shell.
- Route Map не содержит legacy right-arrow control; горизонтальный scroll отключён, доступные route nodes остаются в clipped canvas.

## Результат

Дефекты в рамках SCRUM-984 не обнаружены. Тикет готов к `Готово`.

Disk cleanup: disposable `.godot` cache and QA worktree removed after push (recorded in Jira final comment).
