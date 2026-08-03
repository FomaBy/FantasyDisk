# Soldier weapon ultimate presentation pack

This reference pack covers the class-local mechanics and the separately authored
presentation timelines for `soldier/soldier_rifle`, `soldier/soldier_grenade`
and `soldier/soldier_bayonet`. FAN-1469 adds only exact Soldier overlay/script
pairs and focused tests; it does not change the shared presentation manifest,
presentation scenes, runtime adapter, registry, controller, or executor library.

`manifest.json` is the provenance and timing source for this package. Every
timeline covers the five required presentation groups of
`data/ultimates/presentation_schema/v1/weapon_ultimate_presentation_manifest.schema.json`
and points at the immutable Cast phase IDs of
`data/ultimates/schema/v1/classes/soldier.json`
(`release→execute`, `impact/active→active`, `recovery→recover`,
`cancel→cleanup`). The longest timeline ends at 9.1 seconds, below the contract
limit of 10.0 seconds.

The immutable base catalog still carries `implementation_state="declared"`,
`strategy_id="unbound"`, `params={}` and `legacy_class_ultimate` fallback for
all three profiles. Package discovery overlays the exact Soldier pairs as
`ready`; live catalog binding remains owned by FAN-1541. Mechanics consume the
authored phase rhythm without changing the presentation timestamps.

## Mechanics package

- Rifle captures one aim, selects the first dense formation and cuts a
  three-seat corridor through it. Three `aimed_sequence` volleys resolve over
  the authored active window, followed by activation-owned recovery to 5.6 s.
- Grenade lays seven deterministic annulus points with seed `1469`, deploys
  seven temporary nodes, then detonates them outside-in. A three-tick central
  crater closes the chain; the complete activation lasts 8.4 s.
- Bayonet selects an 18-seat aimed corridor and sends three time-offset ranks.
  Normal targets receive full displacement and pin, epic targets receive 25%
  displacement and half duration without lock, and bosses receive no
  displacement and quarter duration without lock. The activation also owns a
  25% frontal guard until cleanup at 4.25 s.

All damage flows through `UltimateActivation`, so attempted damage is clamped by
the inherited 9% whole-activation boss budget and attribution records only HP
actually removed. Per-target ledgers make grenade detonation and bayonet ranks
idempotent. Charge spending, the one-activation-per-encounter gate, persistence,
active-window earning lockout, temporary nodes, statuses, tweens, and modifiers
remain owned by the existing shared primitives.

The three assets use intentionally different visual language and rhythm:

- Rifle — «Приказ: Сплошной Огонь»: a spectral rank raises rifles behind a war
  banner and sweeps one arena-crossing lane with three evenly spaced volleys,
  then covers the retreat with smoke. 4.1 s active window over 5.6 s total — an
  even three-beat cadence.
- Grenade — «Семь Секунд до Ада»: one high lob seeds seven oversized grenades
  around the aim point, a shared fuse ring counts down in seven beats, and the
  chain detonates outside-in into a central fire column. 7.45 s active window
  over 9.1 s total — the slow-burn silhouette of the set.
- Bayonet — «Последняя Атака»: three time-offset ghost infantry ranks charge one
  aimed corridor, cross bayonets on the pin, and fall back to a rally salute
  while the hero holds a short frontal guard and never leaves the origin.
  2.88 s active window over 4.25 s total — the staccato of the set.

No new raster source art was required, so no PixelLab generation ran and
`new_pixellab_assets` is empty. All three scenes reuse the accepted project
weapon sprites `assets/sprites/weapons/soldier_{rifle,grenade,bayonet}.png`;
`manifest.json` records each source and runtime path, and the focused gate
asserts that every recorded path resolves to a real file.

The shared runtime path redirect is deliberately not included: the shared
presentation manifest and adapter are read-only to this card, with the adapter
owned by FAN-1541. Consumers attach this package by exact weapon ID and must
call `WeaponUltimatePresentationTimeline.set_paused()` plus
`finish("cancel"|"death"|"node_end")` for lifecycle cleanup.

The four contact sheets are rendered from the actual local scenes at 648p, 720p,
1080p and 2K. Action-following framing fits every visible silhouette and impact
mark inside its own labeled panel. The focused headless gate shares the capture
timestamps and panel geometry, and validates composition in addition to
existence, schema-derived phase coverage, frozen phase bindings, timing,
distinction, scene animation length, asset provenance, headless no-op and
per-effect crowd budgets. Runtime enforcement of those budgets is owned by
FAN-1541.

## Focused verification

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/soldier_package_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/soldier_runtime_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/soldier_balance_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/soldier_ultimate_timelines.gd
```

Re-render the contact sheets from a windowed run after any scene change:

```bash
python3 tools/godot_gate.py --path . \
  --script res://tests/ultimates/presentation/soldier_ultimate_contact_capture.gd
```
