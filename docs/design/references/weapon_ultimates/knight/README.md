# Knight weapon ultimate presentation pack

This class-local package supplies authored presentation timelines for the frozen
`knight/long_spear`, `knight/tower_shield`, and `knight/holy_flail` ultimate
profiles. It does not change gameplay, balancing, profile data, the shared
presentation manifest, or runtime adapter ownership.

`manifest.json` is the provenance and timing source for this package. Every
timeline has the five required presentation groups and points at the immutable
Cast phase IDs. Its final time is at most 8.6 seconds, below the contract limit
of 10.0 seconds.

The three assets use intentionally different visual language:

- Long spear (Стена Копий): a spear plant opens an aimed corridor, three ghost
  phalanx ranks charge through it at offset beats with sequential pierce-pin
  chevrons, and a banner line marks the recovery.
- Tower shield (Непроходимый Рубеж): the shield expands into a giant frontal
  wall with a crenellated rampart, pushes forward slowly while guard sparks
  accumulate, and releases the stored charge as one counter crescent slam.
- Holy flail (Небесная Спираль): the chain climbs upward, a luminous spiral
  grows from the feet to arena radius with inward pull glints on early loops,
  and the final swing flashes a sunburst launch ring before the chain retracts.

No new raster source art was required. Each scene reuses the approved weapon
VFX sprite `assets/sprites/effects/vfx_weapon_<id>.png` recorded per weapon in
`manifest.json`; no new PixelLab assets were generated.

The shared runtime path redirect is deliberately not included: the current
shared presentation manifest and adapter are read-only to this card, with the
adapter owned by FAN-1541. Consumers attach this package by exact weapon ID and
must call `WeaponUltimatePresentationTimeline.set_paused()` plus
`finish("cancel"|"death"|"node_end")` for lifecycle cleanup. Numeric
telegraph/damage windows, pin/stagger rules with the boss exemption, the stored
prevented-damage counter, and pull/launch numbers stay owned by mechanics card
FAN-1489; the seam is the frozen `phase_id` set, not numbers.

The four contact sheets are rendered from the actual local scenes at 648p,
720p, 1080p, and 2K. Action-following framing fits every visible silhouette and
impact mark inside its own labeled panel, and the sheet title is centered from
its measured text width for every resolution. The focused headless test shares
the capture timestamps and panel geometry, and validates composition and
title/label text bounds in addition to existence, phase bindings, timing,
distinction, scene animation length, asset provenance, and per-effect crowd
budgets. Runtime enforcement of those budgets is owned by FAN-1541.
