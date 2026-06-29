# Design+Backend Task: SCRUM-673 — Эпический лого-тайтл главного меню

Статус: done (re-submit в QA 2026-06-29 после фикса SCRUM-680)
Контур: Claude
Owner: design+backend
Jira: SCRUM-673
Спринт: 0.1.7 (133)
Locked paths: scripts/ui_screens.gd (`_show_main_menu`), assets/sprites/ui/menu_title/**, tools/build_main_menu_title_logo.py

## Re-fix (2026-06-29, Claude/design) — закрытие блокеров SCRUM-680

Все 4 блокера QA устранены:
1. **Имя ноды** восстановлено `MainMenuTitleLabel` (TextureRect) — тесты завязаны
   на имя (`ui_screens.gd:446`).
2. **Путь ассета** приведён к спеке: `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png`
   (+`.import`, `uid://cpht5yhj88htw`). Старый `assets/sprites/ui/main_menu_title.png` удалён.
3. **Генератор** переименован в `tools/build_main_menu_title_logo.py`.
4. **Перекрытие**: headless-замер реальных rect — лого `y=56..323`, первая кнопка
   `MainMenuStartButton` с `y=383` (зазор 60px); все 6 кнопок чисто. Прошлый фейл
   опирался на bounding-rect полноразмерного контейнера `MainMenuActions`
   (anchor 0..1440), а не rect'ы кнопок — ложный позитив. Добавлен постоянный тест
   `tests/main_menu_title_no_overlap_test.gd` (title-vs-каждая кнопка).

Гейты (godot_gate, 2K viewport): `main_menu_title_no_overlap_test` PASS (6 buttons
clear), `ui_no_overlap_matrix_test` PASS, `runtime_smoke_ui_test` PASS.

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

## QA-Вердикт (2026-06-29)

Статус: PASSED
Проверено (origin/dev @ a7124daa; коммиты 13451fb7 → 91b7d4ce):
- Блокер 1: узел `MainMenuTitleLabel` восстановлен как TextureRect (ui_screens.gd:445-446).
- Блокер 2: ассет `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` (720x300, +.import, uid://cpht5yhj88htw) в origin/dev; старый `assets/sprites/ui/main_menu_title.png` (+.import) удалён; код грузит новый путь (ui_screens.gd:457).
- Блокер 3: генератор переименован в `tools/build_main_menu_title_logo.py`; старого `tools/generate_main_menu_title.py` нет.
- Блокер 4: лого не перекрывает ни одну из 6 кнопок (тест title-vs-каждая кнопка).
Гейты (fdengine, чистый worktree от origin/dev, после --import):
- tests/main_menu_title_no_overlap_test.gd PASS (6 buttons clear).
- tests/ui_no_overlap_matrix_test.gd PASS.
- tests/runtime_smoke_ui_test.gd PASS.
Влито в origin/dev: да. Блокеры SCRUM-680 закрыты. Disk cleanup: worktree удалён.
