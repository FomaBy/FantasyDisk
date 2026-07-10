# BUG: meta_skill_tree live-combat keystone scenarios недетерминированы

Статус: done
Версия: 0.2.1
Jira: SCRUM-1028
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-1028`
Приоритет: high
Роль: Back-end
Найдено QA при тестировании: SCRUM-1024

## Scope And Locks

Claimed scope: `tests/meta_skill_tree_smoke_test.gd`, this mirror and focused
meta test documentation. `scripts/player.gd`, combat/balance data and live
behavioral harness remain read-only: diagnosis proved a test-fixture race, not a
production invisibility or Bastion defect. Do not weaken behavioral assertions
or change combat balance.

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

После параллельного production batch и rebase на `origin/dev` `ee508d559`
ошибка осталась флейки: два из трёх изолированных прогонов прошли, один из трёх
упал в той же строке 928. Задача остаётся актуальной: обязательный gate не
детерминирован, а focused production-семантика ещё не отделена от harness race.

Независимый параллельный rebase-прогон дал ещё одно подтверждение общего класса
дефекта: два запуска прошли, следующий упал уже в SCRUM-835 `Бастион` на строке
970 до shop-discount coverage. Поэтому Jira summary расширен с одной
`Теневой шаг` проверки до недетерминированных live-combat keystone scenarios;
отдельный Bastion-дубликат не нужен, пока диагностика не докажет иной root cause.

## Confirmed Root Cause

The SCRUM-835 block mixes two kinds of verification: direct calls to production
combat API and fully live scene processing while its coroutine awaits frames.
The equipped weapon inherits normal processing and can select/attack a newly
spawned fixture, consume the Assassin shadow cooldown or remove the target
before the manual oracle runs. Separately, the Bastion comparison calls real
`take_damage()`, whose intentional global-RNG dodge check executes before
defense; a dodge by only one side invalidates a defense-only comparison.

This is harness contamination. Production invisibility, defense, dodge and
weapon behavior are correct and remain unchanged.

## Implementation Result

- Manual semantic fixtures disable `_process`/`_physics_process` callbacks on
  themselves and existing children before the first awaited frame. They stay in
  scene/physics space, so explicit production calls and movement oracles remain
  valid without automatic weapon/AI activity.
- The Assassin mini-arena proves a clean cooldown, the immediate configured
  two-second invisibility window and rejected damage with fixture dodge removed.
- The Bastion pair removes dodge from both test dictionaries after stance has
  recalculated `derived_parameters`, asserts both effective chances are zero,
  explicitly proves stance activation, then compares pure damage reduction.
- The separate live `meta_keystone_behavioral_smoke_test.gd` remains untouched.
  Its existing reactor/pierce failures reproduced identically and are tracked by
  SCRUM-1029; they predate and do not overlap this harness-only diff.

## Acceptance Criteria

- focused assassin mini-arena доказывает реальную invisibility-семантику;
- harness исключает автоматические атаки/cooldown contamination без подмены
  production-контракта;
- `meta_skill_tree_smoke_test.gd` проходит 3/3 на отдельных scratch `user://`;
- `meta_keystone_behavioral_smoke_test.gd` и полный runtime smoke остаются
  зелёными;
- Jira/документация/green-gate синхронизированы, результат landed в `dev`.

## Verification

- Latest `origin/dev` `b5e032ed5`: `meta_skill_tree_smoke_test.gd` PASS 10/10
  with clean stderr after the review fixes, then PASS 3/3 after the final rebase.
- Independent pre-land review first reproduced three remaining races; all were
  fixed. Re-review: PASS, no actionable findings.
- `meta_keystone_behavioral_smoke_test.gd`: scoped baseline exception — the
  untouched gate still reports only the two known Reactor failures in
  SCRUM-1029; the prior pierce failure is now green on current production.
- `runtime_smoke_test.gd`: PASS on the final rebased tip (the known non-fatal
  dummy-renderer null-texture screenshot diagnostic remains outside this scope).
- `git diff --check`: PASS; production scripts/data are unchanged.

Landed: `190bec2be` on `origin/dev`; routed to independent QA.

Disk cleanup: removed task `.godot` (~476 MB) and isolated `/tmp` user-data;
clean task worktree removal follows the routing commit.
