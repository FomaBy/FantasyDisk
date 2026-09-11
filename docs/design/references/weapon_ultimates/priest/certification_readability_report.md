## FAN-3944 Priest ultimate certification

This package certifies the shipped Priest ultimate trio after full presentation-v2 adoption. It changes presentation timing and weight only; damage, cooldown, charge, targeting, saves, canonical IDs, HUD behavior, and weapon mechanics are unchanged.

`tests/ultimates/presentation/priest_certification_live_capture.gd` creates every cell through `Player.activate_ultimate` and the Player-owned `UltimateHost`. Each cell retains the shipped Priest scene, real `EnemySpitter` targets, an `ElitePoisonZone` created by `EnemySpitter._spawn_elite_hazard`, and the shipped `UltimateHudRuntimeAdapter`. Headless execution skips PNG creation and is never accepted as image evidence.

## Capture provenance

| Field | Value |
| --- | --- |
| Source ref / commit / tree | `agent/codex-dev-sol-5-6/3fbc2f531de0` / `fd3d25ff193cbc52ffc3a387ca6c7cfa62f2a3d2` / `61e18a3744066df4ef34fd5611b3e3dcaddb3c8c` |
| Engine / renderer | Godot `4.7.stable.official.5b4e0cb0f` / GL Compatibility (OpenGL API 4.1 Metal, Apple M4 Pro) |
| Controlled seed | `394401`, reseeded per phase/weapon/mode cell |
| Workload exclusion | `FSD_GODOT_EXCLUSIVE=1` machine-wide Godot lease |
| Windowed command | `env FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_RUN_TIMEOUT=1800 python3 tools/godot_gate.py --path . --windowed --always-on-top --position 20,20 --script res://tests/ultimates/presentation/priest_certification_live_capture.gd` |
| Output root | `docs/design/reference-assets-lfs/ultimate-certification/priest` (Git LFS) |

## Coverage and observed readability

Twelve native 3 × 4 matrices cover release, active, and recovery at 1152×648, 1280×720, 1920×1080, and 2560×1440. Rows are `priest_reliquary`, `priest_censer`, and `priest_chime`; columns are normal, crowded, reduced motion, and photosensitivity safe. Crowded cells use the declared caps of 22, 20, and 18 real targets.

| Weapon | Named observations |
| --- | --- |
| `priest_reliquary` | 0.90s release, 1.35s active, 3.45s recovery: the shrine, concentric judgment rings, real player, targets, poison telegraph, and HUD remain separable. |
| `priest_censer` | 0.80s release, 1.40s active, 3.15s recovery: the censer orbit, smoke ward, counter-wave recovery, hazard lane, and HUD retain distinct silhouettes. |
| `priest_chime` | 0.75s release, 1.50s active, 2.85s recovery: the sequential silver/gold/dawn arcs and guard sigil remain readable without covering the player or hazard bands. |

Reduced-motion cells read the shipped `screen_shake` setting as off, keeping the camera still and clamping the darkening veil to a calm fade without moving any beat. Photosensitivity-safe cells suppress the fullscreen veil while keeping authored foreground identity and real runtime fixtures. The evidence is spatial still-image proof at named beats; the focused gate separately validates runtime ownership, mode state, executor advancement, timing, and cleanup.

## Native output integrity

`certification_capture_manifest.json` records each required path, viewport, phase, native dimensions, and SHA-256. The focused gate fails closed on a missing mode, provenance key, file, hydrated LFS content, PNG signature/IHDR, dimensions, cell marker, or hash mismatch.
