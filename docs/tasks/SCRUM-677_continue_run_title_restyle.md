# Task: SCRUM-677 — Заголовок окна «Продолжить забег?» в стилистике игры

Статус: done (QA PASSED 2026-06-29)
Контур: Claude
Owner: design+backend
Jira: SCRUM-677
Спринт: 0.1.7 (133)
Locked paths: scripts/ui_screens.gd (`_show_continue_run_dialog`), assets/sprites/ui/ (опц. лого)

## Re-fix (2026-06-29, Claude/design) — закрытие блокеров SCRUM-681

Причина фейла: `TextureRect`-заголовку был задан `custom_minimum_size.y = 96`, что
раздуло min-size VBox и `ContinueRunPanel` до 680×391 (вместо фикс. 680×380),
кнопки вышли за `CR_SAFE_2K` (низ 855 > 844 на 11px).

Фикс:
1. `custom_minimum_size.y` 96 → **72**. Headless-замер реальных rect (autosave seeded):
   `ContinueRunPanel` ровно **680×380** (== CR_PANEL_2K), `ContinueRunTitle` 998,608 564×72,
   `ContinueRunSubtitle` 998,696 564×49, `ContinueRunButtons` 998,761 564×76 → низ **837 ≤ 844**.
   Всё внутри CR_SAFE_2K. Лого читается (~322px ширина при aspect 4.47).
2. `tools/build_continue_run_title_logo.py --check-only` теперь read-only (не пишет,
   exit 0/1 по наличию ассета); ассет не регенерируется (md5 без изменений).

Гейты: `runtime_smoke_ui_test` PASS, `ui_no_overlap_matrix_test` PASS.

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

## QA-Вердикт (2026-06-29)

Статус: FAILED
Проверено:
- `origin/dev` актуален; executor commit observed: `d7d31cdf`.
- `ContinueRunTitle` сохранён и стал `TextureRect`.
- Texture path: `res://assets/sprites/ui/menu_title/continue_run_title.png`.
- Asset exists: PNG RGBA 760x170, transparent alpha present; `.import` sidecar exists.
- `tools/build_continue_run_title_logo.py` exists.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` PASS.

Блокеры:
- Continue-run dialog content-zone regression: `ContinueRunPanel` lays out as `680x391`, not expected `CR_PANEL_2K` `680x380`.
- `ContinueRunButtons` exits `CR_SAFE_2K` by 11 px: button bottom `855`, safe bottom `844`.
- No direct title/subtitle/button overlap, but the hard frame content-zone rule is violated.

Риск:
- `tools/build_continue_run_title_logo.py --check-only` is ignored and regenerates output instead of doing a read-only check.

Баги: `SCRUM-681`.
Disk cleanup: no disposable checkout; subagent removed `/tmp` QA files.

## QA-Вердикт reverify (2026-06-29)

Статус: PASSED
QA: qa-claude-monitor + subagent

Проверено:
- `ContinueRunTitle` остался `TextureRect`, имя и texture path сохранены.
- `custom_minimum_size.y = 72`; `ContinueRunPanel` снова `680x380`.
- `tools/build_continue_run_title_logo.py --check-only` read-only: exit 0,
  asset md5 unchanged (`330dd419ee284ca4a668781fbf4435dc`).
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd` PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` PASS.
- Matrix @2560x1440: panel `940,530 680x380`; buttons bottom `761+76=837 <= 844`.

Риски: в worktree есть unrelated dirty/untracked WIP; ignored.
Disk cleanup: none created; only ignored `build/qa` matrix refreshed by test harness.
