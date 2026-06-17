# BUG/UI: Settings и Attribute Shop — контент перекрывает нижнюю кнопку при 1152×648

Статус: new
Приоритет: high
Роль: Back-end (UI/layout)
Версия: 0.1.6
Создано: 2026-06-17
Автор: QA (находка при batch-QA 0.1.6 — ui_no_overlap_matrix красный)

## Симптом
`tests/ui_no_overlap_matrix_test.gd` падает (2 overlap при **1152×648** — наименьшее разрешение):
1. **settings**: `SettingsContentPanel` [P:(195,297) S:(762,248)] пересекает
   `SettingsBackButton` [P:(436,514) S:(280,87)] — низ панели (297+248=545) заходит на
   кнопку «Назад» (top=514).
2. **attribute_shop_economy**: `AttributeOffer_damage` [P:(242,189) S:(320,280)] пересекает
   `AttributeRerollButton` [P:(366,422) S:(420,62)] — низ карточки оффера (189+280=469)
   заходит на кнопку реролла (top=422).

На бóльших разрешениях (1280×720+) — ок; ломается только на коротком 1152×648.

## Корень (тот же класс, что SCRUM-465 levelup 720p)
Layout этих двух экранов НЕ viewport-aware при коротком вьюпорте: панель/карточки имеют
фиксированную высоту и не ужимаются/не скроллятся, поэтому на 648px заходят на нижнюю
кнопку. SCRUM-465 уже сделал Level Up адаптивным — settings и attribute_shop нужно так же.

Пред-существующий (воспроизводится и на HEAD до текущей UI-волны), НЕ регрессия рестайла.

## Требования
1. **Settings**: при коротком вьюпорте (≤648) ужать/проскроллить `SettingsContentPanel`,
   чтобы он не заходил на `SettingsBackButton`; сохранить семантику/контролы.
2. **Attribute Shop**: при коротком вьюпорте ужать высоту `AttributeOffer_*` карточек или
   опустить/перекомпоновать `AttributeRerollButton`, чтобы не пересекались; сохранить офферы/реролл.
3. По образцу SCRUM-465 (viewport-aware layout в `scripts/ui_screens.gd`).

## Acceptance Criteria
- [ ] `ui_no_overlap_matrix_test` зелёный на ВСЕХ разрешениях (вкл. 1152×648) для settings + attribute_shop.
- [ ] Семантика/контролы settings и attribute_shop целы; runtime_smoke_ui зелёный.
- [ ] Скрины 1152×648 до/после в build/qa/.

## Files
- `scripts/ui_screens.gd` (settings layout; attribute_shop_economy layout)
- `tests/ui_no_overlap_matrix_test.gd` (settings/attribute_shop matrix-проверки)

## Verification
```bash
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd
# → "UI no-overlap matrix test passed." (сейчас: 2 intersects при 1152×648)
```
