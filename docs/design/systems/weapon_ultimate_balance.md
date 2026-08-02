# Weapon ultimate balance: charge economy and power corridor

Status: the numeric contract is implemented, measured and frozen. It is a
declaration layer, exactly like the schema and registry foundations it sits next
to: nothing in shipped gameplay reads it yet. The 17 class mechanics packs
(FAN-1462…FAN-1495) adopt it, and the runtime adoption of the ledger inside
`scripts/player.gd` is a separate, explicitly locked change — see
"Runtime adoption" below.

The goal this contract encodes: an ultimate is **rare and very strong**. A
neutral build prepares it across 3–4 normal encounters, charge survives the
whole run, and one activation is worth 20–35 seconds of the weapon's own normal
output — capped so it can never delete a boss.

## Where it lives

| File | Role |
| --- | --- |
| `scripts/ultimates/balance/ultimate_charge_budget.gd` | The frozen numbers, and the 51 immutable fixture rows derived from them |
| `scripts/ultimates/balance/ultimate_charge_ledger.gd` | The stateful ledger: charge, per-encounter budget, activation gate, snapshot |
| `scripts/ultimates/balance/ultimate_balance_harness.gd` | Measures the 51 rows under every scenario and judges the report |
| `tests/ultimates/balance_harness_test.gd` | 51 rows, corridors, abuse scenarios, and the harness's own negative controls |
| `tests/ultimates/balance_charge_economy_test.gd` | Ledger rules plus the real runtime persistence chain |

Like `WeaponUltimateRegistry`, the balance layer takes the canonical inventory
and the budget model as injected arguments (`Budget.build_rows(PD.WEAPONS_BY_CLASS, PD)`)
instead of importing the `ProgressionData` facade, so no facade ↔ balance
preload cycle can appear later. Every fixture handed to a consumer is a deep
copy: a class pack cannot widen its own corridor by mutating what it was given.

## Charge economy

### Normalized per-weapon budget

Charge is credited from **HP actually removed** — the
`UltimateDamageResult.applied` channel the FAN-1457 foundation already
publishes — never from damage attempted. Overkill, damage-taken reductions and
elite shields therefore cannot inflate the pace.

The credit is normalized by the weapon's own reference output:

```
charge_per_removed_hp = CHARGE_PER_REFERENCE_SECOND / reference_solo_dps
```

`reference_solo_dps` is `ProgressionData.estimate_weapon_budget_for_stats(...)`
at the class's base stats with `include_ultimate = false` — the weapon's *normal*
output. Folding the ultimate back in would make the charge rate depend on the
very ultimate the rate is meant to price.

Normalization is what lets one corridor cover all 51 rows. Measured reference
output spans **14.87 dps (dark_mage/dark_wand) … 85.98 dps (ranger/hunter_trap)**,
a 5.8× spread, yet both fill the bar at the same pace.

### Taken-damage channel

Losing a full health bar across an encounter is worth
`TAKEN_CHARGE_PER_HEALTH_BAR` (8.0) before the class's existing
`ULTIMATE_CONFIGS[class].taken_charge_rate` (0.95…1.55). The channel is capped
at `TAKEN_CHANNEL_ENCOUNTER_SHARE` (35%) of the encounter cap: a tank cannot
farm readiness by standing in damage.

### Per-encounter cap and corridor

| Encounter | Neutral corridor | Hard cap |
| --- | --- | --- |
| normal | 25–35 | 35 |
| elite / boss | 35–45 | 45 |

The corridor is what a neutral build must land inside; the cap is the clamp
**every** build is subject to. Because `ceil(100 / 35) == ceil(100 / 45) == 3`,
the caps alone guarantee that no build — however invested — can be ready again
in fewer than 3 encounters. No scenario has to be trusted for that floor.

Measured neutral values across all 51 rows:

| Metric | Measured | Contract |
| --- | --- | --- |
| normal charge / encounter | 32.30 … 34.70 | inside 25–35, never pinned to the cap |
| elite charge / encounter | 39.90 … 44.70 | inside 35–45 |
| readiness | 3 … 4 normal encounters | 3–4 |

### Build channel — the Energy / `ult_charge_multiplier` / Atlas audit

`build_multiplier = clamp((1 + invested_energy × 0.025) × ult_charge_multiplier, 1.0, 1.60)`

Three findings drove this shape:

1. **Energy counted its own base.** The shipped
   `Player._gain_ultimate_charge` scales by `1 + stats.energy × 0.025`, and
   `stats.energy` includes the class base (3…6 across the roster). A neutral
   build therefore already carried a silent ×1.075…×1.15 that differed per
   class. The contract reads Energy **invested above the class base**, so a
   neutral build is exactly 1.0 for every class.
2. **`ult_charge_multiplier` stacked without a ceiling.** It is now inside the
   same clamp. A maximum build (24 invested Energy × a 1.35 run multiplier)
   resolves to the 1.60 cap, which buys "ready in 3 encounters instead of 4",
   not "ready every round".
3. **Atlas `ult_start_charge` (0.5 and 1.0) is safe as shipped.** `main.gd`
   applies meta modifiers through `apply_ascension_bonuses` only when
   `run_player_snapshot` is empty (`combat_director.gd`), i.e. once at run
   start. The keystone pre-fills the bar for the run opener and never refills
   it between battles. `ultimate_flat` is a damage-side modifier and does not
   touch the charge economy at all. The harness asserts both Atlas scenarios
   separately: they may shorten the *opener*, and they must not shorten the
   *recurring* cadence.

### Activation and the active window

* Activation is the only path that spends charge. A refused activation spends
  nothing.
* **At most one activation per encounter.** A full bar plus a whole encounter of
  further income still buys exactly one cast.
* **An active ultimate earns nothing.** The payoff window cannot pay for itself.

## Power corridor

One activation is worth `POWER_SECONDS_MIN … POWER_SECONDS_MAX` (20…35) seconds
of the weapon's own normal output, published per row as
`power_budget_min` / `power_budget_max`. The three weapons of a class price
their ultimates against **their own** solo output, so the trio keeps its
solo / AoE / defense identity instead of collapsing onto one shared number; the
fixtures also publish `reference_aoe_dps` and `reference_ehp` for the crowd-clear
and survivability sides of that trio.

Two archetypes, decided by the class's existing ultimate `duration`:

| Archetype | Classes | Contract |
| --- | --- | --- |
| `burst` | duration 0 | Damage worth 20–35 s of the weapon's own output |
| `control_save` | berserk, robot, engineer, knight, druid | An equally decisive control/defensive window, at least 4.0 s long |

The corridor is the **neutral** budget. `derived_parameters.ultimate_multiplier`
(Energy, the aggregate attribute term and `ultimate_flat`, which the Atlas can
raise by +0.75) scales an invested build above it on purpose — that is the
progression payoff. `ultimate_flat` never touches the charge side. The hard
bound on the invested end is the whole-activation boss cap below, not the
corridor.

### Whole-activation boss cap

`total_boss_cap` is the share of a boss's health pool the **entire** activation
may remove — not per hit. `UltimateActivation` already implements the budget;
the fixtures publish the number per row (0.07 … 0.11, from the class's declared
`boss_cap`, clamped to 0.05 … 0.15) so a class pack cannot widen it per weapon.
The harness rejects a class that declares more than one cap across its trio.

## Persistence

| Transition | Behaviour | Verified by |
| --- | --- | --- |
| battle → map → battle | charge survives via `run_player_snapshot` | `CombatDirector._store/_restore_player_snapshot` |
| act transition | charge survives; only `health` is healed | `Main.advance_to_next_act` |
| Continue | charge survives the autosave round-trip | `RunAutosave` + `Main.migrate_run_autosave_state` |
| pre-FAN-1460 save | no field → 0 charge | default of the same read |

Reset happens on exactly three events: a successful activation, a new run, and a
class/weapon change before the run starts.

`to_snapshot()` deliberately carries **only** the accumulated charge. The
active-effect flag and the once-per-encounter use flag are runtime state of one
battle and never cross a battle boundary — a cast interrupted by the end of a
node does not resume in the next one, and its spent use does not follow the
player.

## The harness must be able to go red

`Harness.measure()` produces the report; `Harness.violations()` judges any
report it is handed. They are separate on purpose: `balance_harness_test.gd`
feeds `violations()` nine deliberately tampered reports (row removed, corridor
broken, cap exceeded, cadence shortened, activation gate opened, overkill
inflated, taken channel overrun, boss cap widened, trio ratio broken) and fails
if any of them stays green. A harness that cannot go red would be inherited
green by all 17 class packs.

The encounter model is normalized: an encounter contains exactly the HP its own
reference output clears inside the canonical window
(`ProgressionData.BALANCE_WINDOW_SECONDS`, 30 s; 34 s for elite/boss). Swinging
harder than there is HP removes no extra HP, which is what makes the overkill
scenario a real control rather than a restatement of the neutral one.

## Runtime adoption

The ledger is a drop-in for the shipped `Player._gain_ultimate_charge` /
`activate_ultimate` pair, but `scripts/player.gd` and
`scripts/combat_director.gd` are outside this contract's write set. Adoption is
a separate change and needs, in one place each:

1. `Player.on_weapon_hit` → credit `UltimateDamageResult.applied` (HP removed)
   instead of the attempted `dealt_damage`.
2. `Player.take_damage` → route the taken channel through
   `Ledger.add_taken_health`.
3. `CombatDirector._start_combat` → `Ledger.begin_encounter(kind)` with the
   node's combat type.
4. `Player.activate_ultimate` → gate on `Ledger.try_activate()`.

Until that lands, the shipped economy keeps the pre-FAN-1460 behaviour
(attempted damage, no per-encounter cap, no activation gate) and this document
describes the contract, not the current runtime.

## Validation

```
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/balance_charge_economy_test.gd
```
