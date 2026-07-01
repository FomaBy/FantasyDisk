# Design Task: PixelLab Boss Roster Redraw And New Boss Concepts

Статус: done
Контур: Codex
Owner: Design / Codex
Thread: current Codex desktop thread
Locked paths: docs/tasks/codex_design_boss_pixellab_redraw_new_bosses_task.md; docs/design/references/bosses/pixellab_roster_redraw_2026_06/; docs/design/previews/boss_pixellab_roster_redraw_2026_06*; assets/sprites/bosses/pixellab_candidates/
Jira: SCRUM-779

## Autonomy / Approval
Пользователь напрямую запросил перерисовку текущих боссов через PixelLab и пару
новых boss concepts через OpenAI image generation. Пользователь заранее одобрил
in-scope project changes; routine file edits, generation, docs, Jira sync, tests,
commit and push are approved.

## Context
Current ordinary boss roster: `rift_warden`, `disk_devourer`, `bone_archon`,
`brood_mother`, `ashen_colossus`. `secret_ascension_boss` exists as a special
post-Act-3 capstone and should be included as a visual candidate, but not added
to normal boss rotation by this Design task.

Production runtime assets for new/redrawn bosses must come from PixelLab MCP.
OpenAI image generation is allowed here only for concept art/reference images for
new bosses, not as the final runtime replacement.

## Scope
- Generate PixelLab redraw candidates for the current boss roster plus
  `secret_ascension_boss`.
- Create OpenAI concept art references for two new bosses:
  - `skeletal_dragon` / Костяной Дракон, a flying skeletal dragon boss.
  - `bloodthorn_lion` / Шипастый Кровавый Лев, a fast predatory blood-spike boss.
- Create PixelLab runtime candidate sprites for those two new bosses.
- Save manifests, prompts/specs, source IDs, previews, and QA notes.
- Update visual/content docs with Design-source status and handoff notes.

## Out Of Scope
- New boss gameplay mechanics, balance, scenes, route rotation, save/codex unlocks,
  and combat tests.
- Final full-frame animation rows or SpriteFrames integration unless PixelLab
  generation returns ready animation packs within this task.

## Acceptance Criteria
- PixelLab MCP was used for every production boss sprite candidate.
- OpenAI image generation concept art is saved under references and clearly marked
  as concept/reference only.
- Generated PNGs are transparent or have verified alpha where the tool supports it.
- Contact sheet/preview exists for the full boss candidate set.
- `docs/design/content_registry.md`, `docs/design/current_game_state.md`, and
  `docs/design/systems/enemies_bosses.md` mention the new Design-source status
  and downstream backend/animation handoff needs.
- Jira gets owner/status/result comments with locked paths and disk cleanup notes.

## In-Progress Evidence

- Jira issue created and moved to `В работе`: `SCRUM-779`.
- OpenAI concept references saved:
  - `docs/design/references/bosses/pixellab_roster_redraw_2026_06/openai_concepts/skeletal_dragon_concept_openai.png`
  - `docs/design/references/bosses/pixellab_roster_redraw_2026_06/openai_concepts/bloodthorn_lion_concept_openai.png`
- OpenAI concept contact preview:
  - `docs/design/previews/boss_pixellab_roster_redraw_2026_06_openai_concepts.png`
- Current boss visual inventory:
  - `build/qa/boss_pixellab_redraw/current_boss_inventory.png`
- PixelLab job in progress:
  - `rift_warden`: character id `bab59c56-4618-4587-918d-23ca15e66235`

Queue note: on 2026-06-30 PixelLab reported the shared Tier 2 concurrent
background job limit was already saturated by other FantasyDisk character jobs,
so remaining boss submissions are being started only when capacity frees up.

## Result

Design-source pass complete for SCRUM-779.

Delivered:

- OpenAI concept references for the two new boss IDs:
  - `skeletal_dragon` / Костяной Дракон
  - `bloodthorn_lion` / Шипастый Кровавый Лев
- PixelLab MCP production candidates for:
  - current roster: `rift_warden`, `disk_devourer`, `bone_archon`,
    `brood_mother`, `ashen_colossus`
  - special boss: `secret_ascension_boss`
  - new IDs: `skeletal_dragon`, `bloodthorn_lion`
- Source manifest:
  `docs/design/references/bosses/pixellab_roster_redraw_2026_06/manifest.json`
- Runtime-candidate PNGs:
  `assets/sprites/bosses/pixellab_candidates/`
- Previews:
  - `docs/design/previews/boss_pixellab_roster_redraw_2026_06_openai_concepts.png`
  - `docs/design/previews/boss_pixellab_roster_redraw_2026_06_candidates_contact.png`
  - `docs/design/previews/boss_pixellab_roster_redraw_2026_06_rift_warden_rotations.png`
  - `docs/design/previews/boss_pixellab_roster_redraw_2026_06_bloodthorn_lion_rotations.png`

Visual QA:

- Good first-pass candidates: `disk_devourer`, `brood_mother`,
  `secret_ascension_boss`, single-view `bloodthorn_lion`.
- Revise before live replacement: `rift_warden` (too compact/humanoid and loses
  vortex identity), `bone_archon` (too plain/static), `ashen_colossus` (too
  armored/robotic), `skeletal_dragon` (readable but needs more boss mass/detail),
  8-dir `bloodthorn_lion` (useful motion reference but too dark).

Validation:

- Pillow validation PASS for all runtime-candidate PNGs: alpha extrema include
  `0` and `255`, all have non-empty alpha bbox.
- No Godot runtime smoke required for this task: no live scene, script,
  SpriteFrames, route, balance or boss-pool wiring changed.

Handoffs:

- Animation/visual promotion: `SCRUM-793`,
  `docs/tasks/animation_scrum779_boss_pixellab_promotion_handoff_task.md`
- Back-end runtime/new boss integration: `SCRUM-794`,
  `docs/tasks/backend_scrum779_new_bosses_runtime_handoff_task.md`

Disk cleanup: none created outside task/reference/evidence paths; temporary
PixelLab download zips are under `build/qa/boss_pixellab_redraw/` as evidence.
