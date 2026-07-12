# SCRUM-938 — independent QA: Soldier Bayonet Stance

Статус: done
Дата: 2026-07-10
QA owner: Codex `/root`

## QA-Вердикт

Статус: PASSED

`soldier_bayonet` is a 105° close melee cone: contact, close and mid-cone
targets are hit, while side, rear and out-of-range targets are excluded. The
configurable secondary shot is zero at chance 0, guaranteed at chance 1,
targets beyond the cone and remains weaker than the thrust. Double-action
duplicates the cone once without recursive secondary actions. Full geometry,
balance and regression evidence is recorded in `SCRUM-935_qa.md`.
