# SCRUM-540 Secret Ascension Boss Animation Pack

Status: review
Contour: Codex
Owner: Animator/Codex
Thread: anim-loop-1
Locked paths: assets/sprites/bosses/full_frame/secret_ascension_boss/, assets/sprites/bosses/full_frame/secret_ascension_boss_full_frame_sheet.png, assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres, build/qa/scrum540_secret_ascension_boss_anim/, tests/secret_boss_animation_pack_smoke.gd
Jira: SCRUM-540

## Scope

Create a full-frame animation pack for the optional final ascension secret boss
from the accepted SCRUM-539 Design source pack. No boss AI, unlock condition,
damage, rewards, route logic, or class balance changes are included.

## Result

Animator delivery uses the existing boss full-frame SpriteFrames contract.

- Runtime frames: `assets/sprites/bosses/full_frame/secret_ascension_boss/`
- Safe-gutter source sheet:
  `assets/sprites/bosses/full_frame/secret_ascension_boss_full_frame_sheet.png`
- SpriteFrames resource:
  `assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres`
- Focused smoke:
  `tests/secret_boss_animation_pack_smoke.gd`
- QA evidence:
  `build/qa/scrum540_secret_ascension_boss_anim/`

## Animation States

- `idle` / `move`: 6-frame looping presence hover, stable bottom-center pivot.
- `attack_primary`: 6-frame non-looping huge AoE windup/release/recover.
- `attack_primary_windup`: 6-frame non-looping charge segment for sync.
- `attack_primary_release`: 6-frame non-looping impact segment for sync.
- `skill_ring` / `attack_ring`: 6-frame non-looping ring cast.
- `skill_cone` / `attack_cone`: 6-frame non-looping cone cast.
- `skill_beam` / `attack_beam`: 6-frame non-looping beam cast.
- `skill_rupture` / `attack_rupture`: 6-frame non-looping rupture cast.
- `hit`: 6-frame non-looping damage reaction.
- `death`: 6-frame non-looping fade/defeat sequence.

## Validation

- Manifest validator PASS: `FantasyDisk animation manifest OK: 1 entities`.
- Static alpha/slicing check PASS: 61 PNG/sheet entries, 0 edge-alpha errors.
- Godot import PASS after importing the new full-frame PNGs.
- Focused Godot SpriteFrames smoke PASS: 16 states checked.
- General `tests/animation_smoke_test.gd` was attempted and currently fails
  before execution on the pre-existing Windows parse issue:
  `Identifier "ProgressionData" not declared in the current scope` at
  `tests/animation_smoke_test.gd:29`.

## Back-End Handoff

When the secret boss runtime encounter is wired, add `secret_ascension_boss` to
`FullFrameAnimationRegistry` with:

- frames:
  `res://assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres`
- recommended scale: `Vector2(0.86, 0.86)`
- recommended position: `Vector2(0.0, -104.0)`
- source faces left: `true`

