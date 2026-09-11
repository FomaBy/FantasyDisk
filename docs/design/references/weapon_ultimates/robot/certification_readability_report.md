## FAN-3944 Robot ultimate certification

This package certifies the shipped Robot ultimate trio after full presentation-v2 adoption. It changes presentation timing and weight only; damage, cooldown, charge, targeting, saves, canonical IDs, HUD behavior, and weapon mechanics are unchanged.

`tests/ultimates/presentation/robot_certification_live_capture.gd` creates every cell through `Player.activate_ultimate` and the Player-owned `UltimateHost`. Each cell retains the shipped Robot scene, real `EnemySpitter` targets, an `ElitePoisonZone` created by `EnemySpitter._spawn_elite_hazard`, and the shipped `UltimateHudRuntimeAdapter`. Headless execution skips PNG creation and is never accepted as image evidence.

## Capture provenance

| Field | Value |
| --- | --- |
| Source ref / commit / tree | `agent/codex-dev-sol-5-6/3fbc2f531de0` / `3ffe04e8c8f22d175b0303e6e63e8e33185175e6` / `1dcc00f516103ec68a064ff71af5ae5763f7de6e` |
| Engine / renderer | Godot `4.7.stable.official.5b4e0cb0f` / GL Compatibility (OpenGL API 4.1 Metal, Apple M4 Pro) |
| Controlled seed | `394402`, reseeded per phase/weapon/mode cell |
| Workload exclusion | `FSD_GODOT_EXCLUSIVE=1` machine-wide Godot lease |
| Windowed command | `env FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_RUN_TIMEOUT=1800 python3 tools/godot_gate.py --path . --windowed --always-on-top --position 20,20 --script res://tests/ultimates/presentation/robot_certification_live_capture.gd` |
| Output root | `docs/design/reference-assets-lfs/ultimate-certification/robot` (Git LFS) |

## Coverage and observed readability

Twelve native 3 × 4 matrices cover release, active, and recovery at 1152×648, 1280×720, 1920×1080, and 2560×1440. Rows are `robot_magnetic_anchor`, `robot_hydraulic_press`, and `robot_reactor_core`; columns are normal, crowded, reduced motion, and photosensitivity safe. Crowded cells use the declared presentation cap of nine real targets for each weapon.

| Weapon | Named observations |
| --- | --- |
| `robot_magnetic_anchor` | 0.80s release, 1.25s active, 3.15s recovery: cyan debris implosion, outward EMP rhythm, player, targets, hazard telegraph, and HUD remain independently legible. |
| `robot_hydraulic_press` | 0.85s release, 1.30s active, 3.20s recovery: opposing press walls preserve a clear danger corridor and do not obscure the player or hazard bands. |
| `robot_reactor_core` | 0.90s release, 1.35s active, 3.45s recovery: eight red-orange vents retain the circular reactor identity and readable recovery spacing at every viewport. |

Reduced-motion cells read the shipped `screen_shake` setting as off, keeping the camera still and clamping the darkening veil to a calm fade without moving any beat. Photosensitivity-safe cells suppress the fullscreen veil while keeping authored foreground identity and real runtime fixtures. The evidence is spatial still-image proof at named beats; the focused gate separately validates runtime ownership, mode state, executor advancement, timing, and cleanup.

## Native output integrity

`certification_capture_manifest.json` records each required path, viewport, phase, native dimensions, and SHA-256. The focused gate fails closed on a missing mode, provenance key, file, hydrated LFS content, PNG signature/IHDR, dimensions, cell marker, or hash mismatch.
