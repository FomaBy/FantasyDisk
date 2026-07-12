# BUG: Robot redesign docs and balance evidence remain stale after SCRUM-914/915/916/918

Статус: done
Приоритет: normal
Роль: Back-end
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Jira: SCRUM-1035
Спринт: 0.2.1
Найдено QA при тестировании: SCRUM-914, SCRUM-915, SCRUM-916, SCRUM-918
Locked paths: `docs/design/class_traits_registry.md`, Robot sections in current/mechanics/content/system docs, `tools/live_combat_harness.gd`, Robot balance evidence/tests

## Дефект

- `docs/design/class_traits_registry.md` всё ещё помечает `armored_hull` /
  SCRUM-914 как `backlog`, хотя trait уже в runtime.
- `current_game_state.md`, `mechanics_extract.md`, `content_registry.md` и
  `systems/characters_weapons.md` описывают старые сокращённые механики и не
  фиксируют точные x0.8 post-mitigation, 85% point pull, 80% line compression с
  elite/boss ×0.25 и неищущий цели Reactor fan с шагом +6°/cast.
- `tools/live_combat_harness.gd::KNOWN_ARTIFACTS` утверждает, что урон Reactor
  делится на четыре, и описывает фиксированный крест. Лендед runtime применяет
  `REACTOR_VENT_DAMAGE_RATIO = 0.42` на вентиль и вращает паттерн на 6°.
- Нет аудируемой class-trio таблицы Robot с solo, AoE/crowd, defense/control и
  aggregate total; Jira comments приводят только pair-level formula gates.

## Acceptance Criteria

- Trait registry помечен `implemented`; relevant domain/current/registry docs
  синхронизированы с точными runtime формулами, капами и distinct niches.
- Live-combat artifact/model исправлен под вращающийся четыре-вентильный runtime
  и не скрывает реальный риск устаревшим текстом.
- Добавлены per-weapon и class-trio solo/AoE/crowd/defense/total evidence с
  различием Anchor point grouping, Press line alignment и Reactor rotating zone.
- Balance/global/survivability/runtime gates зелёные и приложены к исходным
  Jira issues перед повторным QA.

## Результат (SCRUM-1035)

Синхронизировал доки и balance-evidence Робота с ЛЕНДЕД-рантаймом
(`scripts/progression_data_weapons.gd`, `scripts/progression_data_characters.gd`,
`scripts/class_weapon.gd`):

- `docs/design/class_traits_registry.md`: `armored_hull`/SCRUM-914 переведён
  `backlog → implemented`; в блок «Реализованные traits волны» добавлена запись
  Робота (`incoming_damage_multiplier: 0.8`, последний множитель после
  dodge/block/absorb/defense, пол 0.5, тест robot_kit_test).
- `tools/live_combat_harness.gd::KNOWN_ARTIFACTS`: старый текст «урон делится на
  4 / фиксированный крест» заменён на реальный рантайм — вращающийся 4-вентильный
  веер, +6°/каст (цикл 15 атак), пер-вентильный урон = ролл × `REACTOR_VENT_DAMAGE_RATIO`
  (0.42), extra_projectile лишь расширяет лопасти; артефакт-объяснение оставляет
  реальный риск видимым (не скрывает устаревшим текстом).
- `current_game_state.md`, `mechanics_extract.md`, `content_registry.md`,
  `systems/characters_weapons.md`: Robot-строки/проза приведены к точным формулам
  и капам — x0.8 post-mitigation, 0.85 point pull (cap 1500), 0.80 line
  compression с elite/boss ×0.25, урон по всей ширине коридора 300 (×1.30 с
  «Калибратором»), Reactor +6°/каст ролл×0.42 без самонаведения, distinct niches
  (anchor point-grouping / press line-alignment / reactor rotating-zone).
- `mechanics_extract.md`: добавлена per-weapon + class-trio evidence-таблица
  (solo / 5-target / TTK / niche) из живого `live_combat_harness`, с явным
  artifact-флагом Реактора и разбивкой по осям solo/AoE-crowd/defense-control/total.

Живой замер `tools/live_combat_harness.gd` (L1, окно 8с, стационарный
односторонний кластер, без ульты — систематически ниже формулы):
- `robot_magnetic_anchor`: solo 13.8 / 5-target 51.5 / TTK 6.5с — point grouping.
- `robot_hydraulic_press`: solo 18.7 / 5-target 116.6 / TTK 4.8с — line alignment.
- `robot_reactor_core`: solo 3.8 / 5-target 20.3 / TTK 23.4с — rotating zone
  (документированный артефакт замера: односторонний кластер ловит ~1 из 4 лопастей).
Формульный `balance_harness` держит трио в бюджете профиля `balanced/tank`
(ориентир solo ~45.2 / 5-target ~138.6, ≈0% отклонения).

Гейты (fdengine, `tools/godot_gate.py`, вердикт = `${pipestatus[1]}`+текст), все зелёные:
- `robot_kit_test`: exit 0, passed (100→80, 5→4, ordered→32, dot10→8, soldier→100; worst-case mitigation det 87.23% / dodge-EV 94.25% < 98%).
- `runtime_smoke_weapon_mechanics_test`: exit 0, passed, «Lambda capture» 0.
- `weapon_integrity_test`: exit 0, passed (17 classes, 51 weapons).
- `global_survivability_balance_smoke_test`: exit 0, passed (митигация<98%, бессмертие недостижимо).
- `runtime_smoke_test`: exit 0, passed.
- `live_combat_harness` Robot-секция: «Lambda capture» 0 (было 6).

Коммиты: `3d3446924` (SCRUM-1034 код/тест), docs-коммит — см. Jira-коммент.
Disk cleanup: none created (worktree убирает оркестратор).

## QA-Вердикт (2026-07-10)

Статус: PASSED
QA owner: Claude orchestrator
Checked ref: origin/dev (после a56991648 / f6c26ca81)

Verification:
- robot_kit_test exit=0, «Lambda capture» в выводе = 0 (было 1).
- runtime_smoke_weapon_mechanics_test exit=0, «Lambda capture» = 0 (было 2).
- Побочный улов харнесса (SCRIPT ERROR take_damage в ally_minion) — отдельный SCRUM-1042 (ed651a4b4, закрыт).
- Доки/registry/harness синхронизированы с рантаймом Робота (SCRUM-1035).
