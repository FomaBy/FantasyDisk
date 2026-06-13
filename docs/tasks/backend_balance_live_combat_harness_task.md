# Back-end Task: Live Combat Balance Harness

Статус: in_progress (Claude Backend)
Версия: 0.1.5
Создано: 2026-06-13
Автор: Back-end audit SCRUM-176
Jira: SCRUM-189
Эпик: epic_full_project_quality_pass

## Scope

Add deterministic live combat simulations for all 51 class+weapon pairs to complement `tools/balance_harness.gd`.

## Requirements

- Instantiate real Player + weapon + target enemies.
- Measure solo DPS, 5-target DPS and practical TTK over a fixed window.
- Compare against class profile target with a tolerance decided in the task.
- Output report under `build/`.

## Verification

- New live harness runs headless.
- Runtime smoke remains green.
