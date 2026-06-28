# SCRUM-570: UI Redesign - Level-Up Overlay @2K

Status: blocked
Contour: Codex
Owner: Design/Codex ui-design-level-up
Thread: current Codex Design worker
Locked paths: docs/design/mockups/scrum570_levelup_2k_redesign/, docs/design/references/scrum570_levelup_2k_redesign/, docs/design/previews/scrum570_*, optional assets/sprites/ui/frames/overhaul_2k/level_up*
Jira: SCRUM-570

## Scope

Design-only stage for the level-up overlay redesign. Required deliverables were an OpenAI-API-generated 2K mockup PNG, source references, preview/evidence, and a geometry spec for safe zones/frame margins/responsive behavior. Runtime integration files are out of scope for this stage.

## Work Performed

- Read `AGENTS.md`, `docs/process/ai_agent_memorandum.md`, `docs/process/agent_role_boundaries_and_handoffs.md`, `docs/process/versioning_and_branching.md`, `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md`, `docs/design/systems/visual_style_assets.md`.
- Read `fantasydisk-ui-director` and relevant references: `ui-change-workflow.md`, `mockup-spec.md`, `fantasydisk-ui-style.md`, `common-pitfalls.md`.
- Read `fantasydisk-asset-generator` because UI mockup generation requires the OpenAI Images API project pipeline.
- Checked Jira SCRUM-570 status/comments and confirmed the latest dispatch is for Codex Design, design-only, no runtime file edits.
- Created a blocked mockup/spec package with the intended 2K geometry and prompt: `docs/design/mockups/scrum570_levelup_2k_redesign/spec.md`.

## Blocker

OpenAI Images API generation cannot run because no `OPENAI_API_KEY` is configured:

```text
error: OPENAI_API_KEY is not set (looked in env and C:\Users\FomaE\.codex\.env, C:\Users\FomaE\OneDrive\Documents\Fantasy Disk SCRUM-570\.env)
```

Per `fantasydisk-ui-director`, this must be blocked rather than replaced with a manual or non-API mockup.

## Attempted Command

```powershell
python skills\codex\fantasydisk-asset-generator\scripts\generate_asset.py --prompt "<SCRUM-570 level-up overlay prompt>" --output scrum570_levelup_2k_redesign/levelup_overlay_mockup_source.png --size 2560x1440 --quality high --no-task
```

## Deliverables

- Mockup PNG: not produced, blocked by missing OpenAI API key.
- Preview PNG: not produced.
- Generated source assets: not produced.
- Spec/blocker evidence: `docs/design/mockups/scrum570_levelup_2k_redesign/spec.md`.

## Validation

- `git status --short --branch`: clean for SCRUM-570 after task edits are committed, with unrelated `source_docs/FantasyDisk_GDD.txt` line-ending noise hidden locally and not staged.
- Runtime tests: not run; no Godot runtime files, scenes, scripts, or assets were changed.
- Jira board sync: attempted `python tools/jira_board_sync.py --help`, but this script does not implement help and attempted a real sync; it failed on an existing `fixVersions` Jira configuration error before this task was updated.

## Next Step

Configure the OpenAI API key for the project environment, then rerun the exact prompt/package flow from `spec.md`. After successful generation, update this task to `done`, attach preview paths, and move SCRUM-570 to `Контроль качества`.
