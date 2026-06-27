# SCRUM-490: Ретайр старых UI-китов после переезда на 2K

Jira: SCRUM-490 · Роль: backend · Контур: claude · Приоритет: P2 · foma · Эпик: SCRUM-481
Статус: К выполнению

## Что и зачем

После перевода всех экранов на 2K-набор кадров (`minimal_metal` + `unified` + активные `ornate`/`red_gold`) в `scripts/ui/ui_theme_paths.gd` остались **мёртвые остатки старых UI-китов** — прежде всего полностью неиспользуемый «bright-minimal» набор (`frames/minimal/`) и неиспользуемые константы путей/метаданных. Это технический долг: код-ревью, поиск по теме и новые правки спотыкаются о две почти одинаковые ветки `MINIMAL_*` (старый bright-minimal) и `MINIMAL_METAL_*` (актуальный), а на диске лежат 6 PNG, на которые никто не ссылается.

Цель с точки зрения продукта: **внешне ничего не меняется** (игрок не видит разницы — пиксели те же), но проект становится чище. Убираем неиспользуемые ассеты и мёртвые константы, не задевая активный рантайм-кит. Ожидаемый результат: после задачи нет ни одной ссылки на ретайренные ассеты, UI-смоуки зелёные, файл `ui_theme_paths.gd` короче и без обманчивых дублей.

ВАЖНЫЙ КОНТЕКСТ (анти-ловушка): в самом тикете в списке «убрать» упомянут «minimal-metal». Это **НЕ соответствует реальному коду** — `minimal_metal` сейчас является **активным рантайм-китом** (на него указывают все `GLOBAL_*` пути и его пинит зелёный тест). Удалять `minimal_metal` НЕЛЬЗЯ. Ретайру подлежит именно старый **bright-minimal** (`frames/minimal/`, константы `MINIMAL_*` без суффикса `_METAL`). См. раздел «Подводные камни».

## Текущее состояние в коде

Главный файл: `scripts/ui/ui_theme_paths.gd` (`class_name UIThemePaths`, 333 строки). Единственный внешний потребитель — `scripts/ui_screens.gd` (через `const UIThemePaths := preload(...)` + локальные алиасы).

Три параллельные ветки констант:

1. **bright-minimal (СТАРЫЙ, МЁРТВЫЙ)** — `ui_theme_paths.gd`:
   - `MINIMAL_FRAME_DIR` (стр. 9) → `res://assets/sprites/ui/frames/minimal/`
   - `MINIMAL_MODAL_PATH`, `MINIMAL_PANEL_PATH`, `MINIMAL_CARD_PATH`, `MINIMAL_TOOLTIP_PATH`, `MINIMAL_HUD_STRIP_PATH`, `MINIMAL_FIELD_PATH` (стр. 11-16)
   - `MINIMAL_FRAME_SOURCE_SIZE` (стр. 23-30), `MINIMAL_FRAME_TEXTURE_MARGINS` (стр. 31-38), `MINIMAL_FRAME_CONTENT` (стр. 39-46)
   - Проверено: `grep` по `UIThemePaths.MINIMAL_<X>` (без `_METAL`) даёт **0 внешних ссылок** для всех 10 констант. `MINIMAL_FRAME_DIR` встречается 7 раз, но только внутри файла — он строит сами `MINIMAL_*_PATH`, которые тоже мертвы. Вся ветка замкнута сама на себя и наружу не выходит.

2. **minimal_metal (АКТИВНЫЙ — НЕ ТРОГАТЬ)** — `ui_theme_paths.gd` стр. 10, 17-22, 47-86, 108-117, 298-332. На него указывают `GLOBAL_PANEL_FRAME_PATH`/`GLOBAL_CARD_FRAME_PATH`/… (стр. 108-117) и кнопки. Потребляется в `ui_screens.gd` (`_minimal_metal_frame_style`, стр. ~7060). Пинится тестом `tests/dark_fantasy_ui_theme_test.gd` (`_expect_minimal_metal_frame_kit`, `_expect_minimal_metal_button_kit`) и `tests/runtime_smoke_test.gd` (`MINIMAL_MODAL_TEXTURE := ".../minimal_metal/..."`, стр. 52-53).

3. **unified / ornate / red_gold (АКТИВНЫЕ — НЕ ТРОГАТЬ ИСПОЛЬЗУЕМЫЕ)** — используются в теле `ui_screens.gd` (`UNIFIED_MASTER_FILL_FRAME_PATH` стр. 7515, `UNIFIED_FRAME_TEXTURE_MARGINS` стр. 7516, `UNIFIED_FRAME_CONTENT` стр. 7514, `ORNATE_FRAME_MARGINS/CONTENT` стр. 7520-7521) и пинятся `dark_fantasy_ui_theme_test.gd` (`UNIFIED_FRAME_TEXTURE_MARGINS`, `UNIFIED_FRAME_SAFE_RECT`).

ОЧЕНЬ ВАЖНАЯ ТОНКОСТЬ ПО ИМЕНАМ. В `scripts/ui_screens.gd` (стр. 25-30) локальные алиасы названы `MINIMAL_*`, но указывают на **metal**-кит:
```
const MINIMAL_MODAL_PATH := UIThemePaths.MINIMAL_METAL_MODAL_PATH
const MINIMAL_PANEL_PATH := UIThemePaths.MINIMAL_METAL_PANEL_PATH
... и т.д. (все шесть)
```
То есть десятки констант в `ui_screens.gd` (стр. 110-248, 7046-7051: `SETTINGS_V2_*`, `COMBAT_HUD_*`, `ECONOMY_*`, `CODEX_*`, `REWARD_*`, `PAUSE_END_*`) формально содержат «`MINIMAL`», но в рантайме резолвятся в `minimal_metal`-PNG. **Эти алиасы и их потребителей трогать НЕЛЬЗЯ** — это активный 2K-кит, просто исторически названный коротко.

Состояние диска (`assets/sprites/ui/frames/`):
- `minimal/` — 6 PNG + 6 `.import` (`ui_frame_minimal_card/field/hud_strip/modal/panel/tooltip.png`). **На эти файлы нет ни одной ссылки** из `.gd/.tscn/.tres/.theme` (только косвенно через мёртвые константы в `ui_theme_paths.gd`). Кандидат на удаление.
- `minimal_metal/`, `minimal_metal_buttons/`, `unified/`, `ornate/`, `red_gold/`, `dark_fantasy/` — активны, НЕ трогать.

## Что сделать — по шагам

1. **Удалить мёртвую bright-minimal ветку констант** в `scripts/ui/ui_theme_paths.gd`:
   - стр. 9 `MINIMAL_FRAME_DIR`
   - стр. 11-16 `MINIMAL_MODAL_PATH`, `MINIMAL_PANEL_PATH`, `MINIMAL_CARD_PATH`, `MINIMAL_TOOLTIP_PATH`, `MINIMAL_HUD_STRIP_PATH`, `MINIMAL_FIELD_PATH`
   - стр. 23-46 `MINIMAL_FRAME_SOURCE_SIZE`, `MINIMAL_FRAME_TEXTURE_MARGINS`, `MINIMAL_FRAME_CONTENT`
   Удалять только эти; `MINIMAL_METAL_*` (стр. 10, 17-22, 47-86) НЕ трогать.

2. **Удалить ассеты bright-minimal с диска**: всю папку `assets/sprites/ui/frames/minimal/` (6 `.png` + 6 `.png.import`). Использовать `git rm`, чтобы изменение попало в индекс. После удаления — `grep -rn 'frames/minimal/' --include='*.gd' --include='*.tscn' --include='*.tres' --include='*.theme'` должен дать пусто (кроме, возможно, артефактов в `.claude/worktrees/`, которые игнорируем).

3. **(Опционально, low-risk) подчистить прочие мёртвые константы** в `ui_theme_paths.gd` — у них 0 ссылок и в scripts, и в tests:
   - `RED_GOLD_BUTTON_TYPES` (стр. 151-167) — массив-перечисление, нигде не читается (используется только словарь `RED_GOLD_BUTTON_TEXTURES`).
   - Неиспользуемые `UNIFIED_*` пути/размеры: `UNIFIED_MASTER_FRAME_PATH` (стр. 87), `UNIFIED_INNER_FILL_PATH` (стр. 89), `UNIFIED_ORNAMENT_TOP_PATH` (стр. 90), `UNIFIED_ORNAMENT_BOTTOM_PATH` (стр. 91), `UNIFIED_HOVER_OVERLAY_PATH` (стр. 92), `UNIFIED_FRAME_SOURCE_SIZE` (стр. 93).
     - ОСТОРОЖНО: НЕ удалять `UNIFIED_MASTER_FILL_FRAME_PATH` (стр. 88, используется в ui_screens), `UNIFIED_FRAME_TEXTURE_MARGINS` (стр. 94, пинится тестом), `UNIFIED_FRAME_SAFE_RECT` (стр. 95, пинится тестом), `UNIFIED_FRAME_CONTENT` (стр. 96-106, используется).
   - Если удаляешь `UNIFIED_*` пути — соответствующие PNG в `assets/sprites/ui/frames/unified/` остаются (на `ui_frame_unified_master.png`/`_master_fill.png` ссылается тест `dark_fantasy_ui_theme_test.gd` стр. 89). **Файлы unified НЕ удалять.**
   - Этот шаг 3 необязателен; если есть сомнение — ограничься шагами 1-2 (главная цель тикета) и оставь шаг 3 на отдельную правку. Минимальный безопасный объём = шаги 1, 2, 4, 5.

4. **Прогнать UI-смоук-тесты** (Godot 4.6.3, headless из `~/Downloads/Godot.app`):
   - `tests/dark_fantasy_ui_theme_test.gd` (ключевой гейт кит-стилей)
   - `tests/runtime_smoke_ui_test.gd`, `tests/runtime_smoke_test.gd`, `tests/ui_no_overlap_matrix_test.gd`
   - `tests/asset_reference_integrity_test.gd` — рекурсивно сканирует ассеты на битые ссылки; после удаления `frames/minimal/` должен остаться зелёным (ссылок на удалённое нет).
   Все — зелёные.

5. **Финальная проверка отсутствия висячих ссылок**: `grep -rn 'UIThemePaths.MINIMAL_\(MODAL\|PANEL\|CARD\|TOOLTIP\|HUD_STRIP\|FIELD\|FRAME_DIR\|FRAME_SOURCE\|FRAME_TEXTURE\|FRAME_CONTENT\)' scripts/ tests/` → пусто. Парс `ui_theme_paths.gd` без ошибок (нет ссылок на удалённый `MINIMAL_FRAME_DIR`).

## Acceptance Criteria

- [ ] Из `scripts/ui/ui_theme_paths.gd` удалена мёртвая ветка bright-minimal: `MINIMAL_FRAME_DIR`, `MINIMAL_MODAL_PATH`, `MINIMAL_PANEL_PATH`, `MINIMAL_CARD_PATH`, `MINIMAL_TOOLTIP_PATH`, `MINIMAL_HUD_STRIP_PATH`, `MINIMAL_FIELD_PATH`, `MINIMAL_FRAME_SOURCE_SIZE`, `MINIMAL_FRAME_TEXTURE_MARGINS`, `MINIMAL_FRAME_CONTENT`.
- [ ] Папка `assets/sprites/ui/frames/minimal/` удалена из репозитория (через `git rm`, вместе с `.import`).
- [ ] Нет ни одной ссылки на ретайренные ассеты: `grep -rn 'frames/minimal/'` по `*.gd/*.tscn/*.tres/*.theme` пуст (кроме `.claude/worktrees/`).
- [ ] Нет внешних ссылок на удалённые константы: `grep` по `UIThemePaths.MINIMAL_*` (без `_METAL`) пуст в `scripts/` и `tests/`.
- [ ] Активный кит `minimal_metal` (и `unified`/`ornate`/`red_gold`/`minimal_metal_buttons`) НЕ затронут — все `GLOBAL_*`, `MINIMAL_METAL_*` константы и ассеты на месте.
- [ ] Локальные алиасы `MINIMAL_*` в `scripts/ui_screens.gd` (стр. 25-30 и их потребители) НЕ изменены.
- [ ] UI-смоуки зелёные: `dark_fantasy_ui_theme_test.gd`, `runtime_smoke_ui_test.gd`, `runtime_smoke_test.gd`, `ui_no_overlap_matrix_test.gd`, `asset_reference_integrity_test.gd`.
- [ ] (Если делался шаг 3) Удалённые `UNIFIED_*`/`RED_GOLD_BUTTON_TYPES` константы не имеют ссылок; файлы в `frames/unified/` остались на диске.

## Files / точки входа

- `scripts/ui/ui_theme_paths.gd` — удалить bright-minimal константы (стр. 9, 11-16, 23-46); опционально (шаг 3) — `RED_GOLD_BUTTON_TYPES` (151-167) и неиспользуемые `UNIFIED_*` пути (87, 89-93). НЕ трогать `MINIMAL_METAL_*`, `UNIFIED_FRAME_TEXTURE_MARGINS/SAFE_RECT/CONTENT`, `UNIFIED_MASTER_FILL_FRAME_PATH`, `ORNATE_*`, `GLOBAL_*`.
- `assets/sprites/ui/frames/minimal/` — удалить директорию целиком (`git rm -r`).
- `scripts/ui_screens.gd` — НЕ редактировать (только убедиться `grep`-ом, что не ссылается на удалённое; локальные `MINIMAL_*` алиасы указывают на metal-кит и остаются).
- `tests/dark_fantasy_ui_theme_test.gd`, `tests/runtime_smoke_test.gd`, `tests/ui_no_overlap_matrix_test.gd`, `tests/asset_reference_integrity_test.gd`, `tests/runtime_smoke_ui_test.gd` — НЕ редактировать, использовать как гейт.

## Замечания / подводные камни

- **ГЛАВНАЯ ЛОВУШКА — формулировка тикета врёт про minimal-metal.** Тикет говорит «убрать minimal-metal», но `minimal_metal` — это и есть актуальный 2K-кит (на него указывают `GLOBAL_*`, его пинят два теста). Ретайру подлежит ТОЛЬКО bright-minimal (`frames/minimal/`, `MINIMAL_*` без `_METAL`). Не дай имени `MINIMAL_METAL` ввести в заблуждение.
- **Locked path: `scripts/ui_screens.gd`.** Это большой общий файл за Claude-контуром (анти-коллизия). В рамках этой задачи его править НЕ нужно вообще — все правки локализованы в `ui_theme_paths.gd` + удаление ассетов. Если по ходу кажется, что нужно тронуть `ui_screens.gd`, — стоп, скорее всего ты собираешься удалить что-то активное.
- **`scripts/progression_data.gd` — locked, к задаче отношения не имеет, не трогать.**
- **Обманчивые имена локальных алиасов.** В `ui_screens.gd` есть `const MINIMAL_MODAL_PATH := UIThemePaths.MINIMAL_METAL_MODAL_PATH` и т.п. (стр. 25-30). Они резолвятся в metal-кит. Десятки `SETTINGS_V2_*/COMBAT_HUD_*/ECONOMY_*/CODEX_*/REWARD_*/PAUSE_END_*` (стр. 110-248, 7046-7051) тянут эти алиасы — всё это активный 2K, НЕ удалять.
- **Тест `asset_reference_integrity_test.gd` рекурсивно ходит по ассетам** и проверяет битые ссылки — после удаления `frames/minimal/` он должен остаться зелёным именно потому, что ссылок на эти PNG нигде нет. Если он покраснеет — значит где-то осталась ссылка, которую надо тоже убрать.
- **`.import` обязательно удалять вместе с `.png`.** Godot держит на них `.uid`-карту; брошенный `.import` без `.png` может дать предупреждение при реимпорте. Удаляй парами.
- **Не путать с `minimal_metal_buttons`** (`frames/minimal_metal_buttons/`) — это активные кнопки (пинятся `_expect_minimal_metal_button_kit`, метаданные `scrum450_...`). НЕ трогать.
- **Прочие потенциально-легаси папки** (`hero_select_v2`, `hero_select_v3`, `settings`, `settings_v2`) НЕ входят в скоуп этого тикета — не расширять задачу. Скоуп: только bright-minimal + мёртвые константы в `ui_theme_paths.gd`.
- **Связанные тикеты эпика SCRUM-481 (ui-overhaul-2k):** SCRUM-450 (minimal-metal buttons), SCRUM-451/452 (minimal-metal frame kit), SCRUM-392 (unified frame margins) — их артефакты-метаданные (`docs/design/references/ui_minimal_metal*`, `unified_master_frame`) активны и нужны тестам, НЕ удалять.
- **После правок** прогнать `tools/jira_board_sync.py`, чтобы держать Jira синхронной (статус → по факту выполнения; правило live-sync).
