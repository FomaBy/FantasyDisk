# Задача Для Design-Агента: Применить кит UI-рамок «Ornate Dark» из docs/design/references/UiFrame ко всей игре

Статус: review
Приоритет: high
Роль: Design (Claude-Designer нарезка/9-slice/интеграция) → Back-end handoff
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-274

## Dispatcher Queue Note (2026-06-14)

Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` took this task after
SCRUM-273 reached `done`; SCRUM-273 Red & Gold Dragon buttons are the active
button canon and must stay unchanged while this task replaces panel/frame assets.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Взять новые фреймы из папки docs/design/references/UiFrame и применить их в игре».
Тёмный орнаментальный dark fantasy кит панелей/рамок с красными акцентами.
Дополняет кит КНОПОК Red&Gold Dragon (SCRUM-273) — вместе полный UI-рестайл
(кнопки + панели). Заменяет/обновляет текущий панельный кит (leather+gold
SCRUM-229).

ВАЖНО: `frame_kit_ornate_dark_sheet_b_spec.png` — спек-лист, где у КАЖДОЙ рамки
ПОДПИСАНЫ texture margin и content margin → это ГОТОВЫЕ 9-slice nine-patch
margin'ы, брать их, не угадывать. `_a` лист — доп-источник вариантов.

## 13 типов рамок (из спек-листа, см. README)
Global Panel, Level Panel, List/Card Frame, Hero Portrait/Card Frame,
Card Hover Frame, Tooltip Frame, HUD Panel, HUD Card, Timer Panel,
Pause Main Panel, Pause Stat Group, Pause Stat Chip/Basic Row, Pause Stat Tooltip.

## Требования
1. **Нарезать** обе картинки на отдельные PNG по типам рамок, RGBA, прозрачный
   фон, чистые края (без подписей/номеров/соседей). Имена к канону:
   `ui_frame_ornate_<type>.png`. Финал — `assets/sprites/ui/frames/ornate/`.
2. **9-slice по подписанным margin'ам**: для каждой рамки задать nine-patch
   из её texture margin (растяжение) и учесть content margin (внутренний отступ
   контента) — значения СО СПЕК-ЛИСТА. Тянется центр, орнамент по краям не
   искажается.
3. **Применить ко ВСЕМ панелям/окнам/тултипам/карточкам/HUD** игры (handoff
   Back-end на стайлбоксы/тему): главное окно/панели (Global/Level), списки и
   карточки (выбор героя/level-up/магазин/события), тултипы, HUD-плашки и
   таймер, экран паузы (main panel/stat group/chip/tooltip), кодекс. Карта
   «панель в игре → тип рамки кита» — в отчёт.
4. Сохранить content-отступы (текст/контент не наезжает на орнамент рамки),
   правило «UI не наползает», читаемость.
5. **Старый панельный кит** (leather+gold) после замены — в backup вне assets,
   content_registry почистить. Кнопки (SCRUM-273) — отдельная задача, согласовать
   общий вид (рамки + кнопки = единый ornate dark canon).
6. content_registry + visual_style_assets (новый panel-канон); CHANGELOG;
   превью до/после ключевых экранов в docs/design/previews/.
7. Тест (smoke): панели грузят новые стайлбоксы (фактическое дерево + текстуры);
   content margins корректны (нет наезда текста на рамку); no-overlap; экраны
   зелёные.

## Files / Assets / IDs
- Источник: docs/design/references/UiFrame/ (sheet_b_spec — с margin'ами, sheet_a — доп, README)
- Финал: assets/sprites/ui/frames/ornate/
- scripts/ui_screens.gd, scripts/pause_stats_menu.gd (потребители panel-стайлбоксов)
- docs/design/systems/visual_style_assets.md, content_registry.md

## Acceptance Criteria
- [x] 13 рамок нарезаны (имена/alpha/9-slice по подписанным margin'ам).
- [x] Все панели/окна/тултипы/HUD/карточки/пауза на новом ornate-ките; карта замены полная.
- [x] Старый panel-кит в backup; контент не наезжает на орнамент; no-overlap.
- [ ] 6 smoke зелёные; превью до/после; content_registry/CHANGELOG.

## Документация
visual_style_assets.md (panel-канон ornate dark), content_registry.md, current_game_state.md.

## Результат (2026-06-14)

Design/runtime visual pass готов к QA review.

Добавлено:
- 13 RGBA PNG frame assets в `assets/sprites/ui/frames/ornate/`:
  `global_panel`, `level_panel`, `card_frame`, `hero_card`, `card_hover`,
  `tooltip`, `hud_panel`, `hud_card`, `timer_panel`, `pause_main`,
  `pause_stat_group`, `pause_stat_chip`, `pause_stat_tooltip`;
- Godot `.import` sidecars для всех 13 PNG;
- pipeline `tools/build_ornate_ui_frame_kit.py`;
- contact preview `docs/design/previews/ornate_dark_frame_kit_contact.png`;
- backup прежних leather/gold + dark_fantasy/escape panel textures:
  `build/cleanup_backup_ornate_frames_2026_06_14/`.

Runtime mapping:
- `scripts/ui/ui_theme_paths.gd` теперь содержит `ORNATE_FRAME_DIR`,
  canonical frame paths и signed texture/content margins из spec-листа;
- `scripts/ui_screens.gd` переведен на typed ornate frames для global panel,
  level panel, card/list, hero/card, card hover, tooltip, HUD panel/card и
  timer panel;
- `scripts/pause_stats_menu.gd` переведен на ornate pause main/stat group/stat
  chip/stat tooltip frames, а pause buttons используют Red & Gold Dragon
  `pause` state textures из SCRUM-273.

Карта замены:
- Main/global windows, settings/codex/event containers → `global_panel`;
- Level-up/reward main panel → `level_panel`;
- List/card rows and generic character cards → `card_frame`;
- Hero portrait/card frame → `hero_card`;
- Hover/selected card state → `card_hover`;
- Generic/glossary tooltip → `tooltip`;
- Combat resource HUD strip → `hud_panel`;
- HP/XP/money/ultimate HUD cards → `hud_card`;
- Combat timer/ascension timer badge → `timer_panel`;
- Escape stats main panel → `pause_main`;
- Escape derived stat groups → `pause_stat_group`;
- Escape base stat rows + derived chips → `pause_stat_chip`;
- Escape stat tooltip → `pause_stat_tooltip`.

Проверки:
- `python3 tools/build_ornate_ui_frame_kit.py` — PASS;
- asset validation — 13/13 PNG имеют ожидаемые размеры, RGBA и непустую alpha;
- `tests/dark_fantasy_ui_theme_test.gd` — PASS;
- `tests/runtime_smoke_ui_test.gd` — PASS;
- `tests/ui_no_overlap_matrix_test.gd` — PASS.

Umbrella validation caveat:
- `tests/runtime_smoke_test.gd` сейчас падает на внешнем non-UI ассёрте:
  `Expected thief_coin_pouch to use its weapon sprite.`
- Фактический failure находится в `_test_class_weapon_configs`, где тест всё
  ещё ожидает старый fallback `chakrams.png`, тогда как текущий checkout уже
  имеет canonical `assets/sprites/weapons/thief_coin_pouch.png`.
- Это не связано с ornate UI frame pass и не менялось в этой задаче; чинить
  weapon-config/test ownership внутри Design UI scope не стал.
