# Back-end Task: Integrate Dark Fantasy UI Theme Assets

Статус: in_progress
Версия: 0.1.4
Создано: 2026-06-13
Автор: Design handoff from SCRUM-147
Jira: SCRUM-222

## Dispatcher Note (2026-06-13)
Jira key `SCRUM-222` is now synced. Dispatched to Back-end thread
`019eabd9-780b-78a2-9f4b-e7203d659ef2` for 0.1.4 UI theme integration.
Scope is code/theme wiring and verification; any newly discovered motion/timing
work must be handed off to Animator instead of handled in Back-end.

Dependency update: SCRUM-147 Design review rejected the current generated frame
set on 2026-06-13 because it does not match the Parchment & Wax Seal reference.
Do not wire the rejected dark_fantasy/global/escape frame assets as final
styleboxes. Wait for the accepted SCRUM-147 regeneration, or limit work to
non-final scaffolding that can swap assets without committing the rejected kit.

## Context

Design completed the SCRUM-147 dark fantasy UI asset pass and replaced the live global/escape/shop frame PNGs in-place where possible. A new canonical 4-state button and frame kit now exists in:

```text
assets/sprites/ui/frames/dark_fantasy/
```

This task is Back-end scope: wire the new stateful theme/styleboxes into UI code, verify all screens, and safely retire superseded frame assets only after runtime checks.

## Scope

- Connect 4-state button textures for `ui_df_button_primary_*`, `ui_df_button_secondary_*`, and `ui_df_button_danger_*`.
- Prefer role-based mapping: primary for start/confirm/select/reward, secondary for back/settings/navigation, danger for exit/end run/defeat confirmation.
- Use new panel/card/HUD/tooltip/chip frames where code currently hardcodes global/escape/shop paths.
- Keep existing in-place replacements as fallback while moving toward explicit dark fantasy theme paths.
- Capture screenshots for main menu, settings, hero select, level-up/reward, Escape stats, shop, event, death/victory.
- After integration and smoke are green, archive/remove superseded old contextual/tavern frame assets with the safe asset cleanup procedure.

## Design Asset Map

Canonical kit:

```text
assets/sprites/ui/frames/dark_fantasy/
docs/design/previews/ui_dark_fantasy_restyle_kit_contact.png
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
- Final stylebox wiring uses the accepted SCRUM-147 regenerated kit, not the
  rejected 2026-06-13 frame set.
- No live screen uses the old tavern/contextual UI canon after integration.
- Superseded frame cleanup is done only after reference checks and backup.
