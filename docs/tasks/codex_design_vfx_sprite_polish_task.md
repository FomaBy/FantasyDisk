# Codex Design Task: VFX Sprite Polish Pass

Статус: new
Версия: 0.1.5
Создано: 2026-06-13
Роль: Design / Codex image generation
Jira: SCRUM-181
Parent audit: `docs/tasks/audit_sprites_visual_consistency.md` / SCRUM-177

## Goal

Polish `assets/sprites/effects/` so attack, hazard, telegraph, and pool sprites match the D&D/tabletop painterly canon of the current characters, monsters, and weapons.

## Scope

Review and redraw as needed:

- `beam_strip.png`
- `briar_pool.png`
- `dust_puff_0.png`, `dust_puff_1.png`, `dust_puff_2.png`
- `elite_crystal_shard.png`
- `elite_poison_lob.png`
- `elite_shadow_trail.png`
- `elite_shockwave_ring.png`
- `elite_telegraph_circle.png`
- `hazard_zone.png`
- `impact_flash.png`
- `impact_ring.png`
- `music_note.png`
- `poison_pool.png`
- `slash_arc.png`
- `sound_wave.png`
- `spark_pool.png`
- `void_orb.png`

## Art Direction

- Keep effects restrained, readable, and performant: no acid neon, no overbright bloom baked into every pixel.
- Replace primitive-looking rings/strips with painterly fantasy energy, dust, poison, sparks, and arcane shapes.
- Preserve transparent background and existing filenames unless Back-end requests otherwise.
- Validate over `field_meadow.png` and `field_marsh.png`.

## Acceptance

- Before/after contact sheet in `docs/design/previews/`.
- PNG size/mode/alpha validated.
- Runtime/attack VFX smoke requested from Back-end/QA after integration.
