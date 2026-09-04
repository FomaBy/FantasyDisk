# Parallel ownership map

Updated: 2026-09-05. Authority: `ADR-parallel-agent-ownership.md` and the live Multica card. This map describes path leases, not permission to start work. PM readiness, the dispatcher, and the same-card lifecycle remain control-plane concerns.

Two cards may proceed concurrently only when their declared write sets and behaviour contracts are disjoint. A broad label such as `core` is not an exclusive lease by itself. Actual shared files, generated outputs, data schemas, and observable contracts decide overlap. Integration into `dev` is always serial.

## Initial six owner-authorized slices

| Slice | Exclusive paths | Shared-contract rule |
| --- | --- | --- |
| `actor/<actor_id>` | `data/animation/<kind>/<actor_id>.json`, `tests/actors/<actor_id>_smoke_test.gd`, actor-specific sprites | Do not edit a registry facade, shared animation test, or `animation.md` without an explicit shared lease. |
| `class/<class_id>` | `scripts/classes/<class_id>_weapon.gd`, `scripts/ultimates/classes/<class_id>/**`, `data/ultimates/classes/<class_id>/**`, class tests/assets/docs | `balance/<class>` and `vfx/<class>` are the same class lease; shared legacy weapon families require a joint or serial lease. |
| `ui/<screen>` | `scripts/ui/screens/<screen>.gd`, screen-local UI scripts/scenes/tests | The facade and UI kits are shared; one task may claim at most one listed shared file. |
| `process/docs` | Exact process/design documents listed in the card | A documentation lease does not authorize gameplay or tooling edits. |
| `architecture-map` | This map, its ADR, and `technical_architecture.md` | Documentation-only; no generated inventory or tool changes. |
| `core/<bounded-surface>` | Exact named files, for example `scripts/player.gd` | Core work serializes only when it changes a shared behaviour contract. |

The six slices are a dispatch template, not a promise that all six are ready at once. Each card must still name exact paths and acceptance criteria.

## Existing split surfaces

- Animation data is per actor under `data/animation/**`; the facade remains `scripts/full_frame_animation_registry.gd`.
- Class-specific execution is under `scripts/classes/`; `scripts/class_weapon.gd` closes the inheritance chain.
- UI screen modules live under `scripts/ui/screens/`; `scripts/ui_screens.gd` is the facade.
- Per-class ultimates, tests, and design pages belong to the matching class slice.

Physical inheritance-chain files are not independent components. A module that extends another can share state, virtual methods, preload order, or a facade contract; cards touching that chain must declare the shared contract and serialize if it overlaps.

## Shared-path budget and conflict handling

A domain card may change no more than one shared path unless PM explicitly marks it `cross-domain`. Typical shared paths are `CHANGELOG.md`, `docs/design/content_registry.md`, `docs/design/systems/animation.md`, registry facades, UI kits, and progression-data files. A cross-domain card serializes with every affected lease. Do not broaden a lease during implementation: return the concrete additional path and reason for PM review.

QA reads the candidate write set but does not obtain a production-code lease. QA reports through the same card; screenshots and reports belong in Multica evidence unless the card explicitly owns an additive evidence path.

The later FD02 inventory tool is not part of this card. When it exists, use its machine-readable report to refresh this map; until then, verify paths from the current checkout and the issue's exact manifest.
