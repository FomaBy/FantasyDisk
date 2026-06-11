# FantasyDisk Agent Instructions

This repository is a Godot 4 project for FantasyDisk.

Before making gameplay, balance, character, enemy, UI, or progression changes, read:
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/gdd_source.md` when exact GDD wording matters.
- `docs/design/mechanics_extract.md` when formulas, classes, stats, weapons, or MVP screens matter.
- `docs/design/current_game_state.md` for the implemented game state.
- `docs/design/content_registry.md` for canonical entity IDs and names.
- `docs/process/agent_role_boundaries_and_handoffs.md` for Design/Back-end/Animator ownership and cross-chat handoff rules.

Autonomy and approval:
- The user pre-approves all in-scope project changes requested in task files or direct prompts.
- Do not stop to ask for confirmation when the requirement is clear enough to implement. Make a reasonable product/engineering decision, implement it, test it, and document it.
- Ask the user only when the task is impossible without missing information, would change the product direction outside the request, or would require a dangerous/destructive action.
- Still obey Codex/runtime safety rules: request required sandbox escalation, do not expose secrets, do not use destructive git/file commands unless explicitly requested, and do not modify files outside the project without approval.
- For every future task that changes functionality, balance, content, UI, progression, visuals, or animation, update the relevant documentation in the same task.
- After large multi-agent change batches, run the documentation split/update task in `docs/tasks/documentation_post_changes_domain_split_task.md` and keep domain docs under `docs/design/systems/` up to date.

Role boundaries:
- A PM chat forms requirements and issues tasks; its workflow is `docs/process/pm_workflow.md`, task statuses are tracked in `docs/process/task_board.md`.
- Design, Back-end, and Animator agents must do only their own discipline-specific work: Design owns art/sprites/UI visuals, Back-end owns logic/code/balance/tests, Animator owns motion/rigs/animation states.
- If a task needs another discipline, create/update a `.md` handoff task in `docs/tasks/` and send it to the correct chat instead of doing that specialist's work directly.
- Use `docs/process/agent_role_boundaries_and_handoffs.md` as the source of truth for ownership and handoff format.
- When taking a task, set `Статус: in_progress` in its file; when finishing, set `done` (or `review`) and append a short result summary so the PM can sync the task board.

Use Godot 4 GDScript and keep systems compatible with the source design:
- FantasyDisk is a 2D top-down loot-action survival roguelite with RPG buildcraft.
- The MVP prioritizes Berserk, Dark Mage, Guitarist, melee enemy, shooter enemy, and summoner enemy.
- Berserk should trend toward melee cone/AoE weapons, not generic permanent bullet shooting.
- Spreadsheet stat names and formulas are the long-term authority for balancing.

Project practices:
- Keep code split into focused scenes and scripts.
- Prefer data-driven character/enemy/weapon configuration where practical.
- Keep prototype visuals simple until art direction exists.
- Run Godot headless smoke tests after gameplay changes:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\\ Agent --script res://tests/runtime_smoke_test.gd`
- Do not commit `.godot/`.
