# SCRUM-937 — independent QA: Soldier Grenade with Fuse

Статус: done
Дата: 2026-07-10
QA owner: Codex `/root`

## QA-Вердикт

Статус: PASSED

`soldier_grenade` has separate slow flight and visible 0.85s fuse phases, no
damage before detonation, a heavy radial-falloff payoff, and a 3.10s interval.
Forced double-action creates two independent grenades and exactly two
explosions without recursion. Full timing, balance and regression evidence is
recorded in `SCRUM-935_qa.md`.
