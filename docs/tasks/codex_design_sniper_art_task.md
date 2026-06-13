# Codex Design Task: Sniper Character And Weapon Art

Статус: review
Версия: 0.1.4
Создано: 2026-06-13
Роль: Design
Jira: SCRUM-167
Источник: `docs/tasks/backend_add_character_sniper_task.md`

## Context

Back-end добавил playable class `sniper` как 13-й класс FantasyDisk. Сейчас он использует documented fallback textures, чтобы не блокировать gameplay/testing:

- Character fallback: `assets/sprites/characters/ranger.png`
- `sniper_deadeye_rifle`: `assets/sprites/weapons/moon_crossbow.png`
- `sniper_spotter_scope`: `assets/sprites/weapons/soldier_rifle.png`
- `sniper_shatter_rounds`: `assets/sprites/weapons/storm_longbow.png`

Нужно сделать canonical Design pass без изменения Back-end mechanics.

## Required Assets

Создать и импортировать Godot `.import`:

- `assets/sprites/characters/sniper.png` — 512x512 transparent full-art character.
- `assets/sprites/weapons/sniper_deadeye_rifle.png` — 256x256 transparent weapon.
- `assets/sprites/weapons/sniper_spotter_scope.png` — 256x256 transparent weapon/focus.
- `assets/sprites/weapons/sniper_shatter_rounds.png` — 256x256 transparent weapon/ammo focus.

## Art Direction

- Readable top-down arena character silhouette.
- Dark fantasy/tabletop style consistent with current starter/new-class roster.
- Sniper should read as precise ranged archetype, not generic Ranger clone.
- Character sprite should be unarmed or minimally weapon-neutral so all 3 weapons can attach through `WeaponSocket`.
- Keep legs/torso/arms readable for future cutout slicing.
- Weapon PNGs should be visually distinct:
  - Deadeye rifle: long precision firearm/crossbow-rifle silhouette.
  - Spotter scope: ritual scope/marker focus for kill-zone targeting.
  - Shatter rounds: heavy cartridge/quiver/fragmenting shot identity.

## References

Existing style references:

- `assets/sprites/characters/ranger.png`
- `assets/sprites/characters/soldier.png`
- `assets/sprites/characters/assassin.png`
- `assets/sprites/weapons/moon_crossbow.png`
- `assets/sprites/weapons/soldier_rifle.png`
- `assets/sprites/weapons/storm_longbow.png`

## Acceptance

- All 4 canonical PNGs exist at the paths above and import cleanly in Godot.
- No watermark/text baked into sprites.
- Transparent background, clean alpha, no square placeholder background.
- Character remains suitable for cutout rig handoff.
- Back-end can swap fallback paths to canonical paths without gameplay changes.

## Dispatch

- 2026-06-13: handed off from Back-end thread after SCRUM-167 Sniper gameplay implementation.

## Result

2026-06-13 — Design/Codex visual kit completed and ready for review.

Generated final D&D-canon FantasyDisk PNG assets:

- `assets/sprites/characters/sniper.png` — 512x512 RGBA, transparent background;
- `assets/sprites/weapons/sniper_deadeye_rifle.png` — 256x256 RGBA, transparent background;
- `assets/sprites/weapons/sniper_spotter_scope.png` — 256x256 RGBA, transparent background;
- `assets/sprites/weapons/sniper_shatter_rounds.png` — 256x256 RGBA, transparent background.

Preview / QA sheet:

- `docs/design/previews/sniper_art_contact.png`.

Visual notes:

- Sniper is a dark fantasy/tabletop deadeye marksman with duster coat, brass details, and precise ranged-class silhouette, distinct from Ranger and Soldier.
- Deadeye rifle reads as a long precision weapon, slimmer than the Soldier arquebus.
- Spotter scope reads as a marking/kill-zone focus, not a weapon clone.
- Shatter rounds read as fragmenting ammunition, not a bow or rifle.

Validation:

- PNG dimensions and alpha validated by script.
- Godot import generated `.import` files for all Sniper PNGs.
- Import command hit an unrelated current-worktree parse error in `scripts/player.gd:705` after asset reimport completed; no Sniper asset failure observed.

Handoff:

- Back-end can replace fallback references with the canonical PNG paths above if not already auto-resolved by ID.
- Animator can now proceed with `docs/tasks/animation_sniper_rig_motion_task.md`; Design does not perform rig/cutout/motion work.
