# Design Task: UI Buttons Audit + Unified Dark Fantasy Text-Button Kit

РЎС‚Р°С‚СѓСЃ: done
Agent: Codex
Owner: Design/Codex worker Nietzsche
Thread: 019f0f2d-2132-7393-a5f2-69ce2cfb16b3
Locked paths: docs/design/references/ui_text_buttons_unique_size_redraw/, docs/design/previews/scrum_text_buttons_unique_size_*, assets/sprites/ui/frames/text_buttons_unique/, docs/design/content_registry.md, docs/design/systems/menus_ui.md, docs/tasks/design_text_buttons_unique_size_redraw_task.md
Jira: SCRUM-657

## Result

Completed a design-only runtime text-button audit and generated a unified D&D + Dark Fantasy Dragon text-button kit. No runtime UI scripts/scenes were edited; weapon-select runtime scope was audited/documented only and left untouched for SCRUM-562.

## Deliverables

- Audit JSON: `docs/design/references/ui_text_buttons_unique_size_redraw/button_size_audit.json`
- Audit report: `docs/design/references/ui_text_buttons_unique_size_redraw/button_size_audit.md`
- OpenAI source references: `docs/design/references/ui_text_buttons_unique_size_redraw/scrum657_text_button_family_reference.png` and 15 per-size source PNGs under `docs/design/references/ui_text_buttons_unique_size_redraw/per_size_sources/`
- Runtime PNGs: `assets/sprites/ui/frames/text_buttons_unique/`
- Metadata/safe zones: `docs/design/references/ui_text_buttons_unique_size_redraw/button_family_metadata.json`
- Alpha audit: `docs/design/references/ui_text_buttons_unique_size_redraw/alpha_audit.json`
- Text fit report: `docs/design/references/ui_text_buttons_unique_size_redraw/button_text_fit_report.json`
- Contact sheets: `docs/design/previews/scrum_text_buttons_unique_size_dark_contact.png`, `docs/design/previews/scrum_text_buttons_unique_size_light_contact.png`

## Verification

- Jira inspected/commented through REST after Windows helper fallback failed on macOS Keychain call.
- `rg` audit covered `scripts/ui_screens.gd`, `scripts/ui/ui_theme_paths.gd`, `scenes/**/*.tscn`, and docs.
- OpenAI asset pipeline succeeded with `gpt-image-2` via bundled `fantasydisk-asset-generator` script, `--quality high`, `--no-task`.
- Per-size redraw pass generated an individual source button for every final size group; runtime PNGs are exact-size exports from their matching source, not one stretched master.
- Alpha audit passes 75/75 final runtime PNGs: transparent background, no visible extreme-corner matte.
- Contact sheets render external labels only; final runtime PNGs contain no baked text.
- Text-fit policy is documented: runtime labels must remain inside the central content field between decorative end shutters/caps. If measured text does not fit, increase button width or use the expanded `reset_bindings_long_560x104` / `continue_run_long_420x72` variants.
- Side-cap policy is documented and baked into metadata: left/right decorative shutters are fixed-size ornaments and must not be scaled horizontally; only the central button field can stretch/shrink.

## QA Notes

Accepted action text buttons: 40. Accepted unique runtime display sizes: 13 plus 2 optional expanded long-label variants. Excluded card/icon/symbol/hit-area controls are documented with reasons in the audit. Runtime integration is a future Back-end task if these assets are promoted into `UIThemePaths`.

Disk cleanup: `.godot` and `__pycache__` caches will be removed before final handoff if created.
