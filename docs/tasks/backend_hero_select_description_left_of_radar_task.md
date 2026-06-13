# Задача Для Back-end-Агента: Выбор героя — описание героя слева от розы ветров

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-224
QA: in_progress (2026-06-13)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«На экране выбора героя описание героя надо слева от розы ветров всё-таки
поместить».

Сейчас (ui_screens.gd): роза-радар `HeroStatRadar` — плавающий виджет в правом
верхнем углу (после SCRUM-206 увеличен/опущен); досье героя
`HeroSelectDossierPanel` (354-360) — в content_row. Пользователь хочет, чтобы
ОПИСАНИЕ героя располагалось СЛЕВА от розы ветров (рядом, в одной зоне), а не
отдельно/в другом месте.

## Требования
1. Разместить блок описания/досье героя СЛЕВА от розы ветров — так, чтобы
   описание и роза читались как единая правая информ-панель: слева текст
   (имя класса, описание, сильные/слабые стороны, оружие, возвышение,
   приоритетные атрибуты), справа от него — роза характеристик.
2. Сохранить компоновку: крупный портрет слева экрана, лента героев снизу
   (карусель только картинки), выбор кнопкой. Меняется размещение описания
   относительно розы, остальное не ломать.
3. Отступы к рамкам соблюдать (урок SCRUM-206: роза не залезает на рамку);
   описание и роза не пересекаются между собой и с рамками — правило
   «UI не наползает» (qa_protocol), тест фактических rect на 1280x720/1600x900/
   2560x1440.
4. Обновление при смене героя: описание и роза синхронно меняются при выборе
   другого героя в карусели.
5. Тест (smoke): фактическое дерево — блок описания левее розы (rect описания
   правый край ≤ левый край розы, с зазором); нет пересечений; имя/описание
   присутствуют.
6. Скриншот/дамп в build/qa/; CHANGELOG; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_character_select, HeroStatRadar:77,
  HeroSelectDossierPanel:354, размещение радара)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Описание героя слева от розы ветров, единой панелью, с зазорами к рамкам.
- [x] Синхронное обновление при выборе героя; no-overlap на 3 размерах.
- [x] Smoke/no-overlap зелёные; rect dump в build/qa/; CHANGELOG.

## Документация
docs/design/current_game_state.md (экран выбора героя).

## Dispatcher Note (2026-06-13)
Dispatched to Back-end Codex thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as part of a serialized UI batch with SCRUM-225/SCRUM-226 because all three touch `scripts/ui_screens.gd`. Work with reasoning set to High; do not switch the run/model effort to low. Keep Jira live-synced: in-progress now, then update task/board/Jira on completion, with QA left to the board worker. Duplicate audit: older hero-select/radar Jira items SCRUM-30, SCRUM-110 and SCRUM-206 are already done; this task remains canonical for the new description-left-of-radar layout. If any motion/timing/animation scope appears, create/update an Animator handoff instead of doing animation work in Back-end.

## Result Summary (2026-06-13)

Implemented in `scripts/ui_screens.gd`: `HeroSelectDossierPanel` now contains `HeroSelectInfoRadarRow`, with `HeroSelectDossier` on the left and `HeroSelectRadarPanel` / `HeroStatRadar` on the right. Portrait-left, bottom thumbnail strip and choose flow are preserved. Runtime smoke now asserts the dossier/description right edge stays left of the radar panel with a gap on 1280x720, 1600x900 and 2560x1440, and writes `build/qa/hero_select_radar_rects.md`.

Verification:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd` — passed.
