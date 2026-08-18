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

Chakrams owns a PixelLab animation source (FAN-2541): a nine-frame
transparent-background moon-chakram ring generated through PixelLab MCP
(`create_1_direction_object` + `animate_object`). The isolated source is one
ring, not the eight-disc formation — the compass orbit stays a runtime
composition, so the generated identity is instanced eight times instead of
being redrawn per disc. Frames live under `source/pixellab_chakrams/`, the
runtime copies and their `SpriteFrames` under
`assets/sprites/effects/fan2541_chakrams_ultimate/`, and object/animation IDs,
prompts, verification metrics and replay commands in
`provenance_manifest_chakrams.json`.

Shadow daggers owns the same kind of source (FAN-2542): a nine-frame
transparent-background shadow dagger whose violet edge glow pulses in place.
The isolated source is one blade, not the four-afterimage formation — the
backstab passes stay a runtime composition, so the generated identity is
instanced four times with staggered frame phases and the pulse sweeps from one
afterimage to the next. Frames live under `source/pixellab_shadow_daggers/`,
the runtime copies and their `SpriteFrames` under
`assets/sprites/effects/fan2542_shadow_daggers_ultimate/`, and the same class of
provenance record in `provenance_manifest_shadow_daggers.json`. Both cards reuse
`tools/pixellab_generate_pack.py` to create and queue the job and
`tools/fan2541_chakrams_pixellab.py` to wait on the animation frames themselves.

Venom wire still composes an approved project weapon sprite with Godot vector
effects and was not touched by either card; `manifest.json` keeps both routes,
with their source/runtime paths, side by side.

Consumers bind by exact weapon ID and must forward pause to
`WeaponUltimatePresentationTimeline.set_paused()` and call
`finish("cancel"|"death"|"node_end")`. The shared runtime adapter remains the
responsibility of FAN-1541.

The four contact sheets are rendered from the three actual local scenes at 648p,
720p, 1080p, and 2K by a windowed run of
`tests/ultimates/presentation/assassin_ultimate_contact_capture.gd`. That capture
script is a deterministic no-op under `--headless`, where the dummy driver has no
render target, so sheet production stays on the windowed run.

The focused headless test
`tests/ultimates/presentation/assassin_ultimate_timelines.gd` validates phase
bindings, timings, distinction, scene budgets, the committed sheet dimensions,
pause, headless fallback, and all cleanup reasons. It also holds each generated
pack to its provenance: the declared PixelLab IDs and paths must exist, the
`SpriteFrames` must ship the declared frame count at the generated frame size
with a transparent background, and every composed sprite — eight moons, four
dagger afterimages — must bind that exact resource and be driven by its own
frame track, so a substituted, silently reused or never-animated asset fails the
suite.

`tools/test_fan2541_chakrams_pixellab.py` covers the report parsing that decides
when generated frames are ready, offline and without a token.
