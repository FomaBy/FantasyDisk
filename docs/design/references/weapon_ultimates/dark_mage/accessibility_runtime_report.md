# Dark Mage accessibility runtime report (FAN-3946)

This report records what the three Dark Mage ultimates actually do under the
production accessibility settings, measured through the real runtime path.
It does not certify the FAN-3938 four-mode/four-viewport capture matrix.

## Modes and their combined semantics

The driver `scenes/vfx/ultimates/dark_mage/dark_mage_ultimate_v2_driver.gd` and
the three class executors read the snapshot Main publishes on the scene-tree
root from `user://settings.cfg` (`scripts/settings/ultimate_accessibility_settings.gd`).
Both options are independent booleans; the combined case is the union of the
two rule sets, and where both touch the same device the stricter rule wins.

| Device | normal | reduced motion | photosensitivity-safe | both |
| --- | --- | --- | --- | --- |
| Timeline animation | `ultimate` | `ultimate_reduced_motion` (authored per scene, same length and beats) | `ultimate` | `ultimate_reduced_motion` |
| Camera shake at release | yes | suppressed | yes (honours `screen_shake`) | suppressed |
| Hitstop time-scale dip | 0.4 for 100/120/90 ms | suppressed | kept | suppressed |
| Hero pose / silhouette | scale pop at release | held at released size | alpha capped 0.75 | held, capped |
| Backdrop | per-phase alpha steps 0.14/0.35 (0.30 flash)/0.22/0.08 | same levels, eased at 0.6 alpha/s | one darken veil at 0.12, ramped at 0.24 alpha/s, no flash tint | photosensitivity-safe veil |
| Flipbook luminance | authored | authored | `self_modulate` alpha 0.6 | 0.6 |
| Victim burst | flipbook + extra white flash per victim | unchanged | flipbook dimmed to 0.6, no extra flash (ordinary damage flash only) | dimmed, no extra flash |
| SFX ducking | yes | yes | yes | yes |
| Gameplay, damage, targeting, phase timing | unchanged | unchanged | unchanged | unchanged |

## Reduced-motion substitutes (class manifest `quality.reduced_motion_substitute`)

| Weapon | Declared substitute | Authored `ultimate_reduced_motion` |
| --- | --- | --- |
| `dark_book` | keep the mirror and paired silhouettes while replacing the lens detonation with one low-contrast pulse | mirror held at scale 0.62, reflections held at ±(108, 6); the 1.2 s bloom becomes an alpha pulse 0.72 → 0.90 → 0.72 over 1.2–2.0 s; frame and alpha tracks unchanged |
| `cursed_skull` | hold the crown and three chains while using a single non-flashing harvest contraction | crown held raised at (0, −86) scale 0.72, soul orbits held at ±(82, 26/18); one contraction 0.72 → 0.60 over 2.55–2.9 s; alpha tracks unchanged |
| `dark_wand` | keep the wand silhouette and one persistent thread while collapsing all marks with reduced particle motion | thread held at (−58, 8) rotation −0.14; echoes held at (58, 42) and (112, −58); both contract 0.42 → 0.30 and 0.34 → 0.24 over 2.9–3.3 s |

Each variant has the same length as `ultimate`, so `reduced_motion_preserves_timing` holds by construction and is measured below.

## Method

- Source: `dev` at `6b76adfc0dba4fcad64c34f094ef3f9f79b7e405` plus this card's changes (candidate SHA in the delivery comment).
- Godot 4.7-stable (official), renderer `gl_compatibility`, macOS (Apple Silicon), fixed 60 fps (`--fixed-fps 60`), seed 3946 (the run RNG is re-seeded per cell).
- Test: `tests/ultimates/presentation/dark_mage_accessibility_modes_test.gd`. Each of the 12 cells persists one option combination to `user://settings.cfg`, boots `scenes/Main.tscn`, starts the shipped arena (`_start_combat`) with a real Player equipped with the weapon, places 8 shipped Enemy hazards through the director spawn path, casts through `Player.activate_ultimate()` and samples every process frame until the controller releases the cast. The caller's settings.cfg is restored afterwards.
- The Player's own loops and its equipped weapon subtree are frozen from the first combat frame so the weapon's auto-attacks (and the skull weapon's ticking curse) do not add unrelated hit flashes to the victim measurement; the UltimateHost, its tweens, enemies, camera and HUD run normally.
- Headless command (the shared runtime has no display, so the host's `_presentation_headless_mode` is forced to 0 to mount the same authored scene):

```bash
DARK_MAGE_ACCESSIBILITY_REPORT=build/qa/fan3946/headless_observations.json \
  python3 tools/godot_gate.py --headless --path . --fixed-fps 60 \
  --script res://tests/ultimates/presentation/dark_mage_accessibility_modes_test.gd
```

- Windowed command (exclusive workload admission; adds real `Engine.time_scale`, camera offset and framebuffer measurements):

```bash
FSD_GODOT_EXCLUSIVE=1 DARK_MAGE_ACCESSIBILITY_REPORT=build/qa/fan3946/windowed_observations.json \
  python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 \
  --script res://tests/ultimates/presentation/dark_mage_accessibility_modes_test.gd
```

- Flash measurement: every new `CombatHitTick` sprite in the `combat_feedback_flashes` group is one ordinary enemy hit flash; same-frame ticks form one event; the rate is the largest event count in any rolling one-second window (WCAG 2.3.1 general flash threshold: 3). Coverage uses the inner 0.30 footprint of the shipped 128 px `impact_flash.png` (alpha ≥ 0.25) scaled to the tick and the camera zoom. Windowed runs additionally sample the framebuffer every second frame at an 8 px stride and record the fraction of samples whose relative luminance moves by 10% or more between consecutive samples.

## Windowed observations (all 12 cells PASS)

| Weapon | Mode | Timeline | release / active / recovery seen (s) | min time_scale | camera peak (px) | backdrop peak alpha / max step | flipbook alpha peak | flash events/s | flash coverage | max changed pixels | flash ticks (8 hazards) |
| --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| `dark_book` | normal | `ultimate` | 0.700 / 1.200 / 2.517 | 0.40 | 69.7 | 0.35 / 0.210 | 1.00 | 2 | 0.0388 | 0.212 | 16 |
| `dark_book` | reduced_motion | `ultimate_reduced_motion` | 0.700 / 1.200 / 2.517 | 1.00 | 0.0 | 0.35 / 0.010 | 0.90 | 2 | 0.0388 | 0.127 | 16 |
| `dark_book` | photosensitivity_safe | `ultimate` | 0.700 / 1.200 / 2.517 | 0.40 | 67.7 | 0.12 / 0.004 | 0.60 | 1 | 0.0388 | 0.131 | 8 |
| `dark_book` | combined | `ultimate_reduced_motion` | 0.700 / 1.200 / 2.517 | 1.00 | 0.0 | 0.12 / 0.004 | 0.54 | 1 | 0.0388 | 0.132 | 8 |
| `cursed_skull` | normal | `ultimate` | 0.850 / 1.300 / 2.917 | 0.40 | 65.6 | 0.30 / 0.160 | 1.00 | 9 | 0.0388 | 0.096 | 40 |
| `cursed_skull` | reduced_motion | `ultimate_reduced_motion` | 0.850 / 1.300 / 2.917 | 1.00 | 0.0 | 0.30 / 0.010 | 1.00 | 9 | 0.0388 | 0.125 | 40 |
| `cursed_skull` | photosensitivity_safe | `ultimate` | 0.850 / 1.300 / 2.917 | 0.40 | 69.9 | 0.12 / 0.004 | 0.60 | 3 | 0.0388 | 0.131 | 32 |
| `cursed_skull` | combined | `ultimate_reduced_motion` | 0.850 / 1.300 / 2.917 | 1.00 | 0.0 | 0.12 / 0.004 | 0.60 | 3 | 0.0388 | 0.131 | 32 |
| `dark_wand` | normal | `ultimate` | 0.950 / 1.467 / 2.917 | 0.40 | 68.0 | 0.35 / 0.210 | 1.00 | 7 | 0.0388 | 0.251 | 16 |
| `dark_wand` | reduced_motion | `ultimate_reduced_motion` | 0.950 / 1.467 / 2.917 | 1.00 | 0.0 | 0.35 / 0.010 | 1.00 | 7 | 0.0388 | 0.127 | 16 |
| `dark_wand` | photosensitivity_safe | `ultimate` | 0.950 / 1.467 / 2.917 | 0.40 | 70.7 | 0.12 / 0.004 | 0.60 | 1 | 0.0388 | 0.131 | 8 |
| `dark_wand` | combined | `ultimate_reduced_motion` | 0.950 / 1.467 / 2.917 | 1.00 | 0.0 | 0.12 / 0.004 | 0.60 | 1 | 0.0388 | 0.131 | 8 |

Declared beats: `dark_book` 0.70 / 1.20 / 2.50, `cursed_skull` 0.85 / 1.30 / 2.90, `dark_wand` 0.95 / 1.45 / 2.90. The largest changed-pixel fraction in the normal cells falls on the release frame pair (backdrop step plus camera shake); in every reduced-motion and photosensitivity-safe cell the largest value sits inside the first 0.17 s of the cast (arena settle, present in the normal cells at the same magnitude) and no beat frame pair exceeds it.

## Headless observations (all 12 cells PASS)

| Weapon | Mode | Timeline | release / active / recovery seen (s) | max flipbook travel per frame (px / scale / rad) | backdrop peak alpha / max step | shake flagged / hitstop ms | victim extra flash / burst alpha | flash events/s | flash ticks |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: |
| `dark_book` | normal | `ultimate` | 0.700 / 1.200 / 2.517 | 3.40 / 0.0228 / 0.0000 | 0.35 / 0.210 | true / 100 | true / 1.0 | 2 | 16 |
| `dark_book` | reduced_motion | `ultimate_reduced_motion` | 0.700 / 1.200 / 2.517 | 0.00 / 0.0000 / 0.0000 | 0.35 / 0.010 | false / 0 | true / 1.0 | 2 | 16 |
| `dark_book` | photosensitivity_safe | `ultimate` | 0.700 / 1.200 / 2.517 | 3.40 / 0.0228 / 0.0000 | 0.12 / 0.004 | true / 100 | false / 0.6 | 1 | 8 |
| `dark_book` | combined | `ultimate_reduced_motion` | 0.700 / 1.200 / 2.517 | 0.00 / 0.0000 / 0.0000 | 0.12 / 0.004 | false / 0 | false / 0.6 | 1 | 8 |
| `cursed_skull` | normal | `ultimate` | 0.850 / 1.300 / 2.917 | 6.58 / 0.0255 / 0.0000 | 0.30 / 0.160 | true / 120 | true / 1.0 | 9 | 40 |
| `cursed_skull` | reduced_motion | `ultimate_reduced_motion` | 0.850 / 1.300 / 2.917 | 0.00 / 0.0081 / 0.0000 | 0.30 / 0.010 | false / 0 | true / 1.0 | 9 | 40 |
| `cursed_skull` | photosensitivity_safe | `ultimate` | 0.850 / 1.300 / 2.917 | 6.58 / 0.0255 / 0.0000 | 0.12 / 0.004 | true / 120 | false / 0.6 | 3 | 32 |
| `cursed_skull` | combined | `ultimate_reduced_motion` | 0.850 / 1.300 / 2.917 | 0.00 / 0.0081 / 0.0000 | 0.12 / 0.004 | false / 0 | false / 0.6 | 3 | 32 |
| `dark_wand` | normal | `ultimate` | 0.950 / 1.467 / 2.917 | 7.58 / 0.0000 / 0.0080 | 0.35 / 0.210 | true / 90 | true / 1.0 | 7 | 16 |
| `dark_wand` | reduced_motion | `ultimate_reduced_motion` | 0.950 / 1.467 / 2.917 | 0.00 / 0.0071 / 0.0000 | 0.35 / 0.010 | false / 0 | true / 1.0 | 7 | 16 |
| `dark_wand` | photosensitivity_safe | `ultimate` | 0.950 / 1.467 / 2.917 | 7.58 / 0.0000 / 0.0080 | 0.12 / 0.004 | true / 90 | false / 0.6 | 1 | 8 |
| `dark_wand` | combined | `ultimate_reduced_motion` | 0.950 / 1.467 / 2.917 | 0.00 / 0.0071 / 0.0000 | 0.12 / 0.004 | false / 0 | false / 0.6 | 1 | 8 |

Victim flash event times, photosensitivity-safe and combined: `dark_book` one event at 0.70 s (8 ticks), `dark_wand` one event at 1.35 s (8 ticks), `cursed_skull` four events at 0.85 / 1.30 / 1.75 / 2.80 s (8 ticks each, the crown pulses and harvest the gameplay already deals). Normal and reduced-motion cells add the burst's extra white flash per victim (16 ticks for the book and wand, 40 for the skull), which is the unchanged ordinary presentation.

## Cleanup and restoration

After every cell the authored scene, `BackdropTreatment` and every `VictimImpact*` sprite are gone, `Engine.time_scale` is back to 1.0, the SFX bus volume equals its pre-cast value and the camera offset equals its pre-cast value. The windowed normal and photosensitivity-safe cells prove the restoration after a real 0.4 dip and a real 65–71 px shake.

## Limitations

- The reduced-motion variants keep the flipbook frame tracks: the substitutes remove travel, scale blooms and rotation, not the sprite art's own frame cycle.
- The ordinary `AnimationPlayer` runs on scaled time, so after a real hitstop it trails the real-time phase clock by 60% of the freeze (54–72 ms). This is unchanged production behaviour; the reduced-motion variant has no dip and no drift.
- Flash coverage is a geometric estimate from the shipped flash texture; the windowed changed-pixel fraction is the direct framebuffer measurement.
- Crowded presentation and the four-viewport certification matrix remain owned by FAN-3938 and were not measured here (8 hazards per cell, one viewport at the shipped window size).
- The eased backdrop in reduced motion never reaches its cancel fade-out because the runtime releases the scene at the cancel beat; the veil is removed with the scene at its recovery level (0.08 ordinary levels, 0.12 photosensitivity-safe), which is below the 10% luminance change the framebuffer measurement counts.
