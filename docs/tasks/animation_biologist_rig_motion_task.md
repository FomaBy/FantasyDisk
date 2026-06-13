# Animator Task: Biologist Rig And Motion

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Роль: Animator
Jira: SCRUM-162
Source task: `docs/tasks/backend_add_character_biologist_task.md`
Unblocked by: canonical `assets/sprites/characters/biologist.png` from `docs/tasks/codex_design_biologist_art_task.md`

## Goal

Add Biologist cutout rig, motion profile, and attack pose hooks after canonical Biologist art is ready.

Back-end already implements gameplay and weapon timing. Do not change damage, cooldown, targeting, or balance.

## Required Motion Scope

- Cutout parts generated from canonical `biologist.png`:
  - `assets/sprites/characters/cutout/biologist_torso.png`
  - `assets/sprites/characters/cutout/biologist_arm_l.png`
  - `assets/sprites/characters/cutout/biologist_arm_r.png`
  - `assets/sprites/characters/cutout/biologist_leg_l.png`
  - `assets/sprites/characters/cutout/biologist_leg_r.png`
- Update rig manifest/profile as needed.
- Add a distinct Biologist motion feel: careful field-scientist gait, specimen-handling posture, not a copy of Chemist.
- Add technical attack pose hooks for:
  - `bio_spore_bloom` / `biologist_spore_lens`
  - `bio_sample_dart` / `biologist_sample_injector`
  - `bio_symbiote_web` / `biologist_symbiote_seed`

## Boundaries

- Animator owns motion, rig, pose, timing polish.
- Back-end owns actual gameplay timings and damage windows.
- If pose timing needs gameplay events, create a Back-end handoff instead of changing balance logic.

## Acceptance

- Animation smoke test passes.
- Runtime smoke remains green.
- In idle pose, assembled cutout matches canonical full-art sprite closely.
- Motion profile is visually distinct from Chemist/Doctor.

## Dispatch Notes

- 2026-06-13: Animator received Back-end handoff for SCRUM-162. Verified current branch `dev`, task status remains `blocked` because `assets/sprites/characters/biologist.png` does not exist yet and `docs/tasks/codex_design_biologist_art_task.md` is still `in_progress`. Task board row added as blocked; no Back-end gameplay/balance changes made.
- 2026-06-13: Design handoff unblocked. Ready assets: `assets/sprites/characters/biologist.png`, `assets/sprites/weapons/biologist_spore_lens.png`, `assets/sprites/weapons/biologist_sample_injector.png`, `assets/sprites/weapons/biologist_symbiote_seed.png`; preview `docs/design/previews/biologist_art_contact.png`. Proceed with Animator-owned cutout/rig/motion only; no Back-end gameplay/balance changes.

## Result

- 2026-06-13: generated Biologist cutout parts from `assets/sprites/characters/biologist.png`:
  `assets/sprites/characters/cutout/biologist_torso.png`,
  `biologist_arm_l.png`, `biologist_arm_r.png`, `biologist_leg_l.png`, `biologist_leg_r.png`,
  plus Godot `.import` files.
- Updated `tools/slice_rig_cutouts.py` and regenerated `scripts/sliced_rig_manifest.gd` with Biologist pivots/socket placement; debug sheet: `build/rig_debug/cut_biologist.png`.
- Added distinct careful field-scientist motion profile in `scripts/cutout_rig_2d.gd`: controlled gait, modest bob, specimen-handling arm posture, intentionally different from Chemist/Doctor.
- Added shoot pose hooks:
  - `biologist_spore_lens` / `bio_spore_bloom`: raised inspection/bloom lens stance;
  - `biologist_sample_injector` / `bio_sample_dart`: precise forward dart pose;
  - `biologist_symbiote_seed` / `bio_symbiote_web`: low planting/web gesture.
- Extended `tests/animation_smoke_test.gd` to cover Biologist profile, animation variants, pose separation, and readable weapon socket placement for all 3 Biologist weapons.
- Verification:
  - Godot headless editor import passed.
  - `res://tests/animation_smoke_test.gd` passed.
  - `res://tests/runtime_smoke_test.gd` could not run because of an unrelated Back-end parse error in `tests/runtime_smoke_test.gd:1060`; handoff created: `docs/tasks/backend_runtime_smoke_weapon_mechanics_indent_parse_task.md`.


## QA-Вердикт (2026-06-13)
Статус: PASSED (SCRUM-162)
- Cutout-части (5) + manifest для `biologist`; motion profile/attack pose hooks 3 оружий.
- animation_smoke + runtime_smoke зелёные на чистом HEAD (сборка рига проходит). Багов нет.
