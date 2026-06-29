# Animator Handoff: Secret Ascension Boss Source

Status: handoff note
Parent Jira: SCRUM-539
Owner: unassigned
Locked paths for future animation work: assets/sprites/bosses/full_frame/secret_ascension_boss*, assets/sprites/bosses/cutout/secret_ascension_boss*, animation smoke evidence

## Context

SCRUM-539 delivered the Design source pack for the optional final ascension
secret boss. The accepted visual is a huge dragon-disk rift titan with a large
readable silhouette and violet/gold rift telegraph language.

## Source Files

- Main source alpha: `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_source_alpha.png`
- Runtime candidate: `assets/sprites/bosses/secret_ascension_boss.png`
- Source report: `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_source_pack_report.json`
- Preview: `docs/design/previews/scrum539_secret_ascension_boss_contact.png`

## Recommended Animation Path

Use a full-frame boss spritesheet path rather than production cutout slicing.
The silhouette has a halo disk, claws, tail, and rift core that will read best
as full-frame motion with secondary glow/pulse layers.

Minimum expected states:

- `move` or hover loop, 6+ frames.
- `attack_primary`, 6+ frames.
- `skill_ring`, `skill_cone`, `skill_beam`, `skill_rupture`, 6+ frames each or
  clear anticipation/strike/recover variants.
- `death`, 6+ frames, no-loop.

Recommended source/pivot notes:

- Static source canvas: `1024x1024`.
- Recommended pivot: `(512, 960)`.
- Keep visual feet/tail grounded near bottom-center.
- Keep halo disk and claws within a consistent frame envelope so HP bar/camera
  framing remains stable.

## Acceptance Notes For Future Task

- Transparent RGBA frames with no matte/spill.
- Manifest/SpriteFrames use stable `secret_ascension_boss` IDs.
- Animation smoke passes.
- Handoff back to Back-end lists final SpriteFrames path and state names.

## Animator Result - 2026-06-28

SCRUM-540 delivered the full-frame animation pack from the accepted SCRUM-539
source. Final assets:

- Frames: `assets/sprites/bosses/full_frame/secret_ascension_boss/`
- Sheet: `assets/sprites/bosses/full_frame/secret_ascension_boss_full_frame_sheet.png`
- SpriteFrames: `assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres`
- Manifest/evidence: `build/qa/scrum540_secret_ascension_boss_anim/`

States: `idle`, `move`, `attack`, `attack_primary`,
`attack_primary_windup`, `attack_primary_release`, `skill_ring`,
`attack_ring`, `skill_cone`, `attack_cone`, `skill_beam`, `attack_beam`,
`skill_rupture`, `attack_rupture`, `hit`, and `death`.

Back-end runtime wiring remains a separate task; add the boss to
`FullFrameAnimationRegistry` when the encounter implementation is ready.
