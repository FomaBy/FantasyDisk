# Ultimate HUD widget (FAN-1458)

Status: contract v1 is mounted in the live combat HUD by the narrow
`UltimateHudRuntimeAdapter`. It translates Player charge, the selected exact
registry profile, input-device binding and aim state into the unchanged widget
contract, and routes an accepted request back through `Player.activate_ultimate()`.

## Package

| Path | Role |
| --- | --- |
| `scripts/ui/ultimate_hud/ultimate_hud_state.gd` | Versioned declarative state contract: normalization, fail-closed defaults, readiness/aim-preview predicates, persistent snapshot. |
| `scripts/ui/ultimate_hud/ultimate_hud_view_model.gd` | Builds widget state from a registry snapshot (`catalog_profile_for` + `resolution_source` + weapon config + human ultimate text). |
| `scripts/ui/ultimate_hud/ultimate_hud_widget.gd` | The widget: weapon icon/title, charge bar, ready badge, aim hint, binding glyph, Codex tooltip, activation signal. |
| `scenes/ui/ultimate_hud/ultimate_hud_widget.tscn` | Isolated scene (one `PanelContainer` + script). |
| `tests/ultimates/hud_fixture_library.gd` | Versioned contract fixtures built from the real `WeaponUltimateRegistry`. |

Read-only sources this package consumes and must never edit:
`scripts/ui/input_glyph_registry.gd`, `scripts/input/aim_controller.gd`
(FAN-1449), `scripts/ultimates/registry/**`,
`docs/design/systems/weapon_ultimates_contract.md`.

## State contract (v1)

`apply_state()` accepts any dictionary and normalizes it fail-closed:

```gdscript
{
  "contract_version": 1,
  "selection": {
    "class_id": String, "weapon_id": String,
    "profile_id": String, "title_id": String,     # registry identity IDs
    "weapon_title": String, "weapon_icon_path": String,
    "source": "weapon_profile" | "legacy_class_fallback",
  },
  "ultimate": {"title": String, "description": String},
  "charge": {"fraction": 0.0..1.0, "active": bool},
  "input": {
    "device": "keyboard" | "gamepad" | "none",
    "joy_button": int,        # default JOY_BUTTON_Y (InputDeviceManager "ultimate")
    "key_label": String,      # default "R" (main.gd rebind table)
    "key_glyph": String,      # key glyph registry name, default "generic"
  },
  "aim": {"mode": "nearest" | "cursor", "aiming": bool},
}
```

Contract rules the tests pin down:

- **Selected weapon, never the class.** Identity (icon, title, `profile_id`)
  always comes from the exact selected weapon profile of the registry
  snapshot — including when `resolution_source` is `legacy_class_fallback`.
  Only the executable ultimate *text* may come from the legacy class config.
- **Charge persistence.** `persistent_snapshot()` keeps `charge.fraction` and
  forcibly clears `charge.active`. Re-applying the snapshot draws the same
  charge; the active-state overlay is runtime-only and is never restored
  across UI node transitions.
- **Input glyphs.** Glyph textures come only from
  `scripts/ui/input_glyph_registry.gd`: `key_glyph` for keyboard,
  `JOY_BUTTON_TO_GLYPH[joy_button]` for gamepad. Hot-plug is a repeated
  `apply_state` with the new `input.device`. `device == "none"` renders the
  ultimate inactive (dimmed, inert binding placeholder) and
  `request_activation()` never emits `activation_requested`.
- **Aim/ready feedback.** Aim semantics mirror the canonical AimController:
  the stick preview hint appears only for `cursor` mode on gamepad
  (`reticle_visible` semantics); mouse manual aim points with the cursor; auto
  aim shows nothing. Ready feedback is rare and visible: the "ГОТОВО" badge
  while ready plus a one-shot `consume_ready_pulse()` on the transition to
  full charge — no continuous flashing over combat.
- **Activation.** `request_activation()` emits `activation_requested(profile_id)`
  only when the state is renderable, input is available, charge is full and no
  activation is already active.

## Layout rules

The widget is a self-sized atlas-chip `PanelContainer` (GlobalTooltip panel
style): icon well, title row with ready badge, charge bar with active overlay,
aim hint, binding glyph column. The Codex tooltip is a `top_level` hidden
panel (`codex_tooltip()`); the owner decides where to show it. Typography uses
`SemanticTypography.resolve()` (`hud` / `caption` / `tooltip` roles) against
the live viewport height, so the widget follows the 648→2160 semantic scale.
Content stays inside the frame's content zone (border + authored margins);
the isolated scene passes fit/no-overlap at 1152x648, 1280x720, 1920x1080 and
2560x1440.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/hud_state_contract_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/hud_input_glyph_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/hud_layout_responsive_test.gd
```

All three are ordinary (non-exclusive) headless suites; `tools/quality_gate.py`
discovers them recursively under `tests/ultimates/`. The live adapter keeps the
widget mounted across combat HUD refreshes; charge remains Player-owned and is
therefore preserved by the existing Player snapshot lifecycle while the active
overlay is reset with the HUD node.
