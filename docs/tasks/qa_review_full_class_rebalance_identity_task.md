# QA Review: Full Class Rebalance And Class Identity
Статус: blocked
Версия: 0.2.1
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Locked paths: QA evidence under `build/qa/full_class_rebalance/`, screenshots/reports only
Jira: SCRUM-861
Исполнитель: Codex

## Контекст
QA gate для полной волны class rebalance 2026-07-04. Эта задача остается blocked, пока backend tasks по identity audit, projectile/chain/pierce, melee/counter/tank, summon/deploy/turret and kill-scaling/sustain не переведены в `Контроль качества` или не имеют truthful blocked/handoff status.

## Что Проверить
- [ ] Все 17 классов и 51 оружие покрыты финальным before/after class-trio report.
- [ ] У каждого класса три оружия играются по-разному; нет одинаковых AoE/цепей/взрывов/саммонов, отличающихся только цветом или числом.
- [ ] Soldier grenade, Elementalist meteor, Thief ricochet, Sniper split/pierce, Priest chain, Dark Mage pierce/curse and delayed AoE mechanics are distinguishable in runtime reports or focused tests.
- [ ] Knight counter fantasy реально работает: входящий урон провоцирует meaningful retaliation, но не дает бессмертия.
- [ ] Engineer turret/deploy gameplay works; Druid/Chemist/Guitarist summon/deploy identities remain distinct.
- [ ] Kill-scaling/sustain mechanics capped; Doctor/Priest/Knight/generic vampirism do not collapse into one sustain loop.
- [ ] Docs and Jira evidence match the implemented code.
- [ ] Required smokes from backend evidence are green, including `runtime_smoke_test.gd`.

## QA-Вердикт
Заполняет QA.
