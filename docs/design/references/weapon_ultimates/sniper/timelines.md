# Sniper weapon ultimate timelines

This package stages presentation-only scenes for the frozen Sniper weapon IDs.
It does not change targeting, damage, boss caps, projectile logic, or the shared
runtime manifest. `FAN-1541` (or its explicitly assigned successor) must bind
these scene-local runtime paths when the common adapter is ready.

The contact sheet is ordered left to right as **One Shot**, **Sky Grid**, and
**Crystal Storm**. It contains the accepted PixelLab-derived source used by each
timeline; `provenance_manifest.json` records its source/runtime separation and
object IDs.

| Weapon ID | Timeline | Distinct visual language | Total timeline |
| --- | --- | --- | --- |
| `sniper_deadeye_rifle` | One Shot | scope hold → one full-arena tracer → delayed endpoint crack | 1.85 s |
| `sniper_spotter_scope` | Sky Grid | nine crosshair locks → sequential descending sky beams → collapse point | 3.20 s |
| `sniper_shatter_rounds` | Crystal Storm | five-way fan → one edge ricochet → fifteen returning shards | 2.10 s |

Every definition maps `windup`, `release`, `active`, `recovery`, and `cancel`
to the exact frozen `cast_phases` IDs in `data/ultimates/schema/v1/classes/sniper.json`.
The local runner delegates `begin()`, pause freezing, and `finish("cancel" | "death" |
"node_end")` to `WeaponUltimatePresentationTimeline`; it never claims shared
pool ownership.

Readability and crowd budgets are part of each `visual_contract`: 648p, 720p,
1080p, and 2K are checked; no visual reaches the HUD zone; and the largest
scene is capped at 23 line segments, 15 concurrent emitters, and 3 sprites.
