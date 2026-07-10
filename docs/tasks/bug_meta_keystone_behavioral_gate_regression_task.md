# BUG: behavioral gate Meta 4.1 не видит reactor heat и флейкает pierce

Статус: new
Версия: 0.2.1
Jira: SCRUM-1029
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Приоритет: high
Роль: Back-end
Найдено QA при тестировании: SCRUM-1024

## Scope And Locks

До claim задача не владеет production-файлами. Ожидаемый focused scope после
claim: `tests/meta_keystone_behavioral_smoke_test.gd`, reactor heat hook и
pierce target-query path только после точной диагностики. Нельзя заменять
реальные combat outcomes проверкой словарей или ослаблять пороги.

## Reproduction

На fresh `origin/dev` `b243d6e26`, три из трёх прогонов с отдельным scratch
`user://`:

```bash
HOME=<scratch> XDG_DATA_HOME=<scratch> \
  python3 tools/godot_gate.py --headless --path . \
  --script res://tests/meta_keystone_behavioral_smoke_test.gd
```

## Expected

Обязательный SCRUM-837 live mini-arena gate проходит: активный reactor heat
увеличивает исходящий и входящий урон, а enabled pierce поражает ожидаемые цели.

## Actual

Детерминированно 3/3:

```text
Reactor heat did not increase real weapon damage (cold 16.30, hot 16.30).
Reactor heat downside did not increase incoming damage (cold 8.08, hot 8.08).
```

Дополнительно в двух из трёх прогонов:

```text
Pierce scenario enabled hit 0 targets.
```

SCRUM-1024 не меняет `player.gd`, weapon/meta runtime или этот гейт; дефект
зарегистрирован как отдельная baseline-регрессия.

## Acceptance Criteria

- focused reactor scenario доказывает production active-state transition и
  разные cold/hot outgoing + incoming combat outcomes;
- focused pierce scenario детерминированно поражает ожидаемые live targets;
- обязательный `meta_keystone_behavioral_smoke_test.gd` проходит 3/3 на
  отдельных scratch `user://` без dictionary-only подмены;
- `meta_skill_tree_smoke_test.gd` и полный runtime smoke остаются зелёными;
- Jira/документация/green-gate синхронизированы, результат landed в `dev`.

Disk cleanup: none created by Jira-first QA registration.
