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

Sword owns an isolated PixelLab animation source generated for FAN-2544: nine
transparent 256x256 frames of one scarlet spectral greatsword under
`source/pixellab_sword`, runtime copies and SpriteFrames under
`assets/sprites/effects/fan2544_sword_ultimate`. The three-blade whirlwind stays
a runtime composition, so the blade identity is generated once and instanced
three times. `provenance_manifest_sword.json` records the object and
animation-group IDs, the exact prompts, the two animation groups rejected on
identity morph, and the measured frame verification. Axe and hammer retain the
accepted PixelLab source packs from SCRUM-895; their object and animation-group
IDs are recorded in `manifest.json`. The PixelLab MCP configuration smoke
(`get_balance`) passed during this package.

Two v3 animation groups were rejected before the accepted one: both replaced the
scarlet blade with grey stone in the middle of the cycle. Naming the unwanted
materials in the prompt did not suppress them — describing the blade positively
as red fire with a white-hot core did. Because the object then carried several
animation groups, `pixellab_generate_pack.py` and `fan2541_chakrams_pixellab.py`
both re-downloaded the first group in the report while reporting success;
`tools/fan2544_sword_pixellab.py` takes `--group-id` and fetches exactly the
named group.

The shared runtime path redirect is deliberately not included: the current
shared presentation manifest and adapter are read-only to this card, with the
adapter owned by FAN-1541. Consumers attach this package by exact weapon ID and
must call `WeaponUltimatePresentationTimeline.set_paused()` plus
`finish("cancel"|"death"|"node_end")` for lifecycle cleanup.

Sword also carries a measured `quality` record in `manifest.json` (coverage, HUD
clearance, reduced-motion substitute, flash rate); the focused test holds it to
the same numbers `UltimateVisualDirectionContract` applies to every other weapon
ultimate. Axe and hammer receive their records with FAN-2545 and FAN-2546.

The four contact sheets are rendered from the actual local scenes at 648p,
720p, 1080p, and 2K. Action-following framing fits every visible silhouette and
impact mark inside its own labeled panel. The focused headless test shares the
capture timestamps and panel geometry, and validates composition in addition to
existence, phase bindings, timing, distinction, scene animation length, asset
provenance, and per-effect crowd budgets. Runtime enforcement of those budgets
is owned by FAN-1541.
