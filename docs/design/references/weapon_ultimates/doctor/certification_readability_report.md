# Doctor ultimate presentation-v2 readability

FAN-3942 captured all three canonical Doctor presentations from real
`scenes/Main.tscn` combat through `Player.activate_ultimate()`, the shipped
executor, and the shared presentation runtime. The matrix covers normal,
crowded, reduced-motion, and photosensitivity-safe modes at 1152×648,
1280×720, 1920×1080, and 2560×1440. Release, active, and recovery are measured
for every combination: 144 samples and 12 native-size beat sheets.

Source commit: `82f8133f269046151dafe04270137a5a100f344c`; source tree:
`e6c3e16650eb963b042c99600397682de0825aeb`. Godot 4.7 stable used the
Compatibility renderer on Apple M4 Pro. The capture manifest records the exact
command, configuration, seed, mode state, dimensions, record attestations, and
PNG SHA-256 hashes.

| Weapon | Max effect box | Min HUD contrast | Min player contrast | Max near-white share | Crowded hazards | Max drawn nodes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Restore potion | 0.0293 | 0.545 | 0.386 | 0.0002 | 12 | 5 |
| Plague syringe | 0.0272 | 0.666 | 0.354 | 0.0002 | 12 | 6 |
| Bone saw | 0.0173 | 0.572 | 0.455 | 0.0002 | 12 | 8 |

## Beat observations

| Weapon | Release | Active | Recovery |
| --- | --- | --- | --- |
| Restore potion | At 1.10s the giant flask and glass impact establish the heal/poison identity. | At 2.10s the poison pool, restored white healing spiral, and shield crystal remain present within five drawn nodes. | At 3.05s the pool, healing spiral, and shield recede while the HUD remains clear; the minimum player contrast is 0.386. |
| Plague syringe | At 1.00s the oversized syringe and patient-zero marker are present. | Across the active phase all three staggered infection waves are authored; the 2.60s wave-three beat reaches the largest measured extent, 0.0272, without exceeding six simultaneously drawn nodes. | At 3.55s the recovery footprint falls as low as 0.0027; this sparse tail remains intentional and traceable rather than substituting a blank frame. |
| Bone saw | At 0.85s three saws and the surgical orbit arc establish direction. | At 1.70s the orbit, metal sparks, and restored red/green paired drain ribbons identify the active cut. | At 2.55s the saws and shield stitches remain visible with at most six nodes. |

## Result and limitations

Result: PASS. All 144 activations started through the real Player entry point,
all 144 runtime scenes bound a real cast pose, all required beat nodes were
present, the backdrop covered the full viewport, and every HUD band remained
clear. The original strict node/coverage ceilings are retained: Restore uses at
most 5 measured nodes, Plague 6, and Bone Saw 8. The Plague recovery is
deliberately sparse, and the deterministic hazard fixture caps Doctor crowded
captures at 12; these images are not a performance benchmark.
