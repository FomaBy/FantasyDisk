# BUG/UI: Settings и Attribute Shop — контент перекрывает нижнюю кнопку при 1152×648

Статус: done
Приоритет: high
Роль: Back-end (UI/layout)
Версия: 0.1.6
Создано: 2026-06-17
Автор: QA (находка при batch-QA 0.1.6 — ui_no_overlap_matrix красный)
Jira: SCRUM-471

QA: in_progress (2026-06-19 14:00)

## Dispatch
2026-06-17T15:10Z — Documentation dispatcher routed this Sprint 0.1.6
Back-end/UI bug to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`.
Keep reasoning High/no low. Scope is short-viewport layout only for Settings and
Attribute Shop; preserve semantics and avoid Design/Animator scope. Coordinate
carefully with any concurrent `scripts/ui_screens.gd` work such as SCRUM-470.

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
- [x] `ui_no_overlap_matrix_test` зелёный на ВСЕХ разрешениях (вкл. 1152×648) для settings + attribute_shop.
- [x] Семантика/контролы settings и attribute_shop целы; runtime_smoke_ui зелёный.
- [x] 1152×648 до/после QA evidence в build/qa/ (`build/qa/scrum471/settings_attribute_shop_1152_evidence.md`; PNG capture unavailable in headless dummy renderer).

## Files
- `scripts/ui_screens.gd` (settings layout; attribute_shop_economy layout)
- `tests/ui_no_overlap_matrix_test.gd` (settings/attribute_shop matrix-проверки)

## Verification
```bash
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd
# → "UI no-overlap matrix test passed." (сейчас: 2 intersects при 1152×648)
```

## Result — 2026-06-17 Back-end

Fixed the two 1152×648 layout overlaps in `scripts/ui_screens.gd` without
changing Settings or Attribute Shop semantics:

- Settings: `_settings_v2_content_panel_rect()` now lowers the compressed-modal
  minimum content-panel height only for short modal heights, keeping the panel
  above `SettingsBackButton`.
- Attribute Shop: short viewports (`<=660px` high) use compact attribute cards
  (`320x240`) and slightly shorter bottom action buttons, preserving 720p+
  layout targets.

After fix at 1152×648:

- `SettingsContentPanel` bottom `489.65`, `SettingsBackButton` top `514.0`.
- `AttributeOffer_damage` bottom `429.0`, `AttributeRerollButton` top `430.0`.

QA evidence:

- `build/qa/scrum471/settings_attribute_shop_1152_evidence.md`
- `build/qa/ui_no_overlap_matrix.md`
- `build/qa/scrum439/settings_v2_no_overlap_matrix.md`
- `build/qa/scrum413/attribute_shop_no_overlap_matrix.md`

Screenshot note: attempted `SubViewport` PNG capture at 1152×648 in headless
Godot, but the dummy renderer returned null textures. The rect dumps are the
authoritative evidence for this headless layout regression.

Verification PASS:

- `tests/ui_no_overlap_matrix_test.gd`
- `tests/runtime_smoke_ui_test.gd`
- `tests/runtime_smoke_test.gd`

## QA-Вердикт (2026-06-23)

Статус: PASSED

Независимый QA-прогон на актуальном рабочем дереве (фикс в `scripts/ui_screens.gd`
закоммичен и чист):

- `tests/ui_no_overlap_matrix_test.gd` → EXIT=0, «UI no-overlap matrix test passed.»
- `tests/runtime_smoke_ui_test.gd` → EXIT=0, «Runtime UI smoke suite passed.»
- `tests/runtime_smoke_test.gd` → EXIT=0, «Runtime smoke test passed.»

Логи: `build/qa/qa_session_20260623/`. Перекрытий Settings/Attribute Shop при
1152×648 нет; семантика сохранена. Закрываю → «Готово».
