# FantasyDisk agent context

FantasyDisk is a Godot 4 top-down loot-action survival roguelite. Keep this file
as a lightweight map of repository-specific gotchas. Workspace estimation,
dispatch, ownership, exact-SHA QA, Git, and completion transactions live in the
bound `multica-workspace-governance` skill.

## Start with the assigned issue

- Multica project `FantasyDisk` (`FAN-*`) is the live task source. Jira/SCRUM
  and `docs/tasks/*.md` are read-only history or spec/evidence mirrors.
- Work only the issue explicitly assigned to the current agent. Re-read exact
  assignee/owner, acceptance criteria, dependencies, active runs, candidate
  SHA, and locked paths before edits.
- Use the Multica-provided workdir. Resolve repository paths dynamically and do
  not copy transient agent IDs, quota state, incident history, or closed issue
  exceptions into durable instructions.
- Direct user-control work must follow the explicit manual-ownership contract
  and must not overlap a daemon assignment.

For the compact lifecycle, read `docs/process/ai_agent_memorandum.md`. Load the
full process reference only when the task needs it:

- delivery/ownership: `docs/process/multica_workflow.md`
- PM readiness and PM→Qwen handoff: `docs/process/pm_workflow.md`
- role boundaries: `docs/process/agent_role_boundaries_and_handoffs.md`
- independent review: `docs/process/qa_protocol.md`
- CUE/Fibonacci: `docs/process/story_points.md`
- branch/release policy: `docs/process/versioning_and_branching.md`
- human-readable comments: `docs/process/human_readable_comments.md`
- context architecture: `docs/process/context_engineering.md`

## Load the domain skill

- UI screens, HUD, menus, frames, safe zones:
  `fantasydisk-ui-director`
- full-canvas/scenic backgrounds:
  `fantasydisk-builtin-image-generator`
- non-background assets and UI art:
  `fantasydisk-asset-generator`
- item/stat/weapon icons:
  `fantasydisk-item-icon-generator`
- character/monster animation:
  `fantasydisk-pixellab-animation-integrator`
- class/weapon balance:
  `fantasydisk-class-balance-director`
- code quality, performance, Windows stutter, tooling:
  `fantasydisk-code-quality-director`
- releases: `fantasydisk-release-director`

Read detailed design references only when the assigned scope needs them:
`docs/design/fantasydisk_design_brief.md`,
`docs/design/gdd_source.md`, `docs/design/mechanics_extract.md`,
`docs/design/current_game_state.md`, and `docs/design/content_registry.md`.

## Project gotchas

- Automated Godot runs go through `tools/godot_gate.py`; use the repository
  quality gate required by the changed scope. Current project features target
  Godot 4.7. Never commit `.godot/`.
- UI content must remain inside the real empty content zone of decorative
  frames. Content margins must include frame thickness plus safety space.
  Covering ornament is a QA failure.
- Backgrounds and illustrated underlays use the built-in OpenAI image generator.
  PixelLab is for non-background UI/asset art and animation source packs. The
  OpenAI Images API requires an explicit task/user override.
- Preserve canonical IDs and data-driven configuration. Balance classes as
  three-weapon kits across single-target, crowd-clear, and survivability, not as
  isolated damage multipliers.
- `dev` is the integration branch; `main` and published tags are immutable
  release history. Follow `docs/process/versioning_and_branching.md` for any
  branch/version operation.
- After a successful push to `origin/dev`, safely fast-forward the operator
  mirror at `/Users/sergeyfomin/Documents/AI Agent` when it exists. Never erase
  operator WIP; report the mirror SHA or blocker.

## Completion

Match surrounding code, naming, comments, scenes, and tests. Prefer the smallest
complete change and avoid unrelated cleanup. Update the relevant design/process
reference when behavior or contracts change.

Run focused checks first, then the smallest certifying regression/security
checks required by risk. Inspect the complete task-owned diff, push the exact
candidate, and report SHA, commands/results, evidence, docs, residual risk, and
cleanup. Independent QA—not a developer report or CI alone—decides acceptance.
