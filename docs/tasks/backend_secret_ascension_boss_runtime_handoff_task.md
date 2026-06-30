# Back-end Handoff: Secret Ascension Boss Runtime Art

Status: handoff note
Статус: done
Parent Jira: SCRUM-539
Owner: Backend / Claude
Thread/Worker: claude-backend
Locked paths for future runtime work: scripts/progression_data*.gd, scripts/boss.gd, scripts/combat_director.gd, scenes/*Secret*Boss*.tscn, tests/secret_encounter_test.gd, tests/runtime_smoke_boss_elite_test.gd

## Результат (SCRUM-702, commit 27c4dcd3)

Подключена доставленная full-frame анимация секретного босса
(`secret_ascension_boss_spriteframes.tres`, 16 состояний) вместо плейсхолдера
disk_devourer — через node-meta `full_frame_spriteframes_path/scale(0.86)/position(0,-98)/
source_faces_left` на `scenes/BossSecretAscension.tscn` (meta-fallback в
`enemy.gd::configure_entity_visual`; секретный босс намеренно вне стандартного registry).
Регресс-гейт `_test_secret_boss_uses_full_frame` в `tests/runtime_smoke_boss_elite_test.gd`.
Гейты зелёные: runtime_smoke_boss_elite, secret_encounter_test, secret_boss_animation_pack_smoke,
runtime_smoke_test. ОСТАЁТСЯ (нужна визуальная сверка, вне инкремента): наземные
телеграф-PNG (ring/cone/beam/rupture) — направленная ротация/выравнивание под геометрию
урона (fairness-critical); статик-фолбэк .tscn (не показывается при живом full-frame).

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
