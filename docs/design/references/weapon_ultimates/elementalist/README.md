# Elementalist weapon ultimate presentation pack

This class-local package supplies authored presentation timelines for the frozen
`elementalist/elementalist_orb_ring`, `elementalist/elementalist_prism_focus`,
and `elementalist/elementalist_meteor_core` ultimate profiles. It does not
change gameplay, balancing, profile data, the shared presentation manifest, or
runtime adapter ownership.

`manifest.json` is the provenance and timing source for this package. Every
timeline has the five required presentation groups and points at the immutable
Cast phase IDs. Its final time is at most 8.9 seconds, below the contract limit
of 10.0 seconds.

The three assets use intentionally different visual language:

- Orb ring: four tinted elemental avatars accelerate on a square orbit, fire
  four sequential cast beats, and merge into a white combined supernova.
- Prism focus: one aimed prism unfolds into a slowly rotating refraction
  lattice with staggered focus hits and a rainbow fracture shatter.
- Meteor core: a local sky veil and growing rune shadow give a long fair
  telegraph before one giant meteor leaves a pulsing crater and cooling embers.

No new raster source art was required. Each scene reuses the approved weapon
ultimate VFX sprite `assets/sprites/effects/vfx_weapon_elementalist_<id>.png`
recorded per weapon in `manifest.json`; no new PixelLab assets were generated.

The shared runtime path redirect is deliberately not included: the current
shared presentation manifest and adapter are read-only to this card, with the
adapter owned by FAN-1541. Consumers attach this package by exact weapon ID and
must call `WeaponUltimatePresentationTimeline.set_paused()` plus
`finish("cancel"|"death"|"node_end")` for lifecycle cleanup. Numeric
telegraph/damage windows stay owned by mechanics card FAN-1477; the seam is the
frozen `phase_id` set, not numbers.

The four contact sheets are rendered from the actual local scenes at 648p,
720p, 1080p, and 2K. Action-following framing fits every visible silhouette and
impact mark inside its own labeled panel. The focused headless test shares the
capture timestamps and panel geometry, and validates composition in addition to
existence, phase bindings, timing, distinction, scene animation length, asset
provenance, and per-effect crowd budgets. Runtime enforcement of those budgets
is owned by FAN-1541.
