# Задача Для Back-end-Агента: Settings tab font parity

Статус: done
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

Implementation commit `dc56a743b` is green and pushed directly to `origin/dev`;
Jira is routed to `Контроль качества` for an independent QA verdict.

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

## QA-Вердикт (2026-07-11)

Статус: PASSED

Проверено на свежем `origin/dev` `7c9f07f35` (implementation
`dc56a743b`, routing `6ab80d1aa`; последующий SCRUM-1059 затрагивает только
MainMenu и не меняет Settings-block):

- focused `settings_tab_font_scrum1060_test.gd` headless и real Metal;
- четыре Metal viewport: 1152×648, 1280×720, 1920×1080, 2560×1440 — полный
  текст, точный font parity 21/22/23/23, safe-zone `x=48..212`, без overlap с
  dragon heads/rails/gems/frame; windowed lifecycle без leak diagnostics;
- Settings Game/footer/seamless/audio data+UI, semantic button family и video
  apply;
- `ui_no_overlap_matrix_test.gd` и его rect-report;
- gamepad menu/rebind/core/in-run + два последовательных full-flow прогона;
- animation/meta/targeting regression, runtime UI и full runtime smoke.

Краевые случаи: минимум 1152×648 с самым длинным `Управление`, breakpoints
720/1080 и native 1440 plate, все pressed/selected states, LB/RB wrap
first↔last, повторный full gamepad flow, интеграция последующего SCRUM-1059.

Баги: нет. Runtime UI сохранил только известный non-fatal dummy-renderer
null-texture diagnostic при попытке screenshot и завершился PASS.

Disk cleanup: disposable QA worktree/cache/captures/tmp/branch удаляются после
scoped Jira mirror sync и push этого вердикта.
