# FEATURE(debug): Дебаг-режим в опциях — клик по карте телепортит/ведёт персонажа

Статус: done
Приоритет: medium
Роль: Back-end (UI + геймплей)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-375
QA: in_progress (2026-06-14)
Связано: SCRUM-341 (3 вкладки настроек), SCRUM-275 (скролл «Управление»)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Dispatch Note — 2026-06-14
Documentation dispatcher routed SCRUM-375 to existing Back-end window
`019eabd9-780b-78a2-9f4b-e7203d659ef2`. Duplicate audit: existing
`route_debug_free_pick` coverage is route-map-only debug selection, not combat
arena click-to-move/teleport. Back-end scope only; keep reasoning High/no low.

## Контекст (запрос пользователя)
«Надо в опциях ввести дебаг-режим, в котором на карте можно в любой момент любую
точку выбрать как точку, куда пойдёт персонаж».

Настройки: ui_screens.gd `_show_settings_menu` (тоггл-паттерн ScreenShakeToggle
2068-2077, `_style_checkbox`, save_game_settings). Ключи —
game_settings.gd DEFAULTS (9-22). Движение игрока — player.gd `_physics_process`
(294, velocity по вводу), `global_position`.

## Требования
1. **Тоггл «Дебаг-режим»** в настройках (по умолчанию ВЫКЛ), персистится через
   game_settings (новый ключ `debug_mode`, в DEFAULTS). ВАЖНО: НЕ добавлять новую
   вкладку (настройки фиксируются на 3 слота, SCRUM-341) — положить тоггл строкой
   в существующую вкладку (напр. низ «Управление» или «Экран»), со стилем чекбокса.
2. **Поведение при ВКЛ дебаге**: в забеге (на боевой арене) выбор любой точки →
   персонаж идёт/телепортируется в эту мировую точку. «Куда пойдёт» — реализовать
   move-to-point: задаём целевую точку, игрок движется туда (плавно), новый ввод
   WASD/новый клик перехватывает управление. (Опционально модификатор/двойной клик
   = мгновенный телепорт.)
3. **Не конфликтовать с атакой/прицеливанием**: ЛКМ и курсор уже используются для
   атаки/aim (aim_mode «по курсору»). Для дебаг-перемещения использовать
   НЕконфликтующий ввод (ПКМ, либо средняя кнопка, либо Shift+ЛКМ) — на усмотрение,
   но без слома боя/прицела. Активно ТОЛЬКО при debug_mode = ON.
4. Преобразование экранных координат в мировые (с учётом камеры/зума 2K-арены),
   клампить точку в пределах арены. Опционально — маркер цели на полу.
5. Дебаг-режим не должен влиять на обычный геймплей при ВЫКЛ; не ломать паузу,
   уже существующие клики/ввод, runtime.
6. Тест (smoke): тоггл сохраняется/читается; при debug_mode ON выбранная точка
   задаёт цель и игрок к ней движется (проверка смены target/позиции); при OFF —
   обычное управление, клик не телепортит. Скрин настроек с тогглом в build/qa/.
7. CHANGELOG; current_game_state; systems/menus_ui + combat.

## Files / Assets / IDs
- scripts/game_settings.gd (DEFAULTS — ключ debug_mode)
- scripts/ui_screens.gd (_show_settings_menu — тоггл в существующей вкладке;
  _style_checkbox; save_game_settings)
- scripts/main.gd (загрузка/применение debug_mode; роутинг ввода клика)
- scripts/player.gd (_physics_process 294 — move-to-point/телепорт; global_position;
  преобразование экран→мир, кламп по арене)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Тоггл «Дебаг-режим» в настройках (в существующей вкладке, не 4-я), персистится; по умолчанию выкл.
- [x] При ВКЛ: выбор точки на арене ведёт/телепортит персонажа в неё; неконфликтующий ввод (не ломает атаку/прицел).
- [x] При ВЫКЛ: обычное управление, клик не перемещает; пауза/ввод/runtime не сломаны.
- [x] smoke зелёный; скрин настроек; CHANGELOG; current_game_state.

## Документация
docs/design/systems/menus_ui.md, docs/design/systems/combat.md, current_game_state.

## Result — 2026-06-14

Done by Codex Back-end.

- Added persisted `debug_mode` setting in `scripts/game_settings.gd`, loaded/saved
  through `Main` and exposed in the existing «Управление» settings tab as
  `DebugModeToggle`; no fourth tab was added.
- Added combat-only debug click routing in `scripts/main.gd`: right-click or
  Shift+left-click assigns a smooth arena move target, middle-click teleports to
  the clamped arena point. Screen coordinates are converted through the active
  viewport canvas transform, so camera/zoom are respected.
- Added `Player.debug_set_move_target()` and target-driven movement; WASD input
  cancels the debug target and keeps normal player control authoritative.
- OFF state leaves normal aim/attack/pause/runtime behavior unchanged.
- Updated `CHANGELOG.md`, `docs/design/current_game_state.md`,
  `docs/design/systems/menus_ui.md`, `docs/design/systems/combat.md`, and
  `docs/design/systems/persistence.md`.

Verification:
- `git diff --check` — PASS
- `runtime_smoke_ui_test.gd` — PASS
- `runtime_smoke_test.gd` — PASS
- QA artifact: `build/qa/scrum375/settings_debug_mode_toggle.md`; PNG capture is
  intentionally skipped in headless dummy renderer to avoid false renderer
  warnings, and the same helper saves PNG in non-headless runs.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически):
- **Тоггл + персист**: `game_settings.gd:20` `"debug_mode": false` (default OFF),
  bool-валидация (45); `DebugModeToggle` (ui_screens.gd:2130) — строка в существующей
  вкладке «Управление» (3 вкладки: 1 def + 3 call `_make_settings_tab`, НЕ 4-я);
  main.gd load(454)/save(473)/root-meta(458/481).
- **Визуал** `build/qa/cap_settings_debug_375.png` + QA-dump: вкладка «Управление»
  показывает «Дебаг-режим: Выкл.» чекбоксом (P478,842 S300×72), читаем, без
  наложения; скролл SCRUM-275 цел.
- **Click-to-move** (main.gd:704+): combat-only + OFF-safe
  (`if not debug_mode_enabled or not combat_active or paused: return`); RMB/Shift+LMB
  = smooth move target, MMB = телепорт; screen→world через canvas_transform (камера/
  зум учтены), кламп по арене.
- **Player** (player.gd:137-336): `_debug_move_target` + move-to-target; WASD
  (manual_direction) отменяет дебаг-цель — ручное управление приоритетно.
- **Тесты**: `runtime_smoke_test` (тоггл save/read + ON задаёт цель/движение + OFF
  клик не телепортит) + `runtime_smoke_ui_test` — passed.

Acceptance:
- [x] Тоггл в существующей вкладке (не 4-я), персистится, default выкл.
- [x] ВКЛ: выбор точки ведёт/телепортит; неконфликтующий ввод (RMB/MMB, не ломает aim/атаку).
- [x] ВЫКЛ: обычное управление, клик не перемещает; пауза/ввод/runtime целы.
- [x] smoke зелёный; скрин настроек; доки.

Баги: нет.
