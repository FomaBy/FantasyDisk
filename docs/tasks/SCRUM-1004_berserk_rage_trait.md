# SCRUM-1004 — Berserk: class trait «Ярость»

Jira: SCRUM-1004
Статус: done
Версия: 0.2.1
Роль: Back-end / Balance
Контур реализации: Claude
Owner реализации: `claude-w27-berserk`
QA: Codex `/root/qa_scrum1004`

## Scope

Классовый Berserk-only trait непрерывно усиливает исходящий урон от
недостающего здоровья:

```text
missing_ratio = clamp(1 - health / max_health, 0, 1)
bonus = 0.40 * missing_ratio
multiplier = 1 + bonus
```

Ожидаемые точки: полное HP `x1.00`, половина HP `x1.20`, нулевое и
отрицательное HP `x1.40` с жёстким капом. Слой применяется ко всем трём
оружиям Берсерка и эхо-волне ульты ровно один раз; другие классы и
существующие low-HP artifact effects не меняются.

## Implementation Result

- `ProgressionData.CLASS_TRAITS.berserk.rage_damage_bonus_cap = 0.40`.
- Единая формула: `ProgressionData.class_rage_damage_bonus`.
- Runtime consumer: `Player.rage_damage_multiplier`.
- Все три `sword` / `axe` / `hammer` проходят через один
  `BerserkWeapon._rolled_damage` слой после базового урона и крита.
- Close/execute/followup используют уже усиленный `dealt` и не вызывают
  `rage_damage_multiplier` повторно.
- Эхо-волна `Player._trigger_berserk_ultimate_echo` применяет тот же слой один
  раз; сам radius damage path его повторно не множит.
- Budget mirror: `1 + 0.40 * 0.30 = x1.12` до добавления ultimate output.
- Коммиты реализации и документации: `40b2c14cb`, `e0709a347`; оба являются
  предками production `origin/dev`.

## Balance Result

Независимое сравнение выполнено между parent `5229e770f` (до trait) и
production-версией после `40b2c14cb`; повторная полная приёмка выполнена на
`origin/dev` `30e13b94d` после интеграции последующих общих data/runtime
изменений.

### Class trio before / after

`crowd_score` — среднее `target_CCT / measured_CCT` по 5/10/20 целям и всем
трём оружиям. Defense score оставлен `1.000`: task не меняет survivability,
EHP каждого варианта остаётся `120.2`, глобальный survivability gate зелёный.

| State | Weapons | Solo score | AoE score | Crowd score | Defense score | Total score | Diagnosis |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| before | sword / axe / hammer | 1.000 | 1.000 | 0.935 | 1.000 | 0.984 | all three tuned weapons pass |
| after | sword / axe / hammer | 1.000 | 1.000 | 0.935 | 1.000 | 0.984 | trait budget is compensated; kit corridor preserved |

### Per-weapon before / after

Untuned channels show the expected trait budget factor, while the actual tuned
runtime estimates remain at the target. Thus the sword does not hide a weak
axe/hammer result, and the hammer anti-runaway gate independently covers its
high-density ceiling.

| Weapon | Untuned solo before -> after | Factor | Untuned 5T before -> after | Factor | Runtime tuned solo / 5T | Identity |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| sword | 62.05 -> 69.47 | 1.120 | 212.67 -> 238.11 | 1.120 | 48.00 / 150.08 | long narrow sweep |
| axe | 21.10 -> 23.62 | 1.119 | 100.49 -> 112.51 | 1.120 | 48.02 / 150.00 | wide melee sector |
| hammer | 13.44 -> 15.04 | 1.119 | 41.40 -> 46.33 | 1.119 | 48.02 / 149.97 | circular crowd slam |

Tuning moved `sword 0.739 -> 0.660` and `axe 1.843 -> 1.646`, approximately
the inverse of `x1.12`. Hammer remains at the existing `2.800` tuning ceiling,
but its actual solo/5T and all three CCT rows remain in corridor; the dedicated
runaway gate is also green (`20t=3233 <= 3600`, `1t=356 <= 650`). No weapon is
dead weight or the sole reason the class total passes.

## Static QA

- `rage_damage_bonus_cap` exists only under the `berserk` class trait.
- Full, half, zero/negative, over-max and invalid max-health cases are covered
  by the focused gate; the formula clamps the missing ratio to `[0, 1]`.
- `rage_damage_multiplier` has exactly two production call sites: the shared
  Berserk weapon roll and Berserk ultimate echo.
- Secondary melee effects consume the already calculated amount and do not
  recurse into the Rage formula.
- The SCRUM-1004 diff does not change target `take_damage`, dodge, shield,
  damage prevention or hit-dispatch ordering; prevented/reduced-damage
  semantics therefore remain the existing production semantics.
- Registry, Russian character text, class-trait registry and
  `systems/characters_weapons.md` describe the same cap, formula and budget.

## Verification

All commands used `python3 tools/godot_gate.py --headless --path . --script` on
clean production `origin/dev` `30e13b94d`:

- `tests/berserk_rage_trait_test.gd` — PASS.
- `tests/berserk_dps_runaway_gate.gd` — PASS (`3233/356` against `3600/650`).
- `tools/balance_harness.gd` — PASS; `balance_report.md` and final audit written.
- `tests/global_damage_balance_smoke_test.gd` — PASS, 51 pairs.
- `tests/global_survivability_balance_smoke_test.gd` — PASS, 16 profiles.
- `tests/weapon_tuning_application_test.gd` — PASS, 51 pairs.
- `tests/weapon_integrity_test.gd` — PASS, 17 classes / 51 weapons.
- `tests/damage_type_isolation_test.gd` — PASS, 3 owners / 3 damage types.
- `tests/runtime_smoke_test.gd` — PASS, exit `0`.

The full runtime emitted only the known non-fatal headless screenshot-capture
diagnostics (`Lambda capture ... freed` and dummy-renderer null texture); the
test completed with its explicit PASS marker and exit `0`.

Remaining risk: manual feel of the full-health-to-low-health risk/reward curve
still benefits from playtesting, but no automated balance, integrity,
survivability, isolation or runaway regression remains.

## QA-Вердикт: PASSED

Статус: PASSED

Independent production QA confirmed the formula, hard cap, class isolation,
three-weapon coverage, ultimate echo, exactly-once secondary behavior, budget
factor `x1.12`, trio balance and full regression matrix on the latest
`origin/dev` available during acceptance.

Disk cleanup: disposable QA worktree, `.godot`, generated reports and transient
UID sidecars removed after the QA mirror commit is landed.
