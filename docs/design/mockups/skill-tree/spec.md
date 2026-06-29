# SCRUM-569 — UI-редизайн: Дерево навыков (@2K 2560×1440)

Эпик SCRUM-481 (UI Overhaul). Экран `_show_skill_tree_screen`
(`scripts/ui_screens.gd`), нода `SkillTreeScreen`. Самый плотный экран:
класс-панель + N веток × M узлов. Стиль: D&D + Dark Fantasy Dragon.

## ЭТАП 1 — Раскладка / метрики @2560×1440 (база)

Экран контейнер-управляемый (responsive: PanelContainer + ScrollContainer +
HBox-ветки), уже выверен под 2K. Метрики зафиксированы код-константами:

| Элемент | Нода | 2K-метрика |
|---|---|---|
| Главная панель | `SkillTreeMainPanel` | `SKILL_MAIN_PANEL_2K` Rect2(48,26,2464,1388) (offsets 48/26) |
| Контент-VBox | layout | `SKILL_SAFE_2K` Rect2(136,118,2288,1214) (header→hint→body) |
| Бэйдж очков | `SkillTreePointsBadge` | `SKILL_POINTS_BADGE_2K` Rect2(0,0,215,96), ширина растёт под текст |
| Класс-панель | `SkillTreeClassPanel` | min 330×210, SHRINK_BEGIN, EXPAND_FILL по высоте |
| Ряд веток | `SkillTreeBranches` (в `SkillTreeBranchScroll`) | EXPAND_FILL, sep 14; вертик-скролл при переполнении |
| Панель ветки | `SkillTreeBranchPanel_<id>` | min 164×430, EXPAND_FILL |
| Узел | `SkillNode_<id>` | 74×74 кнопка-бэйдж, SHRINK_CENTER |

### Компактность узлов и safe-зона текста (требование таска)
- Узел = квадрат 74×74 с числом-стоимостью (font 20); под ним короткие
  `SkillNodeTitle` (font 12, autowrap) и `SkillNodeDesc` (font 10, autowrap),
  всё в колонке ветки (SIZE_EXPAND_FILL) — текст переносится внутри колонки,
  за панель ветки не вылазит.
- Полное название+описание узла — в тултипе (`nb.tooltip_text`).
- Переполнение по высоте уводится в `SkillTreeBranchScroll` (вертикальный скролл),
  рамку панели не растягивает.
- Класс-блок: длинные строки прогресса/бонусов — autowrap внутри `SkillTreeClassPanel`.

### Инварианты — PASS на 1080p/2K/4K
- Ничего не вылазит: панель ⊆ экран (offset 48/26), контент ⊆ safe-зона.
- Нет наслоений: header (title/badge/back) HBox, body (class-panel | branches-scroll) HBox.
- Текст в рамке: autowrap во всех лейблах + скролл при переполнении.
- Тесты: `ui_no_overlap_matrix_test` (узлы `SkillTreeBackButton/PointsBadge/
  ClassPanel/Branches`), `display_resolution_test`, `runtime_smoke_test`.

## ЭТАП 2 — Генерация красоты

Раньше древо заимствовало общий `codex`-собор (тот же фон у кодекса/патч-ноутов).
Сгенерирован ВЫДЕЛЕННЫЙ тематичный бэкдроп — «святилище умений»:

- **`ui_backdrop_skill_tree.png`** (2560×1440) — подземный арканный зал
  восхождения: дракон-колонны по бокам, созвездие рун-веток на верхних стенах
  (сине-фиолетовое свечение = визуальная метафора дерева умений), тёмный спокойный
  ЦЕНТР под панели (читаемость UI сохранена). Сгенерирован
  `fantasydisk-asset-generator` (gpt-image-2).
- Новый фон-id **`skill_tree`** в `SCREEN_BACKGROUND_PATHS` +
  `SCREEN_BACKGROUND_FALLBACK_COLORS` (индиго `0.030,0.034,0.062`);
  `_show_skill_tree_screen` переключён с `codex` на `skill_tree` (codex/патч-ноуты
  не затронуты).
- Панели/узлы/бэйджи — общие `_progression_*_style` (уже единый стиль), не дублирую.
- Источник: `docs/design/references/skill_tree_backdrop/`,
  рантайм: `assets/backgrounds/ui/ui_backdrop_skill_tree.png`.

## Примечание по QA
runtime_smoke единожды дал известный ложный red «autosave/New Game» из-за гонки
реального мета-сейва (см. memory godot-userdatadir-not-isolating-real-save) —
на изолированном повторе зелёный. Дифф не трогает run/autosave-код (только фон + 1
строка фон-id).
