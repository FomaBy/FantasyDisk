# SCRUM-760 robot_magnetic_anchor attack VFX PixelLab Prompt Notes

PixelLab MCP tool: `create_map_object`
Object id: `80184364-0712-4722-85f0-2dbcdcbe1363`
Canvas: `256x256`, view `high top-down`, detail `high detail`, outline `selective outline`, shading `detailed shading`.

Prompt:

```text
FantasyDisk attack VFX sprite for robot_magnetic_anchor weapon, transparent background, centered circular magnetic anchor pull pulse. Dark fantasy Dungeons and Dragons + arcane machinery style: cyan-blue magnetic energy ring, subtle inward pull arrows/field lines, iron anchor-shaped spectral silhouette, small lightning sparks and metal runes, readable radial area-of-effect at game scale, calm semi-transparent center, strong silhouette, no text, no letters, no numbers, no UI frame, no watermark, no character, no background.
```

Postprocess summary:

- Raw PixelLab PNG saved as `robot_magnetic_anchor_pixellab_source_raw.png`.
- Opaque gray preview matte removed into `robot_magnetic_anchor_pixellab_source.png`.
- Runtime `assets/sprites/effects/vfx_weapon_robot_magnetic_anchor.png` uses the cleaned PixelLab magnetic field plus a low-opacity ghost of `assets/sprites/weapons/robot_magnetic_anchor.png`.
- Final runtime stays `256x256 RGBA`, transparent corners, max alpha `162`, center 64x64 mean alpha `79.77`.
- No OpenAI Images/image_gen/manual drawing path was used.
- No gameplay, balance, scene, shared script, or broad design documentation changes were made.
