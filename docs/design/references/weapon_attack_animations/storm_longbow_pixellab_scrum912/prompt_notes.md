# SCRUM-912 PixelLab prompt/spec

Production source: PixelLab MCP only. `get_balance` config smoke and
`tools/list` passed without exposing secrets. No OpenAI Images, `image_gen`,
legacy `generate_asset.py` or hand-drawn raster fallback was used.

## Source object

PixelLab object: `5499b202-53d7-4e82-a175-07983f464776`
Logical tag: `storm_longbow`
Tool: `create_1_direction_object`
Style reference: `assets/sprites/weapons/storm_longbow.png`

Prompt:

> FantasyDisk storm_longbow attack VFX source, east-facing top-down combat
> effect. A spectral dark-fantasy longbow release flash at the left-side origin
> fires exactly five distinct lightning arrowheads and narrow trails toward the
> right in a restrained 34-degree fan: outer offsets about minus 17 and plus 17
> degrees, inner offsets minus 8.5 and plus 8.5 degrees, one center arrow. Show
> piercing through-hit sparks continuing behind struck silhouettes, but no
> enemies or characters. Cold cyan-blue storm electricity, dark steel and subtle
> dragon-rune accents, D&D dark fantasy, clean readable shapes at small combat
> scale, calm translucent center, no circular blast, no generic beam channel, no
> text, no UI frame, no background, transparent alpha, safe empty gutter on
> every edge, stable release origin/pivot near x=26 y=128.

## Release animation

PixelLab animation group: `bfaa69ca-1792-471a-bc98-7bd1e13651eb`
Export: `bd9e5428-c100-49c8-a263-ae4e2f45a054`
Tool/mode: `animate_object`, `v3`, 8 generated frames,
`keep_first_frame=false`.

Prompt:

> One restrained longbow release cycle, east-facing. Preserve exactly five
> arrows and the same 34-degree fan. Begin with the spectral bow drawing at the
> left origin, snap release, five arrowheads surge toward the right along their
> fixed narrow paths, cyan lightning trails stretch through targets, small
> through-hit sparks continue forward, then all energy fades. Keep the bow and
> origin stable; no rotation, no camera movement, no extra arrows, no circular
> blast, no character, no enemies, no text, no UI, transparent background, safe
> gutters.

## Acceptance decision

Accepted without a revision pass. The source shows a real longbow silhouette,
exactly five separate arrow trails, a narrow forward cone and clear continuation
past the arrowheads. At `x=96`, alpha segmentation produces five distinct
vertical trail clusters. The animation preserves the bow pivot while the five
arrowheads separate, continue and dissolve into low-density through-hit sparks.

The PixelLab source is intentionally east-facing. The isolated Godot visual
scene rotates the whole resource to the aim vector and scales it uniformly from
the authored `26→230 px` travel interval to the live `26→980 px` contract. Live
damage geometry remains exclusively owned by SCRUM-911.
