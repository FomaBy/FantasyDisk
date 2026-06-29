# SCRUM-539 Secret Ascension Boss Source Pack

Статус: done (QA PASSED; PM sprint audit restored Jira Готово 2026-06-29)
Contour: Codex
Owner: Design/Codex
Thread: SCRUM-539 worktree delivery
Locked paths: docs/design/references/bosses/secret_ascension_boss/, assets/sprites/bosses/secret_ascension_boss.png, assets/sprites/effects/secret_ascension_boss_*_telegraph.png, docs/design/previews/scrum539_secret_ascension_boss_*.png, docs/tasks/*secret_ascension_boss*
Jira: SCRUM-539

## Scope

Create a Design source pack for the optional final ascension secret boss. This is
art/source handoff work only: no boss logic, unlock condition, balance, scene
wiring, AnimationPlayer, SpriteFrames, or combat scripts.

## Result

Generated through the project source-pack workflow and alpha-cleaned for
transparent source/runtime candidates.

- Boss source raw: `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_source_raw.png`
- Boss source alpha: `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_source_alpha.png`
- Boss runtime candidate: `assets/sprites/bosses/secret_ascension_boss.png`
- Telegraph source raw: `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_telegraph_vfx_source_raw.png`
- Telegraph source alpha: `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_telegraph_vfx_source_alpha.png`
- Runtime telegraph candidates:
  - `assets/sprites/effects/secret_ascension_boss_ring_telegraph.png`
  - `assets/sprites/effects/secret_ascension_boss_cone_telegraph.png`
  - `assets/sprites/effects/secret_ascension_boss_beam_telegraph.png`
  - `assets/sprites/effects/secret_ascension_boss_rupture_telegraph.png`
- QA/contact preview: `docs/design/previews/scrum539_secret_ascension_boss_contact.png`
- Scale preview: `docs/design/previews/scrum539_secret_ascension_boss_scale_preview.png`
- Source pack report: `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_source_pack_report.json`

## Visual Direction

The boss is an ancient dragon-disk rift titan: black obsidian armor, bone/stone
halo disk, dragon horns/claws, violet rift core, and a tall endgame-wall
silhouette. It is visually distinct from `rift_warden`, `disk_devourer`,
`bone_archon`, `brood_mother`, and `ashen_colossus`.

Recommended static candidate size: `1024x1024` RGBA, alpha bbox
`[180, 42, 843, 984]`, pivot `(512, 960)`, visual radius about `390px` in source
space.

## Handoffs

- Animator note: `docs/tasks/animation_secret_ascension_boss_source_handoff_task.md`
- Back-end note: `docs/tasks/backend_secret_ascension_boss_runtime_handoff_task.md`

## Validation

- PNG metadata verified with Pillow: all source/runtime candidates are RGBA with
  transparent alpha.
- Contact and scale previews regenerated without baked text.
- No Godot runtime smoke required: no scripts/scenes/mechanics changed.
