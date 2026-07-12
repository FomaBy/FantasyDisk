# SCRUM-936 — independent QA: Soldier Arquebus

Статус: done
Дата: 2026-07-10
QA owner: Codex `/root`

## QA-Вердикт

Статус: PASSED

`soldier_rifle` now launches one visible physical projectile and detonates a
small 95px falloff AoE at the target point. Tests prove projectile travel,
center-versus-edge damage, exclusion outside the radius, contact targeting and
two independent non-recursive explosions under forced double-action. Full
balance and regression evidence is recorded in `SCRUM-935_qa.md`.
