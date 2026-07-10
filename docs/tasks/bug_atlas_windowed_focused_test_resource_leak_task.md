# BUG: Atlas windowed focused test оставляет ObjectDB/resources

Статус: new
Версия: 0.2.1
Jira: SCRUM-1031
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Приоритет: normal
Роль: Back-end / QA tooling
Найдено QA при тестировании: SCRUM-1024

## Scope And Locks

До claim задача не владеет production-файлами. Ожидаемый scope:
`tests/atlas_scrum970_clickability_test.gd` и только доказанно необходимый
teardown/resource-lifecycle helper. Не менять Atlas layout/семантику и не
подавлять warning вместо исправления lifecycle.

## Reproduction

На production `origin/dev` `b243d6e26` и повторно после rebase на
`ee508d559`, с уникальным scratch `user://`:

```bash
HOME=<scratch> XDG_DATA_HOME=<scratch> \
  python3 tools/godot_gate.py --path . \
  --script res://tests/atlas_scrum970_clickability_test.gd -- \
  --user-data-dir=<scratch>
```

## Expected

Функциональный PASS завершается без ObjectDB/resource lifecycle diagnostics.

## Actual

Все четыре viewport и восемь windowed screenshots проходят, затем процесс
иногда сообщает:

```text
WARNING: 4 ObjectDB instances were leaked at exit
ERROR: 2 resources still in use at exit
```

Implementation pre-land также видел тот же diagnostic в одном windowed run.
Headless focused run чистый. Это non-blocking QA-tooling follow-up: визуальное и
интерактивное поведение SCRUM-1024 принято отдельно.

## Acceptance Criteria

- `SubViewport`/`Main` и связанные ресурсы освобождаются детерминированно;
- windowed focused matrix проходит 5/5 без ObjectDB/resource warning;
- headless focused matrix, viewport bounds, real pointer, preview-only, Buy,
  tooltip, dossier scroll и medallion focus assertions не ослаблены;
- полный runtime smoke остаётся зелёным;
- результат синхронизирован в Jira/docs и landed в `dev`.

Disk cleanup: none created by Jira-first QA registration.
