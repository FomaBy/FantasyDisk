# Druid ultimate presentation-v2 readability

FAN-3942 captured all three canonical Druid presentations from real
`scenes/Main.tscn` combat through `Player.activate_ultimate()`, the shipped
executor, and the shared presentation runtime. The matrix covers normal,
crowded, reduced-motion, and photosensitivity-safe modes at 1152×648,
1280×720, 1920×1080, and 2560×1440. Release, active, and recovery are measured
for every combination: 144 samples and 12 native-size beat sheets.

Source commit: `4955fe7e3d4e25137ae73a3f8eb60c181220cc81`; source tree:
`eccc58cfddb9efa57b0fab84bfc68e9ac3fc6114`. Godot 4.7 stable used the
Compatibility renderer on Apple M4 Pro. The capture manifest records the exact
command, configuration, seed, mode state, dimensions, record attestations, and
PNG SHA-256 hashes.

| Weapon | Max effect box | Min HUD contrast | Min player contrast | Max near-white share | Crowded hazards | Max drawn nodes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Summon amulet | 0.0353 | 0.547 | 0.268 | 0.0002 | 24 | 2 |
| Briar staff | 0.0482 | 0.569 | 0.257 | 0.0002 | 20 | 2 |
| Raven totem | 0.0510 | 0.572 | 0.380 | 0.0002 | 22 | 2 |

## Beat observations

| Weapon | Release | Active | Recovery |
| --- | --- | --- | --- |
| Summon amulet | At 1.00s the Wild Hunt release silhouette is present. | At 1.95s the hunt reaches 0.0353 coverage and remains distinct with 24 crowded hazards. | At 3.10s the footprint contracts to 0.0148 while preserving the cast identity and clear HUD. |
| Briar staff | At 1.10s the briar lattice establishes its thorn direction. | At 2.00s the lattice reaches 0.0482 coverage; player contrast remains above the 0.25 floor in all modes and viewports. | At 3.20s the lattice contracts to 0.0206 without changing the declared phase clock. |
| Raven totem | At 0.75s the raven vortex is present and intentionally compact. | At 1.65s the vortex reaches the class-high 0.0510 extent while retaining HUD separation. | At 2.90s the vortex falls to 0.0174 and remains identifiable in both safe modes. |

## Result and limitations

Result: PASS. All 144 activations started through the real Player entry point,
all 144 runtime scenes bound a real cast pose, all required beat nodes were
present, the backdrop covered the full viewport, and every HUD band remained
clear. Briar Staff is the tightest player-contrast case at 0.257, still above
the unchanged 0.25 floor; that margin should remain a focused review point.
The deterministic crowd fixture reaches each weapon's declared hazard cap, and
the resulting images are representative evidence rather than a performance
benchmark.
