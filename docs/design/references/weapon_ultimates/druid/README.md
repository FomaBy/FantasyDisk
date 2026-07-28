# Druid weapon ultimate presentation pack

This class-local package supplies authored presentation timelines for the frozen
`druid/summon_amulet`, `druid/briar_staff`, and `druid/raven_totem` ultimate
profiles. It does not change gameplay, balancing, profile data, the shared
presentation manifest, or runtime adapter ownership.

`manifest.json` is the provenance and timing source for this package. Every
timeline has the five required presentation groups and points at the immutable
Cast phase IDs. Its final time is at most 9.2 seconds, below the contract limit
of 10.0 seconds.

The three assets use intentionally different visual language:

- Summon amulet — Дикая Охота: an amulet howl opens a hunt sigil, eight
  spectral beasts burst outward along the eight compass directions, sweep the
  arena on curved hunting trails, and leap back into the sigil, which swallows
  them without leaving anything behind.
- Briar staff — Лес за Одно Дыхание: the staff slams the ground, five roots race
  outward one after another, connected bramble walls grow between their tips and
  leave readable gaps as safe paths, and thorn crowns burst and then wither.
- Raven totem — Ночь Тысячи Крыльев: the totem opens black wings, three
  counter-rotating raven arcs layer into a vortex that never blacks out the
  screen, marked prey pulses under staggered dive streaks, and the flock
  collapses into one final pulse.

Rhythms are deliberately unlike each other: the amulet is a fast howl-and-burst
with a snapped return, the staff is a heavy slam with slow sequential growth and
a long hold, and the totem is a slow open with layered accumulation and
staggered dives before a single collapse beat.

No new raster source art was required. Each scene reuses the approved weapon
ultimate VFX sprite `assets/sprites/effects/vfx_weapon_<weapon_id>.png` recorded
per weapon in `manifest.json`; no new PixelLab assets were generated.

The shared runtime path redirect is deliberately not included: the current
shared presentation manifest and adapter are read-only to this card, with the
adapter owned by FAN-1541. Consumers attach this package by exact weapon ID and
must call `WeaponUltimatePresentationTimeline.set_paused()` plus
`finish("cancel"|"death"|"node_end")` for lifecycle cleanup. Numeric
telegraph/damage windows, summon caps, boss control caps, and the wisp return
stay owned by mechanics card FAN-1495; the seam is the frozen `phase_id` set,
not numbers.

The four contact sheets are rendered from the actual local scenes at 648p, 720p,
1080p, and 2K. Action-following framing fits every visible silhouette and impact
mark inside its own labeled panel, and each sheet title is centered on its
measured text width rather than a hand-tuned constant. The focused headless test
shares the capture timestamps, panel geometry, and title metrics, and validates
composition and text bounds in addition to existence, phase bindings, timing,
distinction, scene animation length, asset provenance, and per-effect crowd
budgets. Runtime enforcement of those budgets is owned by FAN-1541.
