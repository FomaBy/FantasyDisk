# Doctor ultimate presentation-v2 readability

FAN-3942 captured all three canonical Doctor presentations from real
`scenes/Main.tscn` combat through `Player.activate_ultimate()`, the shipped
executor, and the shared presentation runtime. The matrix covers normal,
crowded, reduced-motion, and photosensitivity-safe modes at 1152×648,
1280×720, 1920×1080, and 2560×1440. Release, active, and recovery are measured
for every combination: 144 samples and 12 native-size beat sheets.

Source commit: `9f494e8d0b41ee5e5ac7aad3fdaf14fbdba33c3f`; source tree:
`0732d537c03473c6efc1127b7fbbbd938139ebb0`. Godot 4.7 stable used the
Compatibility renderer on Apple M4 Pro. The capture manifest records the exact
command, configuration, seed, mode state, dimensions, record attestations, and
PNG SHA-256 hashes.

| Weapon | Max effect box | Min HUD contrast | Min player contrast | Max near-white share | Crowded hazards | Max drawn nodes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Restore potion | 0.0293 | 0.545 | 0.380 | 0.0002 | 12 | 4 |
| Plague syringe | 0.0272 | 0.572 | 0.314 | 0.0002 | 12 | 6 |
| Bone saw | 0.0173 | 0.572 | 0.476 | 0.0002 | 12 | 7 |

## Beat observations

| Weapon | Release | Active | Recovery |
| --- | --- | --- | --- |
| Restore potion | At 1.10s the giant flask and glass impact establish the heal/poison identity. | At 2.10s the poison pool and shield crystal remain present with four or fewer drawn nodes. | At 3.05s the pool and shield recede while the HUD remains clear; the minimum player contrast is 0.380. |
| Plague syringe | At 1.00s the oversized syringe and patient-zero marker are present. | At 2.60s the epidemic spread reaches its largest measured extent, 0.0272, without exceeding six nodes. | At 3.55s the recovery footprint falls as low as 0.0027; this sparse tail remains intentional and traceable rather than substituting a blank frame. |
| Bone saw | At 0.85s three saws and the surgical orbit arc establish direction. | At 1.70s the orbit, metal sparks, and red drain ribbon identify the active cut. | At 2.55s the saws and shield stitches remain visible with at most six nodes. |

## Result and limitations

Result: PASS. All 144 activations started through the real Player entry point,
all 144 runtime scenes bound a real cast pose, all required beat nodes were
present, the backdrop covered the full viewport, and every HUD band remained
clear. The original strict node/coverage ceilings are retained: Restore uses at
most 4 measured nodes, Plague 6, and Bone Saw 7. The Plague recovery is
deliberately sparse, and the deterministic hazard fixture caps Doctor crowded
captures at 12; these images are not a performance benchmark.
