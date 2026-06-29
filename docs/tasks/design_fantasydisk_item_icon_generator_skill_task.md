# SCRUM-514 — Codex skill: генератор артефактов, иконок характеристик/атрибутов и оружия

Jira: SCRUM-514
- Sprint: Спринт 0.1.7
- Role: Design main / Codex
- Owner/thread: 019eabf1-6d54-7561-8af9-ce25cdf483a9
Статус: done (QA PASSED; PM sprint audit restored Jira Готово 2026-06-29)
- Контур: Codex
- Locked paths:
  - `skills/codex/fantasydisk-item-icon-generator/`
  - `docs/tasks/design_fantasydisk_item_icon_generator_skill_task.md`

## Scope

Create a reusable Codex skill workflow for FantasyDisk artifact icons, stat/attribute icons, and weapon icons. This task is workflow/spec only: no production icon pack generation, no runtime UI/code integration, no gameplay/balance/animation changes.

## Acceptance Checklist

- Skill has a valid `SKILL.md` trigger description for artifacts, stat/attribute icons, and weapon icons.
- Workflow records required inputs: category, canonical ID/name, target size, transparency, style notes, output dirs, and QA evidence.
- Quality rules cover transparent PNG, no cropped subject, small-size silhouette readability, palette/material consistency, and no baked text.
- Workflow reuses the OpenAI Images/API asset pipeline from `fantasydisk-asset-generator` and does not route agents back to legacy manual generators.
- Includes an example prompt and checklist so another agent can safely generate a later package without asking the user.

## Notes

- Existing unrelated dirty files for SCRUM-519 / Designer 2 are intentionally not touched.
- Runtime integration or Godot import tuning remains a Back-end handoff if a future production pack needs code wiring.

## Result

- Added `skills/codex/fantasydisk-item-icon-generator/SKILL.md` with a focused workflow for artifact, stat/attribute, and weapon icons.
- Added `skills/codex/fantasydisk-item-icon-generator/agents/openai.yaml` so the skill is discoverable in Codex-style mirrors.
- Validation: `python3 /Users/sergeyfomin/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/codex/fantasydisk-item-icon-generator` → `Skill is valid!`.
- YAML parse check passed for `agents/openai.yaml`.
