# Berserk ultimate readability certification (FAN-3935)

FAN-3877's independent certification of `d192be10bbe52dd89971cab0acc66eb92ccab37f`
failed Berserk on evidence, not on behaviour: the class carried four *resolution*
variants of one authored timeline sheet, which say nothing about how the three
ultimates read in the normal, crowded, reduced-motion and photosensitivity-safe
presentations. This package replaces that gap with live evidence and the tooling
that reproduces it. No production scene, VFX, executor, gameplay or balance value
changed.

## What was captured

Every frame is a real run. `scenes/Main.tscn` is instantiated, `_start_combat()`
builds the shipped arena, the shipped combat HUD and a real `Player` configured
for `berserk/<weapon>`, shipped `Enemy` instances stand around the hero as
hazards, and the ultimate is cast through `UltimatePlayerHost.activate()`. The
capture script sizes the window, sets the mode's switches and reads the
framebuffer back; it draws nothing of its own into the game frame.

- **Weapons** — the canonical trio `sword`, `axe`, `hammer`.
- **Modes** — `normal`, `crowded`, `reduced_motion`, `photosensitivity_safe`.
- **Viewports** — 1152x648, 1280x720, 1920x1080, 2560x1440.
- **Beats** — `release`, `active`, `recovery`, taken from the shared
  `contact_sheet_beats_contract.gd`, the same source the contact-sheet beats gate
  certifies.

That is 48 weapon/mode/viewport combinations and 144 measured frames. Every one
of the 144 is measured at its native resolution and recorded in
`certification_capture_manifest.json` with its weapon, mode, viewport, beat,
sampled and declared beat time, shipped scene path and readability numbers.

Four sheets are committed, one per viewport, each at that viewport's native size
and each carrying all twelve weapon x mode cells at the active beat. That is the
whole committed image budget: the shared visual-direction contract admits exactly
one contact sheet per supported viewport, and it is not this card's file to
change. The four authored timeline sheets that FAN-3877 rejected stay in the
package under `evidence.authored_timeline_sheets` as provenance; the class's
declared `contact_sheets` are now the live four-mode captures. Release and
recovery frames are not committed as images — they are measured for all 48
combinations and regenerate at full size through `BERSERK_CERT_FRAME_DIR`.

## How the four modes are produced

Only switches the shipped game already publishes are used. Nothing is hidden,
suppressed or redrawn for the capture.

| Mode | `screen_shake` | `combat_feedback` | Hazards |
|---|---|---|---|
| `normal` | on | on | 6 |
| `crowded` | on | on | the weapon's declared `performance.crowd_cap` |
| `reduced_motion` | **off** | on | 6 |
| `photosensitivity_safe` | **off** | **off** | 6 |

`screen_shake` is the reduced-motion switch: `berserk_ultimate_v2_driver.gd`
reads it in `_ready()` and damps the backdrop veil, and `combat_director.gd`
holds the camera still. `combat_feedback` is the flash switch that the
victim-impact player and the enemy hit flash read. The metadata is written after
`Main` has published its own settings and before the ultimate spawns, because the
driver samples it once.

The game exposes no separate photosensitivity toggle. Rather than invent one, the
photosensitivity-safe capture uses the shipped low-flash configuration and the
report measures the actual near-white share of every frame against the class's
declared `full_screen_flash_hz: 0.0` / `max_flash_coverage_ratio: 0.0`.

## Observed readability

All 144 samples pass every measured floor. Worst case per weapon and mode across
all four viewports and all three beats:

| Weapon | Mode | Effect box (cap) | Near-white share | HUD band contrast | Player contrast | Hazards in frame |
|---|---|---|---|---|---|---|
| sword | normal | 0.0861 (0.30) | 0.0009 | 0.825 | 0.688 | 6 |
| sword | crowded | 0.0861 (0.30) | 0.0019 | 0.825 | 0.817 | 24 |
| sword | reduced_motion | 0.0861 (0.30) | 0.0011 | 0.749 | 0.736 | 6 |
| sword | photosensitivity_safe | 0.0861 (0.30) | 0.0008 | 0.715 | 0.736 | 6 |
| axe | normal | 0.0419 (0.26) | 0.0005 | 0.764 | 0.669 | 6 |
| axe | crowded | 0.0419 (0.26) | 0.0005 | 0.826 | 0.688 | 18 |
| axe | reduced_motion | 0.0419 (0.26) | 0.0007 | 0.764 | 0.744 | 6 |
| axe | photosensitivity_safe | 0.0419 (0.26) | 0.0007 | 0.777 | 0.573 | 6 |
| hammer | normal | 0.0339 (0.28) | 0.0035 | 0.715 | 0.740 | 6 |
| hammer | crowded | 0.0339 (0.28) | 0.0036 | 0.825 | 0.736 | 20 |
| hammer | reduced_motion | 0.0339 (0.28) | 0.0039 | 0.825 | 0.765 | 6 |
| hammer | photosensitivity_safe | 0.0339 (0.28) | 0.0043 | 0.825 | 0.486 | 6 |

What the columns mean:

- **Effect box** — the union of the on-screen boxes of everything the shipped
  presentation actually draws, excluding the arena-wide backdrop veil, as a share
  of the viewport. This is the quantity the class manifest bounds with
  `quality.max_viewport_coverage_ratio`; the cap is in brackets. In a live run
  the effect stays far under it.
- **Near-white share** — the share of frame pixels above 0.92 luminance. A
  repeating full-screen flash would push this toward 1.0. It never passes 0.5%,
  which is what `full_screen_flash_hz: 0.0` claims.
- **HUD band contrast** — the luminance range inside the narrowest live HUD band,
  read from the real `CombatHudRoot` children rather than from hard-coded
  rectangles. The bands stay legible in every frame, and the effect box never
  intersects one.
- **Player contrast** — the luminance range in the box around the hero. The hero
  stays separable from the effect at every beat.
- **Hazards in frame** — shipped enemies whose screen position is inside the
  frame. `crowded` reaches the declared crowd cap exactly, at every viewport.

Read against the sheets, the three weapons stay visually distinct in all four
modes: the sword's scarlet whirlwind, the axe's single boundary-turning ghost and
the hammer's cardinal rift beats are recognisable at 1152x648 and at 2560x1440.
`crowded` visibly changes the read — victim bursts stack and enemy health bars
fill the ring — without swallowing either the hero or the HUD. The three
non-crowded modes read almost identically for a still frame, which is expected:
`reduced_motion` and `photosensitivity_safe` change camera shake, veil damping
and hit flashing, none of which a single frame shows on its own. The measured
columns are what separates them.

## Limitations and findings

1. **The recovery beat is sampled two frames early.** In a live cast the shipped
   presentation node is released exactly at the class manifest's
   `timing_seconds.recovery` (sword 3.10s, axe 2.70s, hammer 2.35s), which is
   slightly before the frame-local recovery beat the shared beats contract
   declares (3.15s / 2.90s / 2.50s). The contract's beats are certified by seeking
   the scene's own `Timeline`, where the animation still runs. The capture
   therefore samples the last frame the live scene still draws and publishes both
   times — `beat_seconds` and `declared_beat_seconds` — on every sample. Nothing
   is retimed silently, and the focused gate rejects any sample taken *past* its
   declared beat.
2. **The declared coverage caps are upper bounds, not live targets.** The manifest
   measured 0.30/0.26/0.28 on the authored contact sheets, where the composition
   frames the effect tightly. Under the live gameplay camera the same effect
   occupies 0.03–0.09 of the viewport. Both readings are true of their own
   framing; the live number is the one that matters for in-game readability, and
   it is comfortably inside the cap.
3. **`presence.backdrop: "darken"` reads weakly over the shipped arena.** The
   `BackdropVeil` covers the whole viewport in every sample
   (`backdrop_box_ratio` 1.04, matching the declared `fullscreen_footprint`), but
   over the bright arena floor the darkening is subtle to the eye. This is shipped
   behaviour and is recorded, not changed.
4. **A pre-existing runtime error surfaces when a victim dies mid-cast.** With
   ordinary enemy health, casting a Berserk ultimate can raise
   `SCRIPT ERROR: Left operand of 'is' is a previously freed instance` from
   `scripts/ultimates/presentation/victim_impact_player.gd:243` when a victim node
   is freed before its impact spawns. That file is production code outside this
   card's write set, so it is reported rather than repaired. The capture keeps
   hazards alive (`health = 100000`) so they stay in frame across all three beats,
   which also keeps this path out of the evidence run — no capture in this package
   was produced under that error.
5. **The capture ran under the gate's normal shared admission, not exclusively.**
   An unrelated long-running gated Godot process on this host has held a machine
   run token since well before this work started, so `FSD_GODOT_EXCLUSIVE=1`
   cannot be granted and the process is not this run's to cancel. The evidence is
   frame *content*, produced under a pinned `--fixed-fps 60` step and a pinned
   generator seed, so it does not depend on host load, and no timing or
   performance claim is made from these runs.
6. **The capture is structurally, not bit-wise, reproducible.** Across repeated
   runs the structural quantities repeat exactly: the same beats, the same effect
   box ratio to four decimals at every viewport, the same backdrop ratio, and
   `crowded` landing on the declared crowd cap every time. The pixel-content
   readings — HUD band and player contrast — move by a few hundredths, because the
   live arena keeps animating around the cast: enemies drift, the round timer
   ticks, the ground scrolls under the camera. The committed sheets therefore do
   not re-hash identically. The `sha256` in the manifest pins *these* committed
   artifacts against corruption and against an unsmudged LFS pointer; it is not a
   claim that a fresh capture reproduces the same bytes. The gate's floors are set
   well below the observed spread so a re-run does not flip them.
7. **Only the active beat is committed as an image.** The release and recovery
   reads are carried by the 144 measurements and by the reproduce command, not by
   more committed PNGs. Four native-size sheets is what the shared
   `ultimate_visual_direction_contract.gd` capture gate admits per class, and
   growing the committed set would also grow what CI materializes from Git LFS on
   every candidate run.
8. **Six hazards, not a full arena, in the non-crowded modes.** `normal`,
   `reduced_motion` and `photosensitivity_safe` place six shipped enemies in a
   fixed ring so the same layout reads at 648p and at 2K. `crowded` is the mode
   that exercises the declared crowd cap.

## Reproducing

```bash
# Live capture (windowed; writes the sheets and the capture manifest)
BERSERK_CERT_SOURCE_REF=origin/dev \
BERSERK_CERT_SOURCE_SHA=<source-commit> \
BERSERK_CERT_SOURCE_TREE=<source-tree> \
python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 \
  --script res://tests/ultimates/presentation/berserk_certification_live_capture.gd

# Every native full-resolution frame, for inspecting one combination
BERSERK_CERT_FRAME_DIR=$PWD/build/berserk-certification-frames ... # same command

# Focused gate (headless)
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/berserk_certification_capture_test.gd

# Class timeline/presentation contract
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/berserk_ultimate_timelines.gd
```

The four committed sheets are the human index; the 144 measured samples are the
machine-checkable record. The focused gate re-reads the sheets as raw PNG bytes —
signature, IHDR geometry, decode and SHA-256 — so a missing file, an unsmudged
LFS pointer or a wrong dimension fails closed, and it proves every one of those
validators red on a mutated copy of the manifest.
