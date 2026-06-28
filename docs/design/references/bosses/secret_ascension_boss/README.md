# Secret Ascension Boss Source Pack

Jira: SCRUM-539
Status: done

## Visual Identity

Stable proposed ID: `secret_ascension_boss`

Working name: Secret Ascension Boss / Ancient Rift Disk Titan.

Fantasy: optional endgame wall after Act 3 on final ascension. The boss is a
huge dragon-disk rift titan with obsidian armor, bone/stone halo disk, dragon
horns and claws, violet rift core, and a tall readable silhouette.

It is distinct from existing bosses:

- `rift_warden`: not a robed void caster.
- `disk_devourer`: not a round maw/body silhouette.
- `bone_archon`: uses bone motifs, but adds disk/rift/dragon identity.
- `brood_mother`: no insect/spider brood silhouette.
- `ashen_colossus`: not a magma giant.

## Files

- Raw boss source: `secret_ascension_boss_source_raw.png`
- Alpha boss source: `secret_ascension_boss_source_alpha.png`
- Runtime candidate source copy: `secret_ascension_boss_runtime_candidate_1024.png`
- Runtime boss candidate: `assets/sprites/bosses/secret_ascension_boss.png`
- Raw telegraph source: `secret_ascension_boss_telegraph_vfx_source_raw.png`
- Alpha telegraph source: `secret_ascension_boss_telegraph_vfx_source_alpha.png`
- Telegraph source crops: `secret_ascension_boss_telegraph_{ring,cone,beam,rupture}.png`
- Runtime telegraphs: `assets/sprites/effects/secret_ascension_boss_*_telegraph.png`
- Contact preview: `docs/design/previews/scrum539_secret_ascension_boss_contact.png`
- Scale preview: `docs/design/previews/scrum539_secret_ascension_boss_scale_preview.png`
- QA/report metadata: `secret_ascension_boss_source_pack_report.json`

## Technical Notes

- Main runtime candidate: `1024x1024` RGBA, transparent.
- Runtime alpha bbox: `[180, 42, 843, 984]`.
- Recommended pivot: `(512, 960)`.
- Recommended visual radius: about `390px` on the 1024 source.
- Use the static candidate only as interim; preferred production path is a
  full-frame boss animation sheet.

## Telegraph Language

- Warning base: desaturated violet `#7D4DFF`.
- Danger accent: deep crimson `#B22A35`.
- Disk edge: muted old gold `#B58A3A`.
- Bone/rune accent: dim bone white `#C8BFA4`.
- Avoid pure neon magenta, pure white fills, and opaque noisy floor plates.

Recommended shapes: expanding ring, cone sector, narrow beam lane, and rupture
fissure zone. Keep warning silhouettes fair and readable over dark floors.
