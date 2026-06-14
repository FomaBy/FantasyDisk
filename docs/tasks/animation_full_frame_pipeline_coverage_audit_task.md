# Animation: full-frame pipeline coverage audit

Статус: in_progress
Приоритет: high
Версия: 0.1.5
Создано: 2026-06-14
Автор: Dispatcher/User directive 2026-06-14
Исполнитель: Codex Animator
Jira: TBD

## Autonomy / Approval
Пользователь заранее одобрил in-scope работу. Работать автономно; вопросы только при
опасных действиях вне репозитория или sandbox/security escalation.

## Role / Scope
Animator-owned audit/spec task. Do not change gameplay, balance, targeting, spawn
rules, UI layout, or redraw Design assets. If the audit finds missing full-frame
production sheets, create Design handoff. If runtime state/API support is missing,
create Back-end handoff.

## Context
User directive 2026-06-14 and `fantasydisk-animation-director` now require every
playable character, monster, summon, elite, and boss to have:

- 2+ behavior/action patterns;
- movement as 5+ frame walk/run or lore-correct levitation;
- primary attack as 5+ frame non-looping animation;
- elites/bosses as smooth full-frame sprite sheets, not production cutout from a
  static sprite, with multiple attack patterns for skills/phases.

The existing SCRUM-173 audit and SCRUM-184/185/186/187 follow-ups covered the
cutout rig readability layer. This task is not a duplicate: it audits the stricter
frame-count/full-frame production standard and creates the next handoffs.

## Tasks
1. Duplicate audit against existing animation/art tasks.
2. Build coverage matrix for current heroes, enemies, summons, elites, mini-elites,
   and bosses against the new 5+ frame/full-frame standard.
3. Write report `docs/design/reviews/animation_full_frame_pipeline_audit_2026_06.md`.
4. Produce a pass-only manifest for already-compliant SpriteFrames entities under
   `build/qa/animation_full_frame_pipeline_coverage/animation_manifest.json` and
   validate it with the skill validator.
5. Create/update child handoff tasks for Design and Back-end blockers.
6. Update `docs/design/systems/animation.md`, this task, task board, and Jira.

## Acceptance Criteria
- [ ] Duplicate audit records why existing tasks do not cover this new scope.
- [ ] Coverage matrix identifies compliant, partial, and blocked entity families.
- [ ] Child Design/Back-end handoffs exist for missing production sheets/runtime hooks.
- [ ] Skill manifest validator passes for currently compliant animated entities.
- [ ] Jira/task board are synced.

## Verification
Run:

```bash
python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_full_frame_pipeline_coverage/animation_manifest.json
```

Godot runtime smoke is not required for this read-only/spec-only audit unless code,
scenes, or imported assets are changed.

## Result
In progress.
