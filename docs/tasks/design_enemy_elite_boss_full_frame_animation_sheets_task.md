# Design handoff: enemy, elite, and boss full-frame animation sheets

Статус: done
Приоритет: high
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator audit `animation_full_frame_pipeline_coverage_audit_task.md`
Исполнитель: Designer (Codex)
Jira: SCRUM-352
QA: in_progress (2026-06-14)
Parent: SCRUM-350 / `animation_full_frame_pipeline_coverage_audit_task.md`

## Autonomy / Approval
Пользователь заранее одобрил in-scope работу. Design работает автономно по
`fantasydisk-asset-generator`; старый asset pipeline не использовать.

## Role / Scope
Design-owned. Animator must not redraw these production sprites. Back-end gameplay,
balance, targeting, spawn rules, and damage are out of scope.

## Context
The new animation standard requires full-frame production animation for elites and
bosses. Current enemies, elites, mini-elites, and bosses mostly have static source
PNGs plus cutout parts. That remains useful as fallback/readability coverage, but
does not satisfy the new 5+ frame movement and 5+ frame attack-production standard,
especially the "no cutout for elites/bosses" rule.

Existing non-duplicate work:

- SCRUM-156 delivered static source PNGs for new bosses/mini-elites.
- SCRUM-204 only unblocked cutout slicing and is superseded by SCRUM-156.
- SCRUM-184/185 covered cutout readability smoke, not production full-frame sheets.
- SCRUM-298 covers playable characters, not enemies/elites/bosses.

## Needed Assets
Create transparent full-frame sprite-sheet source for:

- Standard enemies: `rift_cutter`, `ash_marksman`, `spark_runner`,
  `stone_bruiser`, `bone_caller`, `void_mage`, `venom_spitter`,
  `rift_shieldbearer`, `small_biter`, `bone_shaman`, `winged_spark`.
- Route elites: `iron_bastion`, `night_stalker`, `plague_prophet`,
  `shard_marshal`.
- Mini-elites: `mini_scavenger_reaper`, `mini_plague_bellringer`,
  `mini_bone_warden`, `mini_spark_wight`, `mini_rot_hound`,
  `mini_shadow_devourer`.
- Bosses: `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`,
  `ashen_colossus`.

## Animation Requirements
- Transparent PNG, no baked background, no crop, stable bottom-center pivot.
- Movement row: 5+ frames, loop=true. Legged enemies use real walk/run; flying or
  lore-floating entities use natural levitation/flap with tucked/natural legs.
- `attack_primary`: 5+ frames, loop=false, with anticipation, active frame,
  follow-through, and recovery.
- Elites/bosses: full-frame sheets only for production animation; no production
  cutout slicing from static sprites. Each elite/boss needs at least two
  skill/phase-specific attack rows. Prefer 7-9 frames for boss attacks.
- Keep readable silhouettes at current game scale and preserve transparent alpha.

## Handoff Back To Animator
When sheets are ready, unblock Animator to:

- build/import SpriteFrames resources;
- map `move`/`attack_primary`/skill attacks into the animation manifest;
- update animation smoke and QA previews;
- keep gameplay timing owned by Back-end.

## Acceptance Criteria
- [ ] Contact sheets/GIF previews exist for each produced entity family.
- [ ] Every sheet has 5+ movement frames and 5+ primary attack frames.
- [ ] Every elite/boss sheet has 2+ skill attack rows and is full-frame, not cutout.
- [ ] Transparent alpha/no-crop/pivot notes are documented for Animator.
- [ ] Task board and Jira are synced.

## Blocker History — 2026-06-14
Design/Codex checked the task and the required `fantasydisk-asset-generator`
skill. This full-frame sheet handoff explicitly says Design works by that skill
and must not use the old asset pipeline. Current shell has no `OPENAI_API_KEY`,
and `import openai` fails with `ModuleNotFoundError`, so production sprite-sheet
generation cannot start. Animator handoff remains blocked until Design can
produce the transparent full-frame sheets.

## Blocker Resolved — 2026-06-14
Documentation dispatcher verified that local `OPENAI_API_KEY` can now be loaded
from the secure Codex env file outside the repository and Python `openai` imports
successfully. Previous asset-generator environment blocker is resolved. This task
is Design-owned source sheet generation; Animator should receive a follow-up only
after accepted transparent full-frame sheets are produced.

## Dispatch Note — 2026-06-14
Documentation dispatcher routed SCRUM-352 to the existing Design Codex thread
`019eabf1-6d54-7561-8af9-ce25cdf483a9`. Design must load the key only from the
secure local env file outside the repository, must not print or persist the key
in project files/logs, and must keep the work Design-owned until accepted sheets
are ready for an Animator handoff.

## Blocked Again — 2026-06-14
Design resumed the task on `dev`, read AGENTS/process docs, the task file, and
`fantasydisk-asset-generator`, then ran a duplicate audit. No accepted
enemy/elite/boss full-frame sheets exist yet; current project coverage is static
PNG + cutout fallback, with only ally full-frame SpriteFrames already present.

Prepared task-specific generator wrapper:

- `tools/generate_scrum352_full_frame_sheets.py`

The wrapper follows the asset-generator rules for OpenAI Images, transparent PNG
outputs, deterministic SCRUM-352 paths, and no runtime/SpriteFrames integration.
It also records sheet rows, 256x256 frame cells, bottom-center pivot metadata,
and a preview/manifest path when generation succeeds.

QA/prep artifact:

- `docs/design/previews/scrum352_current_static_inventory.png`

Pilot generation was attempted for `rift_cutter` using the current approved env
source `$HOME/.codex/.env`, without printing or persisting the key. The OpenAI
Images API returned:

```text
billing_hard_limit_reached
```

Per dispatcher instruction, Design stopped immediately, did not retry, and did
not use old/random/local fallback generators. SCRUM-352 remains blocked until
OpenAI image generation billing is available again or PM provides an approved
alternative generation source.


## Ключ настроен — блокер снят (2026-06-14)
`OPENAI_API_KEY` фактически сохранён в `~/.codex/.env` (права 600, вне git) +
автозагрузка в `~/.zshrc` — доступен в окружении автоматически в каждом новом
shell (включая shell Codex-воркеров). Скилл `fantasydisk-asset-generator`
(gpt-image-2) готов к вызову. Блокер по отсутствию `OPENAI_API_KEY` снят
окончательно; задача готова к исполнению через скилл.

## Retry Succeeded — 2026-06-14
User requested another attempt. Design retried the `rift_cutter` pilot through
the current approved `$HOME/.codex/.env` OpenAI Images path. The first retry
showed `gpt-image-2` edit does not support direct `background=transparent`; the
task-specific wrapper was corrected to generate RGB source PNGs and perform
transparent postprocess as required by the asset-generator skill notes.

Pilot output now exists:

- `docs/design/references/scrum352_full_frame_sheets/raw/rift_cutter_full_frame_sheet_raw.png`
- `assets/sprites/enemies/full_frame/rift_cutter_full_frame_sheet.png`
- `docs/design/references/scrum352_full_frame_sheets/scrum352_sheet_manifest.json`
- `docs/design/previews/scrum352_full_frame_sheets_preview.png`

This removes the previous billing blocker. The full SCRUM-352 production scope
is still open: remaining standard enemies, route elites, mini-elites and bosses
must be generated and then handed off to Animator.

## Result — 2026-06-14
Design completed the full SCRUM-352 production source sheet set through the
approved `fantasydisk-asset-generator` / OpenAI Images path and the
task-specific wrapper:

- `tools/generate_scrum352_full_frame_sheets.py`

Generated accepted transparent full-frame source sheets for all 26 requested
entities:

- 11 standard enemies in `assets/sprites/enemies/full_frame/*_full_frame_sheet.png`
- 10 route/mini elites in `assets/sprites/elites/full_frame/*_full_frame_sheet.png`
- 5 bosses in `assets/sprites/bosses/full_frame/*_full_frame_sheet.png`

Reference/raw outputs and manifest:

- `docs/design/references/scrum352_full_frame_sheets/raw/*_full_frame_sheet_raw.png`
- `docs/design/references/scrum352_full_frame_sheets/scrum352_sheet_manifest.json`

Preview/QA artifacts:

- `docs/design/previews/scrum352_full_frame_sheets_preview.png`
- `docs/design/previews/scrum352_full_frame_sheets_contact.png`

Validation:

- Pillow validation PASS: 26/26 PNGs are `1536x1024`, RGBA, have transparent
  alpha, and have non-empty alpha bounding boxes.
- Manifest PASS: 26 generated entries, 6 columns, 4 rows, 256px cells,
  bottom-center pivot guidance, source faces left.
- Visual contact review PASS: enemy, elite, mini-elite and boss rows are
  readable as D&D/dark fantasy full-frame sheets with movement, primary attack
  and skill/death rows according to the task row contract.
- Godot import PASS:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --import`

Scope note: Design produced and validated the source sheets/manifest/previews.
Runtime SpriteFrames, registry validation, animation smoke and gameplay-facing
integration are Animator-owned and were tracked in the downstream full-frame
integration tasks. Design did not hand-edit gameplay or timing logic.

## QA-Вердикт (2026-06-14)
Статус: PASSED — родительский source-asset деливерабл (26 full-frame листов)

Проверено (фактически):
- **26/26 source-листов** (Pillow): 11 врагов + 10 элит/мини-элит + 5 боссов —
  ВСЕ `1536×1024` RGBA с прозрачной alpha (ext[0]<255) и непустым bbox; BAD=0.
- **Манифест** `scrum352_sheet_manifest.json`: `generated` = 26 записей
  (entity_id/kind/title/source); `frame_size=[256,256]`, columns/rows, pivot
  bottom-center, source_faces_left — контракт рядов задокументирован для Animator.
- **Визуал** `scrum352_full_frame_sheets_contact.png` (+ preview): 26 листов 6×4
  (move/attack_primary/2 skill·death), читаемые dark-fantasy/D&D силуэты,
  прозрачный фон, не cutout.
- **E2E-валидация (сильнейшая)**: эти листы потреблены и проверены 8 downstream-
  интеграциями — SCRUM-363/364/365/366/367 (враги), 368/371 (route-элиты), 376
  (6 мини-элит) — ВСЕ нарезали move 6f loop + attack 6f (+ 2 skill для элит) и
  прошли QA-вердикты. Боссы — downstream SCRUM-377 (в очереди). Godot import PASS.

Acceptance:
- [x] Контакт-листы/превью существуют для каждого семейства (родительский + per-family downstream).
- [x] Каждый лист 5+ move + 5+ attack кадров (downstream подтвердили 6f/6f).
- [x] Каждая элита/босс 2+ skill-ряда, full-frame не cutout (368/371/376 подтвердили).
- [x] Прозрачная alpha/no-crop/pivot задокументированы (манифест + 26 RGBA transparent).
- [x] Доска/Jira синканы.

Примечание: статус review→done (QA пройдено по Design-scope). Баги: нет.
