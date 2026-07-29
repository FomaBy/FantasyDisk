# Engineer weapon ultimate presentation pack

Class-local presentation for the three engineer weapon ultimates. The pack owns
engineer data only: timing rhythm, formation motion, class-local element frames,
and this provenance record. Immutable profile, presentation, and cast-phase IDs
stay owned by the v1 weapon-ultimate registry.

## The three timelines

| Weapon | Title | Silhouette | Motion | Impact |
| --- | --- | --- | --- | --- |
| `engineer_sentry_wrench` | Крепость за Секунду | tall narrow pylon, hexagonal turret head | ground tap, six pylons rise in place on a fixed hexagon | synchronized turret volleys along hex chords |
| `engineer_repair_drone` | Рой Аварийного Ремонта | wide flat rotor bar over a small orb body | canister column unwinds into two counter-phased helix strands | alternating intercept and ram streaks, then a protective dome |
| `engineer_pressure_mines` | Минное Поле Омега | squat prong-topped dome on a wide base plate | blueprint lattice flashes, mines burrow up in place | ordered outer-to-inner chain detonation |

The three are deliberately not one timeline in three colors. They differ in
element proportion (0.417 / 2.019 / 1.333 width-to-height), formation kind
(fixed hexagon / travelling helix / static lattice), rhythm shape, and impact
sound. `engineer_ultimate_presentation_test.gd` fails if any of those collapse.

## Phase rhythm

Values are phase start times in seconds. The shared schema requires them to be
monotonic and inside `max_timeline_seconds = 10.0`.

| Weapon | windup | release | active | recovery | cancel | total |
| --- | --- | --- | --- | --- | --- | --- |
| `engineer_sentry_wrench` | 0.00 | 0.35 | 0.70 | 4.60 | 5.10 | 5.10 |
| `engineer_repair_drone` | 0.00 | 0.55 | 1.05 | 5.40 | 6.10 | 6.10 |
| `engineer_pressure_mines` | 0.00 | 0.90 | 1.70 | 3.10 | 3.60 | 3.60 |

The wrench telegraphs briefly and holds the longest crossfire, the swarm opens
slowest and trails the longest dome, and the mine field telegraphs longest and
detonates in the shortest burst.

Each presentation phase references the exact frozen `phase_id` from
`data/ultimates/schema/v1/classes/engineer.json` through the schema bindings
`windup -> windup`, `release -> execute`, `active -> active`,
`recovery -> recover`, `cancel -> cleanup`. The pack binds to those phase IDs,
not to numeric telegraph or damage windows: the engineer profiles on `dev` carry
`implementation_state = "declared"`, `strategy_id = "unbound"`, and `params = {}`,
so no numeric window exists yet. Mechanics introduce them separately and join by
ID.

## Budgets

- **Crowd cap.** `MAX_ELEMENTS_PER_ULTIMATE = 16`. One cast places at most 16
  sprites (6 pylons, 12 microdrones, 16 mines), and the driver clamps the
  formation to that cap rather than trusting the data.
- **Readability.** The smallest element span stays at or above 6 px on the
  648p floor and scales up through 720p, 1080p, and 2K. The mine telegraph in
  particular is drawn large enough to read as safe-lane guidance rather than as
  decoration.
- **Pivots.** Ground-planted elements use a low pivot (`0.5, 0.85` pylon,
  `0.5, 0.75` mine) so they sit on their seat; the airborne drone uses
  `0.5, 0.5`.

## Lifecycle

`engineer_ultimate_timeline_scene.gd` delegates the whole lifecycle to
`WeaponUltimatePresentationTimeline`:

- `begin()` takes the caller's animation/VFX/SFX handles and owns only the
  sprites it creates itself; it never touches shared VFX pools.
- `set_paused(true)` freezes elapsed time, event emission, and the formation.
- `finish("cancel")`, `finish("death")`, and `finish("node_end")` release every
  supplied handle and free every sprite.
- Teardown releases handles on both `_exit_tree` and `NOTIFICATION_PREDELETE`,
  because a scene freed before it ever entered the tree never receives
  `_exit_tree` and would otherwise orphan its handles.
- In a headless run the timeline returns the deterministic `headless_no_op`
  result and attaches no handle.

## Runtime boundary

The shared bridge `weapon_ultimate_presentation_manifest.gd` still hardcodes
`VFX_SOURCE_PREFIX = "res://assets/sprites/effects/vfx_weapon_"` for both
`source_path` and `runtime_path`, and this pack is forbidden to edit that file.
So the class-local paths here are declared and schema-validated but are **not**
yet wired into live combat. Redirecting the shared runtime paths is unowned
follow-up work; FAN-1541 owns the shared runtime adapter.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/engineer_ultimate_presentation_test.gd
```

Regenerate the element frames and the contact sheet:

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://scenes/vfx/ultimates/engineer/engineer_ultimate_source_forge.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://scenes/vfx/ultimates/engineer/engineer_ultimate_contact_sheet.gd
```

`manifest.json` records source/runtime paths, canvases, and sha256 digests for
every generated frame, plus the accepted assets this pack reuses unmodified.
