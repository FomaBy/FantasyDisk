# Задача Для Back-end-Агента: Выбор оружия — показать спрайт оружия, убрать стиль кнопки, проще и читаемее

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-225
QA: in_progress (2026-06-13)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«На выборе оружия надо показывать спрайт оружия и убрать стиль кнопки, сделать
попроще и более читаемо».

Сейчас `_show_weapon_select` (ui_screens.gd:1987-2009): вертикальный список из
крупных ТЕКСТОВЫХ кнопок 680x84 с многострочным текстом (title + description +
«Range/AoE/Cooldown») и тяжёлым стилем кнопки. Спрайта оружия НЕТ.
Спрайты оружия есть: `assets/sprites/weapons/<weapon_id>.png`.

## Требования
1. **Показать спрайт оружия** для каждого варианта: иконка/спрайт
   `assets/sprites/weapons/<weapon_id>.png` слева от текста (или сверху карточки).
   Размер читаемый (~96-128px), RGBA.
2. **Убрать тяжёлый стиль кнопки**: вместо громоздкой текстурной кнопки —
   чистая лёгкая карточка/строка (спрайт + название + краткое описание +
   ключевые статы компактно). Hover — мягкая подсветка; клик — выбор. Зона
   клика — вся карточка.
3. **Проще и читаемее**: убрать визуальный шум, выровнять колонками
   (спрайт | название+описание | статы), единый ритм; статы — компактно и
   подписанно по-русски (Дальность/Радиус/Перезарядка вместо Range/AoE/Cooldown).
4. Раскладка: варианты в ряд или сетку (если влезает) либо аккуратный вертикальный
   список; на узком окне без переполнения. Кнопка «Назад» и Escape сохраняются.
5. Правило «UI не наползает» (qa_protocol): карточки/спрайты/текст не пересекаются
   на 1280x720 и 2560x1440 (тест фактических rect).
6. Тест (smoke): фактическое дерево — у каждого варианта есть узел спрайта оружия
   (TextureRect с корректным путём), нет старого тяжёлого button-стиля; выбор
   оружия по клику работает (selected_weapon_id ставится).
7. Скриншот/дамп в build/qa/; CHANGELOG; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_weapon_select:1987-2009)
- assets/sprites/weapons/<weapon_id>.png (все оружия классов)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Спрайт оружия показан для каждого варианта.
- [x] Тяжёлый button-стиль убран — лёгкая читаемая карточка; статы по-русски.
- [x] Выбор по клику работает; no-overlap; smoke зелёный; dump в build/qa/.

## Документация
docs/design/current_game_state.md (экран выбора оружия).

## Dispatcher Note (2026-06-13)
Dispatched to Back-end Codex thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as part of a serialized UI batch with SCRUM-224/SCRUM-226 because all three touch `scripts/ui_screens.gd`. Work with reasoning set to High; do not switch the run/model effort to low. Keep Jira live-synced: in-progress now, then update task/board/Jira on completion, with QA left to the board worker. If any motion/timing/animation scope appears, create/update an Animator handoff instead of doing animation work in Back-end.

## Result Summary (2026-06-13)

Implemented a lightweight `_make_weapon_select_card()` in `scripts/ui_screens.gd`. Each weapon option is still a full-card clickable `Button`, but visually uses flat card styling instead of the parchment/wax button frame. Cards show `WeaponSelectSprite_<weapon_id>` from `assets/sprites/weapons/<weapon_id>.png` with Berserk legacy aliases (`sword`, `axe`, `hammer` -> `two_handed_*`), Russian stat labels, title and description. Back/Escape and click selection are preserved.

Verification:
- Runtime smoke checks sprite paths, non-`StyleBoxTexture` card styling, Russian stat labels and click selection; dump: `build/qa/weapon_select_clean_layout.md`.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd` — passed.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 35b79e06 (ветка dev)

Проверено (фактически):
- **Ассеты**: спрайты оружия берсерка `two_handed_sword/axe/hammer.png` есть;
  алиас-карта `sword/axe/hammer → two_handed_*` (ui_screens.gd:2106-2108).
- **Код**: `_make_weapon_select_card()` (2019) — `Button` `WeaponOption_<id>`,
  узел `WeaponSelectSprite_<id>` (2048), flat-стиль; клик ставит
  `game.selected_weapon_id` (2008); «Назад»/Escape сохранены.
- **Целевой тест не пустышка** (runtime_smoke:4818): на каждый weapon_id —
  читаемая высота, normal/hover НЕ `StyleBoxTexture`, `WeaponSelectSprite_<id>`
  с правильным путём текстуры, русские метки («Дальность»+«Перезарядка»), и клик
  (`pressed.emit()`) выставляет `selected_weapon_id`. Прошёл.
- **Регрессия (4×smoke)**: runtime / animation / meta / targeting — зелёные;
  `ui_no_overlap_matrix_test` — passed (1152/1280/1469/2560).
- **Визуал** (`build/qa/scrum225/weapon_select.png`): 3 карточки (Двуручный
  меч/топор/молот) со спрайтом слева, колонки спрайт | название+описание | статы
  по-русски (Дальность/Радиус/Перезарядка), без тяжёлой button-рамки; перекрытий нет.
- **Дамп** `build/qa/weapon_select_clean_layout.md` присутствует. CHANGELOG —
  строка 224/225/226/227 покрывает («PNG-спрайт и русские статы в лёгких
  кликабельных карточках»).

Краевые случаи:
- Клик действительно выбирает оружие (тест ассертит `selected_weapon_id`).
- Легаси-алиасы берсерка резолвятся в `two_handed_*` спрайты.
- no-overlap на 1280/1600/2560.

Баги: нет.

Примечание (не баг): в `current_game_state.md` нет отдельной строки про
SCRUM-225 (спрайт+рус.статы) — экран описан обобщённо, деталь покрыта CHANGELOG.
Доковая мелочь, не блокер.
