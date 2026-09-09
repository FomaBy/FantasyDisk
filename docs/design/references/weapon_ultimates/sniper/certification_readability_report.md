# Sniper ultimate certification — four-mode readability report

FAN-3940. FAN-3877's independent certification of `d192be10bbe52dd89971cab0acc66eb92ccab37f`
recorded Sniper as one of fifteen classes whose evidence was four *resolution*
variants of one legacy timeline sheet rather than declared live captures of the
normal, crowded, reduced-motion and photosensitivity-safe presentation. This
package supplies the missing evidence. It adds no production behaviour: the
Sniper scenes, VFX, gameplay values, adoption shard and the four legacy contact
sheets are untouched.

## What was captured

| | |
| --- | --- |
| Source rendered from | `d192be10bbe52dd89971cab0acc66eb92ccab37f`, tree `e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf` (`origin/dev`) |
| Engine | Godot 4.7-stable (official), `gl_compatibility`, macOS display driver, Apple M4 Pro |
| Renderer | `tests/ultimates/presentation/sniper_certification_live_capture.gd` |
| Gate | `tests/ultimates/presentation/sniper_certification_capture_test.gd` |
| Machine-readable data | `certification_capture_manifest.json` (144 measured frames, 16 file hashes) |
| Matrix | 3 weapons x 4 modes x 4 viewports x 3 beats = 144 native frames in 16 sheets |

Every cell of every sheet is a native-resolution render of the shipped
`*_ultimate.tscn` presentation scene, advanced through `begin()`/`advance()` to a
declared beat, with the shipped weapon effect scene (`scripts/ultimates/classes/sniper/*.tscn`)
configured against live hazard nodes so the production victim-impact flipbook
plays on real victims. The player marker, the hazards and both HUD bands stay on
screen. A sheet cell is that native frame downscaled by one third — never a
separately rendered miniature — so the 648p sheet the shared contract judges
readability on is a true contact sheet of 1152x648 frames.

Headless runs are skipped rather than substituted: a headless display owns no
render target, so the readback would be empty. The gate, not the renderer, is
what fails closed on missing or fake evidence.

## What each mode actually changes

The four modes are configurations of the shipped runtime, and the manifest
records what each one measurably did.

| Mode | Configuration | Measured effect |
| --- | --- | --- |
| `normal` | `screen_shake` on, three live hazards | `camera_shake_applied: true` in all 36 frames, camera offset up to 6.38 px |
| `crowded` | `screen_shake` on, hazards at the weapon's declared `crowd_cap` (24/24/26) | 24-26 live victims per frame, impact pool peak 6-7, `degraded: false` throughout |
| `reduced_motion` | `screen_shake` off — the shipped accessibility toggle `SniperUltimatePresentationScene` reads off the tree root | `camera_shake_applied: false` and camera offset exactly `(0.0, 0.0)` in all 36 frames |
| `photosensitivity_safe` | `screen_shake` off **and** `combat_feedback` off — both switches `main.gd` publishes on the tree root from `GameSettings` — plus a full-cast veil-alpha series sampled every 0.05 s | `flashes: 0` in all 36 frames against 2 in `reduced_motion`, and one rising veil edge per cast: 0.34 Hz / 0.29 Hz / 0.32 Hz, peak alpha 0.42 / 0.34 / 0.34 |

Both root switches are read by shipped code, not by the capture: the presentation
scene gates its camera shake on `screen_shake`, and `UltimateVictimImpactPlayer`
asks every victim for `_combat_feedback_enabled()` before flashing it, exactly as
`enemy.gd` answers it. The hazard nodes in these captures answer the same way and
draw the same additive `impact_flash` tick, so turning the switch off removes a
real flash rather than a drawn annotation.

## Readability at the beats

Measurements are taken on the HUD-free render of the same frame, with the tree
paused between the two reads so the live shake tween cannot move the picture
between what was measured and what was delivered. Probe positions are corrected
by the live camera offset. Markers are judged by luminance contrast against
their own immediate surroundings, because the shipped backdrop is a deliberate
translucent tint that would otherwise read as a lost marker.

| Weapon | Declared `max_viewport_coverage_ratio` | Measured opaque coverage (max) | HUD band intrusion (max) | Declared `full_screen_flash_hz` | Measured veil rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| `sniper_deadeye_rifle` | 0.28 | 0.024 | 0.0000 | 0.0 | 0.34 Hz, one rising edge |
| `sniper_spotter_scope` | 0.30 | 0.079 | 0.0517 | 0.0 | 0.29 Hz, one rising edge |
| `sniper_shatter_rounds` | 0.30 | 0.077 | 0.0487 | 0.0 | 0.32 Hz, one rising edge |

All three stay far inside their declared opaque-coverage caps. None of the three
produces a repeating full-screen flash: the veil is a single monotone step per
phase, one rising edge across a whole cast, three orders of magnitude below the
WCAG 2.3.1 general flash threshold of 3 Hz.

139 of 144 frames keep the player marker readable and every frame keeps the cast
pose and weapon silhouette bound.

## Observed limitations

These are recorded, not repaired. This card authorises no production scene,
runtime, executor or overlay change, so each item below is evidence for a
separate scope decision rather than a defect fixed here.

1. **The photosensitivity-safe difference is real but small.** With
   `combat_feedback` off the per-victim additive tick disappears — `flashes: 0`
   against 2 — and 2.223 % of the 648p sheet's pixels change. That is the whole
   of it: `SniperUltimatePresentationScene` has no photosensitivity branch of its
   own, so the backdrop veil is unchanged between the two shake-off modes. The
   veil series is what carries the rest of the claim, and it shows there is
   nothing left to suppress: one 0.29-0.34 Hz rising edge per cast against a
   3 Hz threshold. At the sheet's one-third scale the two modes look alike; the
   measurements, not the thumbnails, are where they separate.
2. **The reduced-motion variant is narrower than the manifest describes.** Each
   weapon declares a `reduced_motion_substitute` — a steady dim, a held pose, a
   static glint. `SniperUltimatePresentationScene` implements none of that; it
   only skips the camera shake. Classes that already adopted the gate (Berserk,
   Chemist) additionally damp the backdrop veil through `_apply_reduced_motion()`.
   Sniper's declared substitute is therefore ahead of its runtime.
3. **`sniper_shatter_rounds` loses the player marker at 648p.** In 5 frames — the
   release and active beats of the three-hazard modes at 1152x648 only — the
   marker's contrast against its surroundings falls to 0.033-0.108, below the
   0.12 threshold. The crystal fan shares the class's pale-blue palette, and the
   flat pale-blue marker is the worst case for it; a differently coloured player
   sprite would separate better. Every 720p, 1080p and 2560x1440 frame passes, as
   does every crowded frame. Recorded for visual review, not asserted as a
   contract failure.
4. **`sniper_spotter_scope` flattens hazard luminance.** Under its crimson field
   only 1 of 3 hazard markers keeps a 0.12 luminance separation, although all
   three keep their red hue. The crowded frames read better (18-24 of 24), because
   the denser field supplies its own contrast.
5. **Both flash-backdrop weapons reach the HUD review bands.** Up to 5.17 % of
   the band area carries an opaque body behind the HUD. The bands are the review
   convention shared with the Engineer capture spec (top and bottom 9 % of the
   frame), not shipped HUD geometry, so this is a number for the visual reviewer
   rather than a measurement of the declared `hud_bands_clear`.
6. **Hitstop is not tied to the accessibility toggle.** The shipped scene applies
   its declared 90-120 ms hitstop in every mode, reduced motion included.
7. **A still frame cannot show shake amplitude.** What it can show is that the
   frame is displaced in `normal`/`crowded` and exactly centred in the two
   shake-off modes, which is what the recorded camera offsets prove.

## Reproducing this

```bash
# Re-render the sixteen sheets and rewrite the capture manifest (windowed).
FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --fixed-fps 60 \
    --script res://tests/ultimates/presentation/sniper_certification_live_capture.gd

# Gate the committed evidence, including the fail-closed negatives.
python3 tools/godot_gate.py --headless --path . \
    --script res://tests/ultimates/presentation/sniper_certification_capture_test.gd

# The existing class suites stay green.
python3 tools/godot_gate.py --headless --path . \
    --script res://tests/ultimates/presentation/sniper_ultimate_timelines.gd
git lfs fsck
```

The renderer seeds the RNG per frame and the run is pinned to `--fixed-fps 60`,
so the shipped camera-shake tween is sampled at a fixed delta and a re-render
reproduces the committed sheets rather than a differently shaken frame.
