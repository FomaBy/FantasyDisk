# SCRUM-898 — independent QA

Статус: done (QA PASSED after remediation `f75ef20e`)
Date: 2026-07-10
QA owner: Codex `/root/audit_ready` (remediation recheck); previous QA: `/root`
Implementation commits: `35301aa4`, `c4349b57`; remediation: `f75ef20e`; handoff: `64caf658`
Current verdict: **PASSED** (historical FAILED verdict preserved below)

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

## QA-Вердикт (2026-07-10, independent remediation recheck)

Статус: PASSED

Проверено на fresh `origin/dev` worktree: remediation base `64caf658`, final
latest-dev recheck `9450c531`; `f75ef20e` и `64caf658` подтверждены как
ancestors. Изменения после `64caf658` не пересекают SCRUM-898 runtime scope;
`weapon_integrity_test.gd` и `runtime_smoke_test.gd` повторно PASS на final
HEAD. QA не менял production/runtime файлы.

### Acceptance evidence

- `git diff f1e836fd..64caf658` inspected read-only; remediation scope matches
  the three original blockers. The wider range also contains separately landed
  SCRUM-968 audio work, which was not attributed to SCRUM-898.
- `sound_wave_damage` is absent from active weapon scene configs and
  `scripts/ui_screens.gd`.
- `ElectricGuitar`, `BassGuitar`, `SoundAmp`, `BriarStaff`, and `RavenTotem`
  expose `damage_parameter = "magic_damage"` directly from their scenes before
  any `configure_weapon()` adapter runs.
- `weapon_integrity_test.gd` instantiates the roster and verifies all 17 classes
  / 51 weapon configs; every applicable scene/config damage parameter is active
  (`damage` or `magic_damage`) and matches its data config.
- `_shop_item_fallback_icon_id()` returns `magic_damage` for Guitarist class
  affinity; no removed icon id remains in the active UI path.
- `docs/design/current_game_state.md` explicitly records that SCRUM-898 removed
  the separate sound axis and universal battle-shout hook. The active runtime
  hook list no longer claims battle shout.
- `docs/tasks/SCRUM-898_ui_screens_tail.md` is removed after application.
- Remaining `sound_wave_damage` references are either migration guards with
  explicit SCRUM-898 removed/legacy comments or documents marked
  `Историческая справка`; none is an active data/UI/config declaration.

### Test evidence

All Godot commands ran through `python3 tools/godot_gate.py` with Godot 4.7:

- `tests/damage_type_isolation_test.gd` — PASS (3 owners / 3 damage axes).
- `tests/damage_type_palette_test.gd` — PASS.
- `tests/weapon_integrity_test.gd` — PASS (17 classes / 51 weapons).
- `tests/weapon_tuning_application_test.gd` — PASS (51/51).
- `tests/stat_formulas_smoke_test.gd` — PASS (34 definitions).
- `tests/level_up_advisor_test.gd` — PASS.
- `tests/monitor_selector_behavior_test.gd` — PASS.
- `tests/display_resolution_test.gd` — PASS.
- `tools/balance_harness.gd` — PASS; local reports generated.
- `tests/global_damage_balance_smoke_test.gd` — PASS (51 pairs; worst CCT
  deviation +22%, `doctor/restore_potion/20`).
- `tests/ui_no_overlap_matrix_test.gd` — PASS.
- `tests/animation_smoke_test.gd` — PASS.
- `tests/meta_progression_smoke_test.gd` — PASS.
- `tests/melee_weapon_targeting_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS; the known dummy-renderer null-texture
  screenshot diagnostic was non-fatal after assertions.

Краевые случаи: direct unconfigured scene defaults, negative/oversized/zero
monitor regression, removed/unknown damage-channel fallbacks, all 51
scene/config pairs, 2K/FHD display policy, and the full UI resolution matrix.

Баги: нет. Jira may move to `Готово`; remove the stale `qa-failed` label.
