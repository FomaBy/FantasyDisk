# ANIM: Берсерк cartoon/anime anchor — idle + walk/move handoff из SCRUM-456

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-17
Автор: Design main handoff from SCRUM-456
Jira: SCRUM-461
Связано: SCRUM-456, SCRUM-442, `docs/design/references/chars_cartoon/`

## Blocker

Снят 2026-06-17: SCRUM-456 получил QA verdict `PASSED` для Design-source пакета
cartoon/anime anchor, Animator runtime/SpriteFrames этап можно начинать.

## Context

SCRUM-456 создал опорный cartoon/anime style-sheet и Berserk exemplar source:

- style sheet: `docs/design/references/chars_cartoon/character_cartoon_anime_style_sheet.md`
- handoff: `docs/design/references/chars_cartoon/berserk_cartoon_anchor_design_handoff.md`
- source cell: `docs/design/references/chars_cartoon/berserk_cartoon_anchor_idle_cell_512.png`
- source sheet handoff: `docs/design/references/chars_cartoon/berserk_cartoon_anchor_sheet_source_handoff.png`
- QA/source previews: `build/qa/scrum456_chars_cartoon/`

## Animator Scope

After SCRUM-456 source acceptance:

1. Author real `idle` loop for Berserk from the accepted source.
   - 5 frames preferred, loop, `7 fps`.
   - Breathing, hair/fur/cloth secondary motion.
2. Author real `walk` / `move` loop.
   - 5+ frames, loop, `9 fps`.
   - Visible legs and arms must move; no static bob-only loop.
3. Keep `attack_primary` out of scope.
   - Weapon visuals/VFX own attack readability for this initiative.
4. Preserve Design contract.
   - `512x512` cells.
   - Pivot `(256, 470)`.
   - Transparent RGBA.
   - No baked weapon/tool/shield.
   - No white/checker/neutral matte.
5. Only after accepted motion frames exist, integrate runtime paths as Animator
   ownership requires and run animation validation/smokes.

## Out Of Scope

- Back-end gameplay, balance, weapon logic, collision, targeting.
- Attack animation.
- Changing class registry or Hero Select/Codex UI behavior except as required by
  accepted animation asset integration in a later unblocked pass.

## Acceptance Criteria

- [x] `idle` has 5-frame loop, transparent, stable pivot, readable breathing.
- [x] `walk`/`move` has 5+ frame loop with visible arm+leg motion.
- [x] No `attack_primary` row/state added.
- [x] Contact sheet, GIFs, animation manifest and relevant Godot smoke tests are
      recorded in this task.
- [x] Jira/task board synced after status changes.

## Result (2026-06-17)

Статус: done

SCRUM-461 Animator pass consumed the accepted SCRUM-456 cartoon/anime source
sheet and replaced only the live Berserk `idle` / `walk` / `move` full-frame
runtime frames. `assets/sprites/characters/berserk_spriteframes.tres` now uses:

- `idle`: 5 frames, loop, 7 fps.
- `walk`: 5 frames, loop, 9 fps.
- `move`: 5 frames, loop, 9 fps, aliases the walk frames.

Runtime PNGs are the 10 sliced `512x512` transparent RGBA frames under
`assets/sprites/characters/full_frame/berserk/`, with the documented pivot
`(256,470)` and `48 px` source gutters. `attack` / `attack_primary` were not
added by task scope. Previous live Berserk frames and SpriteFrames were backed
up under `docs/design/backups/scrum461_berserk_cartoon_pre_anim/`.

QA artifacts:

- contact: `build/qa/scrum461_berserk_cartoon_anim/scrum461_berserk_cartoon_anim_contact.png`
- idle GIF: `build/qa/scrum461_berserk_cartoon_anim/berserk_cartoon_idle.gif`
- walk GIF: `build/qa/scrum461_berserk_cartoon_anim/berserk_cartoon_walk.gif`
- manifest: `build/qa/scrum461_berserk_cartoon_anim/animation_manifest.json`
- alpha/size report: `build/qa/scrum461_berserk_cartoon_anim/alpha_size_report.json`
- manifest validator output: `build/qa/scrum461_berserk_cartoon_anim/manifest_validator_output.txt`

Validation:

- `python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/scrum461_berserk_cartoon_anim/animation_manifest.json` -> expected scope exception only: `berserk: missing attack_primary animation`.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` -> PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/character_sprite_registry_alignment_test.gd` -> PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` -> PASS.

## QA-Вердикт (2026-06-23)

Статус: PASSED

Независимый QA-прогон на актуальном рабочем дереве (live `berserk_spriteframes.tres`
закоммичен и чист):

- `tests/animation_smoke_test.gd` → EXIT=0, «Animation smoke test passed.»
- `tests/character_sprite_registry_alignment_test.gd` → EXIT=0, «… passed (17 characters).»
- `tests/runtime_smoke_test.gd` → EXIT=0, «Runtime smoke test passed.»

Логи: `build/qa/qa_session_20260623/`. Berserk: 5f looping idle/walk(move) без
attack-строки — соответствует scope. Закрываю → «Готово».
