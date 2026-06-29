# Back-end Handoff: Secret Ascension Boss Runtime Art

Status: handoff note
Parent Jira: SCRUM-539
Owner: unassigned
Locked paths for future runtime work: scripts/progression_data*.gd, scripts/boss.gd, scripts/combat_director.gd, scenes/*Secret*Boss*.tscn, tests/secret_encounter_test.gd, tests/runtime_smoke_boss_elite_test.gd

## Context

SCRUM-539 delivered the Design source pack for the optional final ascension
boss. Use this only after the Animator handoff provides final
animation/SpriteFrames or explicitly approves a static-plus-VFX interim.

## Runtime Candidate Assets

- Static boss candidate: `assets/sprites/bosses/secret_ascension_boss.png`
- Telegraph candidates:
  - `assets/sprites/effects/secret_ascension_boss_ring_telegraph.png`
  - `assets/sprites/effects/secret_ascension_boss_cone_telegraph.png`
  - `assets/sprites/effects/secret_ascension_boss_beam_telegraph.png`
  - `assets/sprites/effects/secret_ascension_boss_rupture_telegraph.png`
- Design report: `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_source_pack_report.json`

## Visual / Gameplay Notes

- Recommended ID: `secret_ascension_boss`.
- This should remain an optional endgame wall after final ascension conditions,
  not part of the normal boss pool.
- Keep boss visually larger than existing bosses, while avoiding HP bar/camera
  overlap.
- Static source bbox is `[180, 42, 843, 984]` on `1024x1024`, pivot `(512, 960)`.
- Telegraph colors: violet core with aged-gold edge and dark smoke interior.
  Warning shapes should remain fair/readable: ring, cone sector, beam lane, and
  rupture/fissure zone.
- Use telegraphs as warning overlays before damage; avoid instant invisible hits.

## Acceptance Notes For Future Task

- Secret boss is not randomly selected by normal route boss nodes.
- Unlock condition and reward path respect existing secret-boss meta-state.
- Boss fight can use the delivered telegraph PNGs without fallback circles.
- Runtime smoke and secret encounter tests pass.
