# SCRUM-464 Economy Matte Cleanup Spec

Status: implemented, awaiting QA visual acceptance.
Role owner: Designer 2 (Codex)
Task: `docs/tasks/bug_economy_screens_opaque_matte_washes_content_task.md`
Jira: SCRUM-464
Base targets: 1280x720, 1920x1080, 2560x1440
Preview: `docs/design/previews/scrum464_economy_matte_free_live_frames.png`
Audit: `build/qa/scrum464/economy_live_frame_matte_audit.md`

## Source Request

Rest and Event screens showed a broad pale/smoky matte over labels and option
cards in SCRUM-458 screenshots. The task asked Design to identify and clean
baked pale frame/source pixels if the live frame source was the root cause,
without changing gameplay rewards, events or economy balance.

## Runtime Mapping

Current Rest/Event economy surfaces do not use the older
`assets/sprites/ui/frames/economy/` card and panel PNGs. Runtime constants in
`scripts/ui_screens.gd` route the relevant roles through the active
minimal-metal kit:

| Runtime role | Constant(s) | Live PNG | Content rect |
| --- | --- | --- | --- |
| economy_panel | `ECONOMY_PANEL_PATH`, `MINIMAL_PANEL_PATH` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_panel.png` | `58,72,666,578` |
| economy_choice_card | `ECONOMY_CHOICE_CARD_PATH`, `ECONOMY_CHOICE_CARD_HOVER_PATH`, `MINIMAL_CARD_PATH` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_card.png` | `46,58,334,374` |
| economy_price_badge | `ECONOMY_PRICE_BADGE_PATH`, `MINIMAL_FIELD_PATH` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_field.png` | `58,52,500,186` |
| economy_tooltip | `ECONOMY_TOOLTIP_PATH`, `MINIMAL_TOOLTIP_PATH` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_tooltip.png` | `66,44,628,158` |

## Cleanup Result

SCRUM-466 cleaned the active minimal-metal source/runtime frames by flattening
their stretch cores to a dark translucent fill. SCRUM-464 verifies that the
Rest/Event roles now have no baked pale/white matte pixels:

| Runtime role | Pale in content | Pale in stretch core | White in content | White in stretch core |
| --- | ---: | ---: | ---: | ---: |
| economy_panel | 0 | 0 | 0 | 0 |
| economy_choice_card | 0 | 0 | 0 | 0 |
| economy_price_badge | 0 | 0 | 0 | 0 |
| economy_tooltip | 0 | 0 | 0 | 0 |

No new OpenAI image generation was required for this bug because this was a
defect verification/cleanup of the already generated SCRUM-452 minimal-metal
frame package and the SCRUM-466 no-seams/no-matte source update. The preview and
pixel audit are the acceptance artifact for this Design pass.

## Legacy Note

The older `assets/sprites/ui/frames/economy/*.png` folder still contains some
pale pixels, but current Rest/Event constants do not point at those panel/card
PNGs. If Back-end later restores the legacy economy PNGs for these screens,
those files need their own cleanup before reuse.

## QA Notes

Headless visual recapture with `tests/design_review_screenshot_capture_test.gd`
is currently blocked in this shell by Godot dummy-renderer `viewport image
unavailable`, same as SCRUM-466. QA should recapture Rest/Event in a
renderer-capable session before marking SCRUM-464 QA PASSED.

Verification completed:

- `tests/ui_no_overlap_matrix_test.gd` — PASS.
- `tests/runtime_smoke_ui_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS.
