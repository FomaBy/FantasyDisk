# Animation Full-Frame Pipeline Audit — 2026-06-14

## Scope
Animator audit against the 2026-06-14 `fantasydisk-animation-director` standard:
5+ movement frames, 5+ primary attack frames, two or more behavior/action patterns
per animated entity, and full-frame production sheets for elites/bosses.

This audit is read-only/spec-only. It does not redraw art, change gameplay logic,
or replace the existing cutout rig.

## Duplicate Audit
- `audit_animation_rig_coverage.md` / SCRUM-173 is done and covered cutout rig
  states, pivots, shadows, hit/death, and readability.
- SCRUM-184/185/186/187 are done and covered cutout enemy/player timing and smoke
  assertions, not the new 5+ frame full-frame production requirement.
- `art_unified_character_style_anim_spec_task.md` / SCRUM-298 covers playable
  characters in ART 0.2.0, not enemies/elites/bosses.
- SCRUM-156 and SCRUM-204 delivered or unblocked static boss/mini-elite source
  sprites; they did not deliver full-frame attack/move sheets.
- `design_summon_creatures_animation_glow_task.md` / SCRUM-336 and
  `backend_druid_wolf_summon_animation_integrate_task.md` / SCRUM-279 cover the
  current animated ally SpriteFrames baseline.

Conclusion: no existing active Animator task covers the new global standard end to
end. The current audit creates the missing pipeline breakdown.

## Coverage Matrix
| Family | Current implementation | New standard status | Blocker / next owner |
| --- | --- | --- | --- |
| Playable heroes, 17 classes | Mostly static full art + cutout rig parts; Berserk has legacy walk sheet; weapon poses via cutout | Partial. Cutout readability exists, but most classes do not have 5+ full-frame move + 5+ attack sheets | Covered by SCRUM-298 and per-character Design tasks; Back-end runtime generalization still needed |
| Standard enemies, 11 archetypes | Static source PNG + cutout parts + archetype action poses | Partial. Motion readable, but not 5+ frame move/attack sheets | Design handoff `design_enemy_elite_boss_full_frame_animation_sheets_task.md` |
| Summons/allies | `druid_beast`, `druid_pack_spirit`, `homunculus`, `leadership_echo` have SpriteFrames move(8)+attack(6); deploy fields are stationary effects | Mostly compliant for animated mobile summons. Deploy fields need separate idle/effect policy, not walk | Keep as pass baseline; future summon types must use same manifest format |
| Route elites, 4 | Static source PNG + cutout parts + phase-aware action poses | Non-compliant for production. Elites must use full-frame sheets and 2+ skill attacks | Design full-frame handoff, then Animator SpriteFrames integration |
| Mini-elites, 6 | Static source PNGs from SCRUM-156; not wired as production full-frame sheets | Non-compliant for production. Need full-frame move/attack and behavior-specific attacks | Design full-frame handoff, then Back-end/Animator runtime mapping |
| Bosses, 5 | Static source PNG/cutout fallback; boss mechanics and VFX exist | Non-compliant for production. Bosses need full-frame movement and multiple skill/phase attacks, ideally 7-9 frames per attack | Design full-frame handoff + Back-end state registry + Animator integration |

## Already-Compliant Manifest
Pass-only manifest:
`build/qa/animation_full_frame_pipeline_coverage/animation_manifest.json`

It intentionally lists only currently compliant animated ally SpriteFrames so the
validator can be a hard gate. Non-compliant entity families are tracked in this
report and child tasks instead of being hidden in a passing manifest.

## Prioritized Gaps
P0 — Full-frame boss and elite sheets are absent. This is the highest risk because
the new directive explicitly forbids production cutout animation for elites/bosses.

P0 — Runtime lacks a general full-frame state registry for enemies/elites/bosses.
`AllyMinion` handles summons, and cutout rig handles pose readability, but bosses
and enemies need state-driven SpriteFrames without changing mechanics.

P1 — Standard enemies need 5+ movement/attack frame sheets. Current cutout motion is
usable as fallback, but it is not the new animation baseline.

P1 — Playable classes are partially covered by SCRUM-298, but Animator should not
start integration until Design sheets and Back-end registry/fallback behavior are
ready.

P2 — Deploy/totem visuals need an explicit exception policy: stationary entities
should use 5+ idle/pulse/effect frames plus attack/activation frames rather than a
walk loop.

## Child Tasks / Handoffs
- Design: `docs/tasks/design_enemy_elite_boss_full_frame_animation_sheets_task.md`
  / SCRUM-352.
- Back-end: `docs/tasks/backend_full_frame_animation_state_registry_task.md`
  / SCRUM-351.
- Existing Design anchor for heroes: `docs/tasks/art_unified_character_style_anim_spec_task.md`
  / SCRUM-298.

## Animator Decision
Do not implement motion fixes on top of the old cutout system for this new standard.
Cutout remains fallback/readability coverage, but production compliance requires
new full-frame sheets and runtime state support first. Animator resumes
implementation after Design and Back-end unblock the sheet/state pipeline.
