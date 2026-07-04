# Ультимейт: не сбрасывать накопленную шкалу при завершении/старте раунда

Статус: new
Приоритет: P1
Роль: Back-end
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Locked paths: `scripts/combat_director.gd` (`_store_player_snapshot`, `_restore_player_snapshot`), `scripts/player.gd` (поле `ultimate_charge`, при необходимости геттер/сеттер), `tests/runtime_smoke_test.gd` (+ новый `tests/ultimate_charge_persist_test.gd`)
Jira: SCRUM-872
Версия: 0.2.1
Создано: 2026-07-04
Автор: PM (прямой запрос пользователя)
Labels: backend, claude, fantasydisk, foma, p1

## Autonomy / Approval
Пользователь заранее одобрил. Вести полностью автономно.

## Source Request

> «Нужно добавить задачку, чтобы ультимейт, накопленная шкала ультимейта, не скидывалась при
> завершении раунда и при начале нового раунда.»

## Контекст (Что и Зачем)

Заряд ульты хранится в игроке: `var ultimate_charge := 0.0` (`scripts/player.gd:183`), максимум
`ultimate_max_charge := 100.0`. Копится в `_gain_ultimate_charge()` (`scripts/player.gd:1538`)
при уроне/убийствах; тратится (сбрасывается в 0) ТОЛЬКО при активации ульты
`activate_ultimate()` (`scripts/player.gd:1554`) — это корректное поведение, его НЕ трогаем.

Проблема — в переходе между раундами/узлами. Каждый бой игрок пересоздаётся:
`current_player = player_scene.instantiate()` (`scripts/combat_director.gd:174`), у свежего узла
`ultimate_charge = 0.0` (дефолт поля). Состояние восстанавливается из снапшота
`_restore_player_snapshot()` (`scripts/combat_director.gd:1188`), который берётся из
`run_player_snapshot`, снятого `_store_player_snapshot()` (`scripts/combat_director.gd:1157`).

Снапшот сохраняет `health/stats/run_modifiers/artifacts/xp/level/money`, но **НЕ сохраняет
`ultimate_charge`** (см. словарь `scripts/combat_director.gd:1173-1185`). Итог: накопленная
ульта обнуляется на каждом переходе раунда — ровно то, на что жалуется пользователь.

(Полный run-reset `ultimate_charge = 0.0` в `scripts/player.gd:248` — это старт нового ЗАБЕГА /
смена персонажа: сбрасываются также xp/level/money/artifacts. Его трогать НЕ нужно.)

## Требования

1. В `_store_player_snapshot()` (`scripts/combat_director.gd:1157`) добавить в снапшот текущий
   `ultimate_charge` игрока (напр. `"ultimate_charge": player.get("ultimate_charge")`).
2. В `_restore_player_snapshot()` (`scripts/combat_director.gd:1188`) восстанавливать
   `ultimate_charge` из снапшота на свежесозданного игрока (с безопасным дефолтом 0.0 и clamp по
   `ultimate_max_charge`, чтобы не превысить максимум после смены статов/оружия).
3. Порядок восстановления: выставлять `ultimate_charge` ПОСЛЕ `configure_character`/`equip_weapon`
   (которые пересчитывают деривативы/макс), затем `clampf(value, 0.0, ultimate_max_charge)`.
4. Поведение при активации ульты не меняется: `activate_ultimate()` по-прежнему сбрасывает заряд
   в 0. Полный run-reset (новый забег/смерть/выход в меню) по-прежнему обнуляет ульту.
5. HUD-шкала ульты (`scripts/ui_screens.gd:12637`) продолжает отражать `ultimate_charge`:
   после перехода раунда полоса должна показывать перенесённый заряд, а не ноль.

## Acceptance Criteria

- [ ] Накопленный `ultimate_charge` сохраняется между боями/узлами и внутри перехода между
      актами (переезжает через `run_player_snapshot`).
- [ ] После перехода в новый раунд HUD-шкала ульты показывает перенесённый заряд, а не ноль.
- [ ] Активация ульты по-прежнему сбрасывает заряд в 0 (поведение не изменилось).
- [ ] Старт нового забега / смена персонажа / смерть — ульта обнуляется как раньше (регрессии
      нет).
- [ ] Восстановленный заряд корректно клампится по `ultimate_max_charge` (нет заряда > максимума).
- [ ] Новый headless-тест `tests/ultimate_charge_persist_test.gd` проверяет: snapshot→restore
      сохраняет заряд; активация обнуляет; clamp работает. Тест зелёный.
- [ ] `runtime_smoke_test.gd` зелёный из чистого worktree.

## Заметки для исполнителя

- Правка изолирована в `combat_director.gd` (две функции снапшота) + минимально в `player.gd`
  (при необходимости геттер). Пересекается по `combat_director.gd` с задачей акт-награды/отхила —
  вести в одном контуре, не параллелить правку файла двумя воркерами.
- Не тащить в снапшот `_ultimate_active`/timed-overlay состояния активной ульты: переносим
  только накопительный ресурс `ultimate_charge` (активная ульта — runtime-only, гибнет с узлом,
  как и transient run_modifiers в `_store_player_snapshot`).

## Файлы

- Изменить: `scripts/combat_director.gd` (`_store_player_snapshot` + `_restore_player_snapshot`),
  `scripts/player.gd` (при необходимости геттер/сеттер `ultimate_charge`).
- Тесты: новый `tests/ultimate_charge_persist_test.gd`; регресс — `tests/runtime_smoke_test.gd`.
- Docs: `docs/design/current_game_state.md` / систему боя — отметить, что ульта персистит между
  раундами и сбрасывается только на активации / новом забеге.

## Валидация

- `python3 tools/godot_gate.py --headless --path . --script res://tests/ultimate_charge_persist_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
- Живой прогон (dev-консоль `~`): накопить ульту частично, завершить раунд, войти в следующий —
  шкала не обнулилась.

## Result

Pending.
