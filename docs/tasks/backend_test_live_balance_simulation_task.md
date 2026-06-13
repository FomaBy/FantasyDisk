# Back-end Task: Add Live Balance Simulation Tests

Статус: done (2026-06-13, Claude Fable 5)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-178
Jira: SCRUM-201
Эпик: epic_full_project_quality_pass

## Scope

Add factual live-DPS/TTK tests to complement formula-only balance harness output.

## Requirements

- Cover representative solo, AoE, deployable, summon and DoT weapons.
- Capture actual damage dealt over time.
- Report outliers without turning the full suite flaky.

## Verification

- New focused test/harness runs headless.

## Done (2026-06-13)
`tests/live_balance_simulation_test.gd` — детерминированный live-DPS/TTK тест: реальный Player+оружие бьёт стационарных болванок 8с, мерится фактический урон по одному представителю каждого архетипа (deploy/summon/dot/aoe/single, автоподбор по конфигу). ЖЁСТКО падает только на реальной поломке (0 урона за окно / NaN / <4 архетипов покрыто); балансовые дельты и aoe<solo — мягкий отчёт без флака. Headless зелёный, 5/5 архетипов покрыто, 0 пропавших.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.
