# Class Balance Model

Use this model to evaluate FantasyDisk classes as complete kits of exactly three selectable weapons.

## Core Scores

For each weapon, collect ratios against the intended budget target:

- `solo_ratio = measured_solo_dps / target_solo_dps`
- `aoe_ratio = measured_5_target_dps / target_5_target_dps`
- `crowd_ratio_5 = target_clear_time_5 / measured_clear_time_5`
- `crowd_ratio_10 = target_clear_time_10 / measured_clear_time_10`
- `crowd_ratio_20 = target_clear_time_20 / measured_clear_time_20`
- `defense_ratio = measured_or_estimated_defense_value / target_defense_value`

If a report exposes deviations instead of ratios, convert them back to a ratio where practical. Faster clear time is stronger, so clear-time ratios use target divided by measured.

## Class Trio Scores

For every class, aggregate its three weapons:

```text
class_solo_score = average(solo_ratio for the 3 weapons)
class_aoe_score = average(aoe_ratio for the 3 weapons)
class_crowd_score = average(crowd_ratio_5, crowd_ratio_10, crowd_ratio_20 across the 3 weapons)
class_defense_score = average(defense_ratio for the 3 weapons), plus explicit implemented defensive utility
class_total_score = weighted_mean(solo, aoe, crowd, defense)
```

Use equal weights unless the task or design docs define a class-specific budget. If using custom weights, document them before changing code.

## Corridors

Prefer these corridors for class kit totals unless existing code defines stricter gates:

- Class axis score: ideal within +/-10%, review at +/-15%, fail beyond +/-20%.
- Class total score across the roster: ideal within +/-8%, review at +/-12%, fail beyond +/-15%.
- Individual weapons may deviate more than class totals if the class kit compensates and the weapon has a clear niche. A weapon with no real niche is still a failure.

Never relax existing automated gates just to pass. If the model must change, update tests, docs, and the task report with rationale.

## Equality Target

All three weapons of one class must be balanced as a sum:

- One weapon can be the best solo tool if another is the better crowd tool and the third provides survival, control, or alternate rhythm.
- One weapon cannot dominate solo, AoE, crowd, and defense at the same time.
- One weapon cannot be dead weight because the other two are strong.
- A class cannot be balanced only around its strongest weapon.

All classes must also be balanced by the sum of their three weapons:

- Compare class kit totals across the entire roster.
- A class with defensive utility must pay for it in the defense axis or in tradeoffs elsewhere.
- A class with low solo pressure must have compensating AoE, crowd, or defense, and the total must still land in the roster corridor.

## Defensive Utility

Count only implemented effects, not fantasy text. Defensive utility includes:

- EHP, mitigation, dodge, absorb, shield, and regeneration.
- Lifesteal or vampirism only within current caps.
- Knockback, slow, stun, stagger, fear, freeze, taunt, summon body-blocking, or hazard denial if they actually reduce incoming damage.
- Range or kiting safety when the weapon's geometry creates meaningful safety in live combat.

Do not double-count the same mechanic as both damage and defense without a clear reason.
