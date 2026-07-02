# Геймпад: пиксель-арт глифы кнопок (A/B/X/Y, D-pad, бамперы, стики, Start/Select)

Статус: new
Контур: Claude
Owner: unassigned
Thread: SCRUM-810 — QA failed 2026-07-02, returned to work
Locked paths: `assets/sprites/ui/input_glyphs/` (новая папка), `scripts/ui/input_glyph_registry.gd` (новый), `tests/input_glyph_assets_test.gd`
Версия: 0.1.8
Приоритет: P1
Создано: 2026-07-02
Автор: PM (прямой запрос пользователя: полная поддержка геймпада)
Jira: SCRUM-810
Labels: claude, design, fantasydisk, foma, gamepad, p1

## Autonomy / Approval
Пользователь заранее одобрил изменения. Не останавливаться для подтверждений.
Jira first: claim через Jira-pull перед правками.

## Роль И Границы
Design (Claude lane): генерация ассетов + лёгкий registry-скрипт (словарь
константа→путь) + ассет-тест. НЕ встраивать глифы в экраны (`ui_screens.gd` НЕ
трогать) — интеграция идёт в задачах настроек/меню пакета по готовому registry.

## Контекст
Пользовательский запрос 2026-07-02: полная поддержка геймпада. UI-задачам пакета
нужны иконки кнопок геймпада (подсказки «какая кнопка за что», кнопки ребинда в
настройках, контекстные подсказки). Пиксель-арт стиль проекта; генерация —
PixelLab MCP `create_ui_asset` (канон: прозрачный фон, «no text», см. память/
процесс pixellab_pull_setup.md). OpenAI images для этой задачи не использовать
(биллинг заблокирован; PixelLab-first и так канон).

## Требования
1. Набор глифов (generic Xbox-style раскладка, узнаваемая без бренда), каждый
   отдельным PNG с прозрачным фоном, 2 размера: 32×32 и 64×64 (или один 64×64,
   если качество даунскейла в Godot приемлемо — зафиксировать выбор в результате):
   - лицевые кнопки: A (зелёный акцент), B (красный), X (синий), Y (жёлтый) —
     круглая кнопка с буквой; буква читаема на 32px;
   - D-pad: нейтральный + 4 направления (подсвеченный сектор): dpad, dpad_up,
     dpad_down, dpad_left, dpad_right;
   - бамперы/триггеры: LB, RB, LT, RT (форма плеча/курка + подпись);
   - Start (≡/▶), Back/Select (⧉/двойное окно);
   - стики: stick_l, stick_r (нейтраль), stick_l_press/stick_r_press (нажатие),
     stick_move (стик со стрелками во все стороны — для «движение»);
   - клавиатурные базовые: key_generic (пустой кейкап под текст), key_esc,
     key_enter, key_space, key_wasd, key_arrows (кейкап-стиль, единый с падом).
2. Стиль: тёмная основа + светлый контур в духе существующего UI-кита
   (leather/gold тона проекта допустимы), БЕЗ жёлтых рамок-обводок как акцента
   всего глифа (жёлтый допустим только внутри Y-кнопки); пиксель-арт, чистые
   края, никакого запечённого фона (чекерборд/серый — дефект: чинить
   border-connected flood-fill alpha-cleanup, НЕ регенерацией, если размер валиден).
3. Пути: `assets/sprites/ui/input_glyphs/<name>_<size>.png` (например
   `btn_a_32.png`, `dpad_up_64.png`). Все PNG с корректными `.import`-сайдкарами
   в коммите (пары png↔png.import в git-tree — QA проверяет).
4. Registry: `scripts/ui/input_glyph_registry.gd` — статический словарь:
   `JOY_BUTTON_A→btn_a`, `JOY_BUTTON_B→btn_b`, … `JOY_BUTTON_START→start`,
   `JOY_BUTTON_BACK→select`, `JOY_BUTTON_LEFT_SHOULDER→lb`, `RIGHT_SHOULDER→rb`,
   оси `JOY_AXIS_LEFT_*→stick_move`, D-pad кнопки 11-14→dpad_*; API:
   `static func texture_for_joy_button(idx: int, size: int = 32) -> Texture2D`
   (+ аналоги для осей/клавиш), null-safe (нет файла → null, не краш).
5. Превью-лист (контактный лист всех глифов на одном PNG) в
   `build/qa/scrum810/glyphs_contact_sheet.png` для QA-приёмки.

## Files / Assets / IDs
- `assets/sprites/ui/input_glyphs/*.png` (+`.import`), `scripts/ui/input_glyph_registry.gd`,
  `tests/input_glyph_assets_test.gd` (все записи registry указывают на
  существующие файлы; текстуры грузятся; альфа по углам прозрачна).

## Acceptance Criteria
- [ ] Полный набор из п.1 сгенерирован, прозрачный фон (углы alpha=0), читаемо
      на 32px, единый стиль, без запечённого чекерборда/фона.
- [ ] Пары png↔png.import закоммичены полностью (git-tree pairing чист).
- [ ] Registry покрывает все JOY_BUTTON_*-константы раскладки пакета + оси +
      базовые клавиши; null-safe.
- [ ] Ассет-тест зелёный headless (после --import).
- [ ] Контактный лист в build/qa/scrum810/ приложен.
- [ ] ui_screens.gd не тронут.

## Документация
`docs/design/content_registry.md` — блок input_glyphs (пути, размеры);
`docs/design/systems/input_controls.md` — ссылка на глифы (если файл уже создан
core-задачей; иначе отметить в content_registry).

## Самопроверка
`--import` + ассет-тест через tools/godot_gate.py; визуальная проверка контакт-листа
(прозрачность, читаемость, стиль); alpha-cleanup при необходимости.

## QA 2026-07-02 — FAILED
Functional asset checks passed, but the task is returned to work because the
delivery explicitly used a PIL generator instead of the required PixelLab MCP
`create_ui_asset` pipeline. Jira comment has the full verdict, test evidence,
and accepted/failed criteria. Next pass needs either PixelLab-compliant source
evidence or an explicit PM waiver for PIL-generated input glyphs.
