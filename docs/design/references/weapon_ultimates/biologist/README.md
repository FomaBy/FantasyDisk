# Biologist weapon ultimate presentation pack

This class-local package supplies authored presentation timelines for the
frozen `biologist/biologist_spore_lens`,
`biologist/biologist_sample_injector`, and
`biologist/biologist_symbiote_seed` profiles. It changes no gameplay, balance,
profile data, shared registry, or runtime adapter.

The three scene timelines deliberately use different shapes and rhythms:

- **Мировой Мицелий** opens the lens, crawls a three-branch fungal graph across
  the ground, grows three capped secondary blooms, then dries the network.
- **Идеальный Образец** charges a long needle rail, extracts a green-white
  sample on a straight beam, rotates a DNA helix over the target, and emits
  capped scan pulses.
- **Матка Симбионта** drops one seed, swells it into a giant pod, lashes six
  tendrils outward, orbits six larvae, and ends with a membrane rupture.

`manifest.json` records the frozen Cast phase IDs, timings, pivots implicit in
the authored scenes, and performance caps that FAN-1541 must enforce when it
connects the shared runtime adapter. Gameplay windows, adaptive damage, pulls,
roots, infections, blooms, and larval hits remain owned by FAN-1481; this
package only gives those mechanics weapon-keyed presentation seams.

No raster was generated for FAN-1480. The scenes reuse the accepted Biologist
weapon/VFX textures and add motion with bounded native Godot nodes. The manifest
records the existing PixelLab ID for the lens, the existing OpenAI source route
for the injector, and the approved source identity for the seed. Source and
runtime files outside this class package remain unchanged.

The four contact sheets are rendered from the actual scenes at 648p, 720p,
1080p, and 2K. The focused test shares the capture timestamps and panel
geometry, measures the sheet title with `ThemeDB.fallback_font`, and proves
`sheet_zone.encloses(sheet_title_rect(size))` at every resolution. It also
checks frozen phases, unique rhythms/silhouettes/motion/impact language,
scene-node budgets, capture composition, pause, headless no-op, and
cancel/death/node-end cleanup.

Focused verification:

```bash
python3 tools/godot_gate.py --headless --path . \
  --script res://tests/ultimates/presentation/biologist_ultimate_timelines.gd
```
