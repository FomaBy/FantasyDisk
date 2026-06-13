# Back-end Task: Combat Target Query Cache

Статус: new
Версия: 0.1.5
Создано: 2026-06-13
Автор: Back-end audit SCRUM-174
Jira: SCRUM-197
Эпик: epic_full_project_quality_pass

## Scope

Reduce repeated hot-path `get_tree().get_nodes_in_group("enemies")` scans in weapons/player/boss code by introducing cached target query helpers.

## Requirements

- Provide nearest, radius, corridor and segment query helpers.
- Preserve enemy group membership for compatibility.
- No gameplay behavior changes except reduced allocations/frame spikes.

## Verification

- Runtime smoke and weapon tests pass.
- Add a performance sanity test/log for dense wave query counts if feasible.
