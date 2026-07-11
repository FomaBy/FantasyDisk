# Задача Для Back-end-Агента: Settings tab font parity

Статус: in_progress
Контур: Codex
Owner: Back-end / `/root/scrum1060_settings_font`
Thread: `/root/scrum1060_settings_font`
Locked paths: Settings-only hunks in `scripts/ui_screens.gd`; focused Settings
font test and Settings expectation hunks; `docs/design/mockups/scrum1060_settings_tab_font/`;
Settings sections of `menus_ui.md`, `current_game_state.md`,
`ui_technical_requirements.md`
Jira: SCRUM-1060

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках задачи. Рабочий контур
самостоятельно ведёт Jira, реализацию, тесты, документацию, commit/push и cleanup.

## Контекст

`SettingsTabButton_0..3` начинают с того же `_readable_font_size(16)`, что и
`SettingsBackButton`, но `_settings_fit_kit_row()` уменьшает весь ряд из-за
иконок и длинной подписи `Управление`. Требуется сохранить точную геометрию
плит и вернуть паритет с Back: 21/22/23/23 px на 648p/720p/1080p/1440p.

## Mockup / Spec

- `docs/design/mockups/scrum1060_settings_tab_font/spec.md`
- `docs/design/mockups/scrum1060_settings_tab_font/layout_contract.json`
- PixelLab previews reused from accepted SCRUM-975 responsive package.

## Acceptance Criteria

- все четыре подписи полностью видны, без иконок, wrap/clip/ellipsis/downscale;
- effective tab font равен Back с допуском <=1 px на четырёх target viewport;
- rendered glyph bounds находятся внутри плоской `x=48..212` content-zone;
- 2x2 `260x72` compact и 4x1 `260x88/104` wide geometry неизменна;
- active tint, five states, mouse/keyboard/LB-RB/D-pad behavior сохранены;
- focused font oracle, Settings responsive/seamless, no-overlap, gamepad flow,
  UI smoke и full runtime smoke проходят; Metal matrix визуально проверена;
- Jira после green push переводится в `Контроль качества`, не в `Готово`.

## Result

Implementation and independent review are green, pending final Git/Jira routing.

- all four runtime icons are absent; accepted PNG sources remain untouched;
- the fixed tab contract is `21/22/23/23 px`, exactly matching Back on the four
  target viewports;
- glyph metrics fit the `164px` flat lane in all five visual states without
  clip/wrap/ellipsis/downscale;
- focused test: `tests/settings_tab_font_scrum1060_test.gd`;
- PASS: Settings Game/footer/seamless/audio, no-overlap, button-family,
  video-settings, gamepad menu/full-flow/rebind, UI smoke and full runtime smoke;
- PASS: Metal four-tier render and visual inspection;
- independent read-only review: PASS, no actionable findings.
