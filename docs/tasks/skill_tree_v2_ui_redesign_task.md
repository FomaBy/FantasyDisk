# Skill Tree v2 — Перерисовка экрана «Древо умений» (PoE-стиль, граф узлов) — UI

Статус: done
Роль: Back-end
Контур: Claude
Lane: claude
Owner: claude-backend
Версия: 0.2.0
Создано: 2026-06-30
Автор: User request (PM)
Jira: SCRUM-698
Labels: foma, backend, claude
Связано: SCRUM-696 (data/economy ✓done), SCRUM-697 (art ✓done), SCRUM-699 (qa)

## Контекст

> Unblocked 2026-06-30: зависимости SCRUM-696 (данные/экономика) и SCRUM-697 (арт-пак)
> сданы (done, в origin/dev). Задача готова к разбору.


Полная перерисовка (с нуля) экрана меню «Древо умений» под новое общее дерево умений в стиле
Path of Exile 1/2: граф взаимосвязанных узлов со связями-рёбрами, прокачка от точки входа класса
наружу, трата метаочков, глобальный уровень персонажа. Текущая реализация — 4 линейные ветки в
`scripts/ui_screens.gd:2099-2402` (`_show_skill_tree_screen()`), её надо заменить.

Кнопка входа в меню: `MainMenuSkillTreeButton`, `ui_screens.gd:614-618` («Древо умений»).

**ЗАВИСИТ от** бэк-таска `codex_skill_tree_v2_data_model_economy` — модель данных (узлы с
`pos`/`adj`/`cost`/`kind`, точки входа классов, метаочки, глобальный уровень, статусы узлов,
allocate/reset API). Начинать после влития его API в origin/dev (статус blocked снять тогда).
**Использует ассеты** из `design_skill_tree_v2_art_pack` (рамки узлов/коннекторы/фон/маркеры).
До готовности арта — рендерить плейсхолдер-графику (Draw API), потом заменить на ассеты.

## Образ (арт-дирекция, см. design-таск)

- Узловой граф на тёмном фоне-«созвездии», как пассивное дерево ПоЕ, но компактнее.
- Узлы трёх типов: `minor` (мелкие кружки), `notable` (крупнее, с рамкой), `keystone` (большие,
  выделенные). Состояния: выделен (allocated, золото/зелёный), доступен (allocatable, подсветка),
  заблокирован (тусклый).
- Рёбра-коннекторы между связанными узлами: подсвечены, если соединяют выделенные/доступные.
- Точка входа текущего класса визуально выделена (маркер/свечение), камера центрируется на ней
  при открытии.
- Единый Dark Fantasy / D&D стиль игры (как codex SCRUM-684, level-up SCRUM-682/683): шрифты,
  палитра, рамки. Контент строго в безопасной зоне фрейма (frame-content-safe-area-rule).
- Высокое разрешение (вьюпорт 2560x1440), читабельность на 1152…3840.

## Обязательное правило размеров UI-ассетов

- Runtime UI не должен исправлять размер generated art через растягивание или сжатие по одной оси.
- Подключать только такие ассеты из SCRUM-697, которые сгенерированы в правильном target aspect/size: предпочтительно отдельные sizes/spec для `2560x1440` и `1920x1080`; допустимый fallback — нативный 2K (`2560x1440`) source package с только пропорциональным downscale до 1080p.
- Запрещены `STRETCH_SCALE`/custom sizing режимы, которые деформируют фон, рамки, узлы, кнопки, бейджи, иконки, орнамент или коннекторы. Whole-image frames/backgrounds scale proportionally; 9-slice/tileable assets may adapt only in flat centers while corners/borders/ornaments/content margins stay native/proportional.
- UI layout/test evidence must record each generated asset's source size, display size at 1080p and 2K, scale factor, aspect ratio and PASS/FAIL for "no stretch/squash".

## Требования

1. Снести старый `_show_skill_tree_screen()` (4 линейные ветки) и собрать заново под графовую модель.
2. **Холст дерева**: панорамируемый (drag мышью) и масштабируемый (колесо/кнопки +/−) контейнер;
   узлы позиционируются по `pos`, рёбра рисуются как линии/спрайты между соседями (`adj`).
   Клиппинг по области, инерция не обязательна.
3. **Рендер узлов**: кнопка/контрол на каждый узел; иконка/рамка по `kind` и статусу
   (`locked|available|purchased` из API); тултип при наведении (title, desc, cost, эффект).
4. **Интеракция**: клик по доступному узлу → `allocate_node()` (трата метаочков), сейв, рефреш
   всех состояний + счётчиков. Блокировать клик по locked. Кнопка «Сбросить дерево» (reset_tree,
   полный рефанд) с подтверждением.
5. **Шапка**: «Древо умений», глобальный уровень персонажа (= выделенных узлов), счётчик
   доступных/заработанных метаочков «X / 100», инфо-кнопка (?) с объяснением, кнопка «Назад».
6. **Точки входа классов**: селектор класса (как сейчас, OptionButton или панель) — выбор класса
   центрирует камеру на его узле-входе и подсвечивает его. Дерево общее: выделенные узлы видны
   при любом выбранном классе, отличается только точка входа/фокус.
7. Привязать новые ассеты из art-пака (фон, рамки узлов по типам/состояниям, коннекторы, маркер
   входа, бейдж метаочков, кнопки) с `.import` сайдкарами; фикс-margin 9-slice где нужно.
8. Без регрессий общих UI-гейтов: `ui_no_overlap_matrix_test`, безопасная зона фрейма, читабельность.

## Acceptance Criteria

- [ ] Экран «Древо умений» открывается без ошибок (headless smoke зелёный).
- [ ] Рендерится графовое дерево: узлы по координатам + коннекторы между соседями; пан и зум работают.
- [ ] Состояния узлов (выделен/доступен/заблокирован) визуально различимы и берутся из API бэк-таска.
- [ ] Клик по доступному узлу выделяет его (трата метаочка), состояние и счётчики обновляются, сейв пишется.
- [ ] Заблокированные узлы некликабельны; связность (рост от входа/соседей) визуально и логически верна.
- [ ] Шапка: глобальный уровень + метаочки «X / 100» + инфо + Назад; «Сбросить дерево» работает.
- [ ] Селектор класса центрирует/подсвечивает разные точки входа; дерево общее.
- [ ] Новые арт-ассеты привязаны (с `.import`), контент в безопасной зоне, единый стиль.
- [ ] Generated UI assets render at native/proportional sizes for `1920x1080` and `2560x1440`; no element is stretched/squeezed to fit its slot.
- [ ] Общие UI-гейты зелёные (`ui_no_overlap_matrix_test`, `runtime_smoke_test`) на всех разрешениях.

## Files

- `scripts/ui_screens.gd` — `_show_skill_tree_screen()` и хелперы (lane: claude, единоличный владелец файла).
- `scripts/main.gd` — задник экрана, навигация (если нужно).
- `assets/sprites/ui/skill_tree/**` — новые ассеты из art-пака (+ `.import`).
- `tests/runtime_smoke_test.gd`, `tests/ui_no_overlap_matrix_test.gd` — frame-path/overlap ассерты под новый экран.

## Реализация (claude-backend, 2026-06-30)

Экран `_show_skill_tree_screen()` (`scripts/ui_screens.gd`) переписан с нуля под графовую
модель PoE-стиля, потребляя API SCRUM-696 (`META_PROGRESSION`):
- **Холст-граф** `SkillTreeCanvas` (clip_contents) с миром `SkillTreeWorld`: панорамирование
  drag'ом ЛКМ по пустому месту, зум колесом (вокруг курсора) и кнопками «+/−» (вокруг центра),
  диапазон 0.28…1.3, default 0.5.
- **Узлы** — `TextureButton` (`SkillNode_<id>`) по `pos`; арт по `kind` (minor/notable/keystone)
  и статусу (`locked|available|purchased`) из `node_status()`; entry-узлы — `class_entry_marker`
  с тинтом статуса; `STRETCH_KEEP_ASPECT_CENTERED` (без stretch). Тултип = title/desc/цена.
- **Рёбра** рисуются процедурными линиями (`draw_line`) между соседями `adj`; подсвечены, если
  соединяют выделенные/доступные (спрайт-коннектор НЕ растягивается под длину ребра).
- **Интеракция**: клик по available → `allocate_node()` + `save_state()` + refresh состояний,
  счётчиков и подсветки рёбер; locked некликабельны (disabled). «Сбросить дерево» (`reset_skill_tree`)
  с подтверждающим попапом.
- **Шапка**: «Древо умений», бейдж `SkillTreePointsBadge` («Ур. N / Метаочки / X / 100»),
  инфо-«?» с объяснением экономики, «Назад в меню» (260, frame-safe).
- **Точки входа классов**: `SkillTreeClassSelector` (все 17 классов) — выбор центрирует камеру на
  узле-входе и подсвечивает его маркером фокуса; дерево общее.
- Новые ассеты арт-пака SCRUM-697 привязаны (главная рамка/бейдж/фон/маркер/узлы) с `.import`.

Гейты (Godot 4.7, headless через `godot_gate.py`): `meta_skill_tree_smoke_test`,
`runtime_smoke_test`, `ui_no_overlap_matrix_test` — все зелёные. Тесты обновлены под новый каркас
(graph-canvas вместо branch-columns; узлы — BaseButton/TextureButton). Доказательства «no-stretch»:
`docs/qa/scrum698_skill_tree_v2_no_stretch_evidence.md`.

## QA-Вердикт

Статус: PASSED

QA (claude-qa, 2026-06-30, HEAD origin/dev = dd3bdaa8):

Гейты (Godot 4.7 headless, godot_gate semaphore, fdengine):
- `meta_skill_tree_smoke_test` — PASS (экран открывается, узлы-кнопки, покупка/трата метаочка, сейв).
- `runtime_smoke_test` — PASS (exit 0; duplicate-artifact guard 11251 files, skill-tree kit).
- `ui_no_overlap_matrix_test` — PASS (3 прогона: 1 flaky-FAIL на НЕ относящемся к задаче экране
  `upgrade_economy` @1600×900 под нагрузкой живого Godot-редактора → 2 чистых PASS подряд;
  секция `skill_tree` зелёная во всех прогонах).

Код (scripts/ui_screens.gd `_show_skill_tree_screen`, meta_progression API) сверен с acceptance:
- Граф-холст `SkillTreeCanvas`/`SkillTreeWorld`: пан drag ЛКМ, зум колесом (вокруг курсора)
  и кнопками +/− (вокруг центра), равномерный `world.scale = Vector2(z,z)` 0.28…1.3.
- Узлы `TextureButton` по `pos`, арт по `kind`/`node_status()` (locked|available|purchased),
  `STRETCH_KEEP_ASPECT_CENTERED` (без axis-stretch); тултип title/desc/цена.
- Рёбра — `draw_line` по `adj` (подсветка по статусу), спрайт-коннектор НЕ растягивается.
- Клик available → `allocate_node()`+`save_state()`+refresh; locked disabled; «Сбросить дерево»
  → `reset_skill_tree()` с подтверждающим попапом.
- Шапка: бейдж «Ур. N / Метаочки / X / 100» (`META_POINTS_CAP`), инфо-«?» попап, frame-safe «Назад».
- Селектор класса (17) центрирует/подсвечивает точку входа; дерево общее.
- Ассеты art-пака привязаны с `.import` (assets/sprites/ui/skill_tree/**), bg `STRETCH_TILE`.

No-stretch evidence: docs/qa/scrum698_skill_tree_v2_no_stretch_evidence.md — сверено, KEEP_ASPECT.

Замечание (НЕ блокер SCRUM-698): `upgrade_economy` @1600×900 даёт редкий flaky-overflow
`UpgradeChoiceButton0Description` под конкурентной нагрузкой; не воспроизводится в изоляции
(2/3 PASS), к этой задаче не относится (dd3bdaa8 не трогал upgrade_economy).
