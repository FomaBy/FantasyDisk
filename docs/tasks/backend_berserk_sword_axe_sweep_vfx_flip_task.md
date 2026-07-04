# Back-end: Berserk sword and axe sweep VFX flip

Статус: done
Приоритет: P1
Роль: Back-end
Контур: Codex
Executor: Codex
Owner: backend/current Codex worker
Thread/Worker: current Codex thread
Jira: SCRUM-875
Версия: 0.2.1
Создано: 2026-07-04
Locked paths: `scripts/berserk_weapon.gd`, `scripts/attack_vfx.gd`, `tests/attack_vfx_smoke_test.gd`, `docs/design/systems/combat.md`, `docs/design/current_game_state.md`, `docs/tasks/backend_berserk_sword_axe_sweep_vfx_flip_task.md`

## Context

User request: for Berserk sword and axe attacks, remove the visible sector overlay
during the attack animation and rotate the visible crescent/half-moon sweep
animation by 180 degrees.

## Acceptance Criteria

- Sword and axe keep their existing `sweep` damage geometry, targeting,
  cooldowns and balance numbers.
- Sword and axe no longer show the `BerserkExactAttackZone` sector/polygon
  overlay during attacks.
- The visible crescent slash for sword and axe sweep attacks is flipped by 180
  degrees.
- Hammer/circle behavior is unchanged.
- Focused VFX smoke and the umbrella runtime smoke pass through `tools/godot_gate.py`.
- Relevant combat/current-state docs are updated with the visual-only rule.

## Start Note

2026-07-04 14:18 EEST Codex claim. Branch/worktree: `dev` at
`/Users/sergeyfomin/Documents/AI Agent`. Lane: Codex. Locked paths are limited to
Berserk sweep VFX/runtime docs/tests. Next verification: focused VFX smoke, then
runtime smoke.

## Result

Implemented SCRUM-875 as a visual-only Berserk sweep fix:

- `scripts/berserk_weapon.gd`: sword/axe `sweep` attacks still use the same
  outward wedge damage geometry, but no longer spawn `BerserkExactAttackZone`
  sector polygons during the attack animation.
- `scripts/attack_vfx.gd`: `AttackVfx.slash()` accepts an optional sprite
  rotation offset; Berserk sweep calls it with `PI`, flipping the crescent slash
  by 180 degrees without changing the attack direction or damage window.
- `tests/attack_vfx_smoke_test.gd`: focused coverage now asserts sweep VFX hides
  the exact sector overlay and rotates crescent sprites by 180 degrees.
- Docs updated in `docs/design/systems/combat.md`,
  `docs/design/mechanics_extract.md`, and
  `docs/design/current_game_state.md`.

Verification:

- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
  - Note: the first runtime smoke attempt was blocked by pre-existing untracked
    Finder/sync duplicates `tests/melee_weapon_targeting_test 2.gd` and `.uid`.
    They were preserved under ignored `tmp/preexisting_duplicate_artifacts/`;
    the rerun passed.
  - Headless run still prints the existing non-fatal null texture warning from
    `_try_capture_weapon_select_screenshot`; the test result is PASS.

Disk cleanup: no disposable worktree created; pre-existing duplicate test copies
quarantined to ignored `tmp/preexisting_duplicate_artifacts/` so Godot duplicate
artifact guard can pass without deleting them.

Thread cleanup: not a disposable worker thread.

## QA-Вердикт

Статус: PASSED
Дата: 2026-07-04
Owner: codex-qa-scrum875-20260704
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum875_20260704`

Acceptance verified against `origin/dev` commit `5683ee22` containing
implementation commit `cb7d6d28`:

- Sword/axe keep `sweep` damage geometry/targeting/cooldowns/balance: code review
  confirms SCRUM-875 changed only `_show_sweep_area()` VFX call and
  `AttackVfx.slash()` sprite rotation, while `_is_enemy_inside_sweep()`,
  `_sweep_zone_points()`, weapon configs, cooldowns and damage math are
  unchanged.
- Sword/axe no longer spawn visible `BerserkExactAttackZone` sector overlay:
  focused smoke asserts no overlay node after `_show_sweep_area()`.
- Visible crescent slash is flipped by 180 degrees: focused smoke asserts all
  slash sprites have `PI` rotation.
- Hammer/circle behavior unchanged: code review confirms `_show_circle_area()`
  still calls `AttackVfx.hammer_slam()` unchanged, and melee targeting smoke
  verifies hammer circle radius/hit rejection and sector upgrades do not affect
  hammer radius.
- Combat/current-state/mechanics docs contain the SCRUM-875 visual-only rule.

QA verification:

- PASS: `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum875_20260704 --script res://tests/attack_vfx_smoke_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum875_20260704 --script res://tests/melee_weapon_targeting_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum875_20260704 --script res://tests/runtime_smoke_test.gd`
  - Non-fatal existing headless warning observed:
    `Parameter "t" is null` in `_try_capture_weapon_select_screenshot`; test
    still printed `Runtime smoke test passed.`

Disk cleanup: pending after scoped Jira sync; disposable Godot import artifacts
will be removed before final report.
