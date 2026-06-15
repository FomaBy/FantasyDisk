# Design: Full-frame death rows for allies, elites, mini-elites, and bosses

Статус: done
Приоритет: high
Роль: Design
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator handoff from SCRUM-370
Jira: SCRUM-380
QA: in_progress (2026-06-14)

## Context
Animator coverage audit for SCRUM-370 found that current standard enemy
SpriteFrames already include explicit 6-frame `death` animations, but allies,
route elites, mini-elites, and bosses do not. They have accepted full-frame
`move`, `attack_primary`, and skill rows, so runtime cannot satisfy the new
director standard for drawn death animation without new source rows.

Audit artifact:
`build/qa/animation_integrate_all_move_attack_death_states/coverage.md`

## Scope
Create transparent full-frame `death` source rows/frames for the existing accepted
visual kits, preserving established scale, silhouette, frame size, naming, and
dark fantasy style. Do not change gameplay, balance, enemy behavior, or runtime
cleanup.

Required entities:
- Allies: `druid_beast`, `druid_pack_spirit`, `homunculus`, `leadership_echo`.
- Route elites: `iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`.
- Mini-elites: `mini_scavenger_reaper`, `mini_plague_bellringer`,
  `mini_bone_warden`, `mini_spark_wight`, `mini_rot_hound`,
  `mini_shadow_devourer`.
- Bosses: `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`,
  `ashen_colossus`.

## Requirements
- Use the mandatory `fantasydisk-asset-generator` path for any generated art.
- Each `death` row must be full-frame, transparent PNG, 5+ frames, non-loop.
- Bosses/elites must remain production full-frame sprite sheet work, not cutout
  deformation of a static sprite.
- Keep existing frame-safe contact previews inside empty preview zones; do not
  place animated content on decorative frame borders.
- Preserve existing SpriteFrames paths and source sheet families where possible.
  Animator will integrate final rows into `.tres` resources after Design review.

## Acceptance Criteria
- [ ] 19 entities above have accepted transparent `death` rows/source frames.
- [ ] Contact sheet/preview shows readable death motion and no dirty background.
- [ ] Asset manifest records frame sizes, paths, and intended animation name
  `death`.
- [ ] Task is handed back to Animator/SCRUM-370 for SpriteFrames integration.

## Result — 2026-06-14

Design source rows complete and ready for Animator integration.

Generated through the mandatory `fantasydisk-asset-generator` / OpenAI Images
workflow, then postprocessed to transparent runtime source rows and frames:

- 19/19 required entities covered.
- 114 transparent `death_00..05` PNG frames produced.
- 19 transparent `*_death_row.png` source rows produced.
- Allies use `256x256` frames.
- Route elites, mini-elites and bosses use `512x512` frames.

Reference/source pack:

- `docs/design/references/scrum380_death_rows/*_death_row_reference.png`
- `docs/design/references/scrum380_death_rows/scrum380_death_rows_manifest.json`

Runtime source paths:

- `assets/sprites/allies/druid_wolf/ally_druid_wolf_death_*.png`
- `assets/sprites/allies/pack_spirit/ally_pack_spirit_death_*.png`
- `assets/sprites/allies/homunculus/ally_homunculus_death_*.png`
- `assets/sprites/allies/leadership_echo/ally_leadership_echo_death_*.png`
- `assets/sprites/elites/full_frame/<elite_or_mini_id>/<id>_death_*.png`
- `assets/sprites/bosses/full_frame/<boss_id>/<boss_id>_death_*.png`

Previews:

- `docs/design/previews/scrum380_death_rows_contact.png`
- `docs/design/previews/scrum380_death_rows_readability.png`

Validation:

- Pillow validation passed: `19` entities, `114` frames, `RGBA`, expected
  frame/row dimensions, non-empty alpha.
- Visual review passed on contact/readability previews.
- Godot headless import passed for all SCRUM-380 PNG/reference/preview files.

Animator handoff:

- SCRUM-370 can consume the manifest and new rows. The Design blocker for
  `bone_archon`, `brood_mother` and `ashen_colossus` is resolved; remaining
  SpriteFrames `.tres` integration is Animator-owned.

## Animator Integration Notes
- 2026-06-14 — Animator integrated all currently available SCRUM-380 rows into
  SCRUM-370 SpriteFrames/manifest/QA previews: 4 allies, 4 route elites, all 6
  mini-elites, `rift_warden`, and `disk_devourer`.
- Remaining required production rows for SCRUM-370 unblock:
  `bone_archon`, `brood_mother`, `ashen_colossus`.
- QA artifact consuming current rows:
  `build/qa/animation_integrate_all_move_attack_death_states/scrum370_partial_death_rows_contact.png`.

## QA-Вердикт (2026-06-14)
Статус: PASSED (Design-scope: death-row source-ассеты 19 сущностей)

Проверено (фактически):
- **Source-кадры**: 114 death-PNG (`ally_*_death_*`, `<elite/mini>_death_*`,
  `<boss>_death_*`) + 19 `*_death_row_reference.png` — alpha-прозрачные (sample
  bad=0). Союзники 256², элиты/мини/боссы 512².
- **Манифест** `scrum380_death_rows_manifest.json`: 19 entities + `animation_name=death`,
  `loop=false`, `frame_count`, paths.
- **Визуал** `scrum380_death_rows_contact.png` (+ readability): 19×6 кадров,
  читаемый death-моушн (коллапс→растворение в искры/дух-фейд), прозрачный фон,
  не cutout. Godot import чист.

Acceptance:
- [x] 19 сущностей имеют death-ряды/source-кадры (114 кадров).
- [x] Контакт-лист читаем, без грязного фона.
- [x] Манифест фиксирует frame sizes/paths/`death`.
- [x] Передано Animator/SCRUM-370 для .tres интеграции.

⚠️ **Важно — victory-регрессия НЕ в 380**: на момент QA `runtime_smoke_test` красный
на `Expected victory screen text to include 'Победа'`. Причина — downstream
**SCRUM-370** (Animator .tres-интеграция death-рядов, НЕЗАВЕРШЕНА: bone_archon/
brood_mother/ashen_colossus остались) × SCRUM-379 death-lifecycle: boss теперь
играет death-анимацию (0.25-1.2с) перед cleanup, а runtime_smoke boss-flow ждёт
victory-текст лишь 2 кадра после смерти босса → не находит «Победа». Victory-экран
работает изолированно (`_show_victory_screen` производит «Победа»); combat-end +
meta-grant в тесте проходят — только текст после 2 кадров не успевает. Это домен
SCRUM-370 (интеграция/тайминг), НЕ Design-source 380. Поймаю при QA SCRUM-370.

Статус review→done (Design-source выполнен). Баги по 380: нет.
