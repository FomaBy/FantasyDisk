# Secret Ascension Boss Source Pack Spec

Jira: SCRUM-539
Status: blocked until OpenAI Images API credentials are available.

## Visual Identity

Stable proposed ID: `secret_ascension_boss`

Working name: Secret Ascension Boss / Ancient Rift Disk Titan

Fantasy: an optional endgame wall after Act 3 on the final ascension. The boss
should feel ancient, huge, unfair at first glance but readable in motion: a
dragon-disk bone titan fused with a cracked black-gold Fantasy Disk and a
restrained violet rift core.

It must be visually distinct from:

- `rift_warden`: avoid making it mostly a robed void caster.
- `disk_devourer`: avoid a round mouth/body as the dominant silhouette.
- `bone_archon`: use bone titan motifs, but add disk/rift/dragon identity.
- `brood_mother`: no insect/spider brood silhouette.
- `ashen_colossus`: avoid magma giant as the main read.

## Source Generation Commands

Run these from the project root after `OPENAI_API_KEY` is available.

```powershell
python C:\Users\FomaE\.codex\skills\fantasydisk-asset-generator\scripts\generate_asset.py --no-task --quality high --size 1536x1536 --output bosses/secret_ascension_boss/secret_ascension_boss_source_raw.png --prompt "FantasyDisk dark fantasy D&D tabletop game boss source art, no text, no watermark. A gigantic optional endgame secret ascension boss: ancient dragon-disk bone titan fused with a cracked black-gold fantasy disk and violet rift core, readable top-down three-quarter game sprite silhouette, huge shoulders and crown horns, asymmetrical bone plates, obsidian metal ribs, glowing restrained purple-red rift fissures, one complete character centered, transparent or plain removable background, clean isolated silhouette, large simple shapes readable at gameplay camera scale, no UI frame, no ground shadow baked into the body, no tiny noisy details."
```

```powershell
python C:\Users\FomaE\.codex\skills\fantasydisk-asset-generator\scripts\generate_asset.py --no-task --quality high --size 1536x1024 --output bosses/secret_ascension_boss/secret_ascension_boss_telegraph_source_raw.png --prompt "FantasyDisk dark fantasy D&D tabletop game VFX concept sheet, no text, no watermark, no UI frame. Large fair-but-brutal boss AoE telegraphs for secret ascension boss: violet rift rings, black-gold disk sectors, crimson fracture lines, bone-white warning runes, narrow beam lane, expanding circle, cone sector, rotating disk blade warning, floor rupture cracks. Top-down combat readability, clean shapes, transparent or plain removable background, restrained palette, clear silhouettes, not noisy, suitable for Godot 2D telegraph implementation."
```

## Postprocess Targets

Expected source files:

- `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_source_raw.png`
- `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_source_clean.png`
- `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_telegraph_source_raw.png`
- `docs/design/previews/scrum539_secret_ascension_boss_contact.png`

Runtime candidate:

- `assets/sprites/bosses/secret_ascension_boss.png`

Technical target:

- PNG, RGBA transparent after cleanup.
- Source canvas: `1536x1536`.
- Runtime candidate: `512x512` or `768x768`, depending on readability after
  scale tests.
- No baked text, no UI frame, no baked HP bar, no background tile.
- Centered body with bottom-center pivot.

## Handoff Notes

Recommended implementation path: full-frame boss sprite source first, then
Animator-owned full-frame sprite sheet for idle/move/cast/attack/death. Avoid
production cutout from this single static image unless a later Design pass
delivers separated source parts.

Suggested pivot:

- Source pivot: bottom center, approximately `(768, 1320)` on the 1536 source.
- Runtime `512x512` pivot estimate: `(256, 440)`.

Suggested gameplay read:

- Runtime visual scale should read larger than current bosses.
- Use boss size profile as a starting point, but secret boss may need a larger
  authored visual radius if camera and HP bar remain readable.
- Initial collision radius target: roughly 70% of the visible torso width, not
  the horn/crown width.

Telegraph color language:

- Warning base: desaturated violet `#7D4DFF` with alpha-friendly edges.
- Danger accent: deep crimson `#B22A35`.
- Disk/gold edge: muted old gold `#B58A3A`.
- Bone/rune accent: dim bone white `#C8BFA4`.
- Avoid pure neon magenta, pure white fills, and opaque noisy floor plates.

Back-end should implement telegraphs procedurally or through dedicated VFX
sprites using these colors; Design source should not bake text or UI labels into
the telegraph art.
