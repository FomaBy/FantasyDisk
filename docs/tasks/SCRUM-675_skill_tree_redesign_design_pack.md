# Design Task: SCRUM-675 — Дерево умений, полный редизайн (дизайн-пакет)

Статус: todo
Контур: Claude (design)
Owner: design
Jira: SCRUM-675 (blocks SCRUM-676)
Спринт: 0.1.7 (133)
Locked paths: docs/design/mockups/scrum675_skill_tree_2k/**, docs/design/references/scrum675_skill_tree_2k/**, assets/sprites/ui/skill_tree/**, tools/build_scrum675_skill_tree_frames.py

## Что и зачем

Экран «Древо умений» (главное меню) выглядит плохо. Нужен полный визуальный
редизайн: переосмыслить раскладку и заменить ВСЕ ассеты/фреймы. Стиль — тёмное
фэнтези / D&D, золото-латунь, гербовая орнаментика, высокая читаемость @2K.

## Текущее состояние

`scripts/ui_screens.gd:1733` `_show_skill_tree_screen`:
- общий `SkillTreeMainPanel` (стиль `_progression_main_panel_style`);
- слева `SkillTreeClassPanel` — заголовок «Классы» + Label-список бонусов класса;
- 4 ветки-пути `SkillTreeBranchPanel_{wealth,lore,might,endure}` в ряд (стиль
  `_progression_branch_panel_style`), узлы — квадратные кнопки 74×74;
- бейдж очков `SkillTreePointsBadge` + кнопка «Назад в меню».
- Фон: `skill_tree` backdrop (assets/backgrounds/ui/ui_backdrop_skill_tree.png).
- 2K: viewport 2560×1440. Координатные константы — ui_screens.gd:236-240.

## Состав дизайн-пакета

1. **Общий фрейм экрана** — замена `_progression_main_panel_style`-вида; рамка
   с safe-area под контент (frame-content-safe-area-rule).
2. **4 компактных фрейма путей** (wealth/lore/might/endure) — компактнее
   текущих, каждый со своим акцентом/иконой пути, под чуть более крупный шрифт.
3. **Классовый dropdown + попап** — фрейм селектора класса и красивое окно,
   показывающее уже применённые бонусы выбранного класса.
4. **Кнопка «Очки умений»** (отдельная) + бейдж счётчика очков.
5. Иконография узлов/состояний (locked/available/purchased) — палитра.

## Acceptance

- Мокап раскладки @2560×1440 + спека зон (ui_plan/layout), zone-audit зелёный.
- Все ассеты PNG, прозрачный фон, сайдкары `.import`/`.uid`, в `assets/sprites/ui/skill_tree/`.
- Контент не на орнаменте рамок (safe-area).
- Генератор в `tools/build_scrum675_skill_tree_frames.py`.
- Готово к интеграции бэкенд-тикетом SCRUM-676.

## Files

- docs/design/mockups/scrum675_skill_tree_2k/**
- assets/sprites/ui/skill_tree/** (+ сайдкары)
- tools/build_scrum675_skill_tree_frames.py
