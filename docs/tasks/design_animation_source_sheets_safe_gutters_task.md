# DESIGN: Regenerate Animation Source Sheets With Safe Gutters

Статус: review
Приоритет: high
Роль: Design
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator handoff from SCRUM-387
Jira: SCRUM-394
Связано: SCRUM-350, SCRUM-352, SCRUM-370, SCRUM-380, SCRUM-387

## Autonomy / Approval

Пользователь заранее одобрил in-scope работу. Работать автономно; вопросы только
при опасных действиях вне репозитория.

## Контекст

Animator SCRUM-387 проверил активные runtime `SpriteFrames` и source/reference
sheets на neighboring-frame bleed, alpha/chroma remnants и safe slicing.

Runtime результат зелёный: 30 `SpriteFrames` / 794 frame PNG прошли проверку без
захвата соседних кадров и без crop-edge chroma remnants. Исправлять активные
runtime PNG не нужно.

Проблема только в canonical source/reference sheets: 45 sheet-файлов имеют
точную 6x4 сетку с inferred `256x256` cells, `0 px` gutter и `0 px` outer
padding. Новый стандарт `fantasydisk-animation-director` требует для `256x256`
cells `24 px` discard-only gutter и `24 px` outer padding. Некоторые visuals
касаются inferred cell boundaries, поэтому эти sheets нельзя считать безопасным
source для будущей нарезки/пересборки.

## Что Уже Сделано

- SCRUM-387 создал отчёт:
  `docs/design/reviews/animation_safe_slicing_audit_2026_06.md`.
- QA JSON:
  `build/qa/animation_sprite_sheet_safe_slicing_audit/source_sheet_audit.json`.
- Active runtime SpriteFrames оставлены без изменений, потому что edge bleed не
  найден.

## Что Нужно От Design

Подготовить обновлённые canonical source/reference sheet packs с безопасными
discard-only gutters и outer padding:

- one pose/frame per cell;
- visual content fully inside its own cell;
- transparent `24 px` gutter between `256x256` cells;
- transparent `24 px` outer padding around the sheet;
- no silhouette, weapon, shadow, VFX, cloth, horn, tail, glow or alpha fringe
  touching another cell, gutter boundary, or sheet edge;
- preserve current visual identity and accepted animation poses;
- do not change gameplay, balance, runtime state names, or animation semantics.

Если Design решит использовать larger cells, follow the skill standard:
`384x384 -> 32 px`, `512x512 -> 48 px`, larger than 512 -> at least 8% rounded
up to the next 8 px.

## Files / Assets / IDs

Regenerate or replace source/reference sheets for these groups:

- `assets/sprites/enemies/full_frame/*_full_frame_sheet.png`:
  `ash_marksman`, `bone_caller`, `bone_shaman`, `rift_cutter`,
  `rift_shieldbearer`, `small_biter`, `spark_runner`, `stone_bruiser`,
  `venom_spitter`, `void_mage`, `winged_spark`.
- `assets/sprites/elites/full_frame/*_full_frame_sheet.png`:
  `iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`,
  `mini_scavenger_reaper`, `mini_plague_bellringer`, `mini_bone_warden`,
  `mini_spark_wight`, `mini_rot_hound`, `mini_shadow_devourer`.
- `assets/sprites/bosses/full_frame/*_full_frame_sheet.png`:
  `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`,
  `ashen_colossus`.
- `docs/design/references/scrum380_death_rows/*_death_row_reference.png`:
  `druid_beast`, `druid_pack_spirit`, `homunculus`, `leadership_echo`,
  `iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`,
  `mini_scavenger_reaper`, `mini_plague_bellringer`, `mini_bone_warden`,
  `mini_spark_wight`, `mini_rot_hound`, `mini_shadow_devourer`,
  `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`,
  `ashen_colossus`.

## Acceptance Criteria

- [x] Updated source/reference sheets include transparent gutters and outer
  padding meeting the `fantasydisk-animation-director` standard.
- [x] Visual content does not touch cell/gutter/sheet boundaries unless a task
  explicitly documents a full-cell VFX exception.
- [x] Existing entity IDs, row semantics, pose order, and accepted animation
  identities are preserved.
- [x] Source metadata/manifest records `frame_gutter_px`,
  `outer_padding_px`, and `safe_slicing_checked`.
- [x] Contact/QA previews stay inside the image content area and do not use UI
  decorative frame borders for content.

## Документация

Update relevant source manifests and Design notes when refreshed sheets are
created. Back-end/gameplay docs are not required unless active runtime paths
change.

## Progress Log

- 2026-06-14 — Взято в работу Design. Решение: выполнить deterministic source
  repack из текущих accepted sheet/death-row cells без изменения runtime
  SpriteFrames, gameplay, state names or timing. Target source layout for
  `256x256` cells: `24px` outer padding + `24px` discard-only gutters, with
  per-cell alpha content kept inside the safe inner area.
- 2026-06-14 — Design pass завершен, задача переведена в review. Repacked
  26/26 full-frame source sheets to `1704x1144` RGBA with `256x256` cells,
  `24px` transparent gutters and `24px` outer padding. Rebuilt 19/19
  SCRUM-380 death-row reference sheets to `1704x304` RGBA from accepted runtime
  death frames with the same gutter/padding contract. Runtime SpriteFrames,
  gameplay, state names and animation timings were not changed.

## Result Summary

- Updated source sheets:
  `assets/sprites/{enemies,elites,bosses}/full_frame/*_full_frame_sheet.png`
  (`26` files), now `1704x1144` RGBA with transparent safe gutters.
- Updated death-row references:
  `docs/design/references/scrum380_death_rows/*_death_row_reference.png`
  (`19` files), now `1704x304` RGBA with transparent safe gutters.
- Updated manifests:
  `docs/design/references/scrum352_full_frame_sheets/scrum352_sheet_manifest.json`
  and `docs/design/references/scrum380_death_rows/scrum380_death_rows_manifest.json`
  now record `frame_gutter_px: 24`, `outer_padding_px: 24` and
  `safe_slicing_checked: true`.
- QA artifacts:
  `build/qa/design_animation_source_sheets_safe_gutters/source_sheet_safe_gutters_report.json`
  and
  `docs/design/previews/scrum394_safe_gutter_source_sheets_contact.png`.
- Verification: PNG safe-gutter validation PASS (`45/45`, `0` failed), Godot
  import PASS, `tests/animation_smoke_test.gd` PASS.
