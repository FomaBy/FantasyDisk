# SCRUM-1069 — Guild Atlas balance uplift

Статус: done
QA: pending independent SCRUM-1070 rerun
Контур: Codex
Owner: `/root/audit_new_sprint_tail`
Thread: `/root/audit_new_sprint_tail`
Jira: SCRUM-1069
Branch: `codex/scrum1069-guild-atlas-balance`
Base: `origin/dev@0b17c754a`

## Locked paths

- Guild-only values/power contracts in `scripts/meta_progression_tree_data.gd`
  and `scripts/meta_progression.gd`;
- required existing runtime consumers in `scripts/player.gd`;
- SCRUM-1069 tests, audit report and Meta/Atlas balance documentation.

Excluded: SCRUM-1068 constellation schema/topology/IDs; `scripts/ui_screens.gd`,
Atlas footer geometry/art and SCRUM-1070 QA scope.

## Architecture

- preserve all IDs, edges, costs, total 59, cap 50 and schema-5 save purchases;
- raise all fourteen minor nodes to role floors and keep four alternative
  branches inside deterministic value-per-dust corridor;
- change only structurally weak mechanics: 100% start ultimate and bounded
  once-per-run death-save recovery at 30% max HP;
- use source-aware Guild weights so stronger QoL values do not rewrite class
  constellation budgets; full 59-cost Atlas is the upper bound for every legal
  50-dust combination;
- generate player descriptions from runtime effect dictionaries; unknown/no-op
  keys are rejected by the existing wiring gate.

## Evidence

- Exact before/after node, branch, consumer and cap audit:
  `docs/design/reports/scrum1069_guild_atlas_balance_audit.md`.
- Baseline `tests/meta_skill_tree_smoke_test.gd`: PASS on `0b17c754a`.
- Implementation focused Guild budget test: PASS.
- Updated Meta skill tree behavioral smoke: PASS.
- Schema-5 Guild purchase roundtrip, exact frozen IDs/costs/edges, all-17
  class-neutral delta and 384 legal exact-50 build oracle: PASS.
- Meta points/keystone behavior, A5/global damage/global survivability/economy,
  Atlas screen/clickability/no-overlap matrix, balance/live-combat harnesses and
  full runtime smoke: PASS.
- Independent post-implementation review: PASS, no P0–P2 findings.

## Result

- Landed to `origin/dev` in implementation commit `665a6f67a` and integration
  commit `0fd4e679f`.
- Post-integration focused Guild, Meta tree and full runtime smokes: PASS.
- Representative windowed Atlas clickability on Apple Metal at all test
  viewports: PASS.
- Jira routing: `Контроль качества`; final QA verdict remains owned by QA.
- Disk cleanup: removed the task `.godot` cache (`446 MB`) and isolated
  `/tmp/fsd-scrum1069-metal`; disposable worktree is removed after board-sync
  evidence is pushed.
