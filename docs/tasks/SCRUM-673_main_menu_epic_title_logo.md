# Design+Backend Task: SCRUM-673 — Эпический лого-тайтл главного меню

Статус: todo
Контур: Claude
Owner: design+backend
Jira: SCRUM-673
Спринт: 0.1.7 (133)
Locked paths: scripts/ui_screens.gd (`_show_main_menu`), assets/sprites/ui/menu_title/**, tools/build_main_menu_title_logo.py

## Что и зачем

Заменить плоский текстовый тайтл главного меню на сгенерированный лого-ассет
названия игры «Fantasy Disk», выполненный красивым шрифтом в стилистике
Dungeons & Dragons и общей стилистике нашей игры (тёмное фэнтези, золото/латунь,
гербовая орнаментика). Лого должно быть эпичным, читаемым и стоять **сверху-слева,
над блоком меню**.

Сейчас тайтл — центрированный по верху текст, что не сочетается с левым
расположением меню и выглядит дёшево. Цель — фирменный, «коробочный» вид заставки.

## Текущий код

`scripts/ui_screens.gd:445-464` — `MainMenuTitleLabel`:
- `Label`, `text = "FANTASY DISK"`, `font_size = 72`;
- центрирован сверху: `anchor_left = 0.25`, `anchor_right = 0.75`, `offset_top = 72`;
- золотой цвет + тень.

Меню: `MainMenuActions` (VBox) внутри `layout` (MarginContainer),
`offset_left = 72`, по левому краю (`scripts/ui_screens.gd:466-486`).
Фон 2K-проект: viewport 2560×1440.

## Шаги

1. **Генерация лого** через skill `fantasydisk-asset-generator` (OpenAI gpt-image,
   прозрачный фон). Промпт: название «Fantasy Disk» декоративным D&D-шрифтом,
   тиснёное золото/латунь на тёмном, лёгкая гербовая орнаментика, без фоновой
   подложки. Несколько вариантов → выбрать лучший. Скрипт-генератор положить в
   `tools/build_main_menu_title_logo.py`, ассет — в
   `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` (+ `.import`/`.uid`).
   Размер с запасом под 2K (например ширина ~760–900 px), прозрачный фон.
2. **Интеграция**: в `_show_main_menu` заменить `MainMenuTitleLabel`-Label на
   `TextureRect` (`name = "MainMenuTitleLabel"` сохранить — на него завязаны тесты
   ui_no_overlap_matrix/runtime_smoke, проверить). `expand_mode = IGNORE_SIZE`,
   `stretch_mode = KEEP_ASPECT_CENTERED`, `mouse_filter = IGNORE`.
3. **Позиция сверху-слева, над меню**: привязать к левому краю по той же оси, что
   и `layout` (offset_left ≈ 72), верх `offset_top ≈ 72`, ширина/высота под
   пропорции лого; нижний край — над верхом `MainMenuActions`, без перекрытия.
4. **Запас под safe-area фрейма**: контент не залезает на орнамент рамки меню
   (см. frame-content-safe-area-rule).

## Acceptance

- В главном меню вместо текста «FANTASY DISK» — сгенерированный лого-ассет.
- Лого стоит сверху-слева, визуально над блоком меню, без перекрытия кнопок.
- Стилистика D&D / тёмное фэнтези, читаемо, эпично; прозрачный фон, без подложки.
- Узел сохраняет имя `MainMenuTitleLabel`; тесты `ui_no_overlap_matrix_test.gd`,
  `runtime_smoke_ui_test.gd` зелёные.
- Ассет закоммичен с сайдкарами (`.import`/`.uid`); генератор в `tools/`.
- Визуальная QA-проверка скриншотом главного меню (design_review capture).

## Files

- `scripts/ui_screens.gd`
- `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` (+ `.import`, `.uid`)
- `tools/build_main_menu_title_logo.py`
