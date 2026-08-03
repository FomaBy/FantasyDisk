# Thief weapon ultimates

Status: the three exact Thief packages are ready. Each class-local JSON overlay
is paired with one executor and its accepted presentation scene. The generic
registry discovers the pairs without edits to Player, ClassWeapon, the shared
registry, or the canonical 51-profile catalog.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `thief_coin_pouch` | Джекпот Короля | Thirteen coins choose unique nearby silhouettes, lose 12% damage per hop, and return in one final burst. Every third resolved hit awards one gold through the existing player money API, capped at four per cast. |
| `thief_shadow_cloak` | Безмолвный Приговор | Up to eight highest-HP silhouettes receive death marks. Shadows stab in sequence with a 12% escalation; where fewer than eight bodies exist, the priority body receives the remaining stabs, producing the intended boss duel cadence. |
| `thief_smoke_bomb` | Идеальное Ограбление | A four-second dome grants `+0.34 dodge_flat` (subject to the normal dodge cap), marks up to five nearby enemies with decoy/ranged-lock metadata, and collapses their stolen pressure once at expiry. |

The three play patterns differ on targeting, cadence, crowd shape, and defense:
coin is an immediate unique-target chain, cloak is escalating priority-target
pressure, and smoke is a defensive hold followed by a delayed local collapse.

## Runtime contract

- Every package uses `ultimate_charge_ledger`: one full-bar spend, no charge
  income while active, one cast per encounter, and only charge persists through
  battle, act, and Continue snapshots.
- Each profile inherits the Thief budget row's 8% total boss cap. All damage
  goes through `UltimateActivation`, so an exhausted boss budget refuses later
  events before they reach the host and `applied_total` remains actual HP
  removed.
- Coin event IDs, shadow-stab event IDs, and smoke-collapse event IDs are
  activation-stable and idempotent. A repeated animation callback cannot create
  an extra hit, gold payment, or collapse.
- Cloak and smoke status IDs include the activation node and target instance;
  teardown removes only those leases. Smoke dodge is registered with
  `apply_modifier`, so normal completion and cancellation restore the original
  dodge value.
- Coin rewards reuse the existing `gain_money()` route exposed by the Player
  host adapter; no gameplay branch or persistent modifier is introduced.

## Balance evidence

The focused proof derives `damage × ultimate_multiplier` from each selected
weapon and prices the three activation shapes against their own 20–35 second
normal-output budget. The output below is from
`tests/ultimates/mechanics/thief_balance_test.gd`.

| Weapon | Solo ratio | AoE ratio | Crowd cap | Defense contribution |
| --- | ---: | ---: | ---: | ---: |
| Coin Pouch | 1.013 | 2.192 | 13 | — |
| Shadow Cloak | 1.024 | 0.233 | 8 | — |
| Smoke Bomb | 1.008 | 1.621 | 5 | 1.36s dodge window |
| Thief trio | 1.015 | 1.349 | 1.000 | 1.007 |

The class composite is 1.093 across solo, AoE, capped crowd, and defense,
inside the 0.90–1.10 corridor. Coin owns wide ricochet pressure, cloak owns
the single-target escalating payoff, and smoke contributes the class's
survival window. The balance proof mutates the cloak stab coefficient and
requires exactly that weapon to fail, preventing an inherited always-green
result.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/thief_package_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/thief_live_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/mechanics/thief_balance_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/registry_contract_test.gd
```
