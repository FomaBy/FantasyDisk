# QA Review: AOE Weapon Overlays, Persistent Zones, Summons, And Doctor Sustain

Статус: new
Версия: 0.2.1
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Locked paths: QA evidence under `build/qa/aoe_weapon_overlays_zones_summons_doctor/`, screenshots/reports only
Jira: SCRUM-855
Исполнитель: Codex

## Контекст

QA gate для backend задачи `backend_aoe_weapon_overlays_zones_summons_doctor_task.md`.

## Что Проверить

- [ ] В бою weapon overlays при атаках читаются примерно как `60% opacity` и не выглядят почти невидимыми.
- [ ] Berserk sword/axe sweep визуально ориентирован как удар наружу от персонажа; hammer circle остается логичным круговым slam.
- [ ] Лужи/зоны/мины не исчезают при следующей атаке, живут собственный lifetime и наносят tick/trigger damage врагам внутри.
- [ ] Summon-оружия добирают minions от стартовой half-quota до Leadership-scaled лимита; minion hit имеет маленький AOE без runaway.
- [ ] Doctor больше не видит внешние regeneration/vampirism rewards в level-up/shop reward pool, но его weapon sustain работает.
- [ ] Документация и task evidence соответствуют фактическому коду.
- [ ] `runtime_smoke_test.gd` и focused tests из backend evidence зелёные; если QA запускает subset, указать точные команды.

## QA-Вердикт

Pending. Backend `SCRUM-854` is preparing a pushed branch/commit and will move
to `Контроль качества` before this QA task is claimed.
