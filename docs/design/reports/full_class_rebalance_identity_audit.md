# Full Class Rebalance Identity Audit

SCRUM-856, worker `class-rebalance-backend-Mill`, 2026-07-04.

Scope: audit only. Runtime files stayed read-only for this task because SCRUM-854
owned overlapping `scripts/class_weapon.gd`, `scripts/summoner_weapon.gd`,
`scripts/player.gd` and progression-data runtime paths during the audit. Final
integration is rebased on top of landed SCRUM-854, so downstream tasks should
treat SCRUM-854 as the new runtime baseline while still re-checking Jira QA state
and locked paths before editing shared files.

## Summary

The current numeric layer is green: all 51 class+weapon pairs pass the existing
solo, 5-target and 5/10/20 crowd-clear gates. That does not mean the class
identity layer is done. `budget_damage_multiplier` hides two kinds of identity
debt:

- Several weapons are cap-pinned at `2.800`, meaning their raw mechanic is too
  weak and has no tuning room without mechanic changes.
- Several DoT/summon/sustain weapons are tuned down to `0.280..0.624`, meaning
  their raw output is too explosive and should be reshaped before future growth
  or kill-scaling work.
- Projectile, chain, delayed AoE, deploy and sustain families have distinct
  labels, but some still feel close because their current proof is mostly a
  shaped hit plus a budget multiplier.

This report treats class balance as the sum of each three-weapon kit. The
numbers below are the pre-implementation-wave baseline for SCRUM-857..860.

## Sources And Commands

Generated on rebased `origin/dev` commit `30c67104`.

- `python3 tools/godot_gate.py --headless --path . --script res://tools/balance_harness.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/global_survivability_balance_smoke_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tools/survivability_harness.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/survivability_scenario_test.gd`

Reports inspected:

- `build/balance_report.md`
- `build/balance_final_audit_0_1_5.md`
- `build/global_damage_balance_report.md`
- `build/survivability_report.md`

Result: all listed checks passed. Worst current 20-target CCT deviation is
`doctor/restore_potion` at `+22%`, still inside the `+/-30%` gate.

## Scoring Model

Scores are ratios against the current harness targets:

- Solo and AoE scores are average measured DPS / target DPS across the three
  weapons.
- Crowd score averages 5/10/20 clear-time ratios as target time / measured time.
- Defense score is average EHP / roster median EHP (`85.0`).
- Total score is the mean of solo, AoE, crowd and defense with defense capped
  at `1.50` so tanks stay tanks without dominating the audit.

## Class Trio Matrix

| Class | Three weapons | Solo | AoE | Crowd | Defense | Total | Diagnosis | Follow-up |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| `berserk` | `sword`, `axe`, `hammer` | 1.000 | 1.000 | 0.935 | 1.41 | 1.087 | Clear melee fantasy; hammer is cap-pinned and all three CCT rows are very similar after tuning. | SCRUM-858: keep sword as long narrow commit, axe as broad cleave, hammer as short danger-zone slam with clearer risk window. |
| `soldier` | `soldier_rifle`, `soldier_grenade`, `soldier_bayonet` | 1.000 | 1.000 | 0.960 | 1.22 | 1.046 | Good tactical trio. Grenade already proves delayed AoE; rifle/bayonet need stronger non-damage identity. | SCRUM-857 rifle suppression; SCRUM-858 bayonet brace/counter tuning. |
| `thief` | `thief_coin_pouch`, `thief_shadow_cloak`, `thief_smoke_bomb` | 1.000 | 1.000 | 0.979 | 0.81 | 0.948 | Strong concept, fragile kit. Smoke bomb is cap-pinned and should be utility-first, not another delayed AoE. | SCRUM-857 coin ricochet; SCRUM-860 gold/kill tempo; smoke dodge tuning. |
| `elementalist` | `elementalist_orb_ring`, `elementalist_prism_focus`, `elementalist_meteor_core` | 1.000 | 1.000 | 0.972 | 0.60 | 0.892 | Good elemental fantasy, but prism and meteor are both cap-pinned; delayed hit family risks feeling like grenade variants. | SCRUM-857 split orbit/rift/meteor payoff rules; keep meteor distinct from grenade. |
| `sniper` | `sniper_deadeye_rifle`, `sniper_spotter_scope`, `sniper_shatter_rounds` | 1.000 | 1.000 | 0.928 | 1.44 | 1.093 | Solo class is numerically healthy. Spotter is cap-pinned and deadeye has slowest 20-target CCT among its kit. | SCRUM-857 lockshot/kill-zone/split-round target pattern pass. |
| `priest` | `priest_reliquary`, `priest_censer`, `priest_chime` | 1.000 | 1.000 | 0.978 | 1.05 | 1.006 | Sustain caster identity is coherent, but reliquary and chime are cap-pinned while all three heal/control channels risk blending. | SCRUM-857 prayer chain; SCRUM-860 sustain caps and role separation. |
| `biologist` | `biologist_spore_lens`, `biologist_sample_injector`, `biologist_symbiote_seed` | 1.000 | 1.000 | 0.991 | 0.82 | 0.953 | Best crowd-table spread. Symbiote is cap-pinned, so network identity needs mechanic support. | SCRUM-857 network/sample/spore role split. |
| `robot` | `robot_magnetic_anchor`, `robot_hydraulic_press`, `robot_reactor_core` | 1.000 | 1.000 | 0.960 | 2.12 | 1.115 | Tank-control identity is strong, but anchor and reactor are cap-pinned; tank ceiling is high but not immortal. | SCRUM-858 tank-control risk/payoff; preserve heavy EHP role. |
| `engineer` | `engineer_sentry_wrench`, `engineer_repair_drone`, `engineer_pressure_mines` | 1.000 | 1.000 | 0.946 | 1.01 | 0.990 | Best deploy trio concept, but sentry is over-hitting and mines are cap-pinned; deploy ownership needs clearer rules. | SCRUM-859 turret/deploy pass on the post-SCRUM-854 runtime baseline, after Jira QA/locks are re-checked. |
| `dark_mage` | `dark_book`, `cursed_skull`, `dark_wand` | 1.000 | 1.000 | 0.960 | 0.59 | 0.888 | Glass AoE is healthy after SCRUM-783, but `dark_book` is cap-pinned and book/skull/wand can collapse into generic magic hits. | SCRUM-857 projectile/curse/pierce separation. |
| `guitarist` | `electric_guitar`, `bass_guitar`, `sound_amp` | 1.000 | 1.000 | 0.961 | 0.80 | 0.940 | Sound/control reads well. Bass is cap-pinned and amp is near the 20-target review edge. | SCRUM-859 deploy stage control; SCRUM-860 control-to-defense valuation. |
| `assassin` | `chakrams`, `shadow_daggers`, `venom_wire` | 1.000 | 1.000 | 0.935 | 1.03 | 0.992 | Solo/crit role is clear, but venom wire is heavily clamped and all three CCT rows are nearly identical. | SCRUM-857 boomerang/poison line; SCRUM-860 crit/kill-scaling. |
| `ranger` | `moon_crossbow`, `storm_longbow`, `hunter_trap` | 1.000 | 1.000 | 0.953 | 0.80 | 0.939 | Good long-range kit, but trap is cap-pinned and beam/fan/trap must feel more different in live combat. | SCRUM-857 charged pierce/fan; SCRUM-859 trap ownership if paths are clear. |
| `doctor` | `restore_potion`, `plague_syringe`, `bone_saw` | 1.000 | 1.000 | 0.887 | 1.18 | 1.016 | Strong sustain fantasy. Restore is cap-pinned; plague and saw are clamped; restore/plague are current worst 20-target CCT. | SCRUM-860 sustain/vampiric growth on top of SCRUM-854's Doctor external-sustain filter. |
| `chemist` | `blast_powder`, `acid_flask`, `homunculus_vial` | 1.000 | 1.000 | 0.963 | 0.63 | 0.898 | AoE kit is green but structurally volatile: blast/acid are cap-pinned while homunculus is hard-clamped. | SCRUM-857 reagent/projectile split; SCRUM-859 homunculus using SCRUM-854 persistent-zone/summon contracts. |
| `knight` | `long_spear`, `tower_shield`, `holy_flail` | 1.000 | 1.000 | 0.935 | 2.21 | 1.109 | Tank ceiling is intentional. Shield/flail are cap-pinned and need clearer block/counter vs holy-control roles. | SCRUM-858 shield counter and melee risk/reward. |
| `druid` | `summon_amulet`, `briar_staff`, `raven_totem` | 0.999 | 0.999 | 0.933 | 0.99 | 0.980 | Good nature/summon fantasy, but summon amulet is hard-clamped and both summon/totem sit near 20-target review edge. | SCRUM-859 summon/deploy after SCRUM-854; SCRUM-860 Leadership scaling. |

## Per-Weapon Identity Matrix

| Class | Weapon | Current identity axes | Contribution / scaling | Audit diagnosis | Mechanic-first recommendation |
| --- | --- | --- | --- | --- | --- |
| `berserk` | `sword` | Long narrow 100-degree sector, high reach, forward commit. | Physical melee, execute-style identity; tuning `0.739`. | Healthy anchor weapon; already distinct from axe/hammer. | Preserve as precise long cone; add more positional commitment only if live play says it is too safe. |
| `berserk` | `axe` | Shorter 180-degree sector, broad cleave around nearest target. | Physical melee, crowd-side cleave; tuning `1.843`. | Healthy but CCT mirrors sword too closely after budget tuning. | Give axe visible cleave spillover/follow-through instead of generic sector DPS. |
| `berserk` | `hammer` | 150px circular slam, close danger zone, target diminishing. | Physical melee, stagger/slam; tuning `2.800`. | Cap-pinned raw mechanic; risks being a weaker circle hidden by multiplier. | SCRUM-858 should add slam payoff: brief stagger/ground-crack pulse or high-risk close burst, not just more damage. |
| `soldier` | `soldier_rifle` | Three quick line shots, suppression corridor. | Perception/physical line pressure; tuning `1.723`. | Strong shape, but suppression defense value is under-documented. | Add/verify slow or stagger suppression window so the rifle is control-fire, not mini-beam. |
| `soldier` | `soldier_grenade` | Telegraph, fuse delay, falloff explosion. | Delayed AoE; tuning `2.643`. | Good delayed AoE exemplar. | Keep delay/falloff; avoid making meteor or smoke use the same timing/payoff. |
| `soldier` | `soldier_bayonet` | Forward brace corridor, one hit per enemy, knockback. | Defensive melee, EHP +3 vs class baseline; tuning `1.833`. | Good tank-adjacent role. | Strengthen counter/hold-line identity in SCRUM-858 if live feel is too passive. |
| `thief` | `thief_coin_pouch` | Ricochet chain between nearby targets, gold steal. | Agility/tempo, economy hook; tuning `2.347`. | Clear idea, but needs stronger bounce readability. | SCRUM-857 should separate bounce rules from priest prayer chain and sniper split rounds. |
| `thief` | `thief_shadow_cloak` | Phantom backstab without moving hero, small splash. | Burst/position fantasy; tuning `2.583`. | Distinct enough if the phantom strike is readable. | Keep non-teleport contract; consider marked-target burst window instead of extra AoE. |
| `thief` | `thief_smoke_bomb` | Delayed smoke AoE plus dodge window. | Fragile defensive utility; tuning `2.800`. | Cap-pinned and too close to delayed explosion family if dodge is not valued. | Shift power toward evade/control zone; make damage secondary. |
| `elementalist` | `elementalist_orb_ring` | Orbiting elemental ticks around hero. | AoE glass-caster, close orbit risk; tuning `2.129`. | Good unique rhythm. | Preserve moving orbit uptime and avoid turning it into static aura only. |
| `elementalist` | `elementalist_prism_focus` | Crossed rift beams after short telegraph. | Magic beam/rift; tuning `2.800`. | Cap-pinned; could feel like just another delayed line. | Add rift intersection bonus or enemy pinning so prism is geometry puzzle, not beam clone. |
| `elementalist` | `elementalist_meteor_core` | Delayed impact plus secondary shard bursts. | Delayed AoE, magic shards; tuning `2.800`. | Cap-pinned and overlaps grenade in broad description. | Keep longer setup and shard scatter; primary impact should be the landing, shards the crowd payoff. |
| `sniper` | `sniper_deadeye_rifle` | Long lockshot with telegraph and line falloff. | Solo profile, long range; tuning `2.056`. | Strong solo identity; slowest 20-target CCT in kit is acceptable for role. | Keep boss/elite focus; do not patch crowd by flattening into split shot. |
| `sniper` | `sniper_spotter_scope` | Marked kill-zone, several sky-beam hits. | Solo profile with setup zone; tuning `2.800`. | Cap-pinned; risks feeling like delayed AoE. | Make mark persistence/priority targeting the identity, not explosion size. |
| `sniper` | `sniper_shatter_rounds` | Primary shot splits to nearby enemies with falloff. | Solo-to-small-pack bridge; tuning `2.109`. | Healthy split archetype. | SCRUM-857 should distinguish split from ricochet by deterministic branches from a primary shot. |
| `priest` | `priest_reliquary` | Sanctify mark then holy area burst with heal. | Sustain caster; EHP 91.1; tuning `2.800`. | Cap-pinned but identity is promising. | Make heal tied to sanctified target payoff; avoid generic AoE heal. |
| `priest` | `priest_censer` | Protective ward pulses around hero. | Close defense/control; EHP 87.5; tuning `2.657`. | Good defensive rhythm. | Value defensive uptime explicitly in SCRUM-860 rather than buffing damage. |
| `priest` | `priest_chime` | Prayer chain bounces between enemies, sustain return. | Chain/sustain; tuning `2.800`. | Cap-pinned; may overlap coin ricochet. | Prayer chain should return to owner or heal on final bounce; chain rules must differ from thief/ranger. |
| `biologist` | `biologist_spore_lens` | Three expanding target-centered rings. | AoE bio ticks; tuning `1.257`. | Healthy crowd identity. | Keep expanding rings; avoid making it a static poison pool. |
| `biologist` | `biologist_sample_injector` | Direct sample dart then delayed analysis pulses. | Single target into local tissue pulses; tuning `1.727`. | Good damaging projectile without relying on landing explosion. | SCRUM-857 should preserve initial dart value plus delayed analysis, not convert to AoE projectile. |
| `biologist` | `biologist_symbiote_seed` | Primary target links nearby enemies in a web. | Network damage share; EHP +1.3 vs kit; tuning `2.800`. | Cap-pinned; web identity needs stronger mechanics. | Add damage-sharing or retargeted link payoff; do not solve by flat multiplier. |
| `robot` | `robot_magnetic_anchor` | Target-centered pull then impulse. | Tank-control, strongest robot EHP 185.5; tuning `2.800`. | Cap-pinned but excellent control fantasy. | Give pull/setup value and body-block safety credit before damage buffs. |
| `robot` | `robot_hydraulic_press` | Two jaws compress a line corridor. | Tank-control line; tuning `2.682`. | Distinct from anchor if axis compression is readable. | Preserve corridor compression, maybe add edge-to-axis squeeze timing. |
| `robot` | `robot_reactor_core` | Four short reactor vents around player. | Close control and knockback; tuning `2.800`. | Cap-pinned; risks becoming circular pulse variant. | Make directional vent windows/knockback the identity, not generic circle damage. |
| `engineer` | `engineer_sentry_wrench` | Temporary sentry, autonomous focused beams. | Deploy/turret, over-hitter tuning `0.335`. | Raw output too high; turret ownership/retargeting needs shape. | SCRUM-859 should tune uptime, target priority and reload, not just lower multiplier. |
| `engineer` | `engineer_repair_drone` | Chain drone links enemies and repairs owner. | Support chain/sustain, EHP 88.2; tuning `2.652`. | Good but can overlap priest chain. | Distinguish as mechanical repair: owner tether, capped repair, different bounce cadence. |
| `engineer` | `engineer_pressure_mines` | Three independent mines in a fan. | Route control deploy; tuning `2.800`. | Cap-pinned; good trap identity but needs ownership rules. | Add arming/trigger spacing and mine occupancy decisions. |
| `dark_mage` | `dark_book` | Two AoE projectiles to nearest targets. | AoE glass cannon; tuning `2.800`. | Cap-pinned and too generic as "two AoE shots." | Add void split/secondary collapse or curse interaction so it is not blast_powder in purple. |
| `dark_mage` | `cursed_skull` | Homing curse, DoT and splash. | DoT/curse, tuning `1.491`. | Distinct if curse duration matters. | Keep homing + DoT; add mark vulnerability rather than more splash. |
| `dark_mage` | `dark_wand` | Two pierce beams in a fan. | Pierce/beam, tuning `2.709`. | Healthy pierce anchor but close to ranger beams. | Differentiate with void decay after beam or stacked arcane vulnerability. |
| `guitarist` | `electric_guitar` | Directed sound wave with knockback. | Control/AoE, tuning `1.354`. | Good flagship weapon. | Preserve directed wave and knockback as defense contribution. |
| `guitarist` | `bass_guitar` | Frequent circular pulse/knockback. | Close control, tuning `2.800`. | Cap-pinned; risks generic pulse. | Make bass a rhythmic control metronome: lower damage, stronger push/slow windows. |
| `guitarist` | `sound_amp` | Deploy amp with autonomous pulses. | Deploy stage control, tuning `1.438`. | Good, but 20-target CCT at +20.1% review edge. | SCRUM-859 should give amp placement/stack rules, not hidden DPS. |
| `assassin` | `chakrams` | Boomerang corridor out and back, crit-friendly. | Solo profile, tuning `1.544`. | Healthy geometry. | Keep return path payoff; avoid becoming generic pierce beam. |
| `assassin` | `shadow_daggers` | Short multi-stab flurry near target. | Close execute/crit; tuning `1.483`. | Good risky melee hybrid. | Add/verify close-risk reward and crit burst windows. |
| `assassin` | `venom_wire` | Thin poison line/garrote with DoT. | DoT line, over-hitter tuning `0.357`. | Raw DoT too high; all assassin CCT rows too similar. | SCRUM-857/860 should shift to ramp/execute poison, with hard caps on runaway. |
| `ranger` | `moon_crossbow` | Long charged piercing shot. | Solo long-range, tuning `2.105`. | Healthy but close to dark_wand if only pierce. | Keep charged stance and single-line precision. |
| `ranger` | `storm_longbow` | Charged fan of beams. | Long-range fan control, tuning `1.375`. | Good if charge/fan timing is clear. | Preserve fan spread and stance payoff. |
| `ranger` | `hunter_trap` | Deploy trap with burst and knockback on entry. | Zone ownership, tuning `2.800`. | Cap-pinned; trap identity needs live placement value. | SCRUM-859 should add arming/trigger/retarget rules and not simply buff damage. |
| `doctor` | `restore_potion` | AoE throw plus self heal. | Sustain tank, EHP 106.9, tuning `2.800`. | Cap-pinned and current worst 20-target CCT. | SCRUM-860 should make potion a healing link or landing-pool support, not generic AoE throw. |
| `doctor` | `plague_syringe` | Homing poison injection plus sustain. | Sustain/DoT, tuning `0.566`. | Over-hitter, current 20-target CCT +21.9%; overlaps curse/skull. | Make plague spread/ramp distinct with capped infection count and lower instant sustain. |
| `doctor` | `bone_saw` | Close saw/flurry, bleed DoT, small heal. | Risky melee sustain, tuning `0.624`. | Strong raw sustain; healthy as close-risk role. | Keep close-range danger and cap heal per second; add wound/execute flavor rather than raw DPS. |
| `chemist` | `blast_powder` | AoE projectile explosion plus spark cloud. | Reagent burst, tuning `2.800`. | Cap-pinned; close to dark_book/restoration projectile family. | Make no-landing damaging cloud or reagent spark the differentiator. |
| `chemist` | `acid_flask` | Acid pool / stacking DoT zone. | Persistent zone, tuning `2.790`. | Near cap; overlaps generic pool/zones. | Use lingering area denial with stacking cap and combo trigger, not bigger radius. |
| `chemist` | `homunculus_vial` | Temporary `tank_control` summon. | Summon/deploy, over-hitter tuning `0.280`, EHP 58.2. | Raw summon output too high and overlaps druid summons if not role-shaped. | SCRUM-859 should make it a single body-blocking tank with slow attacks, not extra DPS pet. |
| `knight` | `long_spear` | Long strip thrust, defense passive. | Tank melee, EHP 184.0, tuning `1.278`. | Healthy line-control weapon. | Preserve poke/brace reach; no generic sweep conversion. |
| `knight` | `tower_shield` | Frontal bash/control, strongest block identity. | Tank EHP 203.3, tuning `2.800`. | Cap-pinned; shield needs counter damage proof. | SCRUM-858 should add block/counter timing and taunt/control credit. |
| `knight` | `holy_flail` | Medium circular heavy swing. | Tank AoE/control, EHP 175.7, tuning `2.800`. | Cap-pinned and could feel like hammer. | Differentiate with holy orbit/return swing or crowd-control pulse, not another slam. |
| `druid` | `summon_amulet` | Commanded beast pack. | Leadership summon, over-hitter tuning `0.280`. | Raw output far too high; 20-target CCT +20.2% after clamp. | SCRUM-859 should tune command distribution/body-blocking and pack roles on top of SCRUM-854 summon-cap contracts. |
| `druid` | `briar_staff` | Thorn zone, AoE DoT, crowd control. | Nature zone, tuning `2.110`. | Good crowd anchor. | Keep zone denial and slow/roots; do not make it another acid pool. |
| `druid` | `raven_totem` | Support totem pulses, Leadership deploy limit. | Support deploy, tuning `1.107`. | Good support idea; 20-target CCT +20.0% review edge. | SCRUM-859 should distinguish support pulses from sound amp via command aura and control. |

## Clone And Dead-Slot Findings

These are not failing numeric gates today; they are implementation risks for the
rebalance wave.

| Finding | Affected weapons | Why it matters | Mechanic-first fix |
| --- | --- | --- | --- |
| Delayed AoE family can blur together. | `soldier_grenade`, `elementalist_meteor_core`, `thief_smoke_bomb`, `sniper_spotter_scope`, `priest_reliquary` | All can become "telegraph, wait, burst" if payoff windows are not unique. | Grenade = falloff explosive; meteor = delayed impact + shard scatter; smoke = evade/control zone; spotter = marked precision beams; reliquary = sanctified heal payoff. |
| Projectile-with-area family is too generic when landing damage is the whole proof. | `dark_book`, `blast_powder`, `restore_potion`, `acid_flask`, `briar_staff` | Different classes can feel like reskinned AoE projectiles. | Add non-landing identity: void collapse, reagent cloud/combo, healing link, stacking acid cap, thorn slow/root. |
| Chain/split/pierce needs rule separation. | `thief_coin_pouch`, `sniper_shatter_rounds`, `priest_chime`, `engineer_repair_drone`, `dark_wand`, `moon_crossbow`, `storm_longbow`, `chakrams`, `venom_wire` | These all distribute damage along targets/lines. Without distinct retarget rules, they feel samey. | Ricochet chooses new nearby targets and steals gold; split branches from a primary shot; prayer returns sustain; repair drone tethers owner; pierce beams are deterministic lines; chakrams return; venom ramps DoT. |
| Deploy/turret/summon slots need ownership and anti-runaway rules. | `sound_amp`, `engineer_sentry_wrench`, `engineer_pressure_mines`, `hunter_trap`, `homunculus_vial`, `summon_amulet`, `raven_totem` | Some are clamped down from huge raw output, others are cap-pinned. Damage multipliers cannot make placement gameplay. | Define arming time, lifetime, retarget cadence, body-blocking, support aura, trigger spacing and target caps before numeric tuning. |
| Sustain family risks becoming one generic lifesteal pipe. | `restore_potion`, `plague_syringe`, `bone_saw`, `priest_reliquary`, `priest_censer`, `priest_chime`, `engineer_repair_drone` | Heal output is capped, but player feel still depends on when and why healing happens. | Potion = recovery/overheal decision, plague = infection ramp, saw = risky close drain, priest = holy ward/chain return, engineer = repair tether. |
| Tank/melee identity still needs explicit counter windows. | `hammer`, `soldier_bayonet`, `robot_*`, `long_spear`, `tower_shield`, `holy_flail`, `bone_saw`, `shadow_daggers` | High EHP alone does not create gameplay. | Add/verify readable guard, close-risk, stagger, taunt, counter or execute windows; numeric DPS is secondary. |

## Implementation Order And Locks

At final integration, SCRUM-854 is already merged into `origin/dev`; use its
persistent-zone, summon-cap and Doctor-sustain changes as the runtime baseline.
Still re-check Jira QA state and current owner comments before editing shared
runtime paths.

1. SCRUM-857: projectile, chain, pierce and delayed AoE pass. Safe first if it
   limits itself to non-overlapping slices and explicitly re-checks shared
   `class_weapon` ownership before edits.
2. SCRUM-858: melee, counter, tank and risk-reward pass. Focus on Berserk,
   Soldier bayonet, Assassin daggers, Doctor saw, Knight and Robot. Re-check
   current Jira locks before editing shared `class_weapon` paths.
3. SCRUM-859: summon, deploy, turret and zone ownership pass. Build on
   SCRUM-854's persistent-zone and summon-cap contracts; do not reopen the same
   paths if SCRUM-854 QA has active fix ownership.
4. SCRUM-860: kill-scaling, sustain and attribute growth pass. Should run after
   mechanic shapes are stable; otherwise sustain/kill growth will amplify the
   wrong mechanics.
5. SCRUM-861 QA gate: blocked until SCRUM-857..860 post evidence.

## User-Idea Coverage

- Delayed grenade/meteor: `soldier_grenade` and `elementalist_meteor_core` are
  called out separately so they do not share one "delayed explosion" feel.
- Damaging projectile without landing damage: `biologist_sample_injector` should
  keep dart + delayed analysis, and `blast_powder` should move toward reagent
  cloud/combo instead of pure landing burst.
- Ricochet/split/pierce: `thief_coin_pouch`, `sniper_shatter_rounds`,
  `dark_wand`, `ranger` beams, `chakrams` and `venom_wire` are split into
  different retarget/line rules.
- Chain lightning/prayer: `priest_chime` and `engineer_repair_drone` should not
  clone thief ricochet; prayer returns sustain, drone repairs through owner
  tether.
- Melee AoE with risk window: `hammer`, `tower_shield`, `holy_flail`,
  `bone_saw`, `shadow_daggers` need close-risk/counter windows.
- Turret/deploy gameplay: `engineer_sentry_wrench`, `sound_amp`,
  `hunter_trap`, `raven_totem`, `homunculus_vial` and `summon_amulet` require
  ownership, lifetime and retarget/trigger rules.
- Shield counter damage: `tower_shield` is assigned to SCRUM-858 as a block and
  counter proof point.
- Kill-scaling/vampiric growth: Doctor/Assassin/Thief/Priest sustain and kill
  tempo are assigned to SCRUM-860 after the mechanic pass.

## Residual Risk

The formula harness is deterministic and pair-level. It cannot fully prove live
feel, target acquisition under motion, player safety from control effects, or
whether two weapons feel too similar moment-to-moment. SCRUM-856 therefore
unblocks mechanic-first implementation tasks but does not replace focused live
combat and QA playfeel checks after each slice.
