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
