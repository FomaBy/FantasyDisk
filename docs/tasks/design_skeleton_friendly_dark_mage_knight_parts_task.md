# Задача Для Design-Агента: Skeleton-friendly parts для Dark Mage и Knight

Статус: done
Приоритет: high
Роль: Design
Исполнитель: Codex (fantasydisk-asset-generator)
Версия: 0.1.6
Создано: 2026-06-19
Автор: Animator handoff from SCRUM-474
Jira: SCRUM-475
Связано: SCRUM-474, SCRUM-456, SCRUM-473
QA: in_progress (2026-06-19 21:45)

## Autonomy / Approval

Пользователь заранее одобрил in-scope изменения. Design должен выполнить
source-art часть без ожидания дополнительного подтверждения.

## Контекст

SCRUM-474 переводит Dark Mage и Knight на настоящий skeletal animation pipeline:
`Skeleton2D` + `Bone2D` + `AnimationPlayer`. Animator обновил
`fantasydisk-animation-director` так, что skeletal pipeline стал предпочтительным
для playable characters, но не может продолжить без accepted Design-source parts.

Текущие whole-body источники:
- Runtime sprites: `assets/sprites/characters/dark_mage.png`,
  `assets/sprites/characters/knight.png`.
- Accepted cartoon2 references:
  `docs/design/references/chars_cartoon/trial_v2/dark_mage_cartoon2.png`,
  `docs/design/references/chars_cartoon/trial_v2/knight_cartoon2.png`.
- Style anchor:
  `docs/design/references/chars_cartoon/character_cartoon_anime_style_sheet.md`.

## Что Уже Сделано

- SCRUM-473 delivered temporary full-frame `idle` / `walk` / `move` SpriteFrames
  for both classes.
- SCRUM-474 Animator intake updated the animation-director skill and added a
  skeleton source manifest validator:
  `~/.codex/skills/fantasydisk-animation-director/scripts/validate_skeleton_source_manifest.py`.

## Что Нужно От Design

Create final skeleton-friendly separated source packages for:
- `dark_mage`
- `knight`

Required source contract:
- Neutral front-facing A- or T-pose.
- Transparent RGBA PNGs, no matte, no checkerboard, no baked shadow, no text.
- Empty hands; weapon visuals remain runtime/socket-owned.
- Preserve cartoon2 identity:
  - Dark Mage: hood/robe, violet/dark-magic silhouette.
  - Knight: blue-gold armor, readable knight silhouette.
- Parts must have enough overlap under joints to hide rotation gaps.
- Document pivot points for every part.

Required parts per character:
- `head`
- `torso`
- `pelvis`
- `upper_arm_l`, `lower_arm_l`, `hand_l`
- `upper_arm_r`, `lower_arm_r`, `hand_r`
- `thigh_l`, `shin_l`, `foot_l`
- `thigh_r`, `shin_r`, `foot_r`

Recommended extra parts:
- Dark Mage: `robe_front`, `robe_back`, `cloak_l`, `cloak_r`, `hood_shadow` if
  useful for secondary motion.
- Knight: `shoulder_armor_l`, `shoulder_armor_r`, `shield_socket_marker` if
  useful, but no baked weapon/shield unless explicitly needed as a body part.

## Files / Assets / IDs

Suggested output layout:

```text
docs/design/references/chars_cartoon/skeleton_parts/dark_mage/
  source/
  parts/
  skeleton_source_manifest.json
  qa/
docs/design/references/chars_cartoon/skeleton_parts/knight/
  source/
  parts/
  skeleton_source_manifest.json
  qa/
```

The manifest should follow the new validator contract and reference all parts
relative to the manifest directory.

## Acceptance Criteria

- [x] Dark Mage separated parts package exists and preserves SCRUM-456/SCRUM-473
      style.
- [x] Knight separated parts package exists and preserves SCRUM-456/SCRUM-473
      style.
- [x] Both packages are transparent RGBA and have no matte/background artifacts.
- [x] Every required part exists as PNG and has documented pivot `x/y`.
- [x] Joint overlap is sufficient for Bone2D rotation.
- [x] Both manifests pass:

```bash
python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_skeleton_source_manifest.py \
  docs/design/references/chars_cartoon/skeleton_parts/dark_mage/skeleton_source_manifest.json
python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_skeleton_source_manifest.py \
  docs/design/references/chars_cartoon/skeleton_parts/knight/skeleton_source_manifest.json
```

- [x] Design updates this task with source paths, QA notes, and any limitations.
      SCRUM-474 source blocker is resolved, but Animator runtime rig/timeline
      work remains on USER HOLD until explicit `делай анимацию`.

## Документация

Update `docs/design/content_registry.md` and relevant visual/source-art docs if
new accepted source paths become canonical. Do not change gameplay, balance, UI
layout, or animation runtime wiring in this Design task.

## Result / Design Handoff (2026-06-19)

Designer 2 delivered accepted transparent skeleton-source packages for both
characters:

- Dark Mage manifest:
  `docs/design/references/chars_cartoon/skeleton_parts/dark_mage/skeleton_source_manifest.json`
- Dark Mage source:
  `docs/design/references/chars_cartoon/skeleton_parts/dark_mage/source/dark_mage_skeleton_source_from_runtime.png`
- Dark Mage parts:
  `docs/design/references/chars_cartoon/skeleton_parts/dark_mage/parts/`
- Knight manifest:
  `docs/design/references/chars_cartoon/skeleton_parts/knight/skeleton_source_manifest.json`
- Knight source:
  `docs/design/references/chars_cartoon/skeleton_parts/knight/source/knight_skeleton_source_from_runtime.png`
- Knight parts:
  `docs/design/references/chars_cartoon/skeleton_parts/knight/parts/`
- Package index:
  `docs/design/references/chars_cartoon/skeleton_parts/skeleton_parts_index.json`

Each package contains all required humanoid parts plus optional cloth/armor
secondary-motion parts:

- Dark Mage: 19 PNG parts including `robe_front`, `cloak_back_l`,
  `cloak_back_r`, and `hood_shadow`.
- Knight: 19 PNG parts including `shoulder_armor_l`,
  `shoulder_armor_r`, `cape_l`, and `cape_r`.

Validation / QA:

- `python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_skeleton_source_manifest.py docs/design/references/chars_cartoon/skeleton_parts/dark_mage/skeleton_source_manifest.json`
  PASS.
- `python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_skeleton_source_manifest.py docs/design/references/chars_cartoon/skeleton_parts/knight/skeleton_source_manifest.json`
  PASS.
- Alpha reports:
  `docs/design/references/chars_cartoon/skeleton_parts/dark_mage/qa/dark_mage_alpha_report.json`,
  `docs/design/references/chars_cartoon/skeleton_parts/knight/qa/knight_alpha_report.json`.
- Both alpha reports show `canvas_edge_alpha_clean=true`,
  `transparent_rgba=true`, `no_background_or_matte=true`, and zero part files
  with alpha on the image border.
- Contact sheets:
  `docs/design/references/chars_cartoon/skeleton_parts/dark_mage/qa/dark_mage_parts_contact.png`,
  `docs/design/references/chars_cartoon/skeleton_parts/knight/qa/knight_parts_contact.png`.
- Dark-background source previews:
  `docs/design/references/chars_cartoon/skeleton_parts/dark_mage/qa/dark_mage_source_dark_bg_preview.png`,
  `docs/design/references/chars_cartoon/skeleton_parts/knight/qa/knight_source_dark_bg_preview.png`.

Limitations / handoff notes:

- Parts are derived from the accepted transparent cartoon2 runtime sprites to
  preserve the approved style and avoid a new opaque/matte generated source.
- Hidden back-side limb pixels were not invented; masks deliberately duplicate
  visible pixels with overlap around shoulders, elbows, hips, knees and wrists
  so Animator can block a Skeleton2D/Bone2D rig without rotation gaps.
- Manifest convention: `_l` is screen-left/source-left and `_r` is
  screen-right/source-right in the front-view source. Animator may remap to
  character-local bone naming during rigging.
- No `Skeleton2D`, `Bone2D`, `AnimationPlayer`, SpriteFrames, gameplay,
  balance, UI layout, or runtime wiring was changed in this Design task.

SCRUM-474 source blocker is resolved, but the USER HOLD in SCRUM-474 still
applies after this Design delivery: Animator must not build the real
rig/timelines until an explicit newer user/PM instruction says `делай анимацию`.

## QA-Вердикт (2026-06-19)
Статус: PASSED

Проверено (фактически, не по отчёту):
- AC «оба манифеста проходят валидатор» — прогнал оба, дважды (детерминированно):
  `validate_skeleton_source_manifest.py` → `OK: dark_mage`, `OK: knight`, exit 0.
- AC «все required parts как PNG + документированный pivot x/y» — разобрал оба
  манифеста: 19 частей в каждом, все 15 обязательных (head, torso, pelvis,
  upper/lower_arm + hand ×2, thigh/shin/foot ×2) присутствуют; в блоке `pivots`
  у КАЖДОЙ из 19 частей есть `{x,y}` (0 частей без pivot).
- AC «transparent RGBA, без matte/фона» — НЕЗАВИСИМАЯ проверка PIL по всем 38
  part-PNG (19+19), а не по alpha-report исполнителя: все mode=RGBA, у всех есть
  полностью прозрачные пиксели (min alpha 0), 0 частей с alpha на границе холста
  (чистые края). Alpha-reports исполнителя подтверждены: `transparent_rgba=true`,
  `canvas_edge_alpha_clean=true`, `no_background_or_matte=true` (summary).
- AC «preserve cartoon2 identity / joint overlap» — глазами по dark-bg превью и
  contact-листам: Dark Mage сохраняет капюшон/робу и фиолетовый dark-magic
  силуэт, руки пустые; Knight — сине-золотая броня, читаемый силуэт рыцаря,
  руки пустые; оба front-facing neutral pose. Конечности на parts имеют
  скруглённый overlap у суставов (плечи/локти/бёдра/колени/кисти) — достаточно
  для Bone2D без щелей. Extra-части на месте: mage `robe_front`/`cloak_back_l|r`/
  `hood_shadow`, knight `shoulder_armor_l|r`/`cape_l|r`.
- Package index `skeleton_parts/skeleton_parts_index.json` существует.
- Задача — чисто source-art: 0 строк кода/сцен/runtime wiring (подтверждено
  git diff: затронуты только assets + docs + этот task-файл).

Краевые случаи:
1. Повторный прогон валидаторов (2 раза) — стабильный PASS, не пустышка
   (валидатор проверяет наличие файлов и контракт манифеста).
2. Независимая попиксельная проверка прозрачности/краёв всех 38 PNG вместо
   доверия alpha-report исполнителя — расхождений нет.
3. Сверка обязательного списка частей и pivot-словаря (не bbox/parts-list) —
   полное покрытие, ни одной части без задокументированного pivot.

Регрессия (smoke):
- `animation_smoke_test` — PASSED.
- `runtime_smoke_test` — FAILED, НО причина не в этой задаче: на committed dev
  HEAD (после stash всех несвязанных WIP-правок) тест падает на
  `_test_back_button_frame_safety` — ищет ноду `HeroSelectBackButton` (старый
  hero-select v3), а активный `_show_character_select()` теперь строит
  `_build_character_select_v4()` с кнопкой `HS4BackButton`. Стейл-тест после
  миграции v3→v4, к asset-only SCRUM-475 отношения не имеет. Заведён отдельный
  баг — `docs/tasks/bug_runtime_smoke_hero_select_v4_backbutton_name_task.md`.

Баги: 1 (несвязанный с задачей, на committed dev) —
`bug_runtime_smoke_hero_select_v4_backbutton_name_task.md`.
