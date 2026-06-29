# Task: SCRUM-677 — Заголовок окна «Продолжить забег?» в стилистике игры

Статус: done (в QA 2026-06-29)
Контур: Claude
Owner: design+backend
Jira: SCRUM-677
Спринт: 0.1.7 (133)
Locked paths: scripts/ui_screens.gd (`_show_continue_run_dialog`), assets/sprites/ui/ (опц. лого)

## Выполнено (2026-06-29, Claude/design)

- Лого-заголовок `assets/sprites/ui/menu_title/continue_run_title.png` (760×170,
  RGBA, прозрачный, uid встроен) — Luminari, золотой градиент + обводка + тень +
  флойриш, стиль-семья с лого главного меню. Генератор
  `tools/build_continue_run_title_logo.py`.
- `_show_continue_run_dialog`: `Label` → `TextureRect`, имя узла `ContinueRunTitle`
  сохранено; subtitle/кнопки/panel/dim/логика не тронуты.
- Гейт: `runtime_smoke_ui_test` PASS.

## Что и зачем

Окно подтверждения «Продолжить забег?» в целом выглядит хорошо. Единственное —
заголовок сейчас плоский жёлтый текст. Заменить его на новый, в стилистике нашей
игры (тёмное фэнтези / D&D): эпично, читаемо. Остальное окно не менять.

## Текущий код

`scripts/ui_screens.gd:760-766` — `ContinueRunTitle`:
- `Label`, `text = "Продолжить забег?"`, `font_size = 34`,
  `font_color = Color(0.96, 0.90, 0.68, 1.0)` (жёлто-золотой).

## Шаги

1. Сделать заголовок стилизованным: либо сгенерированный лого-ассет
   (asset-generator, прозрачный фон → TextureRect), либо стилизованный шрифт с
   тиснением/тенью/орнаментом в духе игры.
2. Имя узла `ContinueRunTitle` сохранить (на него может ссылаться код/тесты).
3. Остальные элементы окна (subtitle, кнопки, dim, panel) не трогать.

## Acceptance

- Заголовок окна — в стилистике игры, не плоский жёлтый текст; читаемо, эпично.
- Узел `ContinueRunTitle` сохранён; окно работает как прежде.
- Если ассет — закоммичен с сайдкарами `.import`/`.uid`.

## Files

- scripts/ui_screens.gd
- (опц.) assets/sprites/ui/... + сайдкары
