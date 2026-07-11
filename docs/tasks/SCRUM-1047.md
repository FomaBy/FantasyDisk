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

Independent QA: pending after direct push to `origin/dev`.

Disk cleanup: active task worktree; pending final gates and push.

Thread cleanup: not a disposable worker thread.
