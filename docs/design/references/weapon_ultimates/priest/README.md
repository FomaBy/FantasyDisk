# Priest weapon ultimate presentation pack

This class-local package supplies authored presentation timelines for the frozen
`priest/priest_reliquary`, `priest/priest_censer`, and `priest/priest_chime`
ultimate profiles. It does not change gameplay, balancing, profile data, the
shared presentation manifest, or runtime adapter ownership.

`manifest.json` is the provenance and timing source for this package. Every
timeline has the five required presentation groups and points at the immutable
Cast phase IDs. Its final time is at most 8.6 seconds, below the contract limit
of 10.0 seconds.

The three assets use intentionally different visual language:

- Reliquary: the shrine opens with a ray burst, three consecration rings grow
  outward in stately beats with an orbiting rune crown, then one vertical
  judgment pillar resolves into a soft heal-shield halo.
- Censer: a chain unwinds and the giant censer orbit accelerates inside a
  thickening smoke ward while stored-light beads grow, ending in a censer slam
  and one holy counter wave.
- Chime: the hand bell swings three staccato toll arcs — a silver interrupt
  fan, a gold zigzag chain smite, and a wide white dawn wave with a cross
  guard sigil — before a celestial mote dissolve.

No new raster source art was required. Each scene reuses the approved weapon
ultimate VFX sprite `assets/sprites/effects/vfx_weapon_priest_<id>.png`
recorded per weapon in `manifest.json`; no new PixelLab assets were generated.

The shared runtime path redirect is deliberately not included: the current
shared presentation manifest and adapter are read-only to this card, with the
adapter owned by FAN-1541. Consumers attach this package by exact weapon ID and
must call `WeaponUltimatePresentationTimeline.set_paused()` plus
`finish("cancel"|"death"|"node_end")` for lifecycle cleanup. Numeric
telegraph/damage windows stay owned by mechanics card FAN-1485; the seam is the
frozen `phase_id` set, not numbers.

The four contact sheets are rendered from the actual local scenes at 648p,
720p, 1080p, and 2K. Action-following framing fits every visible silhouette and
impact mark inside its own labeled panel, and the sheet title is centered from
its measured text width. The focused headless test shares the capture
timestamps and panel geometry, and validates composition — including
`sheet_zone.encloses(sheet_title_rect(size))` per resolution — in addition to
existence, phase bindings, timing, visual distinction (silhouette, motion path,
and impact language), and pairwise distinct timing rhythm (total length and
active window, each separated by an explicit minimum threshold), scene animation
length, asset provenance, and per-effect crowd budgets. Runtime enforcement of
those budgets is owned by FAN-1541.
