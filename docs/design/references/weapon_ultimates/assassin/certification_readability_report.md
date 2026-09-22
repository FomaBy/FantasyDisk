# Assassin ultimate presentation-v2 readability

FAN-3942 captured all three canonical Assassin presentations from real
`scenes/Main.tscn` combat through `Player.activate_ultimate()`, the shipped
executor, and the shared presentation runtime. The matrix covers normal,
crowded, reduced-motion, and photosensitivity-safe modes at 1152×648,
1280×720, 1920×1080, and 2560×1440. Release, active, and recovery are measured
for every combination: 144 samples and 12 native-size beat sheets.

Source commit: `172401c58b0889f34fc4b81634b1a16e69ca177d`; source tree:
`09a2ded8a27f4e29a9eff4dac091dbeb8fe4857e`. Godot 4.7 stable used the
Compatibility renderer on Apple M4 Pro. The capture manifest records the exact
command, configuration, seed, mode state, dimensions, record attestations, and
PNG SHA-256 hashes.

| Weapon | Max effect box | Min HUD contrast | Min player contrast | Max near-white share | Crowded hazards | Max drawn nodes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Chakrams | 0.2867 | 0.504 | 0.744 | 0.0055 | 24 | 13 |
| Shadow daggers | 0.0339 | 0.546 | 0.458 | 0.0002 | 20 | 9 |
| Venom wire | 0.0240 | 0.567 | 0.637 | 0.0037 | 24 | 11 |

## Beat observations

| Weapon | Release | Active | Recovery |
| --- | --- | --- | --- |
| Chakrams | At 0.90s the windup moon, impact flash, and eight-point compass are present; player contrast stays at least 0.744. | At 2.40s the orbit and returning crescents remain readable. Normal, crowded, and photosensitivity-safe captures observe the declared 0.45 impact time-scale dip; reduced motion suppresses it and holds all eight bearings at 0.1083 coverage. | At 3.20s the static reduced-motion compass remains at 0.1083 coverage while the normal crescents and moons recede; all modes have restored the global time scale. |
| Shadow daggers | At 0.90s the freeze marks and first backstab image establish the silhouette. | At 2.05s the separated afterimages and final reveal identify the attack in all modes; the live scene remains at the canonical `1.0` time scale. | At 3.00s the marks and reveal decay without obscuring any measured HUD band. |
| Venom wire | At 0.80s six anchors and the hex web are present. | At 2.80s the web and snap-collapse distinguish the impact without an undeclared global slowdown; the safe mode limits the photosensitive node. | At 3.25s the anchors and collapse remain legible while player contrast stays at least 0.637. |

## Result and limitations

Result: PASS. All 144 activations started through the real Player entry point,
all 144 runtime scenes bound a real cast pose, all required beat nodes were
present, the backdrop covered the full viewport, and every HUD band remained
clear. Every recorded `beat_seconds` and live `elapsed_seconds` value matches
its shared declared beat. The restored ceilings remain unchanged; Chakrams reaches a 0.2867
moving extent but reduced motion retains the smaller static compass.
These are representative deterministic combat captures, not a performance
benchmark, and crowd counts are bounded by each weapon's declared cap.
