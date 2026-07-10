# BUG: Robot redesign docs and balance evidence remain stale after SCRUM-914/915/916/918

Статус: new
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
