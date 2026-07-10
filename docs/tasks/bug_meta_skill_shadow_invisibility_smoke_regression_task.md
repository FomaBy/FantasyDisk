# BUG: meta_skill_tree smoke «Теневой шаг» падает при live combat

Статус: new
Версия: 0.2.1
Jira: SCRUM-1028
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Приоритет: high
Роль: Back-end
Найдено QA при тестировании: SCRUM-1024

## Scope And Locks

До claim задача не владеет production-файлами. Ожидаемый focused scope после
claim: `tests/meta_skill_tree_smoke_test.gd`, assassin shadow hook в
`scripts/player.gd` и только реально необходимая test-harness изоляция. Не
ослаблять behavioral assertion и не менять баланс invisibility без отдельного
дизайн/баланс-решения.

## Reproduction

На fresh `origin/dev` `b243d6e26`, три из трёх прогонов с отдельным scratch
`user://`:

```bash
HOME=<scratch> XDG_DATA_HOME=<scratch> \
  python3 tools/godot_gate.py --headless --path . \
  --script res://tests/meta_skill_tree_smoke_test.gd
```

## Expected

После `trigger_assassin_crit_shadow()` с
`shadow_burst_invisibility_time = 2.0` немедленный `take_damage()` возвращает
`false`, а здоровье Ассасина не уменьшается.

## Actual

Гейт стабильно падает в SCRUM-835 scenario:

```text
Теневой шаг must make the assassin ignore damage during shadow invisibility.
tests/meta_skill_tree_smoke_test.gd:928
```

Backtrace возвращается из `_spawn_test_enemy()` после одного live frame.
Первичная QA-гипотеза, требующая доказательства: equipped weapon продолжает
live processing, пока helper ждёт кадр до установки test health, поэтому
target/cooldown может быть потреблён до ручного вызова. Это может быть harness
race либо настоящая production-регрессия — исправление обязано различить их.

SCRUM-1024 не меняет `player.gd`, этот тест, оружие или Meta data; дефект
зарегистрирован как отдельная baseline-регрессия.

## Acceptance Criteria

- focused assassin mini-arena доказывает реальную invisibility-семантику;
- harness исключает автоматические атаки/cooldown contamination без подмены
  production-контракта;
- `meta_skill_tree_smoke_test.gd` проходит 3/3 на отдельных scratch `user://`;
- `meta_keystone_behavioral_smoke_test.gd` и полный runtime smoke остаются
  зелёными;
- Jira/документация/green-gate синхронизированы, результат landed в `dev`.

Disk cleanup: none created by Jira-first QA registration.

