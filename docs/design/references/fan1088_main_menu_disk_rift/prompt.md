# FAN-1088 PixelLab Source Prompts

## Shared production contract

- Product: FantasyDisk.
- Use: main-menu background art layer at 2560x1440 (16:9).
- Direction: D&D dark fantasy dragon, cold moonlit navy/charcoal palette,
  restrained violet magic, readable silhouettes.
- Composition: one canonical character stands on a cliff above a disk-shaped
  dimensional rift; the title and six runtime actions remain separate Godot
  controls over the calm left side.
- Forbidden: text, labels, logos, buttons, panels, watermarks, extra characters,
  baked UI, orange ember noise.

## PixelLab cliff object

PixelLab map-object ID: `c4c27ed8-71bb-4e83-82c3-5ccacd5aec20`

> A single monumental jagged basalt cliff ledge seen from the side, broken
> slate strata and dragon-scale rock shapes, narrow flat summit where one hero
> can stand, underside tapering into darkness, Dungeons and Dragons dark
> fantasy, cold moonlit navy and charcoal palette with subtle violet rim light,
> clean readable silhouette, isolated object, no characters, no portals, no
> text, no symbols, no watermark.

Generation settings: 400x400, side view, lineless, detailed shading, high detail.

## PixelLab disk-rift object

PixelLab map-object ID: `b3856aa4-8798-4bc3-a5fd-eae710ca9ae6`

> An enormous thin disk-shaped dimensional rift seen at a steep oblique angle
> from above, luminous violet-blue circular fracture with a black center,
> concentric broken arc energy and restrained magical mist, Dungeons and
> Dragons dark fantasy, clean readable elliptical silhouette, isolated object,
> no characters, no ground, no text, no symbols, no watermark.

Generation settings: 400x400, high top-down view, lineless, detailed shading,
high detail.

## Existing canonical character source

The standing figure is the north-facing PixelLab Berserk source already shipped
with FantasyDisk:

- PixelLab character ID: `8486ce45-f749-4c63-9a6d-f0477d619c2d`
- Runtime source: `assets/sprites/characters/full_frame/berserk_pixellab/berserk_idle_north.png`
- Pose intent: back to camera, looking down into the rift.

## Postprocessing contract

The two raw map-object exports contained flat generated canvas colors despite
the MCP response declaring a transparent background. The accepted alpha files
remove those flat colors and isolated sub-96-pixel artifacts, retain the large
generated silhouettes, and are composited without redrawing the generated
objects. The final background uses only the character-free left sky crop from
the previous runtime background as a subdued atmospheric underlay.
