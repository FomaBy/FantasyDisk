# Elementalist ultimate readability certification (FAN-3943)

This package replaces four resolution variants of one authored timeline with
fresh live evidence for the canonical Elementalist trio. Every sample comes from
`scenes/Main.tscn`: the shipped arena, combat HUD, a real Elementalist player and
shipped Enemy hazards remain visible while the ultimate is activated through
`UltimatePlayerHost.activate()`. The windowed capture uses Godot 4.7 Compatibility
on Apple M4 Pro and is pinned to source commit
`e120e4cdeef54b7229529afcc3524aac3f6ea156`, tree
`5368a38320e1fa43f298e01bdd1f90652758eeeb`, fixed 60 fps and seed
`394320260909`.

## Coverage

- Weapons: `elementalist_orb_ring`, `elementalist_prism_focus`,
  `elementalist_meteor_core`.
- Modes: normal, crowded, reduced motion, photosensitivity safe.
- Viewports: 1152x648, 1280x720, 1920x1080 and 2560x1440.
- Beats: release, active and recovery from each weapon's source-pinned
  `timing_seconds` declaration.

The capture manifest contains all 144 weapon/mode/viewport/beat samples. Four
native-size mode-matrix PNGs provide the human-readable active-beat index; every
release and recovery frame can be regenerated with `ELEMENTALIST_CERT_FRAME_DIR`.

## Observed readability

All 144 samples pass the declared limits. The worst value in each weapon/mode
group across all viewports and beats is shown below.

| Weapon | Mode | Effect box | Near-white | HUD contrast | Player contrast | Hazards |
|---|---|---:|---:|---:|---:|---:|
| orb ring | normal | 0.0351 | 0.0006 | 0.838 | 0.885 | 6 |
| orb ring | crowded | 0.0351 | 0.0033 | 0.838 | 0.851 | 24 |
| orb ring | reduced motion | 0.0351 | 0.0005 | 0.838 | 0.911 | 6 |
| orb ring | photosensitivity safe | 0.0351 | 0.0006 | 0.838 | 0.868 | 6 |
| prism focus | normal | 0.0391 | 0.0006 | 0.807 | 0.862 | 6 |
| prism focus | crowded | 0.0391 | 0.0014 | 0.808 | 0.885 | 18 |
| prism focus | reduced motion | 0.0391 | 0.0006 | 0.800 | 0.847 | 6 |
| prism focus | photosensitivity safe | 0.0391 | 0.0009 | 0.818 | 0.857 | 6 |
| meteor core | normal | 0.0502 | 0.0017 | 0.821 | 0.850 | 6 |
| meteor core | crowded | 0.0502 | 0.0017 | 0.821 | 0.850 | 20 |
| meteor core | reduced motion | 0.0502 | 0.0016 | 0.821 | 0.850 | 6 |
| meteor core | photosensitivity safe | 0.0502 | 0.0017 | 0.821 | 0.850 | 6 |

The authored effect box remains below the 0.30 cap, every HUD band remains clear,
the minimum measured HUD contrast is 0.800, player contrast is at least 0.847,
and the full-screen veil reaches at least 1.0087 of the framebuffer area. The
highest near-white share is 0.0033, far below the 0.05 full-frame flash detector.
Crowded mode reaches the exact weapon crowd cap at every viewport.

## Accessibility and limitations

Reduced motion disables camera shake and damps the steady veil without changing
the phase times. Photosensitivity-safe mode additionally disables combat feedback
and further damps the veil. These modes are produced through the same settings
metadata the shipped game publishes; the capture does not redraw or suppress the
ultimate.

The recovery frame is sampled two fixed frames before the declared recovery
boundary because the host releases a live presentation at that boundary. Both
the sampled and declared times are stored for every record. Native pixels are not
bit-reproducible because the arena and enemies keep moving, so the hashes pin the
committed artifacts against corruption rather than promising identical reruns.

## Reproduce

```bash
ELEMENTALIST_CERT_SOURCE_REF=agent/codex-dev-sol-5-6/7c21cbb1a757 \
ELEMENTALIST_CERT_SOURCE_SHA=e120e4cdeef54b7229529afcc3524aac3f6ea156 \
ELEMENTALIST_CERT_SOURCE_TREE=5368a38320e1fa43f298e01bdd1f90652758eeeb \
FSD_GODOT_EXCLUSIVE=1 python3 tools/godot_gate.py --path . --windowed \
  --fixed-fps 60 --script res://tests/ultimates/presentation/elementalist_certification_live_capture.gd

python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/elementalist_certification_capture_test.gd
```
