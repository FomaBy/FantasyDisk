# Animation Task: SCRUM-779 Boss PixelLab Candidate Promotion

Статус: new
Контур: Codex
Owner: unassigned
Thread: n/a
Locked paths: assets/sprites/bosses/pixellab_candidates/; assets/sprites/bosses/full_frame/; assets/sprites/bosses/*spriteframes.tres; docs/design/references/bosses/pixellab_roster_redraw_2026_06/; docs/design/previews/boss_pixellab_roster_redraw_2026_06*
Jira: SCRUM-793

## Autonomy / Approval
Пользователь заранее одобрил in-scope work. Follow
`fantasydisk-pixellab-animation-integrator` for boss/monster animation-source
promotion. Do not ask for routine confirmation.

## Context
SCRUM-779 produced PixelLab boss redraw candidates and concepts, but most are
not final live replacements yet.

Useful first-pass candidates:

- `disk_devourer`: strong radial maw single-view candidate.
- `brood_mother`: readable spider queen single-view candidate.
- `secret_ascension_boss`: readable ascendant demon single-view candidate.
- `bloodthorn_lion`: strong single-view candidate plus darker 8-direction
  quadruped pack.

Revise-needed candidates:

- `rift_warden`: valid 8-direction pack, but too compact/humanoid and loses
  floating rift-vortex identity.
- `bone_archon`: readable but too plain/static and includes baked shadow remnants.
- `ashen_colossus`: readable but feels more armored robot than volcanic colossus.
- `skeletal_dragon`: readable flying skeleton first pass but needs more boss
  mass/detail.
- `bloodthorn_lion_8dir`: useful as movement reference, but too dark and simpler
  than the OpenAI concept.

## What Animator / Design Follow-up Needs To Do
- Choose accepted candidates or request a second PixelLab art pass before live
  promotion.
- For accepted replacements, create/normalize full-frame rows or 8-direction
  SpriteFrames compatible with `scripts/boss.gd`.
- Preserve existing boss gameplay timings; this handoff is visual/animation
  only unless paired with a Back-end task.
- Keep source references, manifests, previews and QA evidence updated.

## Acceptance Criteria
- No current live boss SpriteFrames are replaced by a revise-needed candidate.
- Any promoted boss has transparent source/runtime frames, stable pivot, contact
  preview and animation smoke coverage.
- `docs/design/content_registry.md`, `docs/design/current_game_state.md` and
  `docs/design/systems/enemies_bosses.md` clearly state live versus source-only
  status.
