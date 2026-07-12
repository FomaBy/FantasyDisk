# Release 0.2.1 Announcement Image

Status: accepted for FAN-1027.

## User-facing focus

- 154 artifacts in the completed artifact system, including 85 class-specific artifacts.
- 17 playable heroes and 51 weapons with distinct mechanics and build identities.
- A horizontal route map and a shorter two-act run structure.

## Art direction

Create a premium 16:9 FantasyDisk announcement poster. The right half is the
cinematic focal scene: a battle-worn hero party facing a colossal dragon above
a glowing horizontal branching route, with a handful of legendary relics
orbiting the path. The left half stays dark, calm, and empty for final copy.

Style: D&D dark fantasy dragon key art, realistic lighting and materials,
brutal but elegant, black iron, obsidian, worn gold, deep crimson, blue-violet
magic, subtle embers, clear silhouettes, restrained detail density. No text,
numbers, letters, logos, pseudo-runes, watermarks, labels, UI cards, or opaque
content boxes in the generated base layer.

Strict empty content interiors in the final 1920×1080 canvas:

- release: `x=100 y=64 w=760 h=82`
- brand logo: `x=100 y=174 w=840 h=140`
- subtitle: `x=104 y=352 w=870 h=60`
- highlights: `x=100 y=462 w=880 h=344`
- footer: `x=100 y=952 w=770 h=56`

Decorative art, characters, relics, weapons, bright highlights, seams, smoke,
and ornaments must stay outside these rectangles. The empty areas may contain
only a continuous calm near-black atmosphere matching the scene.

Planning gate: `ready_for_image` (`ok=true`, zero errors, zero warnings).

Generation target: PixelLab MCP `create_ui_asset`, 688×384 source PNG (the
service's exact 16:9 maximum), full-canvas background retained, then
high-quality resize to 1920×1080.
Canonical tag/name: `release_0_2_1_announcement`.

Accepted PixelLab source: `faaec6cf-de1f-4ffb-9a15-2326923918e5`
(`release_0_2_1_announcement_variant_b`). The baked checkerboard outside the
generated ornamental frame is removed with crop `(23, 18, 665, 368)` before
Lanczos resize. No new panels, frames, cards, or opaque backing boxes are added
after generation.
