# SCRUM-861 Final Class Rebalance QA Report

Date: 2026-07-04

Branch/worktree: `codex/scrum861-qa-review` /
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum861-qa-review`

Verified dev commit: `f1cac0d8 feat(SCRUM-860): add assassin kill momentum`.

## Verdict

Status: PASSED.

The final post-wave QA gate covers all 17 classes and all 51 weapons. The
SCRUM-856 report remains the before/baseline identity audit. SCRUM-857..860 then
implemented mechanic-first slices for projectile/chain/pierce, tank/melee
counterplay, summon/deploy/turret ownership, and kill-growth/sustain separation.
This report is the after/final QA closeout for that wave.

Automated gates confirm:

- 51/51 weapon identity signatures are unique.
- 17/17 classes and 51/51 weapons load with valid scenes and registered attack
  modes.
- All 51 class+weapon pairs pass solo, combined, and 5/10/20 crowd-clear gates.
- Global survivability remains finite; no profile reaches immortality.
- Focused SCRUM-857, SCRUM-858, SCRUM-859, and SCRUM-860 identity tests pass.

Residual risk: deterministic harnesses and focused tests cannot replace manual
moment-to-moment playfeel review. Any future feel issue should be filed as a
new scoped tuning or UX task, not as a blocker for this QA gate.

## Before/After Class Trio Matrix

| Class | Before SCRUM-856 baseline risk | After SCRUM-857..860 mechanic proof | Final gate |
| --- | --- | --- | --- |
| `berserk` | Sword/axe/hammer CCT rows were very similar; hammer was cap-pinned. | Melee identity remains split by narrow commit, broad cleave, and close slam/stagger rules; covered by `melee_unique_mechanics_test.gd` and `runtime_smoke_weapon_mechanics_test.gd`. | PASS, best crowd weapon `sword`. |
| `soldier` | Grenade was the delayed-AoE exemplar, but rifle/bayonet needed stronger non-damage identity. | Rifle suppression, grenade fuse-only delayed damage with falloff, and bayonet brace/corridor are distinct; covered by `projectile_chain_pierce_identity_test.gd`. | PASS, best crowd weapon `soldier_grenade`; worst class gate dev 6.6%. |
| `thief` | Ricochet, backstab, and smoke risked becoming generic chain/delayed AoE variants. | Coin ricochet uses nearby retargeting and economy hook, shadow cloak keeps non-teleport backstab fantasy, smoke bomb remains utility/control delayed AoE; chain/split separation is covered by SCRUM-857 tests. | PASS, best crowd weapon `thief_smoke_bomb`; worst class gate dev 8.4%. |
| `elementalist` | Prism and meteor were both cap-pinned and could blur with grenade-style delayed hits. | Orbit, prism rift/cross beams, and long-cast meteor with shard payoff are documented and tested as distinct delayed/geometry patterns. | PASS, best crowd weapon `elementalist_meteor_core`; worst class gate dev 6.6%. |
| `sniper` | Spotter and shatter needed target-rule separation while preserving solo role. | Lockshot/kill-zone/split-round family keeps precision targeting, marked zone, and deterministic fan split with pierce, not ricochet. | PASS, best crowd weapon `sniper_shatter_rounds`; worst class gate dev 10.8%. |
| `priest` | Holy sustain channels risked blending into generic chain/heal. | Reliquary mark, censer ward pulse, and prayer chain sustain arc are split; Priest sustain remains capped and mortal under pressure. | PASS, best crowd weapon `priest_reliquary`; worst class gate dev 9.8%. |
| `biologist` | Symbiote was cap-pinned and needed network identity beyond generic AoE. | Spore bloom, sample dart plus delayed analysis, and symbiote web/link are distinct post-wave modes in docs and smoke coverage. | PASS, best crowd weapon `biologist_spore_lens`; worst class gate dev 8.4%. |
| `robot` | Tank-control identity was strong, but anchor/reactor were cap-pinned. | Magnetic anchor pull, hydraulic compression line, and directional reactor vents remain separate control patterns; survivability gates stay finite. | PASS, best crowd weapon `robot_magnetic_anchor`; worst class gate dev 9.7%. |
| `engineer` | Sentry over-hit, mines were cap-pinned, and deploy ownership was unclear. | SCRUM-859 split deploy roles into `turret_dps`, `repair_chain`, and `mine_grid`; sentries have capped target memory/distribution and splash. | PASS, best crowd weapon `engineer_pressure_mines`; worst class gate dev 8.5%. |
| `dark_mage` | Book/skull/wand could collapse into generic magic hits. | Dark book AoE, cursed skull homing curse/decay, and dark wand pierce decay are distinct from grenade/ricochet/split families. | PASS, best crowd weapon `dark_book`; worst class gate dev 6.6%. |
| `guitarist` | Amp and bass were near review edge and could read as generic pulses. | Electric wave, rhythmic bass pulse, and `stage_pulse` deploy amp are distinct control/deploy loops after SCRUM-859 caps. | PASS, best crowd weapon `electric_guitar`; worst class gate dev 9.8%. |
| `assassin` | Venom wire was hard-clamped and all CCT rows were similar. | Chakrams keep boomerang/return path, daggers keep close crit flurry, and daggers/venom wire gain capped non-healing `shadow_momentum` tempo. | PASS, best crowd weapon `venom_wire`; worst class gate dev 12.9%. |
| `ranger` | Beam/fan/trap needed clearer live difference. | Crossbow remains charged pierce, longbow charged fan, and hunter trap deploy/knockback zone; no conversion into generic projectile spam. | PASS, best crowd weapon `hunter_trap`; worst class gate dev 9.7%. |
| `doctor` | Restore/plague/saw sustain could become generic vampirism, and restore had worst CCT. | Doctor external regen/vamp/lifesteal is blocked; restore/plague/bone saw are weapon-only drain/sustain lanes with softcaps. | PASS, worst CCT remains `restore_potion/20` +22%, inside the +/-30% gate. |
| `chemist` | Blast/acid/homunculus could blur with other AoE/summon families. | Blast reagent burst, acid persistent pool, and homunculus `tank_control` summon/deploy role remain separate; summon output is capped. | PASS, best crowd weapon `blast_powder`; worst class gate dev 6.5%. |
| `knight` | Shield/flail were cap-pinned and needed real counter proof. | SCRUM-858 added incoming-based block/counter with distinct spear, tower shield, and holy flail geometry/caps; shield retaliation is covered by focused tests. | PASS, best crowd weapon `holy_flail`; worst class gate dev 13.0%. |
| `druid` | Summon amulet and raven totem were near review edge and needed ownership rules. | SCRUM-859 split `pack_damage`, briar zone, and `support_totem`; summon/deploy caps and crowd floor are green. | PASS, best crowd weapon `briar_staff`; worst class gate dev 6.6%. |

## Final Test Matrix

All commands ran through `tools/godot_gate.py --headless --path . --script ...`.

| Gate | Result | Evidence |
| --- | --- | --- |
| `tests/weapon_identity_diversity_test.gd` | PASS | 51 weapons, 51 unique signatures, no duplicates. |
| `tests/projectile_chain_pierce_identity_test.gd` | PASS | SCRUM-857 grenade/meteor/ricochet/split/prayer/dark-pierce rules. |
| `tests/melee_unique_mechanics_test.gd` | PASS | SCRUM-858 Knight counter, melee execute/cleave/stagger checks. |
| `tests/summoner_strengthening_test.gd` | PASS | SCRUM-859 summon/deploy strengthening contracts. |
| `tests/summon_weapon_crowd_floor_test.gd` | PASS | Druid, Chemist, and Engineer summon/deploy floor gates. |
| `tests/kill_scaling_identity_test.gd` | PASS | SCRUM-860 Assassin `shadow_momentum` cap/expiry/no-heal/exclusions. |
| `tests/doctor_drain_softcap_test.gd` | PASS | Doctor weapon-drain softcap and mortality under dense pressure. |
| `tests/priest_sustain_softcap_test.gd` | PASS | Priest sustain cap and mortality under dense pressure. |
| `tests/runtime_smoke_weapon_mechanics_test.gd` | PASS | Umbrella weapon mechanics smoke suite. |
| `tests/weapon_integrity_test.gd` | PASS | 17 classes, 51 weapons. |
| `tests/weapon_scene_integrity_test.gd` | PASS | 51 scenes resolve; 35/35 attack modes registered. |
| `tests/global_survivability_balance_smoke_test.gd` | PASS | 16 rows, finite TTD, mitigation below 98%, no immortality. |
| `tests/survivability_scenario_test.gd` | PASS | Formula anchors, monotonicity, layers, and absorb checks. |
| `tests/global_damage_balance_smoke_test.gd` | PASS | 51 pairs, combined +/-25%, solo +/-20%, CCT +/-30%. |
| `tests/runtime_smoke_test.gd` | PASS | Full runtime smoke. |
| `tools/balance_harness.gd` | PASS | `build/balance_report.md`, `build/balance_final_audit_0_1_5.md`. |
| `tools/survivability_harness.gd` | PASS | `build/survivability_report.md`, 16 survivability rows. |

## Final Numeric Snapshot

- Pairs checked: 51.
- Worst solo deviation: `-0.1%` on `druid/summon_amulet`.
- Worst crowd-clear deviation: `+22.0%` on `doctor/restore_potion`, 20 targets.
- All 17 classes have at least one viable crowd-clear weapon.
- Global survivability smoke passes finite-TTD gates.
- `weapon_identity_diversity_test.gd` confirms no duplicate weapon identity
  signatures across the 51-weapon roster.

## Subagent Cross-Check

- Erdos read-only gameplay/code audit found no hard gameplay blocker and judged
  the 17 class trios / 51 weapons distinct enough for the QA gate, with manual
  playfeel as residual risk.
- Darwin read-only docs/Jira audit found mirror/doc closeout gaps: missing final
  before/after report, stale Jira sync map before final sync, and stale
  SummonerWeapon wording in `current_game_state.md`. This SCRUM-861 closeout
  report, mirror update, Jira sync, and current-state doc patch address those
  gaps.
