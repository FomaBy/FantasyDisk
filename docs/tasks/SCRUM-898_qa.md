# SCRUM-898 — independent QA

Статус: done (remediation `f75ef20e`, ожидает повторный QA)  
Date: 2026-07-10  
QA owner: Codex `/root`  
Implementation commits: `35301aa4`, `c4349b57`  
Verdict: **FAILED**

The verdict below records the first independent QA pass. Its three blockers were
fixed in `f75ef20e`; Jira/local status is now review-ready for a new independent
verdict.

## Blocking findings

1. Active scene configuration still uses the deleted parameter:
   `ElectricGuitar.tscn`, `BassGuitar.tscn`, `SoundAmp.tscn`,
   `BriarStaff.tscn`, and `RavenTotem.tscn` each declare
   `damage_parameter = "sound_wave_damage"`. `configure_weapon()` replaces these
   values in the normal player equip flow, but the scenes remain executable
   runtime/config sources and fall back to physical damage if instantiated without
   that adapter. This violates the explicit acceptance criterion that no weapon
   config retain the removed parameter.
2. `scripts/ui_screens.gd` retains five active references to
   `sound_wave_damage`, including `_DAMAGE_TYPE_PARAMETERS`, attribute influence
   tables, and a player-facing label branch. The separate tail specification does
   not satisfy the acceptance criterion that the current UI no longer expose or
   classify the removed stat.
3. `docs/design/current_game_state.md` still describes sound damage as the
   universal off-class combat-shout interpretation. That is current-state prose,
   not a historical marker, and contradicts the implemented removal of the battle
   shout.

## Validation

All commands used the repository semaphore through `tools/godot_gate.py`.

- `tests/damage_type_isolation_test.gd` — PASS (3 owners / 3 damage axes).
- `tests/damage_type_palette_test.gd` — PASS.
- `tests/weapon_integrity_test.gd` — PASS (17 classes / 51 weapons).
- `tests/weapon_tuning_application_test.gd` — PASS (51/51).
- `tests/stat_formulas_smoke_test.gd` — PASS (34 definitions).
- `tests/level_up_advisor_test.gd` — PASS.
- `tools/balance_harness.gd` — PASS; reports generated locally.
- `tests/global_damage_balance_smoke_test.gd` — PASS (51 pairs; worst CCT
  deviation +22%, doctor/restore_potion/20).
- `tests/runtime_smoke_test.gd` — PASS. The known dummy-renderer null-texture
  diagnostic occurred during screenshot capture and did not fail the smoke.
- `git diff --check 1d4eb8c5..c4349b57` — PASS.

## Balance audit

The migration does not change weapon geometry or defensive mechanics. Runtime
tuning keeps the affected kits inside their existing corridors:

| Class | Weapon | Solo DPS | 5-target DPS | CCT 20 deviation | Gate |
| --- | --- | ---: | ---: | ---: | --- |
| guitarist | electric_guitar | 48.00 | 195.07 | +9.7% | PASS |
| guitarist | bass_guitar | 48.00 | 195.02 | +9.7% | PASS |
| guitarist | sound_amp | 48.03 | 195.04 | +20.0% | PASS |
| druid | summon_amulet | 47.96 | 149.84 | +20.2% | PASS |
| druid | briar_staff | 47.99 | 149.98 | +6.6% | PASS |
| druid | raven_totem | 47.97 | 149.97 | +20.1% | PASS |

Required remediation is narrow: migrate the five scene defaults, remove the five
UI references per `SCRUM-898_ui_screens_tail.md`, update the stale current-state
paragraph, add an active-config grep/assertion so the same gap cannot return, and
rerun the focused/balance/runtime gates.
