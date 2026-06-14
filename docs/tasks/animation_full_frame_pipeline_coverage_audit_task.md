# Animation: full-frame pipeline coverage audit

Статус: done
Приоритет: high
Версия: 0.1.5
Создано: 2026-06-14
Автор: Dispatcher/User directive 2026-06-14
Исполнитель: Codex Animator
Jira: SCRUM-350
QA: in_progress (2026-06-14)

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
- [x] Duplicate audit records why existing tasks do not cover this new scope.
- [x] Coverage matrix identifies compliant, partial, and blocked entity families.
- [x] Child Design/Back-end handoffs exist for missing production sheets/runtime hooks.
- [x] Skill manifest validator passes for currently compliant animated entities.
- [x] Jira/task board are synced.

## Verification
Run:

```bash
python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_full_frame_pipeline_coverage/animation_manifest.json
```

Godot runtime smoke is not required for this read-only/spec-only audit unless code,
scenes, or imported assets are changed.

## Result
Done 2026-06-14 (Codex Animator): read-only audit against the new
`fantasydisk-animation-director` full-frame standard is complete.

Deliverables:
- Report: `docs/design/reviews/animation_full_frame_pipeline_audit_2026_06.md`.
- Validated pass-only manifest:
  `build/qa/animation_full_frame_pipeline_coverage/animation_manifest.json`.
- Design handoff: `docs/tasks/design_enemy_elite_boss_full_frame_animation_sheets_task.md`
  / SCRUM-352.
- Back-end handoff: `docs/tasks/backend_full_frame_animation_state_registry_task.md`
  / SCRUM-351.

Verification:
- `validate_animation_manifest.py` passed for 4 currently compliant ally
  SpriteFrames entities.

Godot smoke was not run because this audit did not change code, scenes, imported
assets, gameplay runtime, or animation resources.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 1f58fd93 (ветка dev)

Read-only animation-coverage аудит. QA = наличие/действенность deliverables.

Проверено (фактически):
- **Манифест-валидатор** (skill `validate_animation_manifest.py`):
  «FantasyDisk animation manifest OK: **4 entities**» — pass-only манифест
  `build/qa/animation_full_frame_pipeline_coverage/animation_manifest.json`
  валиден (4 compliant: druid_beast + 3 призыва).
- **Отчёт** `docs/design/reviews/animation_full_frame_pipeline_audit_2026_06.md`:
  Coverage Matrix (heroes — Partial; standard enemies — Partial; summons/allies —
  Mostly compliant) + duplicate-audit (ссылки на SCRUM-173/156/204).
- **Дочерние handoff'ы созданы**: SCRUM-351 (Back-end full-frame state registry)
  + SCRUM-352 (Design enemy/elite/boss full-frame sheets).

Acceptance:
- [x] Duplicate-аудит фиксирует, почему текущие задачи не покрывают новый scope.
- [x] Coverage matrix (compliant/partial/blocked).
- [x] Дочерние Design/Back-end handoff'ы (351/352).
- [x] Skill-валидатор манифеста зелёный; Jira/доска синканы.

Read-only: код/сцены/ассеты не менялись (smoke не требовался). Баги: нет.
