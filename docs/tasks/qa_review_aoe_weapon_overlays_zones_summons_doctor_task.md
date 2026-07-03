# QA Review: AOE Weapon Overlays, Persistent Zones, Summons, And Doctor Sustain

Статус: done
Версия: 0.2.1
Контур: Codex
Owner: qa/codex-scrum855-review
Thread/Worker: Godel independent QA subagent + codex-qa-scrum863-2itic6 evidence recheck
Locked paths: none after completion; mirror repaired under `SCRUM-863`
Jira: SCRUM-855
Исполнитель: Codex

## Контекст

QA gate для backend задачи `backend_aoe_weapon_overlays_zones_summons_doctor_task.md`.

## Что Проверить

- [x] В бою weapon overlays при атаках читаются примерно как `60% opacity` и не выглядят почти невидимыми.
- [x] Berserk sword/axe sweep визуально ориентирован как удар наружу от персонажа; hammer circle остается логичным круговым slam.
- [x] Лужи/зоны/мины не исчезают при следующей атаке, живут собственный lifetime и наносят tick/trigger damage врагам внутри.
- [x] Summon-оружия добирают minions от стартовой half-quota до Leadership-scaled лимита; minion hit имеет маленький AOE без runaway.
- [x] Doctor больше не видит внешние regeneration/vampirism rewards в level-up/shop reward pool, но его weapon sustain работает.
- [x] Документация и task evidence соответствуют фактическому коду.
- [x] `runtime_smoke_test.gd` и focused tests из backend evidence зелёные; если QA запускает subset, указать точные команды.

## QA-Вердикт

PASSED on 2026-07-04.

Evidence:
- Backend mirror `docs/tasks/backend_aoe_weapon_overlays_zones_summons_doctor_task.md`
  is committed on `dev`, status `done`, and records implementation summary,
  locked paths, focused test commands, runtime smoke, docs touched, subagent
  review, and disk cleanup.
- Verified commits:
  - `c6634fac` (`fix(SCRUM-854): clarify attack zones and sustain rolls`)
  - `6228eac2` (`fix(SCRUM-864): raise berserk exact overlay opacity`)
  - `d60283d4` (`docs(SCRUM-854): record QA passed mirror`)
- Main-thread validation recorded in backend mirror:
  - `tests/attack_vfx_smoke_test.gd`
  - `tests/persistent_hazard_contract_test.gd`
  - `tests/summoner_strengthening_test.gd`
  - `tests/doctor_drain_softcap_test.gd`
  - `tests/attribute_relevance_test.gd`
  - `tests/start_boons_test.gd`
  - `tools/balance_harness.gd`
  - `tests/global_damage_balance_smoke_test.gd`
  - `tests/global_survivability_balance_smoke_test.gd`
  - `tests/runtime_smoke_test.gd`
- Independent read-only QA subagent `Godel` reran the same required set with
  `FSD_GODOT_SLOTS=1` and returned PASS.
- SCRUM-863 read-only recheck on fresh `origin/dev` confirmed both referenced
  mirror paths exist in git history; only this QA mirror had remained a pending
  template before the SCRUM-863 evidence repair.

Residual non-blocking note: runtime smoke still logs the known Godot
CallbackTweener `_apply_dot_tick` conversion errors, but exits 0 and reports
`Runtime smoke test passed`.

Disk cleanup: main-thread temporary QA logs removed after final sync/commit;
SCRUM-863 QA recheck removed `/private/tmp/fantasydisk-scrum863-qa-2itic6` and
`/tmp/scrum863_runtime_smoke*.log`.
