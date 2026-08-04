# A5 conditional-final fragment (FAN-1513)

`conditional_final_convergence.json` is the standalone behavioural fragment for
the conditional final families — summon, summon-death, deploy, mine, kill and
execute. It is produced by, and only by, the pack under
`tools/a5/scenarios/conditional/`; it does not feed the canonical FAN-1438
`report.md` / `per_weapon.csv` / `raw.json.gz` artifacts and does not change any
production balance value.

Regenerate:

```
python3 tools/godot_gate.py --headless --path . \
    --script res://tools/a5/scenarios/conditional/conditional_final_probe.gd
```

The probe runs every matrix pair twice on the same seed — once with the weapon
final purchased and once with exactly that one node removed — and writes the
fragment only when every pair passes the A/B oracle. Adding `--pair=<class>/<weapon>`,
`--seeds=N` or `--window=S` makes the run a diagnostic that prints but writes
nothing.

Verify without re-running the simulation:

```
python3 tools/godot_gate.py --headless --path . \
    --script res://tests/a5/scenarios/conditional_final_pack_test.gd
```

Reading the numbers: `trigger_resolutions` and the per-seed series are the
behavioural evidence and are stable run to run. `final_event_damage` is the
damage attributed to the mechanic under test. `ledger_damage` is the arm's total
applied damage and its enabled/disabled delta is context only — a final often
substitutes for baseline output instead of adding to it, and the totals also move
with the host machine's frame pacing, so the oracle never asserts on that delta.
