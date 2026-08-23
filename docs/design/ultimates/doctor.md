## Доктор: weapon-level ultimates

FAN-1487 делает все три профиля `doctor/*` ready class-local packages. Registry
связывает только совпадающие JSON/GDScript пары; shared controller, resolver,
Player и ClassWeapon не получают class-specific веток.

| Weapon | Solo | AoE/crowd | Defense | Activation shape |
| --- | ---: | ---: | ---: | --- |
| `restore_potion` | 28.07s | 12-target outer zone | 10 repair + 8 absorb | aimed dual pool; actual outer damage heals and its final overflow becomes a temporary shield |
| `plague_syringe` | 31.62s | every live enemy | 9 repair | highest-HP patient zero; five fixed map-wide plague waves and a mask finale |
| `bone_saw` | 27.55s | 8 close-orbit targets | 10 drain + 9 absorb | six close orbit cuts; actual removed HP becomes drain and stored vitality becomes a stitch shield |

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

Focused evidence: `doctor_package_test.gd`, `doctor_balance_test.gd`, and
`doctor_live_test.gd`.
