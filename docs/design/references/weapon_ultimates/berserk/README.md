# Berserk weapon ultimate presentation pack

This class-local package supplies authored presentation timelines for the frozen
`berserk/sword`, `berserk/axe`, and `berserk/hammer` ultimate profiles. It does
not change gameplay, balancing, profile data, the shared presentation manifest,
or runtime adapter ownership.

`manifest.json` is the provenance and timing source for this package. Every
timeline has the five required presentation groups and points at the immutable
Cast phase IDs. Its final time is at most 8.15 seconds, below the contract limit
of 10.0 seconds.

The three assets use intentionally different visual language:

- Sword: three red spectral blades expand around the hero, then cross inward.
- Axe: one giant rune-chained axe travels to the aim boundary and returns.
- Hammer: three heavy beats produce cardinal lanes, diagonal lanes, and a quake.

No new raster source art was required. Sword reuses the approved two-handed
weapon sprite. Axe and hammer retain the accepted PixelLab source packs from
SCRUM-895; their object and animation-group IDs are recorded in `manifest.json`.
The PixelLab MCP configuration smoke (`get_balance`) passed during this package.

The shared runtime path redirect is deliberately not included: the current
shared presentation manifest and adapter are read-only to this card, with the
adapter owned by FAN-1541. Consumers attach this package by exact weapon ID and
must call `WeaponUltimatePresentationTimeline.set_paused()` plus
`finish("cancel"|"death"|"node_end")` for lifecycle cleanup.

The four contact sheets are rendered from the actual local scenes at 648p,
720p, 1080p, and 2K. Action-following framing fits every visible silhouette and
impact mark inside its own labeled panel. The focused headless test shares the
capture timestamps and panel geometry, and validates composition in addition to
existence, phase bindings, timing, distinction, scene animation length, asset
provenance, and per-effect crowd budgets. Runtime enforcement of those budgets
is owned by FAN-1541.
