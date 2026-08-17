# Live effectiveness metrics for the 51 weapon ultimates

FAN-2516. What `scripts/ultimates/balance/ultimate_effectiveness_runner.gd`
measures, how each number is produced, and which tolerance it holds to.

Every row is produced by activating the real registry-resolved executor through
the real `UltimateController` against a probe formation. No row is a class-level
legacy kit, and no row is a sustain measurement taken with the ultimate
disabled: `resolution_source` must be `weapon_profile` and `executor_present`
must be true, or the report is red.

## Producing a report

```
python3 tools/godot_gate.py --headless --path . \
    --script res://tools/ultimate_effectiveness_report.gd -- --label=baseline
```

`--label=baseline` (default) writes `build/ultimate_effectiveness_baseline.json`
— the committed reference. `--label=final` writes
`build/ultimate_effectiveness_final.json` and additionally compares it against
the stored baseline. Exit status is non-zero whenever the report is red, so the
tool doubles as a gate.

The focused test is `tests/ultimates/effectiveness_runner_test.gd`.

## The fixture

**Host.** A measuring node implementing the same ten `ultimate_host_*` methods
the shipped `UltimatePlayerHost` implements, plus the optional repair channel.
Its damage context is the real one: `base_stats` → `derived_parameters` → the
class's own damage parameter, exactly as the Player adapter reads it. Across the
51 rows that channel spans 1.57 … 55.69 damage per hit.

**Aim.** The host auto-aims at the formation centre, clamped to whatever range
the executor declared. A weapon that declares a 430 range and one that declares
960 therefore both engage the same pack, which is what makes their numbers
comparable.

**Formation.** A constant-density sunflower disc centred `FORMATION_DISTANCE`
(200 px) ahead of the host on its aim axis. Probe *i* sits at angle
*i* · 2.39996 rad and radius `FORMATION_DENSITY` (42 px) · √*i*, so:

- probe 0 always sits exactly on the aim point;
- the solo, 5, 10 and 20 formations are nested subsets of each other;
- a larger pack spreads instead of stacking.

The layout is closed-form — no RNG, no frame order — so the same probe count
always produces the same positions.

**Probe health.** Each normal/elite probe carries
`reference_solo_dps × POWER_SECONDS_MAX` (35 s of its own weapon's reference
output). HP that is not there cannot be removed, so a probe this size can
neither truncate a full-corridor activation nor let overkill inflate it.

**Boss pool.** The boss probe carries `power_budget_max / total_boss_cap`, i.e.
the pool is normalized so the declared boss share equals exactly one power
budget. `boss_cap_ratio` is then a direct read: 1.0 means the activation spent
its whole allowance against the boss.

## Scenarios

| id | probes | group | what it isolates |
|---|---|---|---|
| `solo` | 1 | `enemies` | single-target output on the aim point |
| `crowd_5` | 5 | `enemies` | small pack |
| `crowd_10` | 10 | `enemies` | medium pack |
| `crowd_20` | 20 | `enemies` | full crowd clear and target caps |
| `elite` | 1 | `elite_enemies` | the executor's declared epic resistance branch |
| `boss` | 1 | `bosses` | the boss resistance branch and the whole-activation cap |

## Metrics

All eight are per scenario. Every one must be finite and non-negative or the
report is red.

| metric | meaning | source |
|---|---|---|
| `damage_applied` | HP actually removed, overkill-clamped | `UltimateActivation.applied_total` |
| `healing_applied` | HP the host actually regained | the host's repair channel, clamped delta |
| `prevention_applied` | damage a live guard absorbed | one canonical 100-damage probe offered to the guard ledger |
| `modifier_granted` | peak distance of the whole modifier set from neutral | `ultimate_host_modifier`; additive keys are neutral at 0, multiplicative at 1 |
| `control_seconds` | summed duration of statuses left on probes | `StatusEffects.snapshot` |
| `displacement` | summed knockback impulse length | `apply_knockback` |
| `summon_count` | peak number of activation-owned nodes alive | `spawned_for_tests`, sampled while the cast is live |
| `targets_struck` | probes that took any damage | probe ledger |
| `uptime_seconds` | measured cast length | stepped tween time |

`effect_total` is the sum of every channel an ultimate is allowed to win
through. It exists so a pure ward (`priest/priest_censer`, 0 damage / 754
modifier) or a pure guard (`knight/tower_shield`, 0 solo damage / 80 prevention)
is not misread as a dead row. A row whose solo `effect_total` is zero is red.

`modifier_granted` and `summon_count` are read **while the cast is live**:
`UltimateActivation.shutdown()` unwinds modifiers and clears the spawn list, so
reading them afterwards would report zero for every row.

Charge cadence (`encounters_to_ready`, `normal_charge`, `elite_charge`) is
reported next to the live impact but is **not** re-derived here — it is the
frozen FAN-1460 economy, read from `UltimateBalanceHarness`. Across the 51 rows
readiness sits at 3…4 normal encounters.

### What this instrument does not measure

- **Borrowed summons.** The fixture owns no pre-existing summons, so
  `ultimate_host_summons()` returns empty. Only the activation's own temporary
  deploys are counted, and their damage is included in `damage_applied` because
  the activation meters it through the same budget.
- **Kill-triggered follow-ups** on normal probes, which are sized to survive a
  full-corridor activation by construction.
- **Presentation.** The fixture returns no presentation node, so timeline and
  VFX cost are out of scope; those belong to FAN-2517.

## Determinism and tolerances

The cast is driven by `Tween.custom_step(STEP_SECONDS)` in fixed 0.02 s steps,
never by wall-clock or frame time, and the formation is closed-form. Two runs of
the same tree therefore produce the same numbers.

| tolerance | value | meaning |
|---|---|---|
| `step_seconds` | 0.02 | cast stepping granularity; `uptime_seconds` is a multiple of it |
| `rerun` | 0.0001 | relative drift allowed between two runs of the same revision |
| `regression` | 0.02 | relative drop a later report may show before it counts as a regression |

`MAX_CAST_SECONDS` (40 s) bounds a cast that never reports itself finished; such
a row fails the `cast_completed` check rather than hanging the run.

## What turns a report red

`UltimateEffectivenessRunner.violations()` — absolute, no baseline needed:

- row count is not 51, class count is not 17, or a class does not carry 3 weapons;
- a duplicate key, an empty class/weapon id, or a key that disagrees with them;
- `resolution_source` is not `weapon_profile` (a legacy-substituted row);
- `executor_present` is false;
- a missing scenario, a missing metric, or a metric that is not finite and non-negative;
- `cast_completed` false, or `targets_struck` above the probe count;
- `boss_cap_ratio` outside [0, 1];
- `reference_solo_dps` not positive, an unknown power archetype, a boss cap
  outside the frozen [0.05, 0.15], or readiness outside 3…4 encounters;
- solo `effect_total` of zero — the "no skipped row" statement.

`UltimateEffectivenessRunner.regressions()` — baseline vs later report:

- a row present in the baseline and missing from the report, or the reverse;
- any effect metric that dropped by more than the regression tolerance, unless
  the later row states why in its own `regression_reason`.

`uptime_seconds` is deliberately outside the regression set: a shorter cast is a
design choice, not a loss of impact.
