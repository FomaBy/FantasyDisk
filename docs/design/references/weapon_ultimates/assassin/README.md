# Assassin weapon ultimate presentation pack

This class-local package supplies timelines for the frozen
`assassin/chakrams`, `assassin/shadow_daggers`, and `assassin/venom_wire`
ultimate profiles. It does not alter gameplay, balance data, the shared
presentation manifest, or the runtime adapter.

`manifest.json` records the exact frozen Cast phase IDs and all five required
presentation phase groups. The longest timeline is 7.6 seconds, below the
10-second presentation-contract cap.

- Chakrams: eight moon discs tighten into orbit, fan out on compass arcs, and
  return as a pale crescent cut.
- Shadow daggers: freeze marks and violet afterimages resolve in a single
  crimson slash reveal.
- Venom wire: six anchors hold a green hex web before its poison snap-collapse.

No new raster asset was needed: each scene composes an approved project weapon
sprite with Godot vector effects. Therefore PixelLab was not invoked and no
PixelLab source or export ID exists for this package. `manifest.json` keeps the
source/runtime paths and this rationale together.

Consumers bind by exact weapon ID and must forward pause to
`WeaponUltimatePresentationTimeline.set_paused()` and call
`finish("cancel"|"death"|"node_end")`. The shared runtime adapter remains the
responsibility of FAN-1541.

The contact sheets are captured from the three actual local scenes at 648p,
720p, 1080p, and 2K. The focused headless test validates phase bindings,
timings, distinction, scene budgets, evidence dimensions, pause, headless
fallback, and all cleanup reasons.
