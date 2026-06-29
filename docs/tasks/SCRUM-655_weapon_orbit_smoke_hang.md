# SCRUM-655: QA RED SCRUM-515 weapon_orbit_smoke_test hangs on current origin/dev

Jira: SCRUM-655
Статус: done
Роль: Back-end
Контур: Codex
Owner: Backend Codex
Thread/Worker: codex-worker-backend-scrum655
Locked paths: `tools/godot_gate.py`, `tests/weapon_orbit_smoke_test.gd`
Версия: 0.1.7

## Context

QA for SCRUM-515 reproduced a hang when running `tests/weapon_orbit_smoke_test.gd`
from a clean current `origin/dev` checkout. The smoke must preserve SCRUM-515
behavior: held/orbit weapon visual hidden in combat, `WeaponVisual.texture`
preserved for projectiles/traps/orbs, and weapon socket orbit mechanics intact.

## Result

Root cause: a fresh checkout can run `Godot --script` before Godot has generated
`.godot/imported/*` texture cache files and `global_script_class_cache.cfg`.
`Player.tscn` then instantiates without the player script, `configure_character`
is missing, and the SceneTree test never reaches `quit()`.

Fix:
- `tools/godot_gate.py` now performs a one-time headless `--import --quit` before
  `--script` test runs when the project import/global-class cache is missing.
- `tests/weapon_orbit_smoke_test.gd` now fails fast if `Player.tscn` loads without
  `configure_character`, instead of hanging on an invalid call.

Commit pushed: `37e7897b fix(SCRUM-655): make Godot script smokes import-safe`.

## Verification

- PASS from deleted `.godot` cache:
  `python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_orbit_smoke_test.gd`
  - gate ran headless import first
  - `Weapon orbit smoke test passed.`
- PASS warm-cache rerun:
  `python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_orbit_smoke_test.gd`
- PASS:
  `python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_scene_integrity_test.gd`
  - `Weapon scene integrity passed (51 оружий, все scene_path резолвятся, id уникальны, активны).`
- PASS:
  `python3 -m py_compile tools/godot_gate.py`

## Disk Cleanup

Generated `.godot` cache and untracked Godot `.import`/`.uid` sidecars from the
disposable checkout were removed before committing. The disposable checkout
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/SCRUM-655` will be removed
after final Jira sync and push.

## QA-Вердикт (2026-06-29)

Статус: PASSED

Проверено:
- Clean isolated checkout `/Users/sergeyfomin/Documents/FantasyDisk-QA-SCRUM-655`
  on `dev` at `a754c7af`; confirmed target commits `37e7897b` and `d7c7b369`
  are present in `origin/dev`.
- Inspected `tools/godot_gate.py`, `tools/jira_board_sync.py`,
  `tests/weapon_orbit_smoke_test.gd`, SCRUM-655 evidence, and SCRUM-515 context.
- `python3 -m py_compile tools/godot_gate.py tools/jira_board_sync.py` passed on
  Python 3.9.6.
- Fresh/deleted-cache gate run:
  `python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_orbit_smoke_test.gd`
  exited 0 in 40.99s; gate printed `import cache missing, running headless import first`;
  test printed `Weapon orbit smoke test passed.`
- Warm-cache gate rerun of `weapon_orbit_smoke_test.gd` exited 0 in 0.56s and
  printed `Weapon orbit smoke test passed.`
- Direct deleted-cache Godot run without the gate:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/weapon_orbit_smoke_test.gd`
  exited 1 in 0.25s with the new fail-fast message instructing use of
  `tools/godot_gate.py`; it did not hang.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_scene_integrity_test.gd`
  exited 0 in 0.26s; `Weapon scene integrity passed (51 оружий, все scene_path резолвятся, id уникальны, активны).`

Краевые случаи:
- Deleted `.godot` cache before the main gate run to force import-cache recovery.
- Verified warm-cache rerun skips the import path and remains fast.
- Verified the smoke still catches real SCRUM-515 behavior: QA dump shows
  `WeaponRootVisible=false`, `WeaponVisualVisible=false`,
  `WeaponVisualTextureSet=true`, `WeaponParent=WeaponSocket`, and
  `SocketDistance=112.00`.

Баги: нет.

Disk cleanup: QA disposable checkout
`/Users/sergeyfomin/Documents/FantasyDisk-QA-SCRUM-655` will be removed after
this QA evidence commit/push and final Jira sync.
