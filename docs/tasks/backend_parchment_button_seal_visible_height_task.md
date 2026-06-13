# Задача Для Back-end-Агента: Кнопка пергамент+печать — печать должна быть видна (увеличить высоту, не сжимать)

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-227
QA: in_progress (2026-06-13)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Везде, где используется стиль кнопки пергамента с печатью, надо сделать так,
чтобы печать была видна — кнопку сделать с большей высотой, чтобы не сжимало».

Сейчас кадр кнопки — текстуры `assets/sprites/ui/frames/dark_fantasy/ui_df_button_*`
(primary/secondary/danger × idle/hover/pressed/disabled), сургучная печать
ВШИТА в кадр слева. Применяется через `_apply_fantasy_button_theme` / `_make_button`
(GLOBAL_BUTTON_FRAME_PATH:17). При низкой высоте кнопки 9-slice сжимает кадр по
вертикали → печать сплющивается/обрезается и плохо читается (видно на level-up,
коротких кнопках 48px, и др.).

## Требования
1. **Аудит всех кнопок** с этим пергамент+печать-стилем (по `_make_button` /
   `_apply_fantasy_button_theme`): где высота слишком мала и печать сжимается.
   Основные точки: меню (76px — проверить достаточно ли), «Назад» (48px),
   asc +/- (38px), level-up/reward, магазин, события и т.п.
2. **Поднять минимальную высоту** кнопок с печатью так, чтобы печать
   отображалась в правильной пропорции и читалась целиком. Подобрать высоту
   (ориентир ≥ 64-72px для кнопок с печатью; мелкие служебные «-»/«+» —
   решить: либо своя высота, либо отдельный кадр БЕЗ печати, чтобы не плющить).
3. **9-slice / поля кадра**: проверить nine-patch margins кадра кнопки — зона
   печати слева не должна растягиваться; если печать плющится даже при высоте —
   поправить patch_margin или вынести печать в фиксированный (не растягиваемый)
   левый сегмент. Зафиксировать решение в отчёте.
4. Текст внутри кнопки не должен налезать на печать (отступ слева под печать).
5. Не ломать раскладки: правило «UI не наползает» (qa_protocol) — кнопки с новой
   высотой не пересекаются с соседями на 1280x720 и 2560x1440.
6. Тест (smoke): фактические размеры — кнопки с печать-темой имеют высоту ≥
   порога; (если возможно) зона печати не сжата; ключевые экраны без overlap.
7. Скриншот/дамп в build/qa/ (level-up + меню как наглядные); CHANGELOG.

## Files / Assets / IDs
- scripts/ui_screens.gd (_make_button, _apply_fantasy_button_theme,
  GLOBAL_BUTTON_FRAME_PATH:17, все custom_minimum_size кнопок)
- assets/sprites/ui/frames/dark_fantasy/ui_df_button_*.png (+ .import nine-patch)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Печать видна целиком и читаема на кнопках с этим стилем.
- [x] Высоты кнопок подняты до достаточных; мелкие служебные кнопки не плющат печать (flat/no-seal style).
- [x] Текст не налезает на печать; no-overlap на 2+ разрешениях.
- [x] Smoke/no-overlap зелёные; dump в build/qa/; CHANGELOG.

## Документация
docs/design/current_game_state.md (UI-кнопки), visual_style_assets.md (если кадр меняется).

## Dispatcher Note (2026-06-13)
Dispatched to Back-end Codex thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as an addition to the serialized `scripts/ui_screens.gd` UI batch with SCRUM-224/SCRUM-225/SCRUM-226. Work with reasoning set to High; do not switch the run/model effort to low. Keep Jira live-synced: in-progress now, then update task/board/Jira on completion, with QA left to the board worker. If fixing small buttons requires new/reworked frame art rather than layout/theme integration, create/update a Design handoff instead of doing visual asset work in Back-end. If any motion/timing/animation scope appears, create/update an Animator handoff instead of doing animation work in Back-end.

## Result Summary (2026-06-13)

Implemented in `scripts/ui_screens.gd`: `_make_button()` now defaults to 68px height, `_button_state_style()` uses wider left 9-slice/content margins for the wax seal, and known low-height seal buttons were raised. Small utility controls (`Ascension +/-`, Upgrade FAB, keybinding buttons and settings dropdowns) were moved to `_make_compact_button()` / `_apply_compact_button_theme()` so they do not squeeze a wax-seal texture.

Decision/rationale: no new Design asset was needed. The existing accepted SCRUM-147 button frame works when used at sufficient height; controls that must remain compact are semantically form/utility controls, so a flat no-seal backend style is safer than stretching the seal.

Verification:
- Runtime smoke checks actual visible wax-seal button rects and writes `build/qa/parchment_button_seal_sizes.md`.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd` — passed.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 35b79e06 (ветка dev)

Проверено (фактически):
- **Код**: `_make_button()` дефолт `Vector2(420, 68)` (ui_screens.gd:4239);
  `_make_compact_button()` + `_apply_compact_button_theme()` присутствуют
  (4246/4293) — мелкие служебные контролы без печати; `_button_state_style()`
  с расширенным левым полем под печать.
- **Целевой тест не пустышка**: `_test_parchment_button_seal_sizes`
  (runtime_smoke:1147, тело 4879-4933) обходит ВСЕ видимые кнопки на 4 экранах
  (меню/выбор героя/выбор оружия/настройки); для кнопок с текстурой
  `/ui_df_button_` требует `rect.size.y ≥ 64 И custom_minimum_size.y ≥ 64`
  (печать не сжата) И что компактные (текст ≤2 симв., узкие) НЕ используют
  печать-текстуру. Прошёл.
- **Дамп** `build/qa/parchment_button_seal_sizes.md`: меню 76px, выбор
  героя/оружия/настройки 68px — все ≥ порога 64px, печати есть место.
- **Регрессия (4×smoke)**: runtime / animation / meta / targeting — зелёные;
  `ui_no_overlap_matrix_test` — passed (1152/1280/1469/2560).
- **Визуал** (`build/qa/scrum227/`): `main_menu_seals.png` — 6 кнопок меню с
  видимой красной сургучной печатью слева, не сплющена (76px); `level_up.png`
  (названный в задаче проблемный кейс) — окно leather+gold, варианты как
  text-field карточки (SCRUM-226), нижняя кнопка с печатью в правильной
  пропорции, перекрытий нет.
- **CHANGELOG**: объединённая строка SCRUM-224/225/226/227 присутствует.

Краевые случаи:
- 4 экрана покрыты тестом печати; компактные `+/-`/dropdown — flat no-seal
  (тест ассертит + видно в настройках).
- Level-up (где раньше печать сжималась на 48px) — печать читаема.
- no-overlap на 1280/1600/2560.

Баги: нет.
