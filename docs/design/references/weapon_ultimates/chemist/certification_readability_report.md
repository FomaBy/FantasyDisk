## FAN-3937 Chemist ultimate certification

This is capture-and-review evidence for the shipped Chemist ultimate trio. It does not change production scenes, gameplay, balance, HUD behavior, overlays, or adoption paths.

`tests/ultimates/presentation/chemist_certification_live_capture.gd` creates every visual cell through `Player.activate_ultimate` and the Player-owned `UltimateHost`. Each cell mounts the shipped Chemist V2 scene, real `EnemySpitter` targets, an `ElitePoisonZone` created by `EnemySpitter._spawn_elite_hazard`, and the shipped ultimate HUD through `UltimateHudRuntimeAdapter`. A headless renderer invocation exits without PNG creation; it is a structural-runner skip, never image evidence.

## Capture provenance

| Field | Value |
| --- | --- |
| Source ref / commit / tree | `agent/codex-dev-terra-b/d54103bd6266` / `6792ca7d538607d602c09b880ad6428d41ba8d08` / `795107f6118bd2683c43f731f0b4de53408b255c` |
| Engine / renderer | Godot `4.7.stable.official.5b4e0cb0f` / GL Compatibility (`OpenGL API 4.1 Metal`, Apple M4 Pro) |
| Controlled seed | `3937`, reseeded per phase/weapon/mode cell |
| Workload exclusion | `FSD_GODOT_EXCLUSIVE=1` acquires the machine-wide Godot lease before PNG generation |
| Windowed command | `env FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_RUN_TIMEOUT=1800 python3 tools/godot_gate.py --path . --windowed --always-on-top --position 20,20 --script res://tests/ultimates/presentation/chemist_certification_live_capture.gd` |
| Output root | `docs/design/reference-assets-lfs/ultimate-certification/chemist` (Git LFS) |

After consuming V2 deferred autoplay, the renderer advances the production executor with fixed `custom_step` increments and seeks the shipped timeline to the named beat. It freezes Player, Enemy, hazard, V2 timeline/sprites, victim impact, and HUD refresh; detached post-executor feedback is suppressed after the real action has run. It then draws exactly three final `UPDATE_ONCE` frames and disables the SubViewport for texture readback. These are capture-only stabilizers; all retained visible combat state remains production runtime state.

## Coverage and readability assessment

The package has twelve native 3 × 4 PNG matrices: three phase sheets (release, active, recovery) at 1152×648, 1280×720, 1920×1080, and 2560×1440. Rows are `blast_powder`, `acid_flask`, and `homunculus_vial`; columns are `normal`, `crowded`, `reduced_motion`, and `photosensitivity_safe`.

Ordinary modes use three real targets. Crowded cells use the declaration's real caps: 18 Blast Powder targets, 16 Acid Flask targets, and 14 Homunculus Vial targets. Each header and state caption identifies the fixed phase beat, shake setting, target count, and veil state. The Player lane, V2 effect zone, right-side hazard lane, caption band, and shipped HUD are non-overlapping.

| Weapon | Named observations |
| --- | --- |
| `blast_powder` | 0.95s release, 1.45s active, 3.15s recovery: ritual/pentagram, real Player, targets, and poison telegraph remain distinguishable. |
| `acid_flask` | 0.85s release, 1.20s active, 3.55s recovery: flask, lake, impact field, player lane, and elite telegraph remain separated at the crowd cap. |
| `homunculus_vial` | 0.90s release, 2.85s active, 3.65s recovery: fusion silhouette and stomp/cascade remain independently readable with the real fixtures. |

Reduced-motion reads the shipped `screen_shake` setting as off and retains the V2 damped fade. Photosensitivity-safe hides the shipped backdrop veil while retaining the authored foreground and real runtime fixtures.

## Native output integrity

`certification_capture_manifest.json` records a required path, native dimensions, phase, and SHA-256 for every sheet. The focused gate fails closed for a missing mode, provenance key, PNG, hydrated LFS content, PNG structure, dimensions, marker, or hash.

| ID | Dimensions | Phase | SHA-256 |
| --- | --- | --- | --- |
| `648p-release` | 1152×648 | release | Final manifest record |
| `648p-active` | 1152×648 | active | Final manifest record |
| `648p-recovery` | 1152×648 | recovery | Final manifest record |
| `720p-release` | 1280×720 | release | Final manifest record |
| `720p-active` | 1280×720 | active | Final manifest record |
| `720p-recovery` | 1280×720 | recovery | Final manifest record |
| `1080p-release` | 1920×1080 | release | Final manifest record |
| `1080p-active` | 1920×1080 | active | Final manifest record |
| `1080p-recovery` | 1920×1080 | recovery | Final manifest record |
| `2k-release` | 2560×1440 | release | Final manifest record |
| `2k-active` | 2560×1440 | active | Final manifest record |
| `2k-recovery` | 2560×1440 | recovery | Final manifest record |

## Verification scope

The focused certification gate covers all 144 phase/weapon/mode/viewport combinations. It proves actual Player activation, real EnemySpitter targets, the actual elite hazard, shipped HUD selection/active state, V2 victim impacts, named V2 seeks, and non-overlapping readability zones. In windowed mode it also checks every hydrated LFS PNG's dimensions, markers, and SHA-256.

The stills show spatial readability at named release, active, and recovery beats; the gate verifies temporal executor and mode behavior. Blast Powder's visual recovery outlasts its executor, so the capture retains the real cast at its last meaningful execution state while seeking the authored recovery beat.
