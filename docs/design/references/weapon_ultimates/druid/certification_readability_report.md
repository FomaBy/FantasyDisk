# Druid ultimate presentation-v2 readability

FAN-3942 captured the three canonical Druid presentations from the real
`scenes/Main.tscn` combat scene through the real Player's shipped presentation
runtime. The matrix covers normal, crowded, reduced-motion, and
photosensitivity-safe modes at 1152×648, 1280×720, 1920×1080, and 2560×1440.
Release, active, and recovery are measured for every combination: 144 samples.

Source commit: `450f4a50bef2e9c355bd7bb63057f5e12e5585de`; source tree:
`579e55b71f91c87f6ab4d825590aa3b134fa3b01`. Godot 4.7 stable used the
Compatibility renderer on Apple M4 Pro. Exact per-sample values, capture time,
commands, PNG dimensions, and SHA-256 hashes are in
`certification_capture_manifest.json`.

| Weapon | Max effect box | Min backdrop | Min HUD contrast | Min player contrast | Max near-white share | Crowded hazards | Max drawn nodes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Summon amulet | 0.0351 | 1.0000 | 0.585 | 0.354 | 0.0002 | 24 | 2 |
| Briar staff | 0.0484 | 1.0000 | 0.636 | 0.369 | 0.0002 | 20 | 2 |
| Raven totem | 0.0512 | 1.0000 | 0.575 | 0.412 | 0.0002 | 22 | 2 |

Result: PASS. All declared nodes are present, every fullscreen darken reaches
the viewport, all measured HUD bands remain clear, player contrast stays above
0.25, near-white coverage stays below 0.05, and crowded samples hold each
weapon's declared cap. The focused validator includes fail-closed mutations for
missing coverage, source provenance, LFS pointers, PNG hashes/dimensions, HUD
occlusion, excessive coverage/flash, crowd shortfall, and retimed beats.
