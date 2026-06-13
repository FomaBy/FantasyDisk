# Codex Design Task: Priest Character And Weapon Art

Статус: review
Версия: 0.1.4
Создано: 2026-06-13
Роль: Design
Jira: SCRUM-165
Источник: `docs/tasks/backend_add_character_priest_task.md`

## Context

Back-end добавил playable class `priest` как 14-й класс FantasyDisk. Сейчас он использует documented fallback textures, чтобы не блокировать gameplay/testing:

- Character fallback: `assets/sprites/characters/doctor.png`
- `priest_reliquary`: `assets/sprites/weapons/restore_potion.png`
- `priest_censer`: `assets/sprites/weapons/holy_flail.png`
- `priest_chime`: `assets/sprites/weapons/sound_amp.png`

Нужно сделать canonical Design pass без изменения Back-end mechanics.

## Required Assets

Создать и импортировать Godot `.import`:

- `assets/sprites/characters/priest.png` — 512x512 transparent full-art character.
- `assets/sprites/weapons/priest_reliquary.png` — 256x256 transparent weapon/focus.
- `assets/sprites/weapons/priest_censer.png` — 256x256 transparent weapon.
- `assets/sprites/weapons/priest_chime.png` — 256x256 transparent weapon/focus.

## Art Direction

- D&D/tabletop dark fantasy style consistent with current FantasyDisk roster.
- Priest should read as healer/support holy caster, not Doctor clone.
- Character sprite should be neutral/unarmed enough for all 3 weapons to attach through `WeaponSocket`.
- Keep legs/torso/arms readable for future cutout slicing.
- Weapon PNGs should be visually distinct:
  - Reliquary: holy icon/relic focus for sanctify marks.
  - Censer: swinging incense/ward object for protective pulses.
  - Chime: bell/chime focus for prayer chains.

## References

Existing style references:

- `assets/sprites/characters/doctor.png`
- `assets/sprites/characters/dark_mage.png`
- `assets/sprites/characters/druid.png`
- `assets/sprites/weapons/restore_potion.png`
- `assets/sprites/weapons/holy_flail.png`
- `assets/sprites/weapons/sound_amp.png`

## Acceptance

- All 4 canonical PNGs exist at the paths above and import cleanly in Godot.
- No watermark/text baked into sprites.
- Transparent background, clean alpha, no square placeholder background.
- Character remains suitable for cutout rig handoff.
- Back-end can swap fallback paths to canonical paths without gameplay changes.

## Dispatch

- 2026-06-13: handed off from Back-end thread after SCRUM-165 Priest gameplay implementation.

## Result

2026-06-13 — Design/Codex visual kit completed and ready for review.

Generated final D&D-canon FantasyDisk PNG assets:

- `assets/sprites/characters/priest.png` — 512x512 RGBA, transparent background;
- `assets/sprites/weapons/priest_reliquary.png` — 256x256 RGBA, transparent background;
- `assets/sprites/weapons/priest_censer.png` — 256x256 RGBA, transparent background;
- `assets/sprites/weapons/priest_chime.png` — 256x256 RGBA, transparent background.

Preview / QA sheet:

- `docs/design/previews/priest_art_contact.png`.

Visual notes:

- Priest is a holy healer/support caster with ivory/deep-teal vestments, gold relic details, and readable separated legs, distinct from Doctor.
- Reliquary reads as a sanctify/relic focus, not a potion.
- Censer reads as ward/protection incense item, not a flail.
- Chime reads as prayer-chain support focus, not a music amplifier.

Validation:

- PNG dimensions and alpha validated by script.
- Godot import completed successfully and generated `.import` files.

Handoff:

- Back-end can replace fallback references with the canonical PNG paths above if not already auto-resolved by ID.
- Animator can now proceed with `docs/tasks/animation_priest_rig_motion_task.md`; Design does not perform rig/cutout/motion work.
