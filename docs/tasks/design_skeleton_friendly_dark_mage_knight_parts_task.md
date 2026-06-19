# Задача Для Design-Агента: Skeleton-friendly parts для Dark Mage и Knight

Статус: in_progress
Приоритет: high
Роль: Design
Исполнитель: Codex (fantasydisk-asset-generator)
Версия: 0.1.6
Создано: 2026-06-19
Автор: Animator handoff from SCRUM-474
Jira: TBD by sync
Связано: SCRUM-474, SCRUM-456, SCRUM-473

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

- [ ] Dark Mage separated parts package exists and preserves SCRUM-456/SCRUM-473
      style.
- [ ] Knight separated parts package exists and preserves SCRUM-456/SCRUM-473
      style.
- [ ] Both packages are transparent RGBA and have no matte/background artifacts.
- [ ] Every required part exists as PNG and has documented pivot `x/y`.
- [ ] Joint overlap is sufficient for Bone2D rotation.
- [ ] Both manifests pass:

```bash
python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_skeleton_source_manifest.py \
  docs/design/references/chars_cartoon/skeleton_parts/dark_mage/skeleton_source_manifest.json
python3 ~/.codex/skills/fantasydisk-animation-director/scripts/validate_skeleton_source_manifest.py \
  docs/design/references/chars_cartoon/skeleton_parts/knight/skeleton_source_manifest.json
```

- [ ] Design updates this task with source paths, QA notes, and any limitations,
      then hands SCRUM-474 back to Animator.

## Документация

Update `docs/design/content_registry.md` and relevant visual/source-art docs if
new accepted source paths become canonical. Do not change gameplay, balance, UI
layout, or animation runtime wiring in this Design task.
