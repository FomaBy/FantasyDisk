# BUG: Боссовский hazard смены фазы — голый залитый красный круг (пропущен VFX-полировкой)

Статус: done 2026-06-12 (fixed Claude-Designer)
Приоритет: normal
Роль: Design (Claude-Designer) / Back-end (зона — рендер во время боя)
Jira: SCRUM-62
Найдено QA при тестировании: `docs/tasks/qa_review_design_weapon_attack_vfx_animations_polish_task.md`
(исходная фича: `docs/tasks/design_weapon_attack_vfx_animations_polish_task.md`)

## Воспроизведение
1. Любой забег, дойти до боя с боссом (достаточно Возвышение 0).
2. Нанести боссу урон до перехода во 2-ю фазу (затем 3-ю).
3. На каждой смене фазы под боссом появляется hazard-зона.

## Ожидание / Реальность
- Ожидание (главный критерий задачи): «голых программных кругов/примитивов,
  которые видит игрок, в боевом слое не осталось»; боссовские зоны оформлены через
  `HazardVfx` (телеграф→детонация).
- Реальность: `scripts/boss.gd:314 _spawn_phase_transition_hazard()` (узел
  `BossPhaseHazard`) рисует голый залитый красный `Polygon2D`-диск (48 точек,
  `Color(1.0,0.28,0.16,0.22)` → темнеет до `0.58` на детонации, `boss.gd:326-332`),
  НЕ используя `HazardVfx`. Соседние `_spawn_rift_zone` (`:202`) и `_spawn_disk_slam`
  (`:230`) переведены на оформленный `HazardVfx.telegraph/detonate` — этот третий
  тип боссовской зоны пропущен.

Дополнительно: документация заявляет полную конверсию, что не соответствует факту —
  `CHANGELOG.md:19` («боссовские rift/disk-slam ... переведены») и
  `content_registry.md:139` («Заменены голые Polygon2D-круги боссовских зон»). Зона
  смены фазы там не учтена.

## Влияние
Достижимо в обычном забеге (босс имеет ≥3 фазы по умолчанию → зона рисуется 2 раза
за бой; на Возвышении 9 — 4-я фаза, чаще). Геймплей (radius/timing/damage) работает,
дефект чисто визуальный, но прямо нарушает центральный acceptance-критерий задачи
«голых не осталось» и противоречит CHANGELOG/registry.

## Предлагаемое направление фикса (для исполнителя)
Перевести `_spawn_phase_transition_hazard()` на `HazardVfx.telegraph(...)` +
`HazardVfx.detonate(...)` по образцу `_spawn_rift_zone`/`_spawn_disk_slam` (цвет
красный, radius/timing/damage сохранить). После фикса синхронизировать формулировки
в `CHANGELOG.md:19` и `content_registry.md:139` (упомянуть зону смены фазы).

## Окружение
Godot 4.6.3.stable, оконный/headless. Коммит 8d5e489 (+ незакоммиченные правки).
Босс, фазы 2/3 (Возвышение 0) и 4 (Возвышение 9). Разрешение — любое.


## Fix / 2026-06-12 (Claude-Designer)
boss.gd::_spawn_phase_transition_hazard переведён с голого Polygon2D на HazardVfx.telegraph→detonate (как rift_zone/disk_slam), windup через _ascension_telegraph. Геймплей (radius/timing/damage) не тронут. Голых боевых кругов больше нет (grep Polygon2D в boss/enemy = только комментарий). Smoke зелёные.


## QA-Вердикт / 2026-06-12 — PASSED
Проверка по критериям (self-review: фикс и верификация одним агентом, объективно):
- [x] `_spawn_phase_transition_hazard()` использует HazardVfx.telegraph→detonate (boss.gd:328/333), как rift/disk-slam.
- [x] Radius (178+(phase-2)*46), windup (_ascension_telegraph(0.55)), damage сохранены — менялся только визуальный узел.
- [x] Голого красного `Polygon2D`-круга нет (grep Polygon2D в boss.gd = пусто).
- [x] CHANGELOG (:7,:21) и content_registry (:139) точно перечисляют «зону смены фазы», не overclaim.
- [x] hazard_vfx/attack_vfx/animation smoke зелёные.
Фикс закоммичен (ff0b4c7). Багов нет.
