# Multica Workflow — FantasyDisk

Обновлено: 2026-07-13
Cutover record: `FAN-1044`; operational hardening: `FAN-1048`

## Authoritative source

По прямой пользовательской директиве от 2026-07-13 Multica является
единственным рабочим источником задач, статусов, владельцев и истории исполнения
для Codex и Claude в FantasyDisk.

- Workspace: `FantasyDisk` (`fantasydisk`)
- Project: `FantasyDisk` (`2ac963eb-b644-4540-8042-a1a4508f1a65`)
- Codex agent: `Codex` (`4eccbced-60b5-4e7a-87fd-d9f3699d3bed`)
- Claude agent: `Claude` (`e2e1c89f-587d-4a2d-bbaa-ce9b5dea908d`)
- Repository resource: `https://github.com/FomaBy/FantasyDisk.git`
- Integration branch: `dev`

Jira больше не используется для intake, claim, status, heartbeat, handoff, QA
или закрытия новых задач Codex/Claude. Jira и Multica project `Jira Archive`
сохраняются только как read-only legacy history. Старые ключи `SCRUM-*` в
коммитах, документах и именах файлов остаются историческими идентификаторами.

Локальные `docs/tasks/*.md` и `docs/process/task_board.md` могут хранить
расширенную спецификацию или исторические evidence, но не дают права начать
работу и не переопределяют Multica.

## Что обязательно трекать

Каждый actionable запрос, который приводит к изменениям кода, ассетов,
документации, конфигурации, GitHub или другого состояния проекта, должен иметь
Multica issue до первой правки. Если запрос продолжает существующую задачу,
нужно использовать её issue и добавить комментарий, а не создавать дубль.

Простой вопрос, чтение статуса или объяснение без изменения состояния не требует
отдельной issue. Обнаруженный в ходе такого ответа новый объём работы сначала
оформляется в Multica и только затем исполняется.

## Проверка подключения

```bash
multica version
multica auth status
multica daemon status
multica workspace list --output json
multica project get 2ac963eb-b644-4540-8042-a1a4508f1a65 --output json
multica agent list --output json
```

Секрет Multica хранится только в локальном `~/.multica/config.json`. Не выводить
полный token, не помещать его в issue, shell scripts, repo files или логи.

## Intake и duplicate audit

Перед созданием новой issue проверить активную доску:

```bash
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 \
  --status in_progress --limit 100 --output json
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 \
  --status in_review --limit 100 --output json
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 \
  --status backlog --limit 100 --output json
```

Сверить title/description, parent/child relations, assignee, comments, active
runs, locked paths и dirty worktrees. Если объём уже покрыт существующей issue,
добавить туда требования пользователя. Не создавать параллельную задачу на те
же файлы, ассеты или экран.

Новая пользовательская задача по умолчанию создаётся в `todo` с project ID,
priority, проверяемым описанием и acceptance criteria:

```bash
multica issue create \
  --title "<краткий результат>" \
  --description "<контекст, scope, acceptance, docs/tests, locked paths>" \
  --project 2ac963eb-b644-4540-8042-a1a4508f1a65 \
  --status todo \
  --priority <urgent|high|medium|low> \
  --output json
```

`backlog` используется только для явно отложенной, blocked или зависимой работы.
Freeze/hold фиксируется в issue description/comment и metadata, а не в Jira
sprint.

## Два режима исполнения

### Multica daemon agent

Для автономного запуска назначить issue ровно одному агенту:

```bash
multica issue assign FAN-123 --to Codex
multica issue assign FAN-124 --to Claude
```

Назначение создаёт task в очереди Multica. Daemon выдаёт изолированный workdir,
запускает соответствующий CLI и сохраняет run, messages, session и usage.
Нельзя одновременно назначить issue агенту и выполнять тот же scope вручную в
другом чате.

### Текущий пользовательский control chat

Если Codex/Claude уже получил прямой запрос пользователя и выполняет его в
текущем чате, issue создаётся или обновляется без agent assignment, переводится
в `in_progress`, а первый комментарий содержит:

```text
Owner: Codex|Claude / <thread-or-control-chat>
Mode: direct control chat
Workdir/branch: <path> / <branch>
Locked paths/screens/assets: <scope>
Next verification: <конкретный gate>
```

Такой issue остаётся полной записью задачи, даже если её execution run не был
создан daemon. Результат, commit и QA evidence всё равно пишутся в Multica.

## Lifecycle

| Multica status | Значение |
| --- | --- |
| `backlog` | отложено, blocked или ждёт зависимости |
| `todo` | готово к назначению |
| `in_progress` | один живой owner выполняет задачу |
| `in_review` | реализация запушена и ждёт независимой проверки |
| `done` | acceptance выполнен; обязательный QA PASSED зафиксирован |

`in_progress` — живой lock, а не парковка. Комментарий-heartbeat нужен минимум
раз в 60 минут и перед переключением контекста. Он должен сообщать текущую фазу,
SHA/branch, locks, пройденный gate, blocker и следующий шаг.

Перед завершением любого run issue должна оказаться в правдивом состоянии:

- `in_review` с commit/push/tests evidence;
- `done` после QA PASSED;
- `todo`, если claim освобождён без результата;
- `backlog` с точным blocker/dependency и снятым assignee;
- либо task `failed/cancelled` с объяснением и безопасным rerun/handoff.

Не оставлять stale `in_progress` или agent assignment после фактической остановки.

## Ownership и parallel work

- Одна issue = один исполнитель = один набор locked paths.
- Codex и Claude могут работать параллельно только над непересекающимися issues.
- Перед правкой проверяются Multica assignee/comments/runs, `git status`,
  `git worktree list` и активные locks.
- Review не редактирует реализацию параллельно. Fix оформляется отдельной child
  issue или возвращает исходную issue в `todo` после завершённого review.
- Reassignment отменяет активные Multica tasks на issue; не использовать его как
  безобидную смену подписи.

Multica daemon workdirs находятся вне основного checkout. Агент не удаляет чужой
workdir и не трогает его branch. После завершения он удаляет только собственные
временные caches/worktrees, если результат уже запушен.

## GitHub boundary

Перед началом:

```bash
git status --short --branch
git fetch origin --prune
git pull --ff-only origin dev
```

Если безопасный sync невозможен, не начинать edits: записать blocker в Multica.
Готовый зелёный результат коммитится только в task-owned scope и сразу
отправляется в `origin/dev` по действующей direct-dev/autoland политике проекта.

Issue нельзя считать review-ready или done, пока комментарий не содержит:

- exact commit SHA и подтверждение push/ancestor `origin/dev`;
- команды и результаты тестов;
- обновлённую документацию;
- residual risks или `none`;
- `Disk cleanup: removed <paths> | none created | blocked by lock <path>`.

## QA

Реализация переводит issue в `in_review`. Для независимой проверки создаётся
child review issue и назначается другому агенту; это не отменяет task владельца
исходной issue и сохраняет отдельную историю run/usage.

QA пишет verdict с exact SHA и evidence:

```text
QA verdict: PASSED|FAILED
Verified SHA: <sha>
Checks: <commands/results>
Findings: <none or list>
Disk cleanup: <result>
```

При `PASSED` parent issue становится `done`. При `FAILED` review issue закрывает
свой run правдивым результатом, а defect оформляется child bug/follow-up issue;
исходная задача возвращается в `todo` или остаётся `in_review` с явным blocker.

## Handoff и зависимости

Cross-discipline handoff сначала создаётся как Multica child issue с точным
scope, role/agent, dependency, acceptance и locked paths. В parent issue
добавляется ссылка/идентификатор child и объяснение, что может продолжаться
параллельно. Локальный `.md` handoff допустим как подробная spec, но не заменяет
Multica issue.

## Комментарии, runs и usage

```bash
multica issue comment add FAN-123 --content "<heartbeat/evidence>"
multica issue update FAN-123 --status in_review
multica issue runs FAN-123
multica issue run-messages <task-id>
multica issue usage FAN-123
multica agent tasks 4eccbced-60b5-4e7a-87fd-d9f3699d3bed --output json
multica agent tasks e2e1c89f-587d-4a2d-bbaa-ce9b5dea908d --output json
multica runtime activity <runtime-id> --output json
```

Multica issue timeline является журналом решений и evidence. Существенные
изменения scope, blockers, handoffs, тесты, commits и QA не должны существовать
только в чате или локальном файле.

## Failure и recovery

- Проверить `multica daemon status` и `multica daemon logs`.
- `runtime_offline`, recovery и timeout могут получить один автоматический
  retry; agent errors не перезапускаются бесконечно.
- Для осознанного нового запуска использовать `multica issue rerun FAN-123`.
- Перед rerun убедиться, что старый task остановлен и workdir/locks не содержат
  незапушенный результат.
- После окончательного failure убрать stale assignee/status и записать blocker.

## Legacy Jira

`docs/process/jira_sync.md`, `tools/jira_next_task.py`,
`tools/jira_board_sync.py`, `tools/jira_qa_next.py` и `tools/jira_to_multica.py`
сохранены для истории, аудита или односторонней архивной миграции. Они не входят
в обычный Codex/Claude workflow и не должны создавать или изменять Jira issues
без отдельной явной пользовательской команды на legacy operation.

Плановый cutover gate из `multica_migration_and_ai_operations.md` superseded
прямой пользовательской директивой 2026-07-13. Возврат к Jira возможен только по
новой явной директиве пользователя; локальный сбой Multica сам по себе не даёт
агенту права вести работу в двух трекерах.
