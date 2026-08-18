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

## Animation source (FAN-2565, `engineer_sentry_wrench`)

The sentry wrench no longer holds one forged frame. Its element is a nine-frame
transparent animation generated with PixelLab MCP — `create_1_direction_object`
plus `animate_object`, mode `v3`, 256x256, view `sidescroller` — object
`7a713b53-f9bb-477c-b478-b4096bc17c33`, animation group
`1fda802e-eb3c-4d18-b304-09de5d50b521`. `provenance_manifest_sentry_wrench.json`
records the exact prompts, every frame digest, and the measured pack quality.

The frames are not played by an `AnimatedSprite2D`: `frame_index()` maps the
phase and its progress to a frame, so the frame is a pure function of the
timeline. A paused timeline therefore holds its frame with no extra pause
handling, and the contact sheet renders the frame the scene plays.

| Phase | Frames | What it shows |
| --- | --- | --- |
| windup | 0 | the folded pylon, still a blueprint ghost |
| release | 1 | the pylon standing up as the hexagon seats |
| active | 2..5, cycled | one muzzle flash per executor volley, 8 volleys |
| recovery | 6 | barrels cool, the head starts to fold |
| cancel | 7, 8 | shutdown vent as the ring folds out |

Runtime frames are the 256x256 source cropped to ONE shared rect — the union of
all nine alpha boxes, so the pivot never moves — then downscaled 2x with nearest
sampling to 76x118, which is the size band the forged 49x112 pylon used. Measured
on the committed pack: 9/9 distinct frames, 0 semi-transparent pixels (no matte
or halo), pivot drift 2.43 x 5.75 px, largest stray island 17 px (the vent puff),
and no frame touches the canvas edge.

The forged `engineer_sentry_pylon` frames stay in the repository and in
`manifest.json`: `engineer_ultimate_source_forge.gd` emits all three class
elements in one pass, and the other two weapons still use theirs.

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

Regenerate the element frames and the class contact sheet:

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://scenes/vfx/ultimates/engineer/engineer_ultimate_source_forge.gd
python3 tools/godot_gate.py --headless --path . \
  --script res://scenes/vfx/ultimates/engineer/engineer_ultimate_contact_sheet.gd
```

Re-shoot the four live captures. A `SubViewport` cannot render under
`--headless`, so this one runs windowed:

```bash
python3 tools/godot_gate.py --path . \
  --script res://tests/ultimates/presentation/engineer_ultimate_contact_capture.gd
```

Regenerate the sentry-wrench animation source and its runtime pack. The first
command is one blocking call of roughly ten minutes and needs
`PIXELLAB_BEARER_TOKEN`; the second is local and needs no credential:

```bash
python3 tools/fan2565_sentry_wrench_pixellab.py \
  --source-dir docs/design/references/weapon_ultimates/engineer/source/pixellab_sentry_wrench \
  --manifest-out docs/design/references/weapon_ultimates/engineer/provenance_manifest_sentry_wrench.json
python3 tools/fan2565_sentry_wrench_runtime_pack.py \
  --source-dir docs/design/references/weapon_ultimates/engineer/source/pixellab_sentry_wrench \
  --runtime-dir assets/sprites/effects/ultimates/engineer/sentry_wrench_deploy \
  --manifest docs/design/references/weapon_ultimates/engineer/provenance_manifest_sentry_wrench.json
```

`manifest.json` records source/runtime paths, canvases, and sha256 digests for
every generated frame, the PixelLab provenance of the sentry pack, the four live
capture viewports, plus the accepted assets this pack reuses unmodified.
