# Knight ultimate readability certification (FAN-3943)

This package replaces four resolution variants of one authored timeline with
fresh live evidence for the canonical Knight trio. Every sample comes from
`scenes/Main.tscn`: the shipped arena, combat HUD, a real Knight player and
shipped Enemy hazards remain visible while the ultimate is activated through
`UltimatePlayerHost.activate()`. The windowed capture uses Godot 4.7 Compatibility
on Apple M4 Pro and is pinned to source commit
`1ce957a89dd901c3ee6161087fb16f28d48b004c`, tree
`f343bce8ecfdc00ca1f70393d4de7422c7ae592b`, fixed 60 fps and seed
`394320260911`.

## Coverage

- Weapons: `long_spear`, `tower_shield`, `holy_flail`.
- Modes: normal, crowded, reduced motion, photosensitivity safe.
- Viewports: 1152x648, 1280x720, 1920x1080 and 2560x1440.
- Beats: exact release, active and recovery times from each weapon's
  source-pinned `timing_seconds` declaration.

The capture manifest contains all 144 weapon/mode/viewport/beat samples. Four
native-size mode-matrix PNGs provide the human-readable active-beat index; every
release and recovery frame can be regenerated with `KNIGHT_CERT_FRAME_DIR`.

## Observed readability

All 144 samples pass the declared limits. The worst value in each weapon/mode
group across all viewports and beats is shown below.

| Weapon | Mode | Effect box | Near-white | HUD contrast | Player contrast | Hazards |
|---|---|---:|---:|---:|---:|---:|
| long spear | normal | 0.0258 | 0.0025 | 0.819 | 0.968 | 6 |
| long spear | crowded | 0.0258 | 0.0037 | 0.785 | 0.807 | 18 |
| long spear | reduced motion | 0.0258 | 0.0027 | 0.819 | 0.877 | 6 |
| long spear | photosensitivity safe | 0.0258 | 0.0029 | 0.819 | 0.947 | 6 |
| tower shield | normal | 0.0240 | 0.0010 | 0.843 | 0.967 | 6 |
| tower shield | crowded | 0.0240 | 0.0020 | 0.843 | 0.961 | 16 |
| tower shield | reduced motion | 0.0240 | 0.0012 | 0.843 | 0.967 | 6 |
| tower shield | photosensitivity safe | 0.0240 | 0.0017 | 0.843 | 0.965 | 6 |
| holy flail | normal | 0.0100 | 0.0037 | 0.845 | 0.964 | 6 |
| holy flail | crowded | 0.0100 | 0.0038 | 0.845 | 0.931 | 20 |
| holy flail | reduced motion | 0.0100 | 0.0045 | 0.845 | 0.964 | 6 |
| holy flail | photosensitivity safe | 0.0100 | 0.0049 | 0.845 | 0.964 | 6 |

The authored effect box remains below the 0.30 cap, every HUD band remains clear,
the minimum measured HUD contrast is 0.785, player contrast is at least 0.807,
and the full-screen veil reaches 1.0087 of the framebuffer-area bounding box.
The highest near-white share is 0.0049, far below the 0.05 full-frame flash
detector. Crowded mode reaches each weapon's exact crowd cap at every viewport.

## Accessibility and limitations

Reduced motion disables camera shake and damps the steady veil without changing
phase times. Photosensitivity-safe mode additionally disables combat feedback
and further damps the veil. These modes are produced through shipped settings
metadata; the capture does not redraw or suppress the ultimate.

The presentation-only tail preserves every exact recovery frame while gameplay,
damage prevention, charge gating and leased control end at their unchanged
combat boundaries. Native pixels are not bit-reproducible because the arena and
enemies keep moving, so hashes pin the committed artifacts against corruption
rather than promising identical reruns.

## Reproduce

```bash
KNIGHT_CERT_SOURCE_REF=agent/codex-dev-sol-5-6/039dfddda019 \
KNIGHT_CERT_SOURCE_SHA=1ce957a89dd901c3ee6161087fb16f28d48b004c \
KNIGHT_CERT_SOURCE_TREE=f343bce8ecfdc00ca1f70393d4de7422c7ae592b \
FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --windowed \
  --fixed-fps 60 --script res://tests/ultimates/presentation/knight_certification_live_capture.gd

python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/knight_certification_capture_test.gd
```
