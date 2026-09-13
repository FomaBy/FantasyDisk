# Sniper ultimate certification — four-mode readability report

FAN-3940. FAN-3877's certification found Sniper's evidence to be four resolution
variants of one legacy timeline sheet rather than live captures of the normal,
crowded, reduced-motion and photosensitivity-safe presentation. This package
supplies the missing evidence from real runs.

It carries one production change, and only the one this class had already
promised: every Sniper `quality.reduced_motion_substitute` declares a static
substitute and says the tracer/barrage/waves, the shake **and the hitstop**
reduce, and the shipped runner performed none of that — it skipped the camera
shake and nothing else. `SniperUltimatePresentationScene` now performs the
declared substitute and drops the hitstop under reduced motion. Gameplay,
balance, timing, SFX, thresholds, the adoption shard and the four authored
timeline sheets are untouched.

## What was captured

| | |
| --- | --- |
| Source rendered from | `67be06fce33d929800a7de9b26f045e77f5f7c62`, tree `127030c3b5a9277e3bf8c620743954ea8abd99e8` (`agent/claude-opus-5/1c5e4dd4976a`) |
| Engine | Godot 4.7-stable (official) `5b4e0cb0f`, `gl_compatibility`, Metal 4.1, macOS, Apple M4 Pro |
| Renderer | `tests/ultimates/presentation/sniper_certification_live_capture.gd` |
| Gate | `tests/ultimates/presentation/sniper_certification_capture_test.gd` |
| Accessibility contract | `tests/ultimates/presentation/sniper_reduced_motion_contract_test.gd` |
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

## What each mode actually is

A mode is a persisted production configuration. It is written to
`user://settings.cfg` before the game boots, and every sample records the four
switches as `Main` itself published them on the scene-tree root — not as the
capture wished them to be. The operator's own settings file is restored byte for
byte however the run ends.

| Mode | Persisted production settings | Measured effect across its 36 samples |
| --- | --- | --- |
| `normal` | shipped defaults, 6 hazards | shake bound in 36/36; declared 90/100/120 ms hitstop applied; `Engine.time_scale` 0.4 at release |
| `crowded` | shipped defaults, hazards at the weapon's declared `crowd_cap` | 24 / 24 / 26 shipped enemies held in frame, matching each weapon's cap |
| `reduced_motion` | `ultimate_reduced_motion` on — **`screen_shake` left on** | substitute applied in 36/36; 0 ms hitstop; no camera ever bound; `Engine.time_scale` 1.0 in 36/36 |
| `photosensitivity_safe` | `ultimate_photosensitivity_safe` on and `combat_feedback` off | the shipped per-hit flashes are gone; near-white share stays at or below 0.0034 |

The reduced-motion column deliberately keeps `screen_shake` **on**. The class
promises a substitute, not the absence of a shake, so the evidence has to come
from the accessibility preference itself: a disabled camera shake cannot be the
thing that produced it. For the same reason `photosensitivity_safe` is a separate
column with the substitute *not* applied — at 1152x648 release its frame differs
from `normal` by 4.9 % of pixels and from `reduced_motion` by 54.9 %.

## What reduced motion does

Read from the values the runner writes where it applies the effect, not from the
manifest sentence that promises them.

| | `normal` / `crowded` / `photosensitivity_safe` | `reduced_motion` |
| --- | --- | --- |
| Backdrop alpha at release / active / recovery | 0.34 or 0.42 → 0.24 → 0.10 | 0.16 → 0.16 → 0.16 (one steady dim) |
| Hero cast pose scale | 0.40 | 0.30, held at its aimed size |
| Weapon silhouette scale | 0.72 | 0.46, held as one static glint |
| Camera shake | bound, 108/108 samples | never bound, 0/36 |
| Hitstop applied | 90 / 100 / 120 ms as declared | 0 ms |
| `Engine.time_scale` at release | 0.4 | 1.0 |
| SFX duck | applied | applied — audio is not motion |
| Phase timing | declared | identical; `reduced_motion_preserves_timing` holds |

`sniper_reduced_motion_contract_test.gd` casts the shipped scenes through the
production presentation runtime across five flag combinations — normal, the
reduced-motion preference alone, the photosensitivity-safe preference alone, both
together, and the shipped `screen_shake` mirror alone — and asserts each of the
rows above, plus restoration of the camera, the time scale, the SFX bus and the
reported state after cancel, natural finish, mid-cast teardown and a repeated
cast. Both suites carry fail-closed negatives for a substitute that was declared
but never applied, a release that kept its normal hitstop, a reduced-motion cast
that still shook or still froze the arena, an ordinary cast that claims the
substitute, and a class manifest that withdrew the promise.

## Readability at the beats

Measurements are taken on the framebuffer at native size, against real geometry —
the union of the boxes the presentation actually draws, and the live HUD control
rects read from `CombatHudRoot` rather than assumed bands.

| Weapon | Declared coverage cap | Measured `effect_box_ratio` (max) | Declared node budget | Nodes drawn (max) | Declared flash ceiling | Near-white share (max) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `sniper_deadeye_rifle` | 0.28 | 0.0731 | 11 | 7 | 0.12 | 0.0036 |
| `sniper_spotter_scope` | 0.30 | 0.0603 | 24 | 9 | 0.16 | 0.0035 |
| `sniper_shatter_rounds` | 0.30 | 0.0607 | 26 | 11 | 0.15 | 0.0049 |

Across all 144 samples:

- the live presentation scene was alive, showing its own phase, and drawing the
  beat's required nodes — 144 of 144;
- four live HUD bands were in frame every time, none was ever overlapped by the
  presentation box, and the worst band contrast was 0.787;
- the worst player contrast was 0.647, in crowded mode; the reduced-motion worst
  was 0.665;
- the declared full-screen backdrop reached the viewport in every sample.

By beat, the effect resolves as declared: `effect_box_ratio` falls from
0.0366-0.0731 at release, to 0.0235-0.0603 at active, to 0.0080-0.0172 at
recovery, and the drawn node count falls from 7-11 to 6. The substitute stays
inside the same envelope: its widest frame is 0.0607, against caps of 0.28-0.30.

## Observed limitations

These are recorded, not repaired. Each is evidence for a separate decision.

1. **Sniper has no photosensitivity-specific branch of its own, by design.** The
   class declares no photosensitivity substitute — only flash ceilings, which the
   shipped presentation already meets. What the mode removes is the shipped
   per-hit flash on the victims, which is real and visible in the sheets. The
   measurement carrying the rest of the claim is the near-white share, which
   never exceeds 0.0049 of the frame against declared ceilings of 0.12-0.16. The
   presentation observes the preference and reports it; it never treats it as
   reduced motion.
2. **`backdrop_box_ratio` is 1.166, not 1.0.** The backdrop treatment is fitted
   to the viewport with the shipped 1.08 overscan on each axis so no gap appears
   when the camera reaches an arena limit. The number is the declared behaviour,
   not an overrun.
3. **`changed_pixel_ratio` is not an effect footprint.** It is the share of the
   frame that differs from the pre-cast baseline, so it also carries ordinary
   scene motion — enemies walking, animation, camera drift — and runs 0.364-0.926.
   The footprint bounded by `max_viewport_coverage_ratio` is `effect_box_ratio`.
4. **A still frame cannot show shake amplitude.** What it can show is whether the
   shipped code took the shake path, which `camera_shake_applied` records for all
   144 samples, alongside the live `Engine.time_scale` at the sampled frame.
5. **The earlier fixture-based contrast findings remain diagnostic only.** The
   first candidate measured a flat marker instead of the shipped player sprite
   and reported it falling into the Shatter Rounds fan at 1152x648. Against the
   real player the worst contrast in this package is 0.647, so that result
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

# The production accessibility contract, on the shipped scenes.
python3 tools/godot_gate.py --headless --path . \
    --script res://tests/ultimates/presentation/sniper_reduced_motion_contract_test.gd
FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --windowed --fixed-fps 60 --path . \
    --script res://tests/ultimates/presentation/sniper_reduced_motion_contract_test.gd

# The existing class suites stay green.
python3 tools/godot_gate.py --headless --path . \
    --script res://tests/ultimates/presentation/sniper_ultimate_timelines.gd
git lfs fsck
```

The run pins its generator seed and `--fixed-fps 60`, so the wave, the hazard
ring and the sampled beats are the same on a re-run. A live game frame is not
promised byte-for-byte across machines: the gate checks the committed bytes by
hash and re-derives every readability claim from the recorded measurements.
