# BUG: Выбор героя — роза ветров внутри рамки; вынести в правый верхний угол, описание слева, без наползаний

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-231
QA: in_progress (2026-06-13)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«На экране выбора персонажа розу ветров надо вынести из рамки и поместить в
правом верхнем углу, а описание героя должно быть слева от розы ветров и не
"наступать" на другие элементы интерфейса».

Регрессия после SCRUM-224: розу `HeroStatRadar` положили в HBox `HeroSelectInfoRadarRow`
ВНУТРИ панели-рамки `HeroSelectDossierPanel` (ui_screens.gd:355-375). Из-за этого
роза внутри рамки. Нужно: роза — ПЛАВАЮЩИЙ виджет в правом верхнем углу экрана
(вне рамки досье), описание героя — СЛЕВА от розы, всё без пересечений.
(Прежняя SCRUM-206 уже делала розу плавающей top-right — вернуть этот принцип,
но с описанием слева от неё.)

## Требования
1. Розу ветров вынести из панели-рамки досье и сделать плавающим виджетом в
   ПРАВОМ ВЕРХНЕМ углу экрана (anchor right/top, отступы к краям/рамке — урок
   SCRUM-206/227: не впритык, с зазором, не залезает на рамку/шапку).
2. Описание/досье героя — СЛЕВА от розы (в одной верхней информ-зоне справа:
   слева текст, справа роза), но описание НЕ должно наползать на розу, шапку
   «УРОВЕНЬ»/портрет, ленту героев и другие элементы.
3. Правило «UI не наползает» (qa_protocol): фактические global_rect розы,
   описания, портрета, шапки, селектора возвышения, кнопок — попарно без
   пересечений на 1280x720 / 1600x900 / 2560x1440.
4. Синхронное обновление при выборе другого героя (роза и описание меняются).
5. Тест (smoke): роза — top-right плавающая (parent не панель досье, anchor_right≈1,
   с зазором); описание левее розы (правый край описания ≤ левый край розы −
   зазор); no-overlap матрица hero select зелёная.
6. Скриншот/дамп в build/qa/; CHANGELOG; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_character_select, HeroStatRadar:77,
  HeroSelectInfoRadarRow:362, HeroSelectDossierPanel:355)
- tests/runtime_smoke_test.gd (no-overlap hero select)

## Acceptance Criteria
- [x] Роза вне рамки, в правом верхнем углу, с отступами; описание слева от неё.
- [x] Ничего не наползает на 3 размерах (тест фактических rect).
- [x] Синхронное обновление; 6 smoke зелёные; скрин/дамп в build/qa/; CHANGELOG.

## Документация
docs/design/current_game_state.md (экран выбора героя).

## Dispatcher Notes

- 2026-06-13: dispatched to Back-end Codex thread
  `019eabd9-780b-78a2-9f4b-e7203d659ef2` as an allowed `0.1.4`
  feature-freeze bug/regression fix. Keep reasoning High; do not switch to low.
  Keep task file, board, and Jira live-synced. Scope is Back-end/UI layout only;
  if any motion/animation work appears, create/update an Animator handoff instead
  of doing animation work here.

## Result (2026-06-13)

Fixed the hero select regression without expanding feature scope:

- `HeroSelectRadarPanel` is now a floating top-right child of
  `HeroSelectScreen`, outside `HeroSelectDossierPanel`.
- `HeroSelectDossierPanel` contains only the hero dossier text/controls.
- `HeroSelectRadarReserve` keeps layout space on the right, so the dossier stays
  to the left of the radar instead of sliding underneath it.
- Runtime smoke assertions now check:
  - radar parent is `HeroSelectScreen`;
  - radar is anchored top-right;
  - dossier/description right edge stays left of the radar with a clear gap;
  - radar is outside the dossier frame;
  - radar does not overlap header, portrait panel, dossier controls or thumbnail
    strip at 1280x720, 1600x900 and 2560x1440.
- QA rect dump updated: `build/qa/hero_select_radar_rects.md`.
- Docs updated: `CHANGELOG.md`, `docs/design/current_game_state.md`.

Verification:

- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_combat_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_progression_economy_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_weapon_mechanics_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_boss_elite_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed. Existing non-fatal `Lambda capture at index 0 was freed` log still appears before the pass line and is unrelated to SCRUM-231.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: f8f1409a (ветка dev)

Проверено (фактически):
- **Код/тест**: smoke (runtime_smoke:293) ассертит `radar_panel.get_parent()
  == HeroSelectScreen` И `anchor_right ≥ 0.99` — иначе fail «floating top-right
  widget outside the dossier frame». Не пустышка.
- **Дамп** `build/qa/hero_select_radar_rects.md` (1280×720): досье-панель правый
  край = 832, радар-панель с 866 (зазор 34px, ВНЕ досье), правый край радара 1258
  при ширине 1280 (top-right, отступ 22px). Портрет вынесен в отдельный
  `HeroSelectPortraitPanel` слева.
- **Визуал** (`build/qa/scrum231/hero_select_radar_fixed.png`): роза
  «Характеристики» — компактный плавающий виджет в ПРАВОМ ВЕРХНЕМ углу СНАРУЖИ
  рамки досье; описание/досье слева от неё; портрет слева; лента героев снизу.
  Перекрытий нет. Соответствует требованию пользователя и принципу SCRUM-206.
- **Тесты**: `runtime_smoke_ui_test` + регрессия (animation/meta/targeting) —
  зелёные.

Acceptance:
- [x] Роза вне рамки, в правом верхнем углу с отступами; описание слева.
- [x] Ничего не наползает на 3 размерах (тест rect + no-overlap matrix).
- [x] Синхронное обновление (один путь `_show_character_select`); скрин/дамп; CHANGELOG.

Краевые случаи:
- Радар-parent = экран (не панель досье) — структурно вне рамки.
- Зазор досье↔радар 34px; радар↔правый край 22px — без впритык (урок SCRUM-206/227).

Баги: нет. **Эта задача устраняет регрессию SCRUM-224** (QA там был FAILED) —
экран выбора героя теперь соответствует намерению пользователя.
