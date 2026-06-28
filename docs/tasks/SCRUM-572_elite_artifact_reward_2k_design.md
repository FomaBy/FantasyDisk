# SCRUM-572 - UI Redesign: Elite Artifact Reward 2K

Статус: blocked
Контур: Codex
Owner: Design/Codex
Thread: Codex current thread
Locked paths: `docs/design/mockups/scrum572_elite_artifact_reward_2k/`, `docs/design/references/scrum572_elite_artifact_reward_2k/`, `docs/design/previews/scrum572_*`, local SCRUM-572 evidence docs
Jira: SCRUM-572

## Scope

Design-only stage for the elite artifact reward screen: create an OpenAI-API-generated 2K mockup/spec/source package for the reward screen that presents 3 artifact choices after an elite victory. Runtime files such as `scripts/ui_screens.gd` are out of scope and were not edited.

## Result

Blocked before image generation. The required `fantasydisk-asset-generator` command failed because `OPENAI_API_KEY` is not configured in this environment.

Generated PNG paths are therefore intentionally absent:

- `docs/design/references/scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_mockup_source.png`
- `docs/design/mockups/scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_mockup.png`
- `docs/design/previews/scrum572_elite_artifact_reward_2k_safe_zones.png`

Created design/spec evidence:

- `docs/design/mockups/scrum572_elite_artifact_reward_2k/spec.md`

## Attempted Command

```powershell
python C:\Users\FomaE\.codex\skills\fantasydisk-asset-generator\scripts\generate_asset.py --prompt "<see spec.md>" --output scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_mockup_source.png --size 2560x1440 --quality high --no-task
```

Output:

```text
error: OPENAI_API_KEY is not set (looked in env and C:\Users\FomaE\.codex\.env, C:\Users\FomaE\OneDrive\Documents\Fantasy Disk SCRUM-572\.env)
```

## Validation

- Read required project docs: `AGENTS.md`, `docs/process/ai_agent_memorandum.md`, `docs/process/agent_role_boundaries_and_handoffs.md`, `docs/process/versioning_and_branching.md`, `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`, `docs/design/systems/visual_style_assets.md`.
- Read `fantasydisk-ui-director` and required references: `ui-change-workflow.md`, `mockup-spec.md`, `fantasydisk-ui-style.md`, `common-pitfalls.md`.
- Confirmed existing reward screen context: `elite_reward` / `artifact_reward` use `assets/backgrounds/ui/ui_backdrop_reward_hall.png`; SCRUM-338/SCRUM-404 reward-card safe-zone rule remains relevant.
- No runtime scripts, scenes, gameplay, balance, or integration files were edited.

## Next Step

Restore `OPENAI_API_KEY` for the OpenAI Images API generator and rerun the command/prompt recorded in `spec.md`. After generation, copy the accepted mockup into the mockup folder, create a safe-zone preview, update this task to `review`, and move SCRUM-572 to `Контроль качества`.
