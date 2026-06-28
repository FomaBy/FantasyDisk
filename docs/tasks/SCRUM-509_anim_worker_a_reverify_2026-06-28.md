# SCRUM-509 anim-worker-a reverify evidence, 2026-06-28

Jira: SCRUM-509
Role/lane: animator / codex
Worker: anim-worker-a
Статус: done
Latest worker: anim-loop
Latest worktree: `D:\FantasyDisk_agents\anim_loop_20260628_172847`

## Result

Fixed on current dev recheck. `scripts/skeleton_player_rig_2d.gd` now builds and finalizes the full `Skeleton2D` while it is still outside the SceneTree, then attaches the completed skeleton once. Bone positions, pivots, z-order, and animation tracks were not changed.

## Verification

Godot: `Godot_v4.7-stable_win64_console.exe`
Logs: `build/qa/SCRUM-509_reverify/`

- `runtime_smoke.log`: PASS; `det == 0` = 0; `No Bone2D children` = 0; `Cannot calculate bone length` = 0.
- `animation_smoke.log`: PASS; `det == 0` = 0; `No Bone2D children` = 0; `Cannot calculate bone length` = 0. Existing non-SCRUM-509 `data.tree is null` weapon-layer noise remains, but the smoke prints `Animation smoke test passed.` and skeletal rig grep counts are clean.
- `skeletal_rig_rest_det_smoke.log`: PASS; 40 bones / 2 rigs; `det == 0` = 0; `No Bone2D children` = 0; `Cannot calculate bone length` = 0.
- `godot_import.log`: import completed before tests; SCRUM-509 grep counts are 0.

## Tooling note

`tools/godot_gate.py` is POSIX-only on this Windows runner (`fcntl` import failure), so verification used direct Godot headless commands after import:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_test.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/animation_smoke_test.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/skeletal_rig_rest_det_smoke_test.gd
```

## Animator loop reverify, 2026-06-28

Worker: `anim-loop`
Branch/worktree: `codex/anim-loop-20260628`, `D:\FantasyDisk_agents\anim_loop_20260628_172847`
Result: still fixed on current `origin/dev`; no code changes needed.

Fresh logs: `build/qa/SCRUM-509_anim_loop_20260628/`

- `runtime_smoke.log`: PASS; exit code 0; `det == 0` = 0; `No Bone2D children` = 0; `Cannot calculate bone length` = 0.
- `animation_smoke.log`: PASS; exit code 0; `det == 0` = 0; `No Bone2D children` = 0; `Cannot calculate bone length` = 0. Existing unrelated `data.tree is null` weapon-layer noise remains, but the suite prints `Animation smoke test passed.`
- `skeletal_rig_rest_det_smoke.log`: PASS; exit code 0; 40 bones / 2 rigs; `det == 0` = 0; `No Bone2D children` = 0; `Cannot calculate bone length` = 0.
- `godot_import.log`: import process exited with Windows code `-1073741819` after logging duplicate UID warnings for existing mirrored reference/runtime PNGs; the subsequent runtime, animation, and focused skeletal smokes all passed and imported required resources.

Disk cleanup: removed disposable `.godot/` and Godot-generated unrelated `.import`/`.uid` sidecars before finishing.
