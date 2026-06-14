# Задача Для Design-Агента: Применить кит UI-рамок «Ornate Dark» из docs/design/references/UiFrame ко всей игре

Статус: new
Приоритет: high
Роль: Design (Claude-Designer нарезка/9-slice/интеграция) → Back-end handoff
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-274

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
- [ ] 13 рамок нарезаны (имена/alpha/9-slice по подписанным margin'ам).
- [ ] Все панели/окна/тултипы/HUD/карточки/пауза на новом ornate-ките; карта замены полная.
- [ ] Старый panel-кит в backup; контент не наезжает на орнамент; no-overlap.
- [ ] 6 smoke зелёные; превью до/после; content_registry/CHANGELOG.

## Документация
visual_style_assets.md (panel-канон ornate dark), content_registry.md, current_game_state.md.
