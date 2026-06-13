# Animation Rig Coverage Audit — June 2026

Date: 2026-06-13  
Version target: 0.1.5  
Source task: `docs/tasks/audit_animation_rig_coverage.md` / Jira SCRUM-173  
Scope: Animator read-only audit. No runtime motion fixes were made.

## Executive Summary

FantasyDisk now has a solid shared cutout rig architecture: playable classes, standard enemies, elites, and the first two bosses use `scripts/cutout_rig_2d.gd` + `scripts/sliced_rig_manifest.gd`, hidden `HeroFull` source art, sliced limbs, `GroundShadow`, and `WeaponSocketMount`. Recent Animator passes added distinct profiles and weapon-action pose hooks for the newest classes.

The remaining risk is not "no animation"; it is uneven depth. Base idle/walk/action/hit/death mechanics exist broadly, but several older playable classes still rely on generic action poses, some enemy archetypes lack per-archetype smoke assertions, hit/death coverage is mostly generic, and newer boss/mini-elite art placeholders block animation-ready cutout quality.

## Coverage Matrix — Playable Classes

Legend: `Full` = bespoke profile + relevant pose coverage in tests; `Base` = shared rig state exists, but no class/weapon-specific pose coverage; `Partial` = some custom coverage only.

| Class | Cutout parts | Idle | Walk | Attack / weapon-action poses | Cast | Hit | Death | Pivot / shadow / socket | Motion quality | Audit result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `berserk` | Full humanoid | Full | Full | Full for sword/axe/hammer variants | Base | Base | Base | Full | Good heavy melee | Good; add hit/death assertions later |
| `dark_mage` | Full humanoid | Full | Full | Base generic cast for 3 weapons | Base | Base | Base | Base | Good caster walk | Needs weapon-specific cast silhouettes |
| `guitarist` | Full humanoid | Full | Full | Base generic shoot/cast for 3 weapons | Base | Base | Base | Base | Good upbeat walk | Needs distinct strum/pulse/amp poses |
| `assassin` | Full humanoid | Full | Full | Base generic action coverage | Base | Base | Base | Base | Distinct quick walk | Needs weapon-specific attack hooks |
| `ranger` | Full humanoid | Full | Full | Base generic action coverage | Base | Base | Base | Base | Distinct ranged walk | Needs bow/trap/shot silhouettes |
| `doctor` | Full humanoid | Full | Full | Base generic action coverage | Base | Base | Base | Base | Distinct support walk | Needs support/tool action hooks |
| `chemist` | Full humanoid | Full | Full | Base generic action coverage | Base | Base | Base | Base | Distinct volatile walk | Needs flask/trap/beam hooks |
| `knight` | Full humanoid | Full | Full | Base generic action coverage | Base | Base | Base | Base | Distinct heavy walk | Needs shield/charge/guard hooks |
| `druid` | Full humanoid | Full | Full | Base generic action coverage | Base | Base | Base | Base | Distinct nature-caster walk | Needs summon/totem/channel hooks |
| `soldier` | Full humanoid | Full | Full | Full: rifle/grenade/bayonet | Base | Base | Base | Full | Disciplined, grounded | Good |
| `thief` | Full humanoid | Full | Full | Full: coin/cloak/smoke | Base | Base | Base | Full | Light/cautious | Good |
| `elementalist` | Full humanoid | Full | Full | Full: orb/prism/meteor | Base | Base | Base | Full | Distinct caster | Good |
| `sniper` | Full humanoid | Full | Full | Full: rifle/scope/shatter | Base | Base | Base | Full | Controlled ranged | Good |
| `priest` | Full humanoid | Full | Full | Full: reliquary/censer/chime | Base | Base | Base | Full | Support caster | Good |
| `biologist` | Full humanoid | Full | Full | Full: spore/sample/symbiote | Base | Base | Base | Full | Scientific/support | Good |
| `robot` | Full humanoid | Full | Full | Full aliases for magnetic/press/reactor family | Base | Base | Base | Full | Heavy construct | Good; naming drift should stay covered |
| `engineer` | Full humanoid | Full | Full | Full: wrench/drone/mines | Base | Base | Base | Full | Practical tinkerer | Good |

## Coverage Matrix — Enemies, Elites, Bosses

| Entity / archetype | Cutout parts | Idle | Walk / movement | Attack / cast / shoot | Hit | Death | Pivot / shadow / socket | Motion quality | Audit result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `rift_cutter` / basic melee | Full humanoid | Full | Full tested | Full tested claw swing | Base | Full ghost tested | Full | Good baseline | Good |
| `ash_marksman` / shooter | Partial: torso/legs/weapon | Full | Base | Shoot recoil tested indirectly | Base | Base | Weapon part present | Readable, less limb nuance | Add archetype-specific assertions |
| `spark_runner` / runner | Full with tail | Full | Base | Base melee/explode prep | Base | Base | Full | Likely good fast profile | Needs explicit runner smoke |
| `stone_bruiser` / bruiser | Full humanoid | Full | Base | Base heavy attack | Base | Base | Full | Heavy profile available | Needs explicit bruiser smoke |
| `bone_caller` / summoner | Robed partial, no legs | Full | Base floating/robed | Base cast | Base | Base | Full | Robed movement OK | Needs cast silhouette assertion |
| `void_mage` / mage | Robed partial, no legs | Full | Base floating/robed | Base cast | Base | Base | Full | Robed movement OK | Needs cast silhouette assertion |
| `venom_spitter` / spitter | Partial legs/torso, no arms | Full | Base | Base shoot/body squash | Base | Base | Full | Attack readability depends on body squash | Needs spitter-specific pose |
| `rift_shieldbearer` / shield | Partial with shield | Full | Base | Base attack/shield motion | Base | Base | Full | Shield part can read well | Needs guard/brace pose assertion |
| `small_biter` / biter | Partial, missing one leg | Full | Base | Base bite/body attack | Base | Base | Full | Asymmetry may be okay but unproven | Needs biter-specific smoke |
| `bone_shaman` | Robed partial, no legs | Full | Base | Base cast | Base | Base | Full | Robed movement OK | Needs cast/ritual pose |
| `winged_spark` | Full with wings | Full | Full wing flap tested | Base | Base | Base | Full | Good flying profile | Good, add attack assertion later |
| `iron_bastion` | Partial shield/fist | Full | Base | Full elite phase variants | Base | Base | Full | Strong slam/guard identity | Good |
| `night_stalker` | Full humanoid | Full | Base | Full elite phase variants | Base | Base | Full | Strong crouch/lunge identity | Good |
| `plague_prophet` | Robed partial | Full | Base | Full elite phase variants | Base | Base | Full | Strong caster identity | Good |
| `shard_marshal` | Full humanoid | Full | Base | Full elite phase variants | Base | Base | Full | Strong command/fan identity | Good |
| `rift_warden` | Partial arms/vortex | Full | Base boss drift | Cast/vortex tested | Base | Base | Full | Good boss caster base | Good, death coverage missing |
| `disk_devourer` | Torso only | Full | Base blob/colossus | Base attack/body squash | Base | Base | Shadow only | Limited by single-part silhouette | Needs boss-specific follow-up |
| `bone_archon` | Placeholder/tinted existing boss | Base | Base | Base via inherited boss art | Base | Base | Placeholder | Blocked by final art | Design handoff needed |
| `brood_mother` | Placeholder/tinted existing boss | Base | Base | Base via inherited boss art | Base | Base | Placeholder | Blocked by final art | Design handoff needed |
| `ashen_colossus` | Placeholder/tinted existing boss | Base | Base | Base via inherited boss art | Base | Base | Placeholder | Blocked by final art | Design handoff needed |
| Mini-elites, 6 kinds | Placeholder/tinted existing elites | Base | Base | Base via inherited elite behavior | Base | Base | Placeholder | Readability blocked by final art | Design handoff needed |

## Findings

### P1 — Older playable classes lack unique weapon-action silhouettes

The newest nine class passes plus Berserk have bespoke pose hooks. Older classes (`dark_mage`, `guitarist`, `assassin`, `ranger`, `doctor`, `chemist`, `knight`, `druid`) have distinct walk profiles but their weapon actions mostly fall through to generic `attack`, `shoot`, or `cast`. This makes some 51-weapon roster entries visually samey even when gameplay patterns differ.

Follow-up: `docs/tasks/animation_legacy_player_weapon_pose_hooks_task.md`.

### P1 — Enemy archetype rig assertions cover samples, not the full roster

The animation smoke test verifies baseline melee, flying wings, elite phases, a boss rig, and death ghost. It does not assert per-archetype attack readability for runner, bruiser, summoner, mage, spitter, shieldbearer, biter, or bone shaman. Several of these have partial rigs with missing arms/legs by design, so they need tailored body/torso/secondary-part poses instead of generic limb assumptions.

Follow-up: `docs/tasks/animation_enemy_archetype_motion_coverage_task.md`.

### P1 — Hit and death states are generic and under-tested

`play_hit()` exists as a separate short feedback state and `_apply_hit_feedback()` applies tint/shake. `play_death()` and `spawn_death_ghost()` exist. Current smoke coverage directly validates enemy death ghost, but player death, boss death, elite death, and hit reaction readability are not covered as a matrix. This is a regression risk because hit/death are global feedback states.

Follow-up: `docs/tasks/animation_hit_death_state_coverage_task.md`.

### P1 — New bosses and mini-elites are art-blocked for animation quality

`bone_archon`, `brood_mother`, `ashen_colossus`, and the six mini-elite kinds are documented as placeholder/tinted existing boss/elite art until SCRUM-156. Animator should not redraw these. Final animation quality requires front-facing animation-ready source sprites with clear separable limbs, secondary parts, and action silhouettes.

Design handoff: `docs/tasks/design_animation_ready_boss_mini_elite_parts_handoff_task.md`.

### P2 — Timing/VFX sync is mostly pose-level, not event-level

Player `ClassWeapon` currently maps most non-caster class weapon modes to `shoot`, with weapon id passed as action variant. This supports a readable start pose, but multi-pulse, delayed, or deploy-style weapons do not have a formal event timeline for secondary pose beats. Elite attack phases are better because Backend exposes windup/strike/recover variants.

Follow-up: `docs/tasks/animation_weapon_timing_vfx_sync_task.md`.

### P2 — Profile duplication is acceptable now, but needs guardrails

The newest class profiles are distinct and tested for walk readability. Older profiles are also distinct enough numerically, but there is no table-driven guard against future copy/paste profiles. This should be folded into the legacy-player follow-up rather than split out as a separate task.

## Verification Status

- Read-only audit: no animation code, manifest, scenes, or assets changed.
- Existing evidence reviewed: `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd`, `tests/animation_smoke_test.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/progression_data.gd`, `docs/design/current_game_state.md`, `docs/design/content_registry.md`.
- No fresh runtime smoke was run for this audit because it is spec-only and the checkout already has an unrelated runtime parse blocker tracked in `docs/tasks/backend_ui_screens_shop_style_parse_errors_task.md`.

## Child Task Index

- `docs/tasks/animation_legacy_player_weapon_pose_hooks_task.md`
- `docs/tasks/animation_enemy_archetype_motion_coverage_task.md`
- `docs/tasks/animation_hit_death_state_coverage_task.md`
- `docs/tasks/animation_weapon_timing_vfx_sync_task.md`
- `docs/tasks/design_animation_ready_boss_mini_elite_parts_handoff_task.md`
