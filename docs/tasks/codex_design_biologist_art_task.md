# Codex Design Task: Biologist Character And Weapon Art

Статус: review
Версия: 0.1.4
Создано: 2026-06-13
Роль: Design / Codex image generation
Jira: SCRUM-162
Source task: `docs/tasks/backend_add_character_biologist_task.md`

## Goal

Create canonical D&D-style FantasyDisk raster art for the new playable class `biologist`.

Back-end gameplay is implemented with documented fallback art. Replace those fallbacks with polished canonical assets once Design review passes.

## Required Assets

| ID | Required path | Size | Notes |
| --- | --- | ---: | --- |
| `biologist` | `assets/sprites/characters/biologist.png` | 512x512 | Transparent RGBA full-body hero sprite, neutral stance, separated legs, scientist/biomancer silhouette |
| `biologist_spore_lens` | `assets/sprites/weapons/biologist_spore_lens.png` | 256x256 | Spore lens / bio-observation focus; readable as a weapon/tool |
| `biologist_sample_injector` | `assets/sprites/weapons/biologist_sample_injector.png` | 256x256 | Injector / sample syringe, distinct from Doctor syringe |
| `biologist_symbiote_seed` | `assets/sprites/weapons/biologist_symbiote_seed.png` | 256x256 | Living symbiote seed / organic capsule |

## Style Direction

- Match current FantasyDisk D&D/tabletop dark fantasy canon.
- Painted cartoon fantasy, readable silhouette, not flat icons.
- Biologist should read as the Scientist pair to Chemist: biological research, spores, specimen jars, living vines/symbiotes, field scholar equipment.
- Avoid modern lab-coat sci-fi. Keep fantasy materials: leather straps, brass tools, glass vials, parchment labels, organic specimens.
- Character sprite should be usable for future cutout rig: visible torso, arms, legs, separated stance.
- Weapon sprites must be transparent PNG, one finished object per file, no UI frame, no text.

## Back-end Fallbacks Currently Used

- Character fallback: `assets/sprites/characters/chemist.png`
- `biologist_spore_lens`: `assets/sprites/weapons/briar_staff.png`
- `biologist_sample_injector`: `assets/sprites/weapons/plague_syringe.png`
- `biologist_symbiote_seed`: `assets/sprites/weapons/homunculus_vial.png`

## Acceptance

- All four PNGs exist at canonical paths with Godot `.import` files.
- Assets pass Design review against current hero/weapon art quality.
- Update `docs/design/content_registry.md`, `docs/design/systems/visual_style_assets.md`, and preview/contact sheet if Design owns those updates.
- Notify Back-end when paths are ready so scenes/configs can switch from fallback paths if needed.

## Result

2026-06-13: Design art kit generated and imported for review.

- Added canonical character sprite: `assets/sprites/characters/biologist.png` (`512x512`, RGBA, transparent).
- Added canonical weapon sprites:
  - `assets/sprites/weapons/biologist_spore_lens.png` (`256x256`, RGBA, transparent).
  - `assets/sprites/weapons/biologist_sample_injector.png` (`256x256`, RGBA, transparent).
  - `assets/sprites/weapons/biologist_symbiote_seed.png` (`256x256`, RGBA, transparent).
- Added QA/contact preview: `docs/design/previews/biologist_art_contact.png`.
- Art direction: D&D/tabletop FantasyDisk field biomancer, distinct from Chemist/Doctor; brass/glass biological tools, spores, parchment tags, living symbiote seed, and readable painterly silhouettes.
- Validation: Godot headless import completed successfully; all four gameplay PNGs have expected size, RGBA alpha, transparent background, non-empty alpha bbox, and generated `.import` files.
- Runtime smoke note: `runtime_smoke_test.gd` was attempted after import and is blocked in the current shared worktree by unrelated compile/signature issues (`scripts/cutout_rig_2d.gd` external member `DATA`, playable class signature list). No Biologist PNG/import error was reported.
- Scope note: Design did not change Back-end gameplay/balance or implement rig/motion. `docs/tasks/animation_biologist_rig_motion_task.md` is now ready for Animator handoff.
