# Back-end Task: Integrate Dark Fantasy UI Theme Assets

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Design handoff from SCRUM-147
Jira: SCRUM-222

## Dispatcher Note (2026-06-13)
Jira key `SCRUM-222` is now synced. Dispatched to Back-end thread
`019eabd9-780b-78a2-9f4b-e7203d659ef2` for 0.1.4 UI theme integration.
Scope is code/theme wiring and verification; any newly discovered motion/timing
work must be handed off to Animator instead of handled in Back-end.

Dependency update: SCRUM-147 received a user correction on 2026-06-13. Use the
accepted-reference Parchment & Wax Seal regeneration for buttons only. All
non-button panel/card/HUD/tooltip/shop frame paths now intentionally mirror the
old/legacy interface look because the full parchment panels looked sliced and
strange in game. Active preview:
`docs/design/previews/ui_button_only_legacy_panels_contact.png`.

## Dispatcher Unblock / Redispatch (2026-06-13)

The previous SCRUM-147 blocker is resolved with narrower final scope: stateful
wax-seal buttons plus legacy-looking non-button frames at the same texture paths.
Redispatched to Back-end thread
`019eabd9-780b-78a2-9f4b-e7203d659ef2` for implementation and Jira sync.

Per PM request, keep High-level model/reasoning settings for this work; do not
downgrade to low. If integration reveals motion, timing, VFX sync, or animation
state work, create/update an Animator handoff instead of absorbing it in
Back-end.

## Context

Design completed the SCRUM-147 button-only correction and replaced the live global/escape/shop frame PNGs in-place where needed. A canonical 4-state button kit remains in:

```text
assets/sprites/ui/frames/dark_fantasy/
```

This task is Back-end scope: wire the new stateful theme/styleboxes into UI code, verify all screens, and safely retire superseded frame assets only after runtime checks.

## Scope

- Connect 4-state button textures for `ui_df_button_primary_*`, `ui_df_button_secondary_*`, and `ui_df_button_danger_*`.
- Prefer role-based mapping: primary for start/confirm/select/reward, secondary for back/settings/navigation, danger for exit/end run/defeat confirmation.
- Keep panel/card/HUD/tooltip/chip paths stable, but their visuals should match the restored old interface style after the SCRUM-147 correction.
- Keep existing in-place replacements as fallback while moving toward explicit dark fantasy theme paths.
- Capture screenshots for main menu, settings, hero select, level-up/reward, Escape stats, shop, event, death/victory.
- After integration and smoke are green, archive/remove superseded old contextual/tavern frame assets with the safe asset cleanup procedure.

## Design Asset Map

Canonical kit:

```text
assets/sprites/ui/frames/dark_fantasy/
docs/design/previews/ui_parchment_wax_scrum147_reference_match_contact.png
docs/design/previews/ui_dark_fantasy_restyle_kit_contact.png
docs/design/previews/ui_button_only_legacy_panels_contact.png
assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png
```

Live fallback paths already refreshed by Design:

```text
assets/sprites/ui/frames/global/*.png
assets/sprites/ui/frames/escape/*.png
assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png
assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png
assets/sprites/ui/shop/ui_shop_price_badge.png
assets/sprites/ui/shop/ui_shop_purchased_overlay.png
assets/sprites/ui/shop/ui_shop_tooltip_frame.png
```

## Acceptance

- Runtime smoke passes.
- UI no-overlap smoke/screenshots pass for key screens.
- Buttons visually use correct hover/pressed/disabled states from the new kit.
- Final stylebox wiring uses accepted SCRUM-147 4-state wax-seal buttons.
- Non-button frames intentionally use old/legacy visuals at the same texture paths.
- Superseded frame cleanup is done only after reference checks and backup.

## Result Summary (2026-06-13)

Closed by Back-end.

- Wired canonical `assets/sprites/ui/frames/dark_fantasy/` frame paths into the common UI style layer.
- Buttons now use real 4-state Parchment & Wax Seal textures for primary, secondary and danger roles instead of tinting a single fallback button frame.
- Common panels, cards, level-up panels, HUD panels/cards and tooltips resolve through the stable canonical paths; after the SCRUM-147 user correction their visuals intentionally mirror the old interface style.
- Added `tests/dark_fantasy_ui_theme_test.gd` to assert exact texture paths for primary/secondary/danger button states and common frame styleboxes.
- Extended runtime smoke to verify main menu primary/secondary/danger buttons use the canonical dark fantasy state textures.
- No Design/Animator work was performed; no rejected assets were wired.
- Safe cleanup of superseded historical frame assets remains deferred to the existing cleanup flow after reference checks/backups.

Verification:

- `Godot --headless --path ... --script res://tests/dark_fantasy_ui_theme_test.gd` — passed.
- `Godot --headless --path ... --script res://tests/ui_no_overlap_matrix_test.gd` — passed.
- `Godot --headless --path ... --script res://tests/runtime_smoke_test.gd` — passed.
