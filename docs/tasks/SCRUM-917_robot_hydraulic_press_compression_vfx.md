# SCRUM-917 — Robot Hydraulic Press compression animation/VFX

Статус: review
Приоритет: medium
Роль: Animator / VFX
Контур: Codex
Owner: `/root/animator_scrum917_finish`
Thread/Worker: `/root/animator_scrum917_finish`
Branch/worktree: `codex/scrum917-robot-hydraulic-vfx` at `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-917-robot-hydraulic-vfx`
Jira: SCRUM-917
Locked paths: `scripts/vfx/robot_hydraulic_press_compression_vfx.gd`, `scripts/robot_hydraulic_press_weapon.gd`, `scenes/vfx/RobotHydraulicPressCompressionVfx.tscn`, `scenes/RobotHydraulicPress.tscn`, `assets/sprites/effects/robot_hydraulic_press_compression/**`, `docs/design/references/weapon_attack_animations/robot_hydraulic_press/**`, `docs/design/previews/weapon_attack_animations/robot_hydraulic_press*`, `docs/design/systems/animation.md`, `docs/design/current_game_state.md`, `docs/design/content_registry.md`, `CHANGELOG.md`, this mirror, `tests/scrum917*`, `tools/build_scrum917*`.

## Контекст

SCRUM-916 replaced the old melee identity with a wide forward compression
corridor. Gameplay is already accepted and remains Back-end-owned. This task
updates only the visual/motion layer so the two side jaws visibly converge on
the centre axis and the crush frame lands on the existing delayed hit.

## Accepted Back-end Contract

- corridor starts at `owner + direction * 28px`;
- length is `attack_range = 430px`;
- full width is `suppression_width = 300px`, or `390px` with Press Calibrator;
- centre jaw/impact width remains `beam_width = 120px`;
- gameplay crush resolves after `grenade_delay = 0.20s`;
- gameplay damage, target query, compression displacement, cooldown and balance
  are read-only for SCRUM-917.

## PixelLab-first Source

- Existing accepted PixelLab object: `99b9c7ec-23d3-4110-a22a-912cf8b455b8`.
- New PixelLab v3 animation group:
  `659bdae5-22a9-4319-a3ca-57b972e5a9a3`.
- Animation: `hydraulic_press_side_to_center_crush`, 8 generated frames,
  transparent 256x256 source canvas.
- No OpenAI Images, `image_gen`, manual redraw or generic asset-generator
  fallback is used.

## Acceptance Criteria

- [x] Two force jaws/pressure waves visibly converge from both sides to the
      centre axis across the full live corridor width.
- [x] The active frame reads as compression/crush rather than a generic beam
      and is distinct from Magnetic Anchor and Reactor Core.
- [x] Visual geometry follows 430x300/390 live geometry without changing it.
- [x] Visual hit marker aligns with the existing 0.20s gameplay resolve.
- [x] Source/runtime frames are transparent, use stable centred pivot, preserve
      safe gutters and do not crop.
- [x] Manifest, alpha/gutter report, contact sheet/runtime preview and focused
      visual smoke are committed.
- [x] Focused visual/animation smoke and full runtime gate pass through
      `tools/godot_gate.py`.

## Result

- Reused the accepted PixelLab object
  `99b9c7ec-23d3-4110-a22a-912cf8b455b8`; generated source is the v3 group
  `659bdae5-22a9-4319-a3ca-57b972e5a9a3`, animation
  `31a9bfff-ee16-4037-a8f5-32477c37a73c`. No legacy/manual/OpenAI Images
  fallback was used.
- Integrated eight transparent `256x256` frames as a one-shot `compress`
  SpriteFrames animation at `25fps`; active frame 5 lands at `0.20s`.
- Added an isolated Robot Hydraulic Press visual bridge and VFX scene. The
  PixelLab layer and procedural jaws follow live `430x300` / `430x390`
  geometry and converge perpendicular to the attack direction. Shared
  `scripts/class_weapon.gd`, gameplay, damage, targets, displacement, cooldown
  and balance remain unchanged.
- Static evidence: all runtime frames use centred `(128,128)` pivots, minimum
  measured gutter is `19px`, and edge-visible pixels are `0`; the committed
  contact sheet was inspected and shows distinct anticipation, convergence,
  peak crush and release phases.
- Pre-sync gates passed through `tools/godot_gate.py`:
  - `tests/scrum917_robot_hydraulic_press_vfx_test.gd`;
  - `tests/animation_smoke_test.gd`;
  - `tests/runtime_smoke_test.gd` (known dummy-renderer screenshot diagnostic,
    followed by `Runtime smoke test passed`, exit `0`).
- Final commit/origin-dev evidence and post-rebase gate results are recorded in
  the Jira result comment after landing.
- Disk cleanup: task worktree retained only through commit/rebase/push; `.godot`
  and generated unrelated UID/cache sidecars are removed before final handoff.
