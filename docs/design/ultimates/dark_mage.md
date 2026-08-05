# Dark Mage weapon ultimates

FAN-1479 makes the three frozen Dark Mage declarations executable through class-local overlays under `data/ultimates/classes/dark_mage/` and one matching executor/scene pair per weapon under `scripts/ultimates/classes/dark_mage/`. The immutable catalog IDs remain unchanged; convention discovery selects only the exact ready profile and executor pair.

## Runtime contracts

| Weapon | Exact mechanic | Active window | Bounded identity |
| --- | --- | ---: | --- |
| `dark_book` | **Abyss Mirror** selects up to 12 nearby silhouettes. After the 0.60s release each produces an original blast, and 0.45s later a delayed reflected blast lands at its mirrored point. A lethal hit may produce one reflected kill burst; kill-burst damage never enters the kill trigger, so it cannot recurse. Replayed pair events are idempotent. | 5.20s | 2 reflected and 3 kill-burst targets per pair |
| `cursed_skull` | **Cursed Crown** marks up to 14 screen-wide live targets — dead silhouettes are excluded before the cap is spent — reducing outgoing damage to 65%. It emits four curse pulses, transfers a dead target's mark once to an unmarked survivor, then harvests remaining marks. | 6.35s | 8 transfers, 260px transfer radius |
| `dark_wand` | **Vanishing Thread** captures an aimed 72px half-width rail at the 0.28s release, marks up to 10 distinct targets (duplicate entries never add a node), then collapses all marks together at 0.62s. Each distinct node raises its own collapse multiplier by 14%. | 3.85s | 65% per-target activation cap |

All three profiles use `rare_charge_ledger`, `activation_owned` cleanup, and the Dark Mage whole-activation boss cap of 11% maximum health. Every damage operation goes through `UltimateActivation`, so actual applied HP—not attempted overkill—is credited, boss caps cover every phase, and event IDs are idempotent. Book and Crown have no weaker parallel target cap; their bounded target sets are their anti-crowd boundary. The Wand's 65% focus cap additionally prevents one rail target from absorbing every collapse.

The Crown uses the shared control policy: normal targets receive the full 5.5s damage-output reduction, epic targets 2.75s, bosses 1.375s; none receive a movement lock or execute. Its status leases are removed on ordinary completion, cancellation, natural status expiry, new-run reset, and node teardown without touching other effects. The lease also owns the shared `status_marker_color` slot: while the crown color is still the one on the target, removal restores the exact prior marker (or clears a slot that was empty); a foreign marker written over the crown is preserved untouched.

## Charge and lifecycle

- The real `Player` routes all ultimate charge state through the FAN-1460 `UltimateChargeLedger`: the accumulated bar, the active-cast latch, and the encounter activation gate have one authoritative owner and no class branches.
- A full bar is spent once for one activation via `try_activate()`; active casts reject both new charge and re-entry.
- The encounter gate permits one activation per encounter and a refused cast spends nothing; the next battle's `configure_character` reopens exactly one. This is the shared FAN-1460 rule in `docs/design/systems/weapon_ultimate_balance.md` — identical for Sniper, Biologist, Engineer, Priest and Thief — not a Dark Mage exception.
- Only charge survives battle, act, and Continue snapshots (`run_player_snapshot` uses the ledger's own snapshot key). Active state, encounter-use state, tweens, effects, target marks, and status leases do not.
- Reconfiguring the real `Player` cancels the active generic controller and frees each activation-owned scene.

## Balance evidence

`dark_mage_ultimate_balance_test.gd` derives level-1 normal-weapon references with the ultimate excluded, then prices a single-target ultimate payoff against the immutable 20–35 reference-second budget. Five-target output is a declared comparison rail: one Book pair with reflected/kill targets, five Crown marks, or the first five Thread nodes. Defense is equivalent enemy-output-reduction seconds, not player EHP.

| Weapon | Ultimate solo | Solo ratio | 5-target output | AoE ratio | Crowd cap | Defense | Role |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `dark_book` | 408.33 | 0.999 | 1801.45 | 0.720 | 12 | 0.00s | bounded paired blast |
| `cursed_skull` | 415.53 | 0.998 | 2077.64 | 0.815 | 14 | 1.93s | broad curse/control bridge |
| `dark_wand` | 411.24 | 1.006 | 2631.91 | 1.048 | 10 | 0.00s | aimed ramping chain |
| Class mean | — | 1.001 | — | 0.861 | normalized 1.000 | 0.64s | composite 0.966 |

The individual solo payouts and class composite are inside the declared 0.90–1.10 corridor. The Book, Crown, and Wand AoE corridors are 0.65–0.80, 0.75–0.90, and 1.00–1.10 respectively; this keeps their roles distinct without letting the crowd-specialist erase the other two niches. The balance proof also mutates Book's direct coefficient to verify that an over-budget configuration goes red. These corridor figures are declared-capacity arithmetic against the frozen budget rows; the runtime behavior behind them — real caps binding, real Enemy damage, real Player lifecycle — is certified by the mechanics and live suites, not by this table.

## Presentation boundary

The executors emit the accepted frozen phase event IDs through `activation.present` exactly once per cast and exactly at the frozen manifest chronology: `dark_book.execute/active` at 0.60/1.05 (release / first delayed reflection), `cursed_skull.execute/active/recover` at 0.85/1.35/5.55 (crowning / settled aura / harvest), and `dark_wand.execute/active` at 0.28/0.62 (rail beam / joint collapse). Conditional per-instance visuals use executor-local beat IDs (`.mirror`, `.transfer`, `.mark`), never frozen phase IDs. The generic host adapter renders primitive shapes and tags every spawned primitive with its exact event id (`ultimate_event_id` meta), so required event identity stays observable without class branches. The class-local runtime scenes are activation-owned; the shared presentation bridge remains its existing FAN-1541 integration boundary.

## Executable evidence

```text
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/dark_mage_ultimate_package_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/dark_mage_ultimate_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/dark_mage_ultimate_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/dark_mage_ultimate_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/registry_contract_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_charge_economy_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/controller_player_integration_test.gd
```
