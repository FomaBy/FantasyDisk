# Animation Task: SCRUM-779 Boss PixelLab Candidate Promotion

Статус: done
Контур: Codex
Owner: Animator / codex-animator-auto
Thread: fantasydisk-codex-animator-agent
Locked paths: assets/sprites/bosses/pixellab_candidates/; assets/sprites/bosses/full_frame/; assets/sprites/bosses/*spriteframes.tres; docs/design/references/bosses/pixellab_roster_redraw_2026_06/; docs/design/previews/boss_pixellab_roster_redraw_2026_06*; build/qa/scrum793*; docs/design/content_registry.md; docs/design/current_game_state.md; docs/design/systems/enemies_bosses.md
Jira: SCRUM-793

## Claim / Start

2026-07-02: Claimed via Jira-pull by Codex Animator worker
`fantasydisk-codex-animator-agent / codex-animator-auto`.
Worktree: `/Users/sergeyfomin/.codex/worktrees/849d/AI Agent`, detached at
`origin/dev` after `git fetch origin --prune` and fast-forward to `origin/dev`.
Next verification step: promote only accepted SCRUM-779 PixelLab boss candidates,
generate alpha/pivot/contact evidence, then run focused animation/full-frame
registry smokes through `tools/godot_gate.py`.

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

## Result

2026-07-02: Implemented the accepted-candidate promotion only.

- Promoted `disk_devourer` PixelLab source
  `81b491db-7240-4513-bad5-263b7f81539d` into the existing live full-frame rows
  under `assets/sprites/bosses/full_frame/disk_devourer/`.
- Promoted `brood_mother` PixelLab source
  `99d1c48c-ab86-4025-80b0-5a0ccb3d2edf` into the existing live full-frame rows
  under `assets/sprites/bosses/full_frame/brood_mother/`.
- Preserved existing SpriteFrames resources, state names, frame counts, speeds
  and boss gameplay callbacks; no boss scene, route rotation, damage, timing or
  balance logic changed.
- Kept `rift_warden`, `bone_archon`, `ashen_colossus`, `skeletal_dragon`,
  `bloodthorn_lion_8dir`, `secret_ascension_boss` and single-view
  `bloodthorn_lion` source-only/revise-needed for separate follow-up.
- Updated live docs: `CHANGELOG.md`, `docs/design/content_registry.md`,
  `docs/design/current_game_state.md`,
  `docs/design/systems/enemies_bosses.md` and
  `docs/design/systems/animation.md`.

Validation:

- Visual contact QA: PASS —
  `build/qa/scrum793_boss_pixellab_promotion/scrum793_boss_pixellab_promotion_contact.png`.
- Alpha/pivot report: PASS —
  `build/qa/scrum793_boss_pixellab_promotion/alpha_pivot_report.json`.
- SpriteFrames file contract: PASS —
  `build/qa/scrum793_boss_pixellab_promotion/spriteframes_file_contract.json`
  confirms expected states and existing texture paths for both promoted bosses.
- Godot focused smoke: BLOCKED in this disposable worktree. Command
  `python3 tools/godot_gate.py --headless --path . --script res://tests/full_frame_registry_integrity_test.gd`
  reached `[ DONE ] first_scan_filesystem`, then produced no further output for
  about 60 seconds; interrupted before the smoke script executed. Evidence:
  `build/qa/scrum793_boss_pixellab_promotion/godot_import_blocker.md`.

Disk cleanup: removed `.godot` and Python `__pycache__` created by this run.
