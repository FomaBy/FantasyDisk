## Доктор: weapon-level ultimates

FAN-1487 делает все три профиля `doctor/*` ready class-local packages. Registry
связывает только совпадающие JSON/GDScript пары; shared controller, resolver,
Player и ClassWeapon не получают class-specific веток.

| Weapon | Solo | AoE/crowd | Defense | Activation shape |
| --- | ---: | ---: | ---: | --- |
| `restore_potion` | 28.07s | every live enemy on the map | 10 repair + 8 absorb | aimed dual pool; actual outer damage heals and its final overflow becomes a temporary shield |
| `plague_syringe` | 31.62s | every live enemy | 9 repair | highest-HP patient zero; five fixed map-wide plague waves and a mask finale |
| `bone_saw` | 27.55s | every live target in the 240-radius orbit | 10 drain + 9 absorb | six close orbit cuts; actual removed HP becomes drain and stored vitality becomes a stitch shield |

The trio midpoint is 29.08 seconds of each weapon's normal-output reference,
inside the shared 20–35 second U3 power corridor. Every profile uses
`rare_charge_ledger`, spends one charge per encounter, credits only actual HP
removed while inactive, and has a whole-activation `total_boss_cap` of 8%.
Transient tweens and `absorb_flat` modifiers are activation-owned and removed on
completion/cancel; charge snapshots intentionally contain no active-effect state.

Executor presentation events preserve the accepted doctor timelines without
editing their locked assets: Life and Death emits flask/release, poison-ring,
healing-spiral, and shield events; Black Epidemic emits injection, veins, wave,
and mask events; Emergency Surgery emits stance, orbit, and stitch-shield events.

Ultimate Direction v2 (FAN-3235) makes Black Epidemic's reach map-wide: the
five fixed waves start with every eligible live enemy already infected, so a
crowd cannot dilute its per-enemy floor. The whole-activation boss cap, repair
budget, and rare charge ledger remain unchanged; `wave_visual_radius` controls
only the pulse presentation, never gameplay reach.

Ultimate Direction v2 (FAN-3234) makes Life and Death's outer damage map-wide:
the aimed release point and visible 220 px ring remain its identity, but the
outer damage channel reaches every eligible live enemy without a count cap.
Each target receives the same four-pulse channel while the 8% whole-activation
boss cap, per-target damage shaping, repair budget, rare-charge ledger, and
activation-owned cleanup remain unchanged.

The deterministic effectiveness runner measured the following before and after
the conversion:

| Scenario | Baseline struck | Final struck | Final damage |
| --- | ---: | ---: | ---: |
| Solo | 1/1 | 1/1 | 1748.92 |
| 5 enemies | 5/5 | 5/5 | 8744.61 |
| 10 enemies | 10/10 | 10/10 | 17489.21 |
| 20 enemies | 12/20 | 20/20 | 34978.42 |
| Elite | 1/1 | 1/1 | 1748.92 |
| Boss | 1/1 | 1/1 | 1748.92 |

The final cast stays inside the shared power corridor: `total_boss_cap=0.08`,
normal charge `33.50`, elite charge `42.30`, and three normal encounters to
ready.

Focused evidence: `doctor_bone_saw_direction_v2_test.gd`,
`doctor_package_test.gd`, `doctor_balance_test.gd`, and `doctor_live_test.gd`.
