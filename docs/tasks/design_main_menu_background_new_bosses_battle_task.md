# ART: Новый фон главного меню — 3 новых босса + герои в бою, гладкие текстуры

Статус: done
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-316
QA: in_progress (2026-06-14)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Надо нарисовать новый бекграунд для главного меню: пусть там будут 3 НОВЫХ
босса и пара персонажей, которые сражаются. Хочу картинку с более ГЛАДКИМИ
текстурами, чем сейчас».

Фон подключается через `MAIN_MENU_BACKGROUND`
(scripts/main.gd:73 = res://assets/backgrounds/main_menu_epic_battle.png),
рисуется в `_show_main_menu` (scripts/ui_screens.gd:113-117), размер 2560×1440.

## Требования
1. Новый эпичный фон главного меню, **2560×1440** (как текущий; PNG).
2. Композиция: **3 новых босса** (новые дизайны, не копии текущих врагов; каждый
   читаемо-разный силуэт — напр. колоссальный демон / нежить-титан / зверь-аберрация,
   на усмотрение художника в рамках канона) + **пара героев**, которые с ними
   СРАЖАЮТСЯ (динамика боя, эффекты заклинаний/ударов).
3. **Более гладкие текстуры**, чем в текущем фоне: чище рендер, мягче градиенты,
   меньше «шумной»/зернистой поверхности, аккуратные блики — но сохранить тёмное
   фэнтези и канон D&D.
4. Композиция дружелюбна к UI: оставить читаемую зону под логотип (верх-центр) и
   колонку кнопок меню (см. _show_main_menu) — фокус боя не перекрывает текст
   кнопок, достаточный контраст/затемнение под элементы UI.
5. Положить как новый ассет (напр. assets/backgrounds/main_menu_epic_battle_v2.png)
   и переключить `MAIN_MENU_BACKGROUND` на него; **старый файл оставить в бэкап**,
   не удалять.
6. Проверка читаемости: кнопки и заголовок главного меню остаются разборчивыми
   поверх нового фона на 1280×720 и 2560×1440.
7. Тест (smoke): главное меню строится, новый фон грузится без ошибок; скрин в
   build/qa/. CHANGELOG; content_registry.

## Files / Assets / IDs
- scripts/main.gd (MAIN_MENU_BACKGROUND:73)
- scripts/ui_screens.gd (_show_main_menu 89-117)
- assets/backgrounds/ (новый файл + бэкап старого)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Новый фон 2560×1440: 3 новых босса + пара героев в бою, более гладкие текстуры.
- [ ] Кнопки/логотип читаемы поверх; MAIN_MENU_BACKGROUND переключён; старый в бэкап.
- [ ] 6 smoke зелёные; скрин в build/qa/; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md (фоны/меню), docs/design/systems/menus_ui.md,
current_game_state.

## Progress — 2026-06-14
- Design/Codex взял задачу в работу на ветке `dev` по прямому пользовательскому
  override после проверки board: task board строка была `new`/future-scope, но
  пользователь явно попросил не простаивать при наличии Design-задач.
- Генерация выполняется через встроенный `imagegen` skill/tool, потому что эта
  задача не содержит обязательной директивы `fantasydisk-asset-generator`, а
  локальный `OPENAI_API_KEY` для custom skill отсутствует.

## Результат — 2026-06-14
- Создан новый production background:
  `assets/backgrounds/main_menu_epic_battle_v2.png` (`2560x1440`, PNG).
- Исходник/reference сохранен:
  `docs/design/references/main_menu_background_new_bosses/main_menu_epic_battle_v2_source.png`.
- Preview сохранен:
  `docs/design/previews/main_menu_epic_battle_v2_preview.png` (`1280x720`).
- Старый фон не удалён; backup сохранен архивом:
  `docs/design/backups/scrum316_main_menu_background_2026_06_14/main_menu_epic_battle_pre_scrum316.zip`.
- `scripts/main.gd` переключен на
  `res://assets/backgrounds/main_menu_epic_battle_v2.png`.
- Изображение подготовлено proportional cover-crop до `2560x1440`, без
  растяжения по одной оси. Композиция оставляет спокойную левую треть под
  вертикальные кнопки и спокойную top-center область под заголовок.
- Документация обновлена: `CHANGELOG.md`, `content_registry.md`,
  `current_game_state.md`, `menus_ui.md`, `visual_style_assets.md`.
- Проверки: Godot import PASS; `runtime_smoke_test.gd` PASS;
  `runtime_smoke_ui_test.gd` PASS; `ui_no_overlap_matrix_test.gd` PASS;
  `dark_fantasy_ui_theme_test.gd` PASS.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически):
- **Ассет**: `main_menu_epic_battle_v2.png` = `2560×1440` (PIL); `MAIN_MENU_BACKGROUND`
  (main.gd:73) переключён на v2; бэкап старого
  `docs/design/backups/scrum316_.../main_menu_epic_battle_pre_scrum316.zip` (не удалён);
  smoke-ассерт пути фона обновлён на v2 (runtime_smoke:32) — консистентно.
- **Визуал** (`build/qa/cap_main_menu_v2.png` + превью
  `main_menu_epic_battle_v2_preview.png`): композиция = 3 читаемо-разных НОВЫХ
  босса (огненный демон-титан с цепью / тёмный рогатый латник / пурпурная
  аберрация с глазами-щупальцами) + 2 героя в бою (воин с топором + маг-кастер);
  гладкие painterly-текстуры (чище/мягче прежнего), тёмное фэнтези/канон сохранены.
- **Читаемость UI**: левая треть спокойная — 6 кнопок меню (red_gold) и top-center
  логотип разборчивы поверх фона, высокий контраст.
- **Тесты**: `runtime_smoke_test`, `runtime_smoke_ui_test`,
  `ui_no_overlap_matrix_test`, `dark_fantasy_ui_theme_test` — passed.

Acceptance:
- [x] Фон 2560×1440: 3 новых босса + 2 героя в бою, гладкие текстуры.
- [x] Кнопки/логотип читаемы; MAIN_MENU_BACKGROUND переключён; старый в бэкап.
- [x] smoke зелёные; скрин в build/qa/; доки.

Баги: нет.
