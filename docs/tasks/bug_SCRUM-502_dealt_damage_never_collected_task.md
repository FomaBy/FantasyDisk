# bug(SCRUM-502): нанесённый урон (damage_dealt) никогда не собирается — на экране итогов всегда 0

Jira: SCRUM-502 (переоткрыт QA) · Роль: bug · Контур: claude · Приоритет: P2 · foma
Статус: done — исправлено (claude-backend, 2026-06-28), QA PASSED

## QA-Вердикт

Статус: PASSED
- 2026-06-28 17:51 (claude-backend-3): фикс 2fe432b4 на месте в origin/dev — хук в единой точке схода scripts/enemy.gd:271-272, после `health -= final_amount` репортит в current_scene.add_run_damage_dealt.
- 2026-06-28 19:09 (codex-qa-502): mirror-вердикт на fresh origin/dev worktree b57410a9, Windows Godot 4.7 — PASS; runtime_smoke_test.gd:4327 проверяет реальный бой (не инжект).
- 2026-07-02 (PM, ревизия беклога): Jira-переход SCRUM-502 в «Готово» доведён (дрейфовал из-за нестандартного слова статуса в этом файле), map зафиксирован.

## Решение (claude-backend, 2026-06-28)
Подключил `add_run_damage_dealt` в ЕДИНОЙ точке схода всех источников урона по врагу —
`scripts/enemy.gd::take_damage` (после `health -= final_amount`):
```gdscript
if final_amount > 0.0 and is_inside_tree():
    var game_node := get_tree().current_scene
    if game_node != null and game_node.has_method("add_run_damage_dealt"):
        game_node.add_run_damage_dealt(final_amount)
```
- `final_amount` = фактически снятое HP (после `damage_taken_multiplier` и elite-щита) — точная метрика.
- Один хук покрывает ВСЕ пути (`projectile.gd`, прямой удар/enchant/echo/blast/контратаки `player.gd`, DoT-тики, урон саммонов) — все сходятся в `enemy.take_damage`.
- Паттерн идентичен уже рабочему gold-хуку (`player.gd:gain_money` → `current_scene.add_run_gold_collected`).
- Регрессия в smoke: `_test_run_damage_dealt_metric` — РЕАЛЬНЫЙ `enemy.take_damage(250)` на Main как `current_scene`, ассерт `run_metrics.damage_dealt > 0` (закрывает дыру инжекта матрицы). Зелёный.
- Пункт #3 (семантика `gold_collected` finals-перезапись) НЕ трогал — это отдельный мелкий вопрос, не блокер dealt-damage; вынести в отдельный тикет при необходимости.

## Симптом
На экране итогов забега (run summary, SCRUM-502) строка «Урон по врагам» в реальной игре ВСЕГДА показывает 0 — и на победном, и на смертном экране. Остальные метрики (убийства, полученный урон, время, золото, уровень, артефакты, причина исхода) собираются корректно.

## Корневая причина
Агрегатор `game.add_run_damage_dealt(amount)` (`scripts/main.gd:552`) определён, но **не вызывается нигде во всём проекте** — единственная ссылка это само его определение:
```
$ grep -rn "add_run_damage_dealt" . --include="*.gd"
scripts/main.gd:552:func add_run_damage_dealt(amount: float) -> void:
```
Игрок наносит урон врагам через множество путей `enemy.take_damage(...)`:
- `scripts/projectile.gd:89` `body.take_damage(damage)` (снаряды/основная атака)
- `scripts/player.gd:1293` `enemy.take_damage(final_amount)` (прямой удар)
- `scripts/player.gd:1356,1372,1464,1506,678,692,772` (enchant, DoT-тики, echo, blast, контратака, рефлект, пульс)

Ни один из них не зовёт `add_run_damage_dealt`. В `scripts/enemy.gd::take_damage` (`:251`) обратного хука к `game`/`current_scene` нет. Коммит-месседж `b69b85a5` утверждает «dealt damage — через current_scene», но соответствующего кода в diff’е нет (хук был забыт; для taken damage и gold аналогичные хуки есть и работают).

## Воспроизведение (headless, через gate)
Реальный бой: `player.take_damage(40)` + `enemy.take_damage(75)` (тот же путь, что `projectile.gd:89`), затем чтение `game.run_metrics`:
```
PROBE_RESULT enemy_take_damage_called=true damage_dealt=0.0 damage_taken=40.0 kills=1
PROBE_VERDICT: BUG CONFIRMED -> player dealt damage to enemy but damage_dealt stayed 0.0
```
`damage_taken` и `kills` копятся; `damage_dealt` остаётся 0 после нанесённого урона.

## Почему тесты не поймали
- `tests/ui_no_overlap_matrix_test.gd` инжектит фейковые метрики (`_sample_run_metrics`, `damage_dealt: 48213.0`, `:304`) и проверяет только наличие/overlap узлов сводки — НЕ что реальный бой их наполняет.
- `tests/runtime_smoke_test.gd` не ассертит значение `damage_dealt`.

## Что сделать
1. Подключить `add_run_damage_dealt` к реальному нанесению урона игроком. Предпочтительно централизованно: при попадании игрока по врагу звать `current_scene.add_run_damage_dealt(dealt)` — ровно по образцу уже рабочих хуков:
   - taken: `scripts/ui_screens.gd:_on_player_damaged` → `game.add_run_damage_taken(amount)`,
   - gold: `scripts/player.gd:gain_money` → `get_tree().current_scene.add_run_damage_dealt`-аналог (`add_run_gold_collected`).
   Самая дешёвая централизованная точка — там, где игрок вычисляет фактический урон перед `enemy.take_damage(...)` (`scripts/player.gd:1293` и спутники), либо передать флаг «источник = игрок» в `enemy.take_damage` и репортить из enemy в `current_scene`. Выбрать ОДИН подход, не дублировать на каждый из 8 путей вручную, если можно агрегировать.
   - Если централизованно дорого — запасной вариант: суммировать `max_health` убитых врагов в `_on_enemy_died` (`scripts/combat_director.gd`) и подписать строку нейтрально («Урон по врагам ~»), пометив как приближение (крит/оверкилл/DoT исказят). НО предпочтителен точный путь.
2. Добавить в smoke регрессию: после короткого реального боя `run_metrics.damage_dealt > 0` (а не инжект). Это закрывает дыру, из-за которой баг прошёл QA.
3. (Опц., отдельный мелкий вопрос) Семантика золота: `capture_run_metrics_finals` (`scripts/main.gd:587`) ПЕРЕЗАПИСЫВАЕТ `gold_collected` текущим `money` игрока (`:591`), затирая накопленное `add_run_gold_collected`. После трат в магазине «Собрано золота» покажет остаток на руках, а не собранное за забег. Решить: либо НЕ перезаписывать gold в finals (оставить аккумулятор), либо переименовать подпись в «Золото на руках». Не блокер дефекта dealt-damage, но стоит решить заодно.

## Acceptance
- [ ] После реального боя (не инжект) `game.run_metrics.damage_dealt > 0` и правдоподобно растёт за забег; строка «Урон по врагам» на экранах победы/смерти ненулевая в реальной игре.
- [ ] Добавлен ассерт в runtime smoke: `damage_dealt > 0` после боя.
- [ ] Решён вопрос семантики `gold_collected` (аккумулятор vs остаток) — подпись соответствует значению.
- [ ] `ui_no_overlap_matrix_test` и `runtime_smoke_test` зелёные на HEAD.

## Files
- `scripts/main.gd` — `add_run_damage_dealt` (`:552`), `capture_run_metrics_finals` (`:587`).
- `scripts/player.gd` — точка(и) нанесения урона (`:1293` и спутники) / `gain_money` (`:1544`) как образец хука.
- `scripts/enemy.gd` — `take_damage` (`:251`), если выбран путь репорта из enemy.
- `scripts/combat_director.gd` — `_on_enemy_died` (если fallback по max_health убитых).
- `tests/runtime_smoke_test.gd` — добавить ассерт `damage_dealt > 0` после боя.
