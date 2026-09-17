# Assassin ultimate presentation-v2 readability

FAN-3942 captured all three canonical Assassin presentations from real
`scenes/Main.tscn` combat through `Player.activate_ultimate()`, the shipped
executor, and the shared presentation runtime. The matrix covers normal,
crowded, reduced-motion, and photosensitivity-safe modes at 1152×648,
1280×720, 1920×1080, and 2560×1440. Release, active, and recovery are measured
for every combination: 144 samples and 12 native-size beat sheets.

Source commit: `112e9dacfa5406f7a2ad9907091d59fe36ad4c51`; source tree:
`65d83634c9441ed1448219d6fac881ceb57c2e24`. Godot 4.7 stable used the
Compatibility renderer on Apple M4 Pro. The capture manifest records the exact
command, configuration, seed, mode state, dimensions, record attestations, and
PNG SHA-256 hashes.

| Weapon | Max effect box | Min HUD contrast | Min player contrast | Max near-white share | Crowded hazards | Max drawn nodes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chakrams | 0.2840 | 0.504 | 0.744 | 0.0076 | 24 | 13 |
| Shadow daggers | 0.0339 | 0.567 | 0.457 | 0.0003 | 20 | 9 |
| Venom wire | 0.0240 | 0.546 | 0.574 | 0.0048 | 24 | 11 |

## Beat observations

| Weapon | Release | Active | Recovery |
| --- | --- | --- | --- |
| Chakrams | At 0.90s the windup moon, impact flash, and eight-point compass are present; player contrast stays at least 0.744. | At 2.40s the orbit and returning crescents remain readable. Reduced motion holds all eight bearings at 0.1083 coverage instead of collapsing to the former 0.0003 dot. | At 3.20s the static reduced-motion compass remains at 0.1083 coverage while the normal crescents and moons recede; cast identity stays above the backdrop. |
| Shadow daggers | At 0.90s the freeze marks and first backstab image establish the silhouette. | At 2.05s the separated afterimages and final reveal identify the attack in all modes. | At 3.00s the marks and reveal decay without obscuring any measured HUD band. |
| Venom wire | At 0.80s six anchors and the hex web are present. | At 2.80s the web and snap-collapse distinguish the impact; the safe mode limits the photosensitive node. | At 3.25s the anchors and collapse remain legible while player contrast stays at least 0.566. |

## Result and limitations

Result: PASS. All 144 activations started through the real Player entry point,
all 144 runtime scenes bound a real cast pose, all required beat nodes were
present, the backdrop covered the full viewport, and every HUD band remained
clear. The restored ceilings remain unchanged; Chakrams reaches the accepted
0.284 moving extent but reduced motion retains the smaller static compass.
These are representative deterministic combat captures, not a performance
benchmark, and crowd counts are bounded by each weapon's declared cap.
