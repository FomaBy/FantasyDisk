# SCRUM-1069 Guild Atlas Balance Audit

Date: 2026-07-11  
Base: `origin/dev@0b17c754a`  
Scope: Guild Atlas values/runtime outcomes only; IDs, graph, topology, costs,
schema 5 and UI geometry are unchanged.

## Decision

Guild Atlas remains an account-wide economy/support layer. No direct global
damage was added. Numeric tuning is sufficient for the fourteen minor nodes and
three established economy/reward keystones; the structurally weak death-save
needed one mechanic change from symbolic `1 HP` to a clamped `30% max HP`
recovery. `Боевой раж` now starts at 100% ultimate charge.

## Exact 24-node before/after audit

| ID | Role / cost | Before | After | Runtime consumer | Outcome / value per dust |
| --- | --- | --- | --- | --- | --- |
| `atlas_m0` | minor / 1 | gold +2% | gold +5% | `Player.META_SKILL_MULT_MAP` → money pickup | 1.00 utility/dust |
| `atlas_m1` | minor / 2 | gold +2% | gold +5% | same | 0.50 |
| `atlas_m2` | minor / 2 | start gold +10 | +25 | `Main.apply_ascension_bonuses` | 0.50 |
| `atlas_m3` | minor / 2 | start gold +10 | +25 | same | 0.50 |
| `atlas_n0` | notable / 3 | gold +3%, start +5 | gold +10% | money pickup | 0.67 |
| `atlas_k0` | keystone / 5 | guaranteed epic shop, start +15 | guaranteed epic, start +50 | shop sampler + run start | 0.80 |
| `atlas_m4` | minor / 2 | shop −2% | −5% | shop price materialization | 0.50 |
| `atlas_m5` | minor / 2 | shop −2% | −5% | same | 0.50 |
| `atlas_m6` | minor / 2 | attribute cost −2% | −5% | attribute-buy price | 0.50 |
| `atlas_m7` | minor / 2 | attribute cost −2% | −5% | same | 0.50 |
| `atlas_n1` | notable / 3 | shop/attribute −2%/−2% | −10%/−10% | both price pipelines | 1.33 |
| `atlas_k1` | keystone / 5 | first level-up main stat | unchanged strong unique outcome | reward sampler | 0.50 |
| `atlas_m8` | minor / 2 | XP +2% | +5% | `Player.META_SKILL_MULT_MAP` → XP pickup | 0.50 |
| `atlas_m9` | minor / 2 | XP +2% | +5% | same | 0.50 |
| `atlas_m10` | minor / 2 | XP +2% | +5% | same | 0.50 |
| `atlas_n2` | notable / 3 | +1 attribute option | unchanged strong unique outcome | attribute offer sampler | 0.67 |
| `atlas_k2` | keystone / 5 | 50% start charge | 100% | `Player.apply_meta_skill_modifiers` | 0.80 |
| `atlas_h0` | hidden / 0 | gold +3% | +10% | Codex milestone gate → money pickup | notable-grade, free challenge reward |
| `atlas_m11` | minor / 2 | pickup +10 | +30 | player flat map → derived pickup | 0.50 |
| `atlas_m12` | minor / 2 | pickup +10 | +30 | same | 0.50 |
| `atlas_m13` | minor / 2 | healing +4% | +8% | healing multiplier across heal flows | 0.50 |
| `atlas_n3` | notable / 3 | pickup +8, healing +3% | healing +12% | healing flows | 0.50 |
| `atlas_k3` | keystone / 5 | once/run save at 1 HP | once/run save at 30% max HP | `Player.take_damage` | 0.90 |
| `atlas_h1` | hidden / 0 | start gold +25 | +50 | Secret Boss gate → run start | notable-grade, free challenge reward |

Descriptions are generated from the same effect dictionaries. Every new number
therefore reaches the Atlas node panel without a duplicated text constant.

## Branch budgets

| Branch | Cost | Before total | After target | Normalized value/dust |
| --- | ---: | --- | --- | ---: |
| Казна | 15 | +7% gold, +40 start | +20% gold, +100 start, guaranteed epic shop | 0.667 |
| Лавка | 16 | −6% shop, −6% attribute | −20% shop, −20% attribute, first main-stat reward | 0.656 |
| Знание | 14 | +6% XP, +1 option, 50% ult | +15% XP, +1 option, 100% ult | 0.643 |
| Дорога | 14 | +28 pickup, +7% healing, 1-HP save | +60 pickup, +20% healing, 30% save | 0.643 |

The 0.64–0.68 corridor keeps all four complete branches competitive without
requiring identical effects. Challenge-hidden nodes are scored separately and
do not change the 59-cost purchase budget.

The exhaustive connectivity oracle enumerates exactly 384 valid builds at the
50-dust cap. Their normalized scores stay in `31..34` (spread `1.097 < 1.10`),
so no branch is mandatory at the actual spend ceiling.

## Class and weapon equality

No weapon config, target geometry, cooldown, damage, AoE or class-affinity data
changes. Consequently every 17-class three-weapon kit keeps its before scores:

| Roster | Solo | AoE | Crowd | Direct class damage | Guild support upper bound |
| --- | ---: | ---: | ---: | ---: | ---: |
| all 17 classes / all 51 weapons | unchanged | unchanged | unchanged | +0% | identical +17.4% weighted maximum |

The +17.4% is the *full 59-cost Atlas* including all support keystones. It is a
strict upper bound for any legal 50-dust build and stays below the +18% contract.

## Caps and runaway proof

- `atlas_total_cost = 59`, `STARDUST_CAP = 50`; schema 5 and purchase IDs stay
  unchanged, so existing saves receive stronger values without respec.
- Full-Atlas account power = `1.174 < 1.35`; weighted class delta = `0.174 ≤ 0.18`.
- Full unlocked economy upper bounds: gold `+30%` including Codex hidden,
  XP `+15%`, start gold `150` including Secret Boss hidden, shop and attribute
  prices no lower than `0.80×` from Guild sources.
- At A5, enemy HP/damage remain above `1.5×`; `0.68 × 1.20 = 0.816` healing
  remains below A0, and `0.80 × 1.30 = 1.04` gold reward remains bounded.
- Death-save fraction is runtime-clamped to `0.25..0.30` and its used flag is
  persisted in the run snapshot; no healing loop or second trigger is possible.

## Validation contract

Focused test: `tests/guild_atlas_scrum1069_balance_test.gd`. It checks all 24
outcomes, role floors, descriptions, branch totals/value, hidden positive and
negative controls, the exact 25-ID/cost/edge manifest, all-17 class-neutral
Guild contribution, full-Atlas power/economy caps and A5 pressure. Existing
`tests/meta_skill_tree_smoke_test.gd` verifies schema-5 Guild purchase roundtrip,
all four keystones and the established shop/reward pipelines. Independent
post-implementation review returned PASS with no P0–P2 findings.
