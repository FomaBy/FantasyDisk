# Ultimate accessibility configuration

Ultimate presentation preferences are stored in `user://settings.cfg`, in the existing `[settings]` section:

```ini
[settings]
ultimate_reduced_motion=false
ultimate_photosensitivity_safe=false
```

Both options default to `false`, so an existing configuration with neither key keeps the normal presentation behaviour. The supported stored values are the booleans `true` and `false`. As with the existing boolean settings contract, loaded legacy or malformed values are normalized with GDScript boolean coercion before they are published.

## Runtime API and application timing

`scripts/settings/ultimate_accessibility_settings.gd` is the production configuration API. `Main._load_game_settings()` loads the persisted values during normal startup and calls `apply_settings()` to publish one normalized dictionary on the scene-tree root under the `ultimate_accessibility_settings` metadata key. Consumers should preload the helper and call:

```gdscript
const ULTIMATE_ACCESSIBILITY_SETTINGS := preload("res://scripts/settings/ultimate_accessibility_settings.gd")

var modes := ULTIMATE_ACCESSIBILITY_SETTINGS.read_snapshot(get_tree().root)
var reduced_motion := bool(modes[ULTIMATE_ACCESSIBILITY_SETTINGS.REDUCED_MOTION_KEY])
var photosensitivity_safe := bool(modes[ULTIMATE_ACCESSIBILITY_SETTINGS.PHOTOSENSITIVITY_SAFE_KEY])
```

`read_snapshot()` reports the currently applied root snapshot, not a stale settings dictionary. Editing `user://settings.cfg` or a dictionary does not live-update an already running scene tree. To intentionally change the active snapshot, normalize and publish it with `apply_snapshot(get_tree().root, changed_snapshot)`, then call the normal `Main.save_game_settings()` boundary to persist it. The next application start also applies the saved values automatically.

Main writes the applied snapshot back into its ordinary save dictionary before every save. Therefore unrelated audio, display, and input saves preserve both preferences.

## Combined modes and consumer scope

The two booleans are independent and all four combinations are preserved:

| Reduced motion | Photosensitivity safe | Published request |
| --- | --- | --- |
| false | false | Normal ultimate presentation |
| true | false | Reduced-motion ultimate presentation |
| false | true | Photosensitivity-safe ultimate presentation |
| true | true | Both requirements apply together |

This configuration contract does not alter class scenes, effects, timings, or rendering by itself. Each ultimate presentation consumer is responsible for reading the snapshot and implementing the requested behaviour, including the combined case. No Settings UI controls or accessibility certification are supplied by this configuration-only change; those are separate dependent deliveries.
