# Задача Для Back-end-Агента: Возвышения — у кнопки старта показывать изменения ТОЛЬКО выбранного уровня

Статус: done
Приоритет: normal
Роль: Back-end (UI)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-230
QA: in_progress (2026-06-13)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## PM Override (2026-06-13)

Пользователь уточнил: всю текущую board нужно доделать в версии `0.1.4`.
Эта уже существующая board-задача возвращена из backlog `0.1.5` в текущий
релиз и отправлена Back-end владельцу. Новые задачи после этой директивы всё
ещё оформляются отдельно, но текущая board должна быть закрыта до релиза.

## Контекст (запрос пользователя)
«Для возвышений каждый уровень надо писать только изменения этого уровня возле
кнопки начать игру».

Сейчас `ascension_modifier_lines(level)` (progression_data.gd:1813) возвращает
КУМУЛЯТИВНЫЙ список (все усложнения 1..level), и `AscensionModsLabel`
(ui_screens.gd:423) показывает их все. Пользователь хочет: при выбранном уровне
возвышения показывать ТОЛЬКО изменение(я), которое добавляет ЭТОТ уровень
(дельта уровня), рядом с кнопкой старта забега.

## Требования
1. Добавить data-аксессор «изменение конкретного уровня» — например
   `ascension_level_change(level) -> String/Array`: вернуть title+description
   усложнения, добавляемого ИМЕННО на этом уровне (entry с level == выбранный),
   без предыдущих. Уровень 0 — «без усложнений».
2. У кнопки старта забега (hero select, рядом с «Выбрать»/началом игры) показать
   эту дельту выбранного уровня компактным читаемым текстом по-русски: «Уровень N:
   <что добавляется>». При смене уровня селектором — текст обновляется.
3. Кумулятивный полный список (если нужен где-то ещё, напр. тултип/кодекс) можно
   оставить, но у кнопки старта — ТОЛЬКО дельта текущего уровня.
4. Правило «UI не наползает»: текст дельты не пересекается с кнопками/розой/
   досье (qa_protocol), на 1280x720 и 2560x1440.
5. Тест (smoke): для уровня N текст содержит описание именно N-го усложнения и
   НЕ содержит описаний 1..N-1; уровень 0 — «без усложнений».
6. CHANGELOG (когда фриз снят); current_game_state.

## Files / Assets / IDs
- scripts/progression_data.gd (ascension_modifier_lines:1813, ASCENSION_MODIFIERS,
  новый ascension_level_change)
- scripts/ui_screens.gd (AscensionModsLabel:423, область кнопки старта)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] У кнопки старта показывается ТОЛЬКО изменение выбранного уровня возвышения.
- [x] Текст обновляется при смене уровня; уровень 0 — «без усложнений».
- [x] no-overlap; тест дельты (есть N, нет 1..N-1); 6 smoke зелёные; CHANGELOG.

## Документация
docs/design/current_game_state.md (возвышения/выбор героя).

## Dispatcher Redispatch (2026-06-13)

Отправлено в существующий Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`
как первый элемент очереди закрытия всей текущей board для `0.1.4`. Keep
reasoning High/no low. Scope Back-end/UI only; если всплывёт animation/motion
scope, создать/update Animator handoff вместо выполнения motion-работы.

## Result (2026-06-13)

Status: done.

Implemented Back-end/UI delta display for Ascension selection:
- Added `ProgressionData.ascension_level_change_line(level)` for exact selected-level text.
- Updated hero select `AscensionModsLabel` to show only the selected level delta near the start/choose area, while preserving cumulative `ascension_modifier_lines(level)` for HUD tooltip/codex use.
- Extended runtime smoke coverage for level 0 text, level 3 delta-only text, and hero select UI label content; hero select no-overlap matrix also checks `AscensionModsLabel` against the floating radar.
- Updated `CHANGELOG.md` and `docs/design/current_game_state.md`.

Verification:
- `runtime_smoke_ui_test.gd` — passed.
- `runtime_smoke_combat_test.gd` — passed.
- `runtime_smoke_progression_economy_test.gd` — passed.
- `runtime_smoke_weapon_mechanics_test.gd` — passed.
- `runtime_smoke_boss_elite_test.gd` — passed.
- `runtime_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 6b56d592 (ветка dev)

Проверено (фактически, прямой вызов аксессора):
- **Delta-only поведение**: `ProgressionData.ascension_level_change_line(level)`
  (progression_data.gd:974):
  - L0 → «Уровень 0: без усложнений.»
  - L1 → «Уровень 1: Закалённые враги …» (только ур.1)
  - L3 → «Уровень 3: Быстрая орда …» — **ТОЛЬКО ур.3, БЕЗ ур.1-2**.
  Кумулятив `ascension_modifier_lines(3)` при этом сохраняет все 3 записи
  (для тултипа/кодекса) — требование «оставить кумулятив где нужно» выполнено.
- **Целевой тест не пустышка** (runtime_smoke:4309-4322): ассертит L0 содержит
  «без усложнений»; L3 описывает только ур.3 И НЕ содержит изменений младших
  уровней; плюс кумулятив включает 1+2+3 и исключает 4+.
- **Тесты**: `runtime_smoke_ui_test`, `ui_no_overlap_matrix_test` (матрица также
  проверяет `AscensionModsLabel` против плавающего радара), animation, meta,
  targeting — все зелёные.
- **Доки**: CHANGELOG (SCRUM-230) + `current_game_state.md` (селектор возвышения
  показывает только дельту) обновлены.

Acceptance:
- [x] У кнопки старта — ТОЛЬКО изменение выбранного уровня (доказано L3=только ур.3).
- [x] Уровень 0 = «без усложнений»; текст обновляется при смене уровня (label
  ре-резолвится из аксессора в `_show_character_select`).
- [x] no-overlap (matrix + label-vs-radar); тест дельты; 6 smoke; CHANGELOG.

Краевые случаи:
- L0 (нет усложнений) — корректный нейтральный текст.
- Delta vs cumulative — разведены (дельта у старта, кумулятив у тултипа/кодекса).
- AscensionModsLabel не наползает на радар (no-overlap matrix зелёный).

Баги: нет.
