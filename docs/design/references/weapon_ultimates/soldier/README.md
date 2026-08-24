# Soldier weapon ultimate presentation pack

This class-local package supplies authored presentation timelines for the frozen
`soldier/soldier_rifle`, `soldier/soldier_grenade` and `soldier/soldier_bayonet`
ultimate profiles. It does not change gameplay, balancing, profile data, the
shared presentation manifest, or runtime adapter ownership outside the live
exact-pair binding described below.

`manifest.json` is the provenance and timing source for this package. Every
timeline covers the five required presentation groups of
`data/ultimates/presentation_schema/v1/weapon_ultimate_presentation_manifest.schema.json`
and points at the immutable Cast phase IDs of
`data/ultimates/schema/v1/classes/soldier.json`
(`release→execute`, `impact/active→active`, `recovery→recover`,
`cancel→cleanup`). The longest timeline ends at 3.8 seconds, below the contract
limit of 10.0 seconds.

The ready Soldier overlay/script pairs are now active at
`data/ultimates/classes/soldier` and `scripts/ultimates/classes/soldier`.
Discovery admits each pair only when its profile, class/weapon identity and
executor agree, so the three live Soldier selections resolve through their
exact weapon profiles. The former staged roots were removed after activation,
so no staged Soldier runtime fallback remains.

The three assets use intentionally different visual language and rhythm:

- Rifle — «Приказ: Сплошной Огонь»: a spectral rank raises rifles behind a war
  banner and sweeps one arena-crossing lane with three evenly spaced volleys,
  then covers the retreat with smoke. 1.7 s active window over 3.2 s total — an
  even three-beat cadence.
- Grenade — «Семь Секунд до Ада»: one high lob seeds seven oversized grenades
  around the aim point, a shared fuse ring counts down in seven beats, and the
  chain detonates outside-in into a central fire column. 1.9 s active window
  over 3.5 s total — the slow-burn silhouette of the set.
- Bayonet — «Последняя Атака»: three time-offset ghost infantry ranks charge one
  aimed corridor, cross bayonets on the pin, and fall back to a rally salute
  while the hero holds a short frontal guard and never leaves the origin.
  2.1 s active window over 3.8 s total — the staccato of the set.

No new raster source art was required, so no PixelLab generation ran and
`new_pixellab_assets` is empty. All three scenes reuse the accepted project
weapon sprites `assets/sprites/weapons/soldier_{rifle,grenade,bayonet}.png`;
`manifest.json` records each source and runtime path, and the focused gate
asserts that every recorded path resolves to a real file.

The shared runtime now resolves the class-local scene by exact weapon ID,
forwards pause, and finishes it on cancel, death or node teardown. It rejects a
missing scene or a declared visual budget that cannot be honoured rather than
substituting a generic weapon texture.

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
  --script res://tests/ultimates/soldier_player_integration_test.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/soldier_ultimate_timelines.gd
```

Re-render the contact sheets from a windowed run after any scene change:

```bash
python3 tools/godot_gate.py --path . \
  --script res://tests/ultimates/presentation/soldier_ultimate_contact_capture.gd
```
