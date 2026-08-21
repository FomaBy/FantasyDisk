# Sniper weapon ultimate timelines

The three Sniper timelines are runtime-bound through the shared weapon ultimate
presentation manifest. Their visual contract is part of the gameplay package:
each record supplies the same V2 envelope to the validator and runtime adapter
as its class-local executor.

| Weapon ID | Visual language | Windup / active / total |
| --- | --- | --- |
| `sniper_deadeye_rifle` | held breath → full-arena tracer → endpoint crack | 0.75 / 1.25 / 2.90 s |
| `sniper_spotter_scope` | sky locks → arena-wide artillery grid → collapse point | 0.85 / 1.55 / 3.40 s |
| `sniper_shatter_rounds` | crystal fan → five expanding waves → dissipating shards | 0.65 / 1.30 / 3.10 s |

All three use an explicit full-screen footprint, Sniper's glacial-crimson
palette, a hero cast pose, a weapon-specific silhouette, backdrop treatment,
camera shake, time-scale dip, and first-impact hitstop (100/120/90 ms). The
release points differ by at least 0.1 s and all active windows exceed 1.2 s.

The local timeline runner owns `begin()`, pause freezing, and
`finish("cancel" | "death" | "node_end")`; it does not own shared pooling or
damage. Presentation details are bounded by each scene's `visual_contract` and
remain readable at 648p, 720p, 1080p, and 2K without reaching the HUD zone.
