# Codex Design Task: VFX Sprite Polish Pass

Статус: done (Design review approved 2026-06-13)
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

## Dispatcher Note (2026-06-13)
Dispatched to Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` after user confirmed no feature freeze / backlog is eligible.

## Result (2026-06-13)

Design pass completed for all 19 active `assets/sprites/effects/*.png` files. The previous flat/neon/primitive-looking VFX set was replaced in-place with restrained painterly D&D/tabletop sprites while preserving every filename, canvas size, RGBA mode and transparent alpha.

Updated files:

- `beam_strip.png`, `slash_arc.png`, `sound_wave.png`, `void_orb.png`, `music_note.png`;
- `impact_flash.png`, `impact_ring.png`, `elite_shockwave_ring.png`, `elite_telegraph_circle.png`, `hazard_zone.png`;
- `poison_pool.png`, `spark_pool.png`, `briar_pool.png`;
- `dust_puff_0.png`, `dust_puff_1.png`, `dust_puff_2.png`;
- `elite_crystal_shard.png`, `elite_poison_lob.png`, `elite_shadow_trail.png`.

Review previews:

- `docs/design/previews/vfx_polish_before_contact.png`;
- `docs/design/previews/vfx_polish_after_contact.png`;
- `docs/design/previews/vfx_polish_before_after_contact.png`;
- `docs/design/previews/vfx_polish_readability_field_meadow.png`;
- `docs/design/previews/vfx_polish_readability_field_marsh.png`.

Validation:

- PNG validation: all 19 effect files are RGBA, preserve existing source dimensions, and have non-empty alpha bounds.
- Godot import: passed with the updated VFX PNGs.
- `res://tests/attack_vfx_smoke_test.gd`: passed.
- `res://tests/runtime_smoke_test.gd`: blocked by unrelated Back-end/runtime regression in noncombat shop node stock persistence: reopening the same shop node generated a different stock list. No VFX asset or Design-path failure was reported before that assertion.

Back-end/QA note:

- No gameplay logic or mapping changes were made in this Design task.
- Full runtime smoke should be rerun after the shop stock persistence regression is fixed by Back-end.


## Design Review / 2026-06-13 — ПРИНЯТО (Claude-Designer)
- SCRUM-181: 19 эффектов перерисованы in-place, имена/размеры/RGBA/alpha сохранены (тех-валидация чистая).
- Стиль: сдержанный painterly D&D, без неона/перебитого блума; примитивные кольца/полосы заменены.
- Читаемость подтверждена на field_meadow и field_marsh — VFX читаются, не перекрывают персонажа.
- Рантайм attack_vfx smoke pass; runtime_smoke блокирован НЕ нашим багом (shop stock persistence, фикс — Back-end).
- Ассеты закоммичены Design-ревью. Интеграционный VFX-smoke после фикса shop — QA/Back-end.
