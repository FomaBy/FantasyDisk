# Sniper ultimate certification — four-mode readability report

FAN-3940. FAN-3877's certification found Sniper's evidence to be four resolution
variants of one legacy timeline sheet rather than live captures of the normal,
crowded, reduced-motion and photosensitivity-safe presentation. This package
supplies the missing evidence from real runs. It adds no production behaviour:
the Sniper scenes, VFX, gameplay values and adoption shard are untouched, and
the four authored timeline sheets stay committed as `authored_timeline_sheets`.

## What was captured

| | |
| --- | --- |
| Source rendered from | `68c1d74aa749b00a4c55827af27c06455ee3e658`, tree `740683f960a1d9f8da454240b68e55aca994eed9` (`agent/claude-opus-5/382672c5cdf7`, production code equal to `origin/dev`) |
| Engine | Godot 4.7-stable (official) `5b4e0cb0f`, `gl_compatibility`, macOS, Apple M4 Pro |
| Renderer | `tests/ultimates/presentation/sniper_certification_live_capture.gd` |
| Gate | `tests/ultimates/presentation/sniper_certification_capture_test.gd` |
| Machine-readable data | `certification_capture_manifest.json` — 144 measured samples, 4 file hashes |
| Matrix | 3 weapons x 4 modes x 4 viewports x 3 beats = 144 live samples |

Every sample is a frame of a real run. `scenes/Main.tscn` is instantiated,
`_start_combat()` builds the shipped arena with the shipped combat HUD and a real
`Player` configured for `sniper/<weapon>`, shipped `Enemy` instances stand in the
frame as hazards, and the ultimate is cast through
`UltimatePlayerHost.activate()`. The window is resized to the viewport under test
and the framebuffer is read back at that native size; nothing about the
presentation is redrawn, substituted or annotated.

The four committed sheets are one per viewport, twelve weapon x mode cells at the
active beat. They are the human index; the per-beat record lives in the capture
manifest. The shared visual-direction contract admits exactly one contact sheet
per viewport and CI materialises only the LFS paths a class manifest lists under
`evidence.contact_sheets`, so a fifth sheet would reach the gate as an unsmudged
pointer. `SNIPER_CERT_FRAME_DIR` re-renders every one of the 144 frames at full
size for anyone who wants to inspect a single combination.

## What each mode actually changes

The four modes are driven only by switches the shipped game already publishes on
the scene-tree root from `GameSettings`. The manifest records what each one
measurably did across its 36 samples.

| Mode | Shipped switches | Measured effect |
| --- | --- | --- |
| `normal` | `screen_shake` on, `combat_feedback` on, 6 hazards | `camera_shake_applied: true` in all 36 samples |
| `crowded` | same switches, hazards at the weapon's declared `crowd_cap` | 24 / 24 / 26 shipped enemies held in frame, matching each weapon's cap |
| `reduced_motion` | `screen_shake` off | `camera_shake_applied: false` in all 36 samples — the presentation never binds a camera |
| `photosensitivity_safe` | `screen_shake` off and `combat_feedback` off | the shipped per-hit flashes are gone; near-white share stays at or below 0.0036 |

`camera_shake_applied` is the runtime's own answer, not a label: the presentation
only assigns its camera after its `screen_shake` check passes, so a
reduced-motion sample that still shook would fail the gate.

## Readability at the beats

Measurements are taken on the framebuffer at native size, against real geometry —
the union of the boxes the presentation actually draws, and the live HUD control
rects read from `CombatHudRoot` rather than assumed bands.

| Weapon | Declared coverage cap | Measured `effect_box_ratio` (max) | Declared node budget | Nodes drawn (max) | Declared flash ceiling | Near-white share (max) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `sniper_deadeye_rifle` | 0.28 | 0.0731 | 11 | 7 | 0.12 | 0.0036 |
| `sniper_spotter_scope` | 0.30 | 0.0603 | 24 | 9 | 0.16 | 0.0035 |
| `sniper_shatter_rounds` | 0.30 | 0.0607 | 26 | 11 | 0.15 | 0.0050 |

Across all 144 samples:

- the live presentation scene was alive, showing its own phase, and drawing the
  beat's required nodes — 144 of 144;
- four live HUD bands were in frame every time, none was ever overlapped by the
  presentation box, and the worst band contrast was 0.787;
- the worst player contrast was 0.617, at 2560x1440;
- the declared full-screen backdrop reached the viewport in every sample.

By beat, the effect resolves as declared: `effect_box_ratio` falls from
0.0366-0.0731 at release, to 0.0332-0.0603 at active, to 0.0143-0.0172 at
recovery, and the drawn node count falls from 7-11 to 6.

## Observed limitations

These are recorded, not repaired. This card authorises no production change, so
each item is evidence for a separate decision rather than a defect fixed here.

1. **The Sniper presentation has no photosensitivity-specific branch of its own.**
   What `combat_feedback` removes is the shipped per-hit flash on the victims,
   which is real and visible in the sheets; the backdrop treatment is identical
   between the two shake-off modes. The measurement that carries the rest of the
   claim is the near-white share, which never exceeds 0.005 of the frame against
   declared ceilings of 0.12-0.16.
2. **The reduced-motion variant is narrower than the manifest describes.** Each
   weapon declares a `reduced_motion_substitute` — a steady dim, a held pose, a
   static glint. `SniperUltimatePresentationScene` implements none of that; it
   only skips the camera shake. Classes that already adopted the gate (Berserk,
   Chemist) additionally damp the backdrop veil in `_apply_reduced_motion()`.
3. **`backdrop_box_ratio` is 1.166, not 1.0.** The backdrop treatment is fitted
   to the viewport with the shipped 1.08 overscan on each axis so no gap appears
   when the camera reaches an arena limit. The number is the declared behaviour,
   not an overrun.
4. **`changed_pixel_ratio` is not an effect footprint.** It is the share of the
   frame that differs from the pre-cast baseline, so it also carries ordinary
   scene motion — enemies walking, animation, camera drift — and runs 0.36-0.93.
   The footprint bounded by `max_viewport_coverage_ratio` is `effect_box_ratio`.
5. **Hitstop is not tied to the accessibility toggle.** The shipped scene applies
   its declared 90-120 ms hitstop in every mode, reduced motion included.
6. **A still frame cannot show shake amplitude.** What it can show is that the
   shipped code did or did not take the shake path, which is what
   `camera_shake_applied` records for all 144 samples.
7. **Earlier fixture-based contrast results are diagnostic only.** The previous
   candidate measured a flat marker instead of the shipped player sprite and
   reported the marker falling into the Shatter Rounds fan at 1152x648. Against
   the real player the worst contrast in this package is 0.617, so that result
   describes the fixture, not the game.

## Reproducing this

```bash
# Re-capture the 144 live samples and the four sheets (windowed; a headless
# display server owns no framebuffer to read back).
SNIPER_CERT_SOURCE_REF=<ref> SNIPER_CERT_SOURCE_SHA=<sha> SNIPER_CERT_SOURCE_TREE=<tree> \
FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 \
    --script res://tests/ultimates/presentation/sniper_certification_live_capture.gd

# Optional: every frame at full size, for inspecting one combination.
SNIPER_CERT_FRAME_DIR=/tmp/sniper-frames ...

# Gate the committed evidence, including the fail-closed negatives.
python3 tools/godot_gate.py --headless --path . \
    --script res://tests/ultimates/presentation/sniper_certification_capture_test.gd

# The existing class suites stay green.
python3 tools/godot_gate.py --headless --path . \
    --script res://tests/ultimates/presentation/sniper_ultimate_timelines.gd
git lfs fsck
```

The run pins its generator seed and `--fixed-fps 60`, so the wave, the hazard
ring and the sampled beats are the same on a re-run. A live game frame is not
promised byte-for-byte across machines: the gate checks the committed bytes by
hash and re-derives every readability claim from the recorded measurements.
