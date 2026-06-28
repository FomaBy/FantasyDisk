# Design Task: Secret Ascension Boss Source Pack

Status: blocked
Contour: Codex
Owner: Design / design-codex-auto-1
Thread: design-codex-auto-1
Locked paths: docs/design/references/bosses/secret_ascension_boss/, assets/sprites/bosses/secret_ascension_boss*
Jira: SCRUM-539

## Context

Jira SCRUM-539 asks for a Design source pack for the optional endgame secret
ascension boss: a huge, readable, visually distinct boss plus large AoE
telegraph language. Scope is Design-only: no boss logic, unlocks, balance,
AnimationPlayer, SpriteFrames, or combat mechanics.

## Attempted Work

On 2026-06-28, Codex worker `design-codex-auto-1` claimed SCRUM-539 from the
active sprint and attempted to generate the first source image through the
mandatory `fantasydisk-asset-generator` workflow:

```powershell
python C:\Users\FomaE\.codex\skills\fantasydisk-asset-generator\scripts\generate_asset.py --no-task --quality high --size 1536x1536 --output bosses/secret_ascension_boss/secret_ascension_boss_source_raw.png --prompt "<see reference README>"
```

The generator failed before making any PNG:

```text
error: OPENAI_API_KEY is not set (looked in env and C:\Users\FomaE\.codex\.env, D:\FantasyDisk_worktrees\design-codex-auto-1\.env)
```

The Python `openai` package is available, but the current worker environment
only exposes `JIRA_API_TOKEN`; it does not expose `OPENAI_API_KEY`.

## Blocker

Blocked by missing OpenAI Images API credentials in the worker environment.
Project rules require `fantasydisk-asset-generator` / OpenAI Images API for this
asset work and forbid replacing it with an ad hoc/manual fallback. No runtime
candidate PNG or source reference PNG was generated in this pass.

## Prepared Spec

The generation prompt, intended deliverables, telegraph palette, pivot/radius
notes, and handoff contract are recorded in:

- `docs/design/references/bosses/secret_ascension_boss/README.md`

## Next Step

Unblock by making `OPENAI_API_KEY` available to the worker environment or
`C:\Users\FomaE\.codex\.env`, then rerun the generator commands from the README.
After successful generation, alpha-clean/crop the source, create a runtime
candidate under `assets/sprites/bosses/`, build a preview/contact sheet, update
`docs/design/content_registry.md` and `docs/design/systems/enemies_bosses.md`,
then move SCRUM-539 to quality control with the generated paths.

## Verification

- `python -c "import importlib.util; ..."`: `openai=available`.
- `fantasydisk-asset-generator` invocation: blocked before image generation by
  missing `OPENAI_API_KEY`.
- No Godot smoke was run because no runtime assets, scripts, scenes, imports, or
  UI changed.
