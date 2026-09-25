# Guitarist ultimate readability certification (FAN-3943)

This package replaces four resolution variants of one authored timeline with
fresh live evidence for the canonical Guitarist trio. Every sample comes from
`scenes/Main.tscn`: the shipped arena, combat HUD, a real Guitarist player and
shipped Enemy hazards remain visible while the ultimate is activated through
`UltimatePlayerHost.activate()`. The windowed capture uses Godot 4.7 Compatibility
on Apple M4 Pro and is pinned to source commit
`50174fb6b1282527b68f8c33bd757bcb614dd47e`, tree
`08663585acaa3209a58a3bc8b62cd5197db030e2`, fixed 60 fps and seed
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
| electric guitar | normal | 0.0286 | 0.0008 | 0.761 | 0.852 | 6 |
| electric guitar | crowded | 0.0286 | 0.0009 | 0.745 | 0.828 | 14 |
| electric guitar | reduced motion | 0.0286 | 0.0007 | 0.754 | 0.848 | 6 |
| electric guitar | photosensitivity safe | 0.0286 | 0.0007 | 0.765 | 0.864 | 6 |
| bass guitar | normal | 0.0329 | 0.0007 | 0.788 | 0.904 | 6 |
| bass guitar | crowded | 0.0329 | 0.0010 | 0.788 | 0.899 | 12 |
| bass guitar | reduced motion | 0.0329 | 0.0008 | 0.788 | 0.917 | 6 |
| bass guitar | photosensitivity safe | 0.0329 | 0.0010 | 0.791 | 0.919 | 6 |
| sound amp | normal | 0.0261 | 0.0022 | 0.837 | 0.905 | 6 |
| sound amp | crowded | 0.0261 | 0.0028 | 0.837 | 0.895 | 14 |
| sound amp | reduced motion | 0.0261 | 0.0022 | 0.837 | 0.921 | 6 |
| sound amp | photosensitivity safe | 0.0261 | 0.0022 | 0.837 | 0.921 | 6 |

The authored effect box remains below the 0.30 cap, every HUD band remains clear,
the minimum measured HUD contrast is 0.745, player contrast is at least 0.828,
and the full-screen veil reaches at least 1.0087 of the framebuffer area. The
highest near-white share is 0.0028. Crowded mode reaches the exact weapon crowd
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
GUITARIST_CERT_SOURCE_REF=agent/claude-dev-fable/9426dc35badb \
GUITARIST_CERT_SOURCE_SHA=50174fb6b1282527b68f8c33bd757bcb614dd47e \
GUITARIST_CERT_SOURCE_TREE=08663585acaa3209a58a3bc8b62cd5197db030e2 \
FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --windowed \
  --fixed-fps 60 --script res://tests/ultimates/presentation/guitarist_certification_live_capture.gd

python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/guitarist_certification_capture_test.gd
```
