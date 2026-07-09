# SCRUM-949 — independent QA: Elementalist full-map prism X

Статус: done
Дата: 2026-07-10
QA owner: Codex `/root`
Implementation commits: `f6266a76`, `3b9a0a6c`, `4cf721fa`, `d62eb642`

## QA-Вердикт

Статус: PASSED

The prism telegraphs before damage, reaches beyond the `4096x2304` arena
diagonal, pierces near and 4,000-pixel diagonal targets without falloff, and
leaves off-axis targets untouched. A focus lying on both diagonals receives
one beam hit plus one center bonus, proving intersection de-duplication. The
center AoE reaches targets outside the beams, and the Prismatic Cross artifact
adds the reduced horizontal/vertical cross without changing the base X.

`tests/elementalist_kit_test.gd`, projectile identity, 51/51 tuning, global
damage, global survivability, comfort-band, animation and full runtime smokes
passed. Current tuned DPS is `51.84` solo and `178.22` at 20 targets;
crowd-clear deviations are `+2.0%/+13.1%` at 5/20 targets. No production fix
or follow-up bug is required for SCRUM-949. The separate SCRUM-947 trait
failure does not alter this weapon's prism acceptance result.
