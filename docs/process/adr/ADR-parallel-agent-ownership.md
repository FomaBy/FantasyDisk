# ADR: Parallel agent ownership domains

Status: accepted. Original decision: FAN-3638, 2026-08-28. Historical audit base: `dev@fef0e5e5c` (early sample `dev@948b4459`). Reconciled: 2026-09-05.

## Context

The historical 300-commit audit found frequent collisions in central files: `scripts/full_frame_animation_registry.gd` (22 touches), `build/ultimate_effectiveness_baseline.json` (19), `tests/animation_smoke_test.gd` (18), `docs/design/systems/animation.md` (17), `CHANGELOG.md` (17), and `docs/design/content_registry.md` (11). The old monoliths were also hot spots: `ui_screens.gd` (~16,993 lines), `class_weapon.gd` (~5,996), `player.gd` (4,295), `enemy.gd` (1,950), and `runtime_smoke_test.gd` (~9,997).

Those figures are historical evidence, not current architecture measurements. At baseline `a53a521604cd7ab7137733838cdda11b3efaf71e`, the facades are now `ui_screens.gd` (50 lines) and `class_weapon.gd` (46 lines); the large runtime components remain `player.gd` (4,295), `enemy.gd` (1,950), `main.gd` (1,842), `route_map_screen.gd` (1,574), and `combat_director.gd` (1,493).

## Decision

Use explicit, disjoint path leases for actor, class, UI, documentation, and bounded core work as defined by `ownership_map.md`. Ownership is based on exact paths and shared behaviour contracts, not a broad category label. The first six authorized slices are listed there. A task needing a second shared file or another domain is marked `cross-domain` and serializes with all affected leases.

Actor data is per file in `data/animation/<kind>/<actor_id>.json`; class executors and ultimate data are per class; UI screens are per-screen modules behind a facade; additive per-actor and per-class tests avoid shared test monoliths. An inheritance-chain split is physical layout, not proof of independent behaviour: facade, state, virtual API, preload order, and shared kits remain one contract where applicable.

## Invariants and consequences

- Preserve public APIs, canonical IDs, save formats, observable RNG order, art provenance, localisation, gameplay, and balance values.
- New GDScript includes `.gd.uid`; no `.godot` material is committed.
- Ratchets and contract tests may not be weakened to make a change pass.
- Every candidate follows same-card independent QA and exact-content serial integration into `dev`; developers do not select QA or integrate their work.
- `core` is a routing hint, not a global lock. Actual overlapping files or contracts serialize; disjoint core paths may be independently assessed.

The FD02 inventory tool is a follow-up, not a dependency. Once published, its report becomes the preferred source for current counts and lease candidates.
