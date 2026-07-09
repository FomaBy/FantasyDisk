# SCRUM-1016 — Druid Ghost Summon PixelLab Animation Integration

Статус: in_progress
Контур: Codex
Owner: Animator/Codex
Thread/Worker: `/root/audit_ready`
Jira: SCRUM-1016
Parent: SCRUM-901
Design source: SCRUM-1015 (independent QA PASSED)
Backend roster/gameplay: SCRUM-902
Branch: `codex/scrum-1016-druid-ghost-animations`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1016-druid-ghost-animator-codex`
Locked writes: `assets/sprites/allies/druid_ghost_*/**`,
`assets/sprites/allies/ally_druid_ghost_*_spriteframes.tres`,
`scripts/full_frame_animation_registry.gd`, `scripts/ally_minion.gd`,
`scenes/AllyMinion.tscn` only if technically required,
`tests/animation_smoke_test.gd`, animation/current-state/content-registry docs,
Animator evidence for this task, this mirror and the scoped Jira sync-map entry.
Read-only: `scripts/summoner_weapon.gd`, progression data, Summon Amulet roster,
spawn weighting, damage, aura/balance behavior and all SCRUM-902 paths.

## Goal

Consume the exact accepted SCRUM-1015 PixelLab identities and deliver west/east
movement plus role-readable attack/cast animation packs for the five Druid ghost
summons. Integrate only the visual animation path; roster and gameplay behavior
remain Backend-owned by SCRUM-902.

## Canonical PixelLab Identities

| Runtime ID | Role | PixelLab character ID | Action target |
| --- | --- | --- | --- |
| `druid_ghost_wolf` | physical melee AoE | `8d473df8-9bc2-481c-ad58-b69cfecc5d33` | claw/body sweep |
| `druid_ghost_bear` | physical melee AoE | `6805608a-b64a-471c-a1d9-9601a3062e2f` | heavy ground slam |
| `druid_ghost_panther` | physical melee AoE | `b2d06d20-aabb-48e2-9d8a-5053daa03e8e` | pounce/circular rake |
| `druid_ghost_stag` | magical ranged caster | `f17948e2-8e1d-44f2-93f1-8f8593ae01fe` | spirit-lance cast |
| `druid_ghost_lion` | magical ranged caster | `48d76788-eeba-4a9f-a36f-bd40a8f42e07` | spectral roar projectile |

## Requirements

1. Use PixelLab MCP and the exact accepted character IDs; do not redraw or
   substitute a legacy/manual/OpenAI source.
2. Produce only west/left and east/right movement plus attack/cast animations,
   with at least five frames per direction/action.
3. Keep PixelLab source exports separate from normalized runtime assets.
4. Normalize every runtime frame to transparent `256x256`, centered on X and
   bottom-aligned to a stable common baseline with safe exterior gutters.
5. Build explicit `move_left`, `move_right`, `attack_left`, `attack_right`
   SpriteFrames rows. New ghost summons must not use horizontal flip and must
   not depend on north/south/diagonal assets.
6. Extend `FullFrameAnimationRegistry` and the narrow AllyMinion visual adapter
   so all five IDs resolve and select left/right movement/action animations,
   preserving all existing allies and gameplay logic.
7. Add focused smoke coverage for frame counts, loop flags, absence of extra
   directions, live left/right selection and attack/cast selection.
8. Deliver manifest, contact sheet and alpha/baseline/crop QA evidence including
   PixelLab character/job IDs, role, action names/counts, paths, `256x256`
   canvas and pivot/baseline contract.

## Verification Plan

- PixelLab config smoke: `get_balance`.
- Static PNG/manifest validation and contact-sheet review.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`.
- `git diff --check` and owned-path audit.

## Progress

- 2026-07-10: live Jira preflight confirmed To Do, unassigned, Codex/Animator,
  no blocked label and no competing owner/locks; SCRUM-1015 is independently
  accepted.
- 2026-07-10: claim-first completed through `jira_next_task.py` as
  `/root/audit_ready`; exact branch/worktree/locks/next verification posted to
  Jira before implementation.
- 2026-07-10: PixelLab MCP generated the requested west/east movement and
  action rows from all five exact accepted SCRUM-1015 character UUIDs. Strict
  alpha/crop and animator contact-sheet review rejected the first bear/stag/lion
  candidates where required; selected retakes are recorded in
  `pixellab_requests.json`, `pixellab_jobs.json` and `pixellab_job_ids.json`.
- 2026-07-10: the final pack contains 120 raw PixelLab PNGs plus 120 normalized
  runtime PNGs. Automated pack audit passed: transparent `256x256`, shared
  center X `128`, baseline Y `232`, minimum gutter `20`, no north/south/diagonal
  repository assets and no horizontal flip.
- 2026-07-10: `animation_smoke_test.gd` PASS; `runtime_smoke_test.gd` PASS
  (exit `0`; the existing dummy-renderer screenshot path still logs its known
  non-gating null-texture warning). Static manifest/PNG/JSON audit and
  `git diff --check` PASS.

## Implementation Result (pre-QA)

- Five `SpriteFrames` resources expose `move`, `move_left`, `move_right`,
  `attack`, `attack_left`, and `attack_right`; directional rows contain six
  distinct PixelLab frames, move loops at 10fps and action is a 12fps one-shot.
- `FullFrameAnimationRegistry` owns the five exact visual IDs and marks them as
  explicit-horizontal. `AllyMinion` selects left/right rows, keeps `flip_h`
  disabled for these entries and preserves all existing ally flip behavior.
- Evidence: `docs/design/references/druid_summons_ghost_animation_pack/` and
  `docs/design/previews/druid_summons_ghost_animation_pack_contact.png`.
- Gameplay/balance/roster paths were not changed; SCRUM-902 remains the Backend
  integration owner.
- Independent QA is still required before Jira may move from
  `Контроль качества` to `Готово`.
