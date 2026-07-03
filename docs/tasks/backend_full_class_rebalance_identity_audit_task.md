# Full Class Rebalance: Identity Audit And Trio Matrix
Статус: new
Версия: 0.2.1
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Locked paths: `docs/design/reports/full_class_rebalance_identity_audit.md`, `build/full_class_rebalance_*`, focused audit/test helpers only; core runtime files read-only unless this task is explicitly expanded
Jira: SCRUM-856
Исполнитель: Codex

## Контекст
Пользовательская задача 2026-07-04: полностью пересмотреть ребаланс всех классов так, чтобы каждый класс и каждое из трех оружий имели уникальный gameplay. Сейчас часть атак ощущается похожей: зоны, взрывы, цепи, summon/deploy и sustain должны различаться не только цифрами, но и ритмом, геометрией, setup/payoff, риском и defensive utility.

## Требования
- [ ] Прочитать `fantasydisk-class-balance-director` и обязательные balance docs.
- [ ] Инвентаризировать все 17 классов и 51 оружие из `ProgressionData.WEAPONS_BY_CLASS`.
- [ ] Составить before class-trio table: solo, AoE/5t, crowd 5/10/20, defense/sustain/control, total kit score, identity diagnosis.
- [ ] Составить per-weapon identity table: range/risk, target geometry, cadence, setup/payoff, solo/crowd role, defensive contribution, scaling hook.
- [ ] Отметить клоны/почти-клоны: одинаковые AoE, одинаковые delayed explosions, одинаковые pierce/chain/ricochet, мертвые summon/deploy slots, слишком похожий sustain.
- [ ] Развести implementation follow-ups по dependency order и locked paths; `SCRUM-854` считать активным overlapping scope для zones/summons/doctor until Jira says otherwise.
- [ ] Обновить `docs/design/systems/characters_weapons.md`, `docs/design/systems/progression_balance.md` или `docs/design/mechanics_extract.md`, если аудит уточняет текущий контракт.

## Acceptance Criteria
- [ ] В отчете есть таблица всех 17 class kits и всех 51 weapons.
- [ ] Для каждого класса указан intended gameplay fantasy и три непохожие роли оружия.
- [ ] Для каждого найденного clone/dead-slot указан конкретный recommended mechanic-first fix, а не только numeric buff/nerf.
- [ ] Отчет явно покрывает идеи пользователя: delayed grenade/meteor, damaging projectile without landing damage, ricochet/split/pierce, chain lightning/prayer, melee AoE with risk window, turret/deploy gameplay, shield counter damage, kill-scaling/vampiric growth.
- [ ] Команды/источники измерений перечислены; если full harness не запускался, указана причина.
- [ ] Jira result comment содержит ссылки на отчет и список задач, которые audit разблокировал.

## Результат
Заполняет исполнитель.
