# Guitarist ultimate readability certification (FAN-3943)

This package replaces four resolution variants of one authored timeline with
fresh live evidence for the canonical Guitarist trio. Every sample comes from
`scenes/Main.tscn`: the shipped arena, combat HUD, a real Guitarist player and
shipped Enemy hazards remain visible while the ultimate is activated through
`UltimatePlayerHost.activate()`. The windowed capture uses Godot 4.7 Compatibility
on Apple M4 Pro and is pinned to source commit
`e120e4cdeef54b7229529afcc3524aac3f6ea156`, tree
`5368a38320e1fa43f298e01bdd1f90652758eeeb`, fixed 60 fps and seed
`394320260910`.

## Coverage

- Weapons: `electric_guitar`, `bass_guitar`, `sound_amp`.
- Modes: normal, crowded, reduced motion, photosensitivity safe.
- Viewports: 1152x648, 1280x720, 1920x1080 and 2560x1440.
- Beats: release, active and recovery from each weapon's source-pinned
  `timing_seconds` declaration.

The capture manifest contains all 144 weapon/mode/viewport/beat samples. Four
native-size mode-matrix PNGs provide the human-readable active-beat index; every
release and recovery frame can be regenerated with `GUITARIST_CERT_FRAME_DIR`.

## Observed readability

All 144 samples pass the declared limits. The worst value in each weapon/mode
group across all viewports and beats is shown below.

| Weapon | Mode | Effect box | Near-white | HUD contrast | Player contrast | Hazards |
|---|---|---:|---:|---:|---:|---:|
| electric guitar | normal | 0.0286 | 0.0007 | 0.786 | 0.866 | 6 |
| electric guitar | crowded | 0.0286 | 0.0011 | 0.786 | 0.870 | 14 |
| electric guitar | reduced motion | 0.0286 | 0.0007 | 0.781 | 0.880 | 6 |
| electric guitar | photosensitivity safe | 0.0286 | 0.0008 | 0.777 | 0.858 | 6 |
| bass guitar | normal | 0.0329 | 0.0008 | 0.788 | 0.950 | 6 |
| bass guitar | crowded | 0.0329 | 0.0011 | 0.788 | 0.932 | 12 |
| bass guitar | reduced motion | 0.0329 | 0.0009 | 0.788 | 0.950 | 6 |
| bass guitar | photosensitivity safe | 0.0329 | 0.0012 | 0.791 | 0.952 | 6 |
| sound amp | normal | 0.0261 | 0.0024 | 0.837 | 0.915 | 6 |
| sound amp | crowded | 0.0261 | 0.0033 | 0.837 | 0.909 | 14 |
| sound amp | reduced motion | 0.0261 | 0.0024 | 0.837 | 0.909 | 6 |
| sound amp | photosensitivity safe | 0.0261 | 0.0024 | 0.837 | 0.907 | 6 |

The authored effect box remains below the 0.30 cap, every HUD band remains clear,
the minimum measured HUD contrast is 0.777, player contrast is at least 0.858,
and the full-screen veil reaches at least 1.0087 of the framebuffer area. The
highest near-white share is 0.0033. Crowded mode reaches the exact weapon crowd
cap at every viewport.

Victim-side impact bursts remain visible in the frames and are included in the
drawn-node record. Their distributed boxes are excluded from the activation
footprint because `UltimateVictimImpactPlayer` explicitly owns them under its
separate bounded pool contract; including them would conflate target feedback
with the authored scene's `max_viewport_coverage_ratio` and visual-node budget.

## Accessibility and limitations

Reduced motion disables camera shake and damps the steady veil without changing
the phase times. Photosensitivity-safe mode additionally disables combat feedback
and further damps the veil. These modes are produced through shipped settings
metadata; the capture does not redraw or suppress the ultimate.

The recovery frame is sampled two fixed frames before the declared recovery
boundary because the host releases a live presentation at that boundary. Both
times are stored on every record. Native pixels are not bit-reproducible because
the arena and enemies keep moving, so hashes pin the committed artifacts against
corruption rather than promising identical reruns.

## Reproduce

```bash
GUITARIST_CERT_SOURCE_REF=agent/codex-dev-sol-5-6/7c21cbb1a757 \
GUITARIST_CERT_SOURCE_SHA=e120e4cdeef54b7229529afcc3524aac3f6ea156 \
GUITARIST_CERT_SOURCE_TREE=5368a38320e1fa43f298e01bdd1f90652758eeeb \
FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --windowed \
  --fixed-fps 60 --script res://tests/ultimates/presentation/guitarist_certification_live_capture.gd

python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/guitarist_certification_capture_test.gd
```
