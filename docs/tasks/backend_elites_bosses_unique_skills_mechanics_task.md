# Уникальные паттерны и новые скилы/механики для ВСЕХ элиток и боссов

Статус: done
Приоритет: high
Роль: Back-end (механики/бой)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-259
QA: in_progress (2026-06-14)
Эпик-патч: 0.1.5 Бой и баланс (SCRUM-232)

## Dispatcher Dispatch (2026-06-14)

Queued to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after
SCRUM-253. Keep reasoning High/no low. Scope is Back-end mechanics only:
enemy/boss/combat/hazard/progression-data/tests. Design VFX task SCRUM-261
stays blocked until mechanics are done; if animation or VFX ownership appears,
create/update Design/Animator handoff instead of doing art/motion work here.

## Sprint 0.1.5
Фича-фриз снят после релиза `v0.1.4`; задача входит в активный sprint 0.1.5 и
готова к dispatch, если нет file-collision с уже взятой Back-end задачей.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Подумать насчёт скилов всех элиток и боссов, добавить ВСЕМ уникальные паттерны
поведения, новые скилы и механики: ауры, призывы, телепортация, лужи урона, яд,
блокирование урона и т.д. — придумать ещё».

Сейчас у части элиток/боссов есть telegraph-атаки/фазы, но не у всех уникальные
поведенческие паттерны. Нужно: каждой элитке и боссу — СВОЙ узнаваемый набор.

## Требования
1. **Каталог механик** (переиспользуемые, data-driven): аура (бафф себе/свите
   или дебафф игроку в радиусе), призыв адъютантов/роя, телепортация/блинк к
   игроку или реpositioning, лужи урона/огня/кислоты (HazardVfx-телеграф), яд/
   DoT при попадании, блок/щит (временное снижение/иммунитет фронтального урона),
   рывок-charge с телеграфом, отражение снарядов, замедляющие зоны, вампиризм
   элитки, разлом-волны. ПРИДУМАТЬ дополнительно ещё 4-6 уникальных (например:
   раскол на двух при низком HP; зеркальный двойник; гравитация-притяжение;
   временная неуязвимость с уязвимой точкой; проклятие, инвертирующее лечение
   игрока; шипованный панцирь — урон в ответ на ближний удар).
2. **Назначить КАЖДОЙ элитке и боссу уникальный паттерн** (комбинация 1-3
   механик из каталога) — не повторяющийся между сущностями; согласовать с их
   темой (костяной — призыв скелетов; чумной — яд/лужи; теневой — телепорт;
   панцирный — блок; и т.д.).
3. **Телеграфы обязательны** для отложенных/зонных скилов (HazardVfx, никаких
   голых кругов). Фазовость боссов сохранить/расширить.
4. Баланс: новые скилы не превращают элиток/боссов в нечестных; TTK-цели и
   выживаемость игрока в коридорах глобального smoke (SCRUM-249); честные окна
   для контрплея.
5. **Handoff Design** (VFX скилов/аур/луж/телепорта — отдельная задача
   design_codex_elite_boss_new_skills_vfx) и **Animator** (анимации новых атак).
6. Кодекс/бестиарий: описать новые паттерны по-русски.
7. Тест (smoke): спавн каждой элитки/босса инстанцирует её уникальный паттерн
   (фактическое дерево/мета/телеграфы создаются); фазы переключаются.
8. CHANGELOG; mechanics_extract; current_game_state.

## Files / Assets / IDs
- scripts/enemy.gd, scripts/boss.gd, scripts/combat_director.gd, scripts/hazard_vfx.gd,
  scripts/progression_data.gd (данные элиток/боссов/паттернов), tools/balance_harness.gd, tests/
- Handoff: design_codex_elite_boss_new_skills_vfx_task, animation (боссовые атаки)

## Acceptance Criteria
- [x] Каталог механик (включая 4-6 новых придуманных) реализован data-driven.
- [x] Каждой элитке и боссу — уникальный непов­торяющийся паттерн с телеграфами.
- [x] Баланс в коридорах глобального smoke; честный контрплей.
- [x] Кодекс пополнен; тесты паттернов; 6 smoke зелёные; VFX/анимация handoff'ы созданы.

## Result Summary (2026-06-13, Back-end)

- Добавлен data-driven каталог `ProgressionData.ENEMY_MECHANIC_CATALOG` с 16 mechanics, включая новые `reflect_thorns`, `mirror_double`, `gravity_pull`, `weakpoint_shell`, `healing_inversion`, `split_spawn`.
- Вынесены elite configs в `ProgressionData.ELITE_ATTACK_CONFIGS` и добавлен registry `ProgressionData.UNIQUE_ENCOUNTER_PATTERNS` для всех 4 элиток и 5 боссов.
- Runtime enemies/bosses теперь получают meta `unique_pattern_id`, `unique_pattern_title`, `unique_mechanics`; smoke проверяет эти meta, уникальные signatures и фазовые telegraph states.
- Добавлены/закреплены mechanics:
  - Iron Bastion: shield + `reflect_thorns` + slam wave.
  - Night Stalker: blink + phase-2 mirror strike.
  - Plague Prophet: poison volley/pools + plague hook.
  - Shard Marshal: aura + shard fan + phase-2 ring volley.
  - Rift Warden: `BossGravityWell`.
  - Disk Devourer: `BossVampiricBite`.
  - Bone Archon: bone prison/wall через `BossRiftZone` с safe gap.
  - Brood Mother: дополнительный `BroodWebZone` pressure.
  - Ashen Colossus: `BossMoltenArmorPulse`.
- Кодекс и domain docs обновлены; Design handoff `design_codex_elite_boss_new_skills_vfx_task.md` разблокирован и дополнен фактическими runtime node/mechanic IDs. Нового арта/animation work в Back-end не выполнялось.

Verification:
- `res://tests/progression_data_api_surface_test.gd` — passed.
- `res://tests/runtime_smoke_boss_elite_test.gd` — passed.
- `res://tests/runtime_smoke_test.gd` — passed.
- `res://tests/global_damage_balance_smoke_test.gd` — passed.
- `res://tests/global_survivability_balance_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 2981acf8 (ветка dev)

Проверено (фактически):
- **Data-driven каталог механик** + уникальные паттерны 4 элитки / 5 боссов с
  телеграфами (enemy.gd/boss.gd/combat_director).
- **Целевой тест** `runtime_smoke_boss_elite_test` — passed (спавн каждой элитки/
  босса инстанцирует её уникальный паттерн — acceptance #7); `codex_data_smoke`
  — passed (26 монстров/механик в реестре).
- **Баланс/контрплей в коридоре**: `global_damage_balance` (51 пара) +
  `global_survivability` (TTD≤600с, честные окна — бессмертие/анти-плей нет) —
  зелёные; api_surface + runtime — зелёные.

Acceptance:
- [x] Каталог механик (4-6 новых) реализован data-driven.
- [x] Каждой элитке/боссу — уникальный непов­торяющийся паттерн с телеграфами.
- [x] Баланс в коридорах global smoke; честный контрплей. SCRUM-261 VFX handoff —
  закрыт (QA passed).

Баги: нет.