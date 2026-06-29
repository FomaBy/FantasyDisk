# SCRUM-528: Награда с элитки только если элитка убита (не выжила)

Jira: SCRUM-528 · Роль: backend (codex) · Контур: combat · Приоритет: P1 · foma · Эпик: SCRUM-522
Статус: done (qa-ready; реализовано — коммит bb474b91; reverified backend-loop-rawls-peer 2026-06-28). Gate `_elite_defeated` в `combat_director.gd` и регресс-тесты уже на `dev`; follow-up reverify: `runtime_smoke_boss_elite_test.gd` passed on Godot 4.7 headless. Full `runtime_smoke_test.gd` is currently blocked by unrelated upstream main-menu autosave prompt regression noted in SCRUM-516.

## Что и зачем

Элитный узел маршрута (`elite_battle`) — это **таймерный бой**: на арену выходит одна усиленная элитка (+ волны миньонов), а раунд длится фиксированное время (`round_time_left`). Победа в элитном бою даёт ценную награду — экран выбора **1 артефакта из 3** (`EliteArtifactRewardScreen`), что заметно сильнее обычной награды за рядовой бой.

Сейчас награда с элитки привязана только к факту «бой в элитном узле завершился победой», но НЕ к смерти самой элитки. Из-за того, что не-боссовый бой засчитывается победой по истечении таймера (`round_time_left <= 0.0`) независимо от того, жива элитка или нет, игрок получает артефакт-награду, даже если элитка **выжила** (игрок прятался/кайтил весь раунд и не добил её) или бой был прерван иным способом.

Цель с точки зрения игрока/баланса: награда за элитный бой должна быть **заработана убийством элитки**. Пережидание таймера без убийства элитки не должно выдавать артефакт — иначе теряется смысл сложного боя и ломается экономика артефактов. Ожидаемый результат: элитка убита → экран награды показывается как сейчас; элитка выжила (или бой завершился победой по таймеру с живой элиткой) → артефакт-награды нет, идёт обычный победный флоу (баннер → докачка атрибутов → карта).

## Текущее состояние в коде

Внимание: в тикете указан `Files: scripts/main.gd`, но фактическая логика награды живёт в `scripts/combat_director.gd`. `main.gd` отвечает только за условие завершения раунда.

**1. Условие победы (где «протекает» таймерная победа).** `scripts/main.gd` → `_process(delta)`:
- строки 750-751: для не-боссового боя таймер тикает: `if not boss_combat_active: round_time_left -= delta`.
- строки 763-766: завершение боя.
  ```gdscript
  if boss_combat_active and get_tree().get_nodes_in_group("bosses").is_empty():
      combat._end_combat(true)
  elif not boss_combat_active and round_time_left <= 0.0:
      combat._end_combat(true)
  ```
  То есть босс-бой завершается победой, когда не осталось боссов; а элитный (как и обычный) бой завершается победой **просто по истечении таймера** — состояние элитки не проверяется. Живая элитка на момент `round_time_left <= 0.0` всё равно приводит к `_end_combat(true)`.

**2. Выдача награды за элиту.** `scripts/combat_director.gd` → `_end_combat(victory)`:
- строка 112: `var was_elite_fight := str(game.current_combat_type) == "elite"`.
- строки 124-146: при `victory` для не-боссового боя строится победный флоу. Ключевое:
  ```gdscript
  game.ui._show_victory_banner(func() -> void:
      if was_elite_fight:
          game.ui._show_elite_artifact_reward(func() -> void:
              game.ui._show_attribute_shop(return_to_route_map)
          )
      else:
          game.ui._show_attribute_shop(return_to_route_map)
  )
  ```
  Награда (`_show_elite_artifact_reward`) показывается **по одному только флагу `was_elite_fight`** — нет проверки, была ли элитка действительно убита.

**3. Старт элитного боя и сама элитка.** `scripts/combat_director.gd`:
- `_start_combat(is_boss_fight, combat_type)` строки 13-56: `game.round_time_left = _current_round_duration()` (стр. 21), `game.current_combat_type = "boss" if is_boss_fight else combat_type` (стр. 27); при `current_combat_type == "elite"` вызывается `_spawn_elite_enemy()` (стр. 55-56).
- `_spawn_elite_enemy()` строки 507-530: инстансит элитку, `elite.add_to_group("elite_enemies")` (стр. 518), `_connect_enemy_rewards(elite)` (стр. 527).

**4. Сигнал смерти и где его уже ловят.** 
- `scripts/combat_director.gd` → `_connect_enemy_rewards(enemy)` строки 662-664: `if enemy.has_signal("died"): enemy.died.connect(_on_enemy_died)`.
- `_on_enemy_died(enemy)` строки 667-685: обрабатывает hit-stop/тряску, лечение при убийстве, спавн пикапов; ветка `elif enemy.is_in_group("elite_enemies"):` (стр. 672-674) уже выполняется именно при смерти элитки. **Это идеальная точка, чтобы выставить флаг «элитка убита».**
- `scripts/enemy.gd`: `signal died(enemy: Node2D)` (стр. 3); в `take_damage` при `health <= 0.0` (стр. 249) сразу `died.emit(self)` (стр. 253). Узел из группы `elite_enemies` синхронно НЕ удаляется: дальше либо проигрывается death-анимация и `queue_free` откладывается (`_play_full_frame_death_then_free`, стр. 256-258), либо `queue_free()` (стр. 262) — удаление произойдёт на следующем idle-кадре. **Вывод:** наивная проверка `get_nodes_in_group("elite_enemies").is_empty()` в момент `_end_combat` НЕнадёжна (умершая-но-ещё-не-освобождённая элитка может остаться в группе в этом же кадре). Нужен явный булев флаг, выставляемый в `_on_enemy_died`.

**5. Псевдо-«фазовая награда» — НЕ путать.** В `_scale_elite_enemy` есть `elite.set_meta("elite_phase_reward", "artifact_choice_1_of_3")` (combat_director.gd стр. 581) и `elite_phase_threshold = 0.50` (стр. 580). Эта мета **нигде не считывается** для выдачи награды — это только тег. Боевая «фаза 2» (`_elite_in_phase2()` в enemy.gd, стр. 691-696) меняет лишь поведение атак, не награды. То есть награда сейчас гейтится исключительно флагом `was_elite_fight` в `_end_combat`.

**6. Тесты (важно — текущий тест ЗАКРЕПЛЯЕТ баг).** `tests/runtime_smoke_test.gd` → `_test_elite_flow` (стр. 3254-3369). Блок «краевой кейс победы» строки 3352-3368:
```gdscript
elite_main.call("_start_combat", false, "elite")
await process_frame
elite_main.combat.call("_end_combat", true)   # элитка ТОЛЬКО что заспавнена, НЕ убита
await process_frame
... emit VictoryBanner ...
if elite_main.find_child("EliteArtifactRewardScreen", true, false) == null:
    push_error("Expected elite reward window to appear before the attribute shop on elite victory.")
```
Здесь `_end_combat(true)` вызывается с **живой** элиткой, а тест требует появления экрана награды. После фикса этот сценарий должен давать **обратное** (награды нет), поэтому блок нужно переписать: добить элитку перед `_end_combat`. Запускается набор: `runtime_smoke_boss_elite_test.gd` (`_initialize` стр. 1-30) подключает `_test_elite_flow` и `_test_enemy_stage_scaling_and_elite_rewards` через `extends "res://tests/runtime_smoke_test.gd"`.

## Что сделать — по шагам

1. **Ввести флаг убийства элитки в боевом состоянии.** Сбрасывать его в начале каждого боя и выставлять при смерти элитки.
   - Вариант с минимальной связностью: хранить флаг в `combat_director` (`game.combat` — это инстанс `CombatDirector`), например `var _elite_defeated := false`. Если нужен доступ из автосейва/UI — можно завести `var elite_defeated := false` в `main.gd` рядом с `current_combat_type` (стр. ~333) и читать `game.elite_defeated`. Предпочтительно держать в `combat_director`, т.к. вся логика боя там.
2. **Сброс флага при старте боя.** В `combat_director._start_combat` (рядом со стр. 25-27, где выставляются `combat_active`/`current_combat_type`) выставить `_elite_defeated = false` (или `game.elite_defeated = false`). Это гарантирует чистый старт для каждого элитного узла и для повторных боёв.
3. **Установка флага при смерти элитки.** В `combat_director._on_enemy_died` в ветке `elif enemy.is_in_group("elite_enemies"):` (стр. 672-674) добавить `_elite_defeated = true`. Это единственная достоверная точка «элитка реально умерла» (сигнал `died` от enemy.gd:253).
4. **Гейтнуть награду фактом смерти элитки.** В `combat_director._end_combat` (стр. 140-145) заменить условие показа награды: вместо `if was_elite_fight:` использовать `if was_elite_fight and _elite_defeated:`. При невыполнении — идти в общий путь `game.ui._show_attribute_shop(return_to_route_map)` (как для обычного боя). Победа сама по себе остаётся (баннер, инкремент `route_stage`, докачка, карта) — убирается ТОЛЬКО артефакт-награда.
   - Эквивалентно: вынести в локальную `var grant_elite_reward := was_elite_fight and _elite_defeated` сразу после строки 112 и использовать её в замыкании баннера, чтобы не зависеть от внешней мутации.
5. **(Опционально, для чистоты семантики) не засчитывать ascension reset/economy дважды.** Ничего в `_grant_combat_completion_rewards` менять НЕ нужно — обычные XP/деньги-пикапы и так падают только с убитых врагов через `_on_enemy_died`. Меняем исключительно гейт артефакт-награды.
6. **Обновить существующий тест `_test_elite_flow` (строки 3352-3368).** Переписать «краевой кейс победы» так, чтобы перед `_end_combat(true)` элитка была **убита**:
   - после `_start_combat(false, "elite")` и `await process_frame` получить элитку: `var e := elite_main.get_tree().get_first_node_in_group("elite_enemies")`;
   - добить: `e.call("take_damage", 1.0e9)` (или выставить `health = 0` и эмитнуть `died`), `await process_frame`;
   - затем `_end_combat(true)`, эмит `VictoryBanner` и существующая проверка, что `EliteArtifactRewardScreen` появился — теперь это валидный happy-path.
7. **Добавить регресс-тест «элитка выжила → награды нет».** Рядом, в `_test_elite_flow` (или отдельной `_test_elite_reward_requires_kill`, подключив её в `runtime_smoke_boss_elite_test._initialize`):
   - `_start_combat(false, "elite")`, `await process_frame` (элитка жива, НЕ трогаем);
   - `elite_main.set("round_time_left", 0.0)` и дать `_process` сработать (или напрямую `combat._end_combat(true)` — что моделирует победу по таймеру с живой элиткой);
   - проэмитить `VictoryBanner` (`pressed`), `await process_frame`;
   - проверить, что `EliteArtifactRewardScreen == null`, а сразу открылся `_show_attribute_shop`/победный флоу без артефакта. Падать с `push_error`, если экран награды всё же появился.

## Acceptance Criteria

- [ ] Награда элитки (`EliteArtifactRewardScreen` / выбор 1 артефакта из 3) выдаётся **только** когда элитка действительно убита в бою (сигнал `died` от enemy в группе `elite_enemies`).
- [ ] Если элитка выжила или бой завершился победой по истечении таймера с **живой** элиткой — артефакт-награды НЕТ; идёт обычный победный флоу (VictoryBanner → докачка атрибутов → карта).
- [ ] Флаг убийства элитки сбрасывается в начале каждого боя (нет «протечки» из предыдущего узла).
- [ ] Проверка опирается на достоверный сигнал смерти, а не на наивный `get_nodes_in_group("elite_enemies").is_empty()` в момент `_end_combat` (учтена отложенность `queue_free`/death-анимации в enemy.gd).
- [ ] Существующий `_test_elite_flow` обновлён: happy-path добивает элитку перед `_end_combat`, и экран награды всё ещё появляется.
- [ ] Добавлен регресс-тест: элитка жива на момент победы → экран награды НЕ появляется.
- [ ] `runtime_smoke` (`runtime_smoke_test.gd`) и `runtime_smoke_boss_elite_test.gd` зелёные.
- [ ] Обычные XP/деньги-пикапы и не-элитные/боссовые флоу не затронуты (без регрессий).

## Files / точки входа

- `scripts/combat_director.gd:13` — `_start_combat`: сбросить флаг `_elite_defeated = false` рядом со стр. 25-27.
- `scripts/combat_director.gd:107` — `_end_combat`: гейтнуть показ награды условием `was_elite_fight and _elite_defeated` (стр. 140-145).
- `scripts/combat_director.gd:667` — `_on_enemy_died`: в ветке `elif enemy.is_in_group("elite_enemies")` (стр. 672-674) выставить `_elite_defeated = true`.
- `scripts/combat_director.gd` (поля класса, верх файла) — добавить `var _elite_defeated := false`.
- `scripts/main.gd:763` — `_process`: точка, где элитный бой засчитывается победой по таймеру (контекст бага; менять НЕ обязательно — гейт делаем в `_end_combat`). Если решено хранить флаг в `main.gd`, добавить `var elite_defeated := false` рядом со стр. 333.
- `tests/runtime_smoke_test.gd:3254` — `_test_elite_flow`: обновить happy-path (стр. 3352-3368) + добавить регресс-кейс.
- `tests/runtime_smoke_boss_elite_test.gd:1` — `_initialize`: при необходимости подключить новый тест-метод.

## Замечания / подводные камни

- **Локация против тикета.** Тикет говорит `scripts/main.gd`, но награда выдаётся в `scripts/combat_director.gd._end_combat`. Правка — в combat_director; `main.gd` трогаем максимум ради хранения флага (необязательно).
- **Anti-collision / locked paths.** НЕ требуется править `scripts/ui_screens.gd` и `scripts/progression_data.gd` — задача целиком в `combat_director.gd` (+ тест). `_show_elite_artifact_reward` и генерацию артефактов (`elite_artifact_choices`) НЕ менять, только условие вызова.
- **Отложенное удаление узла.** `enemy.gd` эмитит `died` синхронно (стр. 253), но `queue_free`/death-анимация откладывают фактическое удаление. Поэтому гейт по флагу из `_on_enemy_died` надёжнее группо-поллинга. Не пытайтесь проверять «жива ли элитка» через подсчёт узлов в тот же кадр.
- **Сейв/лоад в середине элитного боя.** Флаг — рантайм-состояние боя. Если бой можно сохранить/восстановить посреди (run autosave, `run_autosave.gd`, `state.get("current_combat_type")` в main.gd стр. 561) — при восстановлении элитного боя флаг должен начинаться с `false` (элитка восстанавливается живой). Хранение флага в combat_director (не в сейве) это даёт автоматически. Если положите флаг в `main.gd` и он попадёт в `serialize`/`deserialize` — убедитесь, что при загрузке он `false`.
- **Несколько элиток.** Сейчас элитный узел спавнит ровно одну элитку (`_spawn_elite_enemy`), но мини-элитки (`_maybe_spawn_mini_elite`, группа `elite_enemies`, мета `drop_class = "mini_elite"`) тоже входят в группу `elite_enemies` и тоже триггерят ветку в `_on_enemy_died`. Это НЕ должно ложно выставлять «награду за элитный узел»: артефакт-награда привязана к узлу типа `elite` (`was_elite_fight`), и мини-элитки появляются в обычных боях. Так как гейт = `was_elite_fight AND _elite_defeated`, ложного срабатывания в обычном бою не будет (там `was_elite_fight == false`). В элитном узле же убийство любой элитки/мини-элитки честно означает прогресс боя — приемлемо; если нужна строгая привязка именно к «главной» элитке узла, можно дополнительно сверять `enemy.get_meta("drop_class") == "elite"` в шаге 3. Решение оставить на исполнителя; по умолчанию достаточно `is_in_group("elite_enemies")` + `was_elite_fight`.
- **Связанные тикеты.** Эпик SCRUM-522. Не конфликтует со SCRUM-503 (берсерк DPS softcap) и SCRUM-519 (level-up badge) — разные подсистемы.
- **Запуск тестов (для проверки):**
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_boss_elite_test.gd`
  и общий `res://tests/runtime_smoke_test.gd`.
