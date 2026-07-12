# SCRUM-948 — independent QA: Elementalist square field

Статус: done
Дата: 2026-07-10
QA owner: Codex `/root`
Implementation commits: `f6266a76`, `3b9a0a6c`, `4cf721fa`, `d62eb642`

## QA-Вердикт

Статус: PASSED

The weapon is named `Кольцо Четырёх Стихий` in canonical data. Its persistent
area is a true square anchored at the cast position: diagonal corner targets
inside the square are hit, targets outside a side are not, and moving the hero
does not move the field. Runtime assertions confirm independent magic,
physical and periodic channels, outward knockback, bounded per-cast damage and
effect cleanup.

`tests/elementalist_kit_test.gd`, type isolation, 51/51 tuning, global damage,
global survivability, comfort-band, animation and full runtime smokes passed.
Current tuned DPS is `51.84` solo and `178.11` at 20 targets; crowd-clear
deviations are `-4.7%/+9.8%` at 5/20 targets. No production fix or follow-up
bug is required for SCRUM-948. The separate SCRUM-947 trait failure does not
alter this weapon's square-field acceptance result.
