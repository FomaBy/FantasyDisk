# Empty-frame source inspection

Selected source: PixelLab drawing `0d0cbdac-0034-44ca-a495-0d09ee5707b0`, downloaded as `base.png` (512 × 512 PNG, opaque RGBA). SHA-256: `6283bd9afbc0c14b777a16ffaa9c767f4dd0db50fb14bc144f7d13312e6c1892`.

The refreshed plan gate is `ready_for_image` with `ok: true`, zero errors and zero warnings. The final image was viewed at native size and in PixelLab Workbench's 2× crop (`image_id` `99c86db0-592e-4d74-a547-1458230a8d0b`). The three upper zones, two lower zones, and central disk are spatially separated; no text, pseudo-text, logo, watermark, or ornament enters a content zone.

The five uniformly scaled plan rectangles are pixel-flat `#211F2BFF`:

- Game title: `x=42, y=47, w=125, h=47`.
- Version: `x=193, y=47, w=125, h=47`.
- Release date: `x=345, y=47, w=125, h=47`.
- Main highlights: `x=47, y=218, w=190, h=161`.
- World and animation: `x=275, y=218, w=190, h=161`.

An exact pixel read found one RGBA color in each complete zone. The full canvas is opaque (`alpha=255` throughout) and uses an 11-color palette. The cracked disk stays in the free central band.

PixelLab Pro currently caps square output at 512 × 512, while the approved final plan is 1350 × 1350. This source preserves the plan's uniform `512/1350` geometry. No resize, text composite, final poster render, repository edit, or release candidate was made in this stage.

Three AI image outputs were retained as rejected attempts because their frame/emblem pixels crossed planned zones. They remain separate from the selected source; their job IDs, asset IDs, hashes, and reported generation usage are in `generation_manifest.json`.
