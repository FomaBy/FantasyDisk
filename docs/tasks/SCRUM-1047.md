# SCRUM-1047 — Berserk hammer stale circular targeting oracle

Статус: done
Версия: 0.2.1
Jira: SCRUM-1047
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-next5`
Branch: `codex/scrum1047-hammer-oracle`
Related: SCRUM-1043

## Scope And Locks

Only the Hammer probes in `tests/melee_weapon_targeting_test.gd` and this
evidence mirror are writable. `scripts/berserk_weapon.gd`, weapon config,
damage/cooldown/radius growth/diminishing, VFX/assets and all other weapons are
read-only.

## Baseline And Root Cause

Fresh `origin/dev` deterministically failed the focused test at the old
`owner + Vector2(0, 170)` rejection assertion. SCRUM-1043 intentionally replaced
the centered circle with a Hammer-only footline ellipse: center `+Vector2(0,16)`
and vertical scale `1.12`, with unchanged nominal radius `150`.

For the old probe, normalized vertical distance is `(170 - 16) / 1.12 = 137.5`,
which is inside radius 150. The test was stale; production matches the accepted
and independently QA-passed gameplay/VFX contract.

## Decision

- Assert the protected center/scale contract remains exactly `+16 / 1.12`.
- Keep the legacy owner-space `y=170` point as an explicit **inside** regression
  anchor using the real attack path.
- Add owner-space `y=185` as the real just-outside lower point.
- Preserve the existing near and sector-upgrade checks. Radius growth keeps an
  exact enlarged-boundary oracle, but its vertical ±1 px probes are derived from
  `expected_radius × accepted_y_scale` instead of the second stale circular
  hard-code.

This is not a balance or mechanic change. Per Class Balance Director, the gate
is aligned to an explicitly changed product target rather than weakened to make
an implementation pass. Class-trio scores, weapon budgets and per-weapon
identity remain identical to the accepted SCRUM-1043 report, so no before/after
balance table is regenerated.

## Balance Result

- Scope: stale test-oracle alignment only.
- Baseline reports: regenerated `balance_report.md`,
  `balance_final_audit_0_1_5.md` and global damage report; no source/report
  budget changed.
- Before/after Berserk trio: the accepted SCRUM-1043 values remain
  Solo `1.000`, AoE `1.000`, Crowd `0.935`, Defense `1.000`, Total `0.984`.
- Per-weapon identity: sword long/narrow sector, axe broad sweep, hammer close
  footline crowd slam — all unchanged.
- Mechanics changed: none.
- Numeric tuning changed: none.
- Remaining risk: none beyond normal playfeel; deterministic membership and
  VFX geometry are covered.

## Verification

PASS:

- `melee_weapon_targeting_test.gd` — three isolated runs;
- `scrum1043_hammer_lower_hit_zone_test.gd` — top 150 / bottom 180 inside,
  bottom 185 outside, horizontal 149/151 boundary, VFX aligned, Holy Flail
  unchanged;
- `scrum895_berserk_axe_hammer_vfx_test.gd`;
- `runtime_smoke_weapon_mechanics_test.gd`;
- `tools/balance_harness.gd`;
- `global_damage_balance_smoke_test.gd` — 51/51 pairs, worst CCT +21%;
- `berserk_dps_runaway_gate.gd` — 20t `3389 ≤ 3600`, 1t `468 ≤ 650`;
- isolated full `runtime_smoke_test.gd` (known dummy-renderer screenshot
  diagnostic only, exit 0/PASS).

Independent QA: **PASSED** on fresh `origin/dev` (`c244e25e7`) by
`/root/qa_scrum1047`; implementation/evidence commits `19eb5748d` and
`6a77cdb75` are both ancestors of the verified ref.

Implementation commit: `19eb5748d`, rebased without conflict on final
SCRUM-1046/952 QA sync `21f838587` and pushed directly to `origin/dev`.
Post-rebase focused SCRUM-1047 and SCRUM-1043 geometry gates PASS; the pre-rebase
full runtime/global damage results remain authoritative because the intervening
QA batch changed evidence/map only.

Disk cleanup: removed the 446 MiB task `.godot` cache and all owned isolated
HOME/XDG scratch roots. Generated balance reports match tracked content, so the
worktree is clean; the checkout is retained only until QA dispatch is recorded.

Thread cleanup: not a disposable worker thread.

## Independent QA Verdict — PASSED

Fresh-worktree review confirms this is an oracle correction for the accepted
SCRUM-1043 contract, not a weakened gate:

- production code, weapon configs, scenes, VFX and assets have no diff in the
  SCRUM-1047 commit range;
- the test now protects the exact Hammer-only center `owner + (0, 16)` and
  visual/hit scale `(1.0, 1.12)`;
- the legacy owner-space `y=170` probe is explicitly required to hit because
  `(170 - 16) / 1.12 = 137.5 < 150`;
- owner-space `y=185` is explicitly required to miss because
  `(185 - 16) / 1.12 ~= 150.89 > 150`;
- after Radius growth, the lower boundary is still tested on both sides at
  `expected_radius * 1.12 +/- 1px`; no permissive tolerance or skipped attack
  assertion was introduced.

Independent verification PASS:

- `melee_weapon_targeting_test.gd` — 3/3 separate userdata roots;
- `scrum1043_hammer_lower_hit_zone_test.gd` — asymmetric Hammer footprint,
  VFX alignment and unchanged Holy Flail defaults;
- `scrum895_berserk_axe_hammer_vfx_test.gd`;
- `runtime_smoke_weapon_mechanics_test.gd`;
- `tools/balance_harness.gd` — unchanged Berserk budget multipliers
  (`sword 0.660`, `axe 1.646`, `hammer 2.800`) and targets (`48 / 150`);
- `global_damage_balance_smoke_test.gd` — 51/51, worst CCT `+21%`;
- `berserk_dps_runaway_gate.gd` — 20 targets `2778 <= 3600`, one target
  `367 <= 650`;
- isolated full `runtime_smoke_test.gd` — exit 0/PASS; only the known
  dummy-renderer screenshot diagnostic appeared.

Sword, Axe and Holy Flail behavior stays isolated: the reviewed commit changes
only Hammer membership probes and evidence, while the focused SCRUM-1043 gate
also asserts Holy Flail keeps the shared centered-circle defaults.

Disk cleanup: QA `.godot`, generated reports, transient `.uid` sidecars, all
owned HOME/XDG roots, worktree and branch removed after evidence push.
