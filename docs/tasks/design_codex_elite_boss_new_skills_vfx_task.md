# Арт/VFX новых скилов элиток и боссов (ауры/лужи/яд/телепорт/щит) — патч 0.1.5

Статус: done (QA PASSED 2026-06-14)
Приоритет: normal
Роль: Design (Codex генерация) → Claude-Designer
QA: in_progress (2026-06-14)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-261
Эпик-патч: 0.1.5 Бой и баланс (SCRUM-232)

## Dispatcher Dispatch (2026-06-14)

Sent to Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` after SCRUM-259
completed and unblocked this VFX handoff. Keep reasoning High/no low. Scope is
Design/VFX polish only: preserve Back-end timings, damage, node names and
mechanics; create Animator or Back-end handoff if motion-state work or gameplay
wiring is needed.

## Dependency Gate 0.1.5
SCRUM-259 mechanics готов и переведен Back-end в `done` 2026-06-13. Задача
разблокирована для Design: VFX делаются под реальные data-driven patterns из
`ProgressionData.ENEMY_MECHANIC_CATALOG` / `UNIQUE_ENCOUNTER_PATTERNS`.

## Back-end Handoff Update (2026-06-13, SCRUM-259 done)

Runtime nodes/mechanics, которым нужен финальный VFX polish:

- Elite Iron Bastion: `shield_block`, `reflect_thorns`, `slam_wave`.
- Elite Night Stalker: `blink_reposition`, `mirror_double`, `shadow_strike`.
- Elite Plague Prophet: `poison_volley`, `hazard_pool`, `poison_dot`.
- Elite Shard Marshal: `aura_buff`, `shard_fan`, phase-2 ring volley.
- Boss Rift Warden: `BossGravityWell`, `rift_zone`, `rift_wave`, shield/summon.
- Boss Disk Devourer: `BossVampiricBite`, `DiskSlamZone`, radial burst, enrage.
- Boss Bone Archon: bone prison/wall via `BossRiftZone`, skull fan, summon.
- Boss Brood Mother: `BroodWebZone`, swarm/summon pressure, phase-3 lunge.
- Boss Ashen Colossus: `BossMoltenArmorPulse`, `AshEmberZone`, slam/enrage.

Back-end currently uses existing `HazardVfx.telegraph`/`detonate`,
`hazard_zone.png`, poison pool and elite VFX fallback assets. Design should
replace/polish visuals without changing gameplay timings, damage or node names.

## Parked Draft (2026-06-13)

По superseded dispatcher handoff Design успел сгенерировать черновой VFX-kit до
коррекции фриза. Черновики убраны из live assets и припаркованы для будущей
версии `0.1.5`:

- `docs/design/backlog/vfx_015/effects/`
- `docs/design/backlog/vfx_015/previews/`
- `docs/design/backlog/vfx_015/vfx_unique_weapon_enemy_kit.md`
- `docs/design/backlog/vfx_015/generate_unique_weapon_enemy_vfx.py`

Это не active 0.1.4 content, не runtime wiring и не основание переводить задачу
в `in_progress`.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
Новым уникальным скилам элиток/боссов (ауры, лужи урона, яд, телепортация,
блок/щит, призыв и придуманные) нужен читаемый D&D VFX и телеграфы.

## Требования
1. По каталогу механик (backend_elites_bosses_unique_skills_mechanics_task):
   нарисовать/обновить VFX-кадры и телеграфы — аура-кольца, лужи (огонь/кислота/
   яд), маркеры телепорта (вход/выход), щит/блок-эффект, призывной портал,
   зоны замедления/гравитации и т.д. D&D-канон, читаемо, без неона; telegraph
   чётко отличим от детонации.
2. Генерация — Codex с референсами; Claude-Designer ревью/нарезка/интеграция в
   HazardVfx/эффект-пулы.
3. content_registry; превью; smoke (hazard_vfx/attack_vfx/runtime).
4. CHANGELOG.

## Files / Assets / IDs
- assets/sprites/effects/, scripts/hazard_vfx.gd (интеграция), docs/design/previews/
- content_registry.md

## Acceptance Criteria
- [x] VFX/телеграфы новых скилов в каноне, читаемы; превью.
- [x] Интегрированы в HazardVfx/пулы; content_registry/CHANGELOG; focused VFX/boss smokes зелёные, full runtime caveat записан ниже.

## Результат (2026-06-14)

Статус: review

Design/Codex VFX pass завершён для SCRUM-261.

Сделано:
- Перерисован/усилен активный shared hazard kit: `hazard_zone.png`,
  `impact_ring.png`, `impact_flash.png`, `poison_pool.png`,
  `elite_telegraph_circle.png`, `elite_shockwave_ring.png`,
  `elite_shadow_trail.png`, `elite_poison_lob.png`, `elite_crystal_shard.png`.
- Добавлены dedicated PNG под runtime node/mechanic IDs SCRUM-259:
  `boss_gravity_well_zone.png`, `boss_vampiric_bite_zone.png`,
  `boss_rift_zone.png`, `boss_bone_prison_zone.png`,
  `boss_brood_web_zone.png`, `boss_ash_ember_zone.png`,
  `boss_molten_armor_pulse.png`, `enemy_summon_portal.png`,
  `enemy_shield_block_front.png`, `enemy_reflect_thorns_aura.png`,
  `enemy_command_aura_pulse.png`, `enemy_shadow_blink_mark.png`,
  `enemy_shard_fan_burst.png`.
- `HazardVfx` теперь выбирает texture по runtime node name, поэтому
  `BossGravityWell`, `BossVampiricBite`, `BossRiftZone`/bone prison,
  `BroodWebZone`, `AshEmberZone`, `BossMoltenArmorPulse` получают отдельный
  визуальный материал без изменения damage/timing/node names.
- Добавлены визуальные helpers `shield_block()` и `summon_portal()`; они
  подключены к текущим shield/summon моментам как VFX-only слой.
- Elite telegraph selection различает `shadow_strike` и `shard_fan` через новые
  `enemy_shadow_blink_mark.png` / `enemy_shard_fan_burst.png`.
- Pipeline/источник: `tools/generate_elite_boss_vfx_015.py`.
- QA preview: `docs/design/previews/scrum261_elite_boss_vfx_contact.png`.
- Обновлены `content_registry.md`, `current_game_state.md`,
  `docs/design/systems/enemies_bosses.md`, `CHANGELOG.md`.

Проверки:
- `Godot --headless --path ... --import` — PASS, новые PNG импортированы.
- `tests/hazard_vfx_smoke_test.gd` — PASS.
- `tests/attack_vfx_smoke_test.gd` — PASS; в логе остаются существующие
  нерелевантные warnings/errors от duplicate global-class/CombatTargetQuery
  состояния рабочего дерева, но test завершился успешно.
- `tests/runtime_smoke_boss_elite_test.gd` — PASS; те же существующие
  нерелевантные log errors присутствуют, exit code 0.
- `tests/runtime_smoke_test.gd` — FAIL на существующем нерелевантном состоянии
  рабочего дерева (`CombatTargetQuery`/global-class duplicate + hero select
  path в `ui_screens.gd`), не на новых SCRUM-261 VFX assets/routes.

Границы соблюдены: gameplay timings, damage, balance, node names и Back-end
mechanics не менялись; motion/AnimationPlayer scope не выполнялся. Full runtime
smoke требует отдельного Back-end/UI cleanup вне Design scope.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 2981acf8 (ветка dev)

Проверено (фактически):
- **13 boss/enemy VFX-ассетов** (`boss_*_zone.png` ×7 + `enemy_*` ×6:
  summon_portal/command_aura/reflect_thorns/shadow_blink/shard_fan/shield_block) —
  все RGBA8, 0 битых.
- **Интеграция VFX-only**: `HazardVfx` выбирает текстуру по runtime node name
  (BossGravityWell/VampiricBite/RiftZone/BroodWeb/AshEmber/MoltenArmor), хелперы
  `shield_block()`/`summon_portal()`, telegraph различает shadow_strike/shard_fan —
  БЕЗ изменения damage/timing/node-names (границы соблюдены).
- **Визуал** (`scrum261_elite_boss_vfx_contact.png`): 13 telegraph/aura VFX
  читаемы, различимы по цвету/форме per-способность, в dark-fantasy каноне,
  прозрачный фон.
- **Smoke**: `hazard_vfx` + `attack_vfx` + `runtime_smoke_boss_elite` — passed.
  **Full `runtime_smoke` теперь ТОЖЕ зелёный**: заявленный в Result FAIL был
  артефактом ` 2.gd` duplicate-class корраптации рабочего дерева — она УСТРАНЕНА
  cleanup'ом SCRUM-270/271 (зачтены QA), и runtime_smoke на текущем HEAD проходит.

Acceptance:
- [x] VFX/телеграфы новых скилов в каноне, читаемы; превью.
- [x] Интегрированы в HazardVfx/пулы; focused VFX/boss smokes зелёные; full runtime
  caveat снят (corruption вычищена).

Баги: нет.
