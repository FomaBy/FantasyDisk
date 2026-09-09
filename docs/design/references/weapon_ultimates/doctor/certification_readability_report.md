# Doctor ultimate presentation-v2 readability

FAN-3942 captured the three canonical Doctor presentations from the real
`scenes/Main.tscn` combat scene through the real Player's shipped presentation
runtime. The matrix covers normal, crowded, reduced-motion, and
photosensitivity-safe modes at 1152×648, 1280×720, 1920×1080, and 2560×1440.
Release, active, and recovery are measured for every combination: 144 samples.

Source commit: `b9911a7a908c1da23129303f9794cedef8320bc5`; source tree:
`dc28f372db1c6d822da2eb4b05c4fc972ed7e756`. Godot 4.7 stable used the
Compatibility renderer on Apple M4 Pro. Exact per-sample values, capture time,
commands, PNG dimensions, and SHA-256 hashes are in
`certification_capture_manifest.json`.

| Weapon | Max effect box | Min backdrop | Min HUD contrast | Min player contrast | Max near-white share | Crowded hazards | Max drawn nodes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Restore potion | 0.0475 | 1.0000 | 0.587 | 0.377 | 0.0002 | 12 | 5 |
| Plague syringe | 0.0336 | 1.0000 | 0.592 | 0.344 | 0.0002 | 12 | 6 |
| Bone saw | 0.0434 | 1.0000 | 0.608 | 0.411 | 0.0002 | 12 | 8 |

Result: PASS. All declared nodes are present, every fullscreen darken reaches
the viewport, all measured HUD bands remain clear, player contrast stays above
0.25, near-white coverage stays below 0.05, and crowded samples hold each
weapon's declared cap. The focused validator includes fail-closed mutations for
missing coverage, source provenance, LFS pointers, PNG hashes/dimensions, HUD
occlusion, excessive coverage/flash, crowd shortfall, and retimed beats.
