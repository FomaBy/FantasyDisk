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
- QA queue owner: `QA Codex Sol` (`f992a646-a8ea-4935-ba94-212595803052`)
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

Каждая actionable issue независимо от типа и роли получает оценку сложности по
`docs/process/story_points.md`: CUE (Complexity, Uncertainty, Effort), шкала
Фибоначчи `1, 2, 3, 5, 8, 13`. Description содержит `Story points: <N>`,
`Label: SP:<N>` и короткое обоснование; issue — ровно один канонический Label
из `SP:1`, `SP:2`, `SP:3`, `SP:5`, `SP:8`, `SP:13`; Multica metadata —
совпадающий числовой `story_points=<N>` и
`estimation_model="CUE Fibonacci 1,2,3,5,8,13"`. Label является обязательным
измерением для отчётов, metadata — числовым зеркалом. Без полного совпадения
задача не готова к assignment, dispatch или `in_progress`; оценка больше
`13 SP` означает обязательную декомпозицию.

CUE не складывается по формуле: dispatcher и worker используют целостную
относительную рубрику из `docs/process/story_points.md`, а не отдельные баллы
факторов, механическую сумму C, U и E или пороги перевода. Любая инструкция
должна быть переносимым пересказом этого единственного контракта.

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
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 \
  --status todo --limit 100 --output json
multica issue list --project 2ac963eb-b644-4540-8042-a1a4508f1a65 \
  --status blocked --limit 100 --output json
```

Сверить title/description, parent/child relations, assignee, comments, active
runs, locked paths и dirty worktrees. Если объём уже покрыт существующей issue,
добавить туда требования пользователя. Не создавать параллельную задачу на те
же файлы, ассеты или экран.

Новая пользовательская задача по умолчанию создаётся в `todo` с project ID,
priority, проверяемым описанием, acceptance criteria и блоком оценки из
`docs/process/story_points.md`:

```bash
multica issue create \
  --title "<краткий результат>" \
  --description-file ./issue-description.md \
  --project 2ac963eb-b644-4540-8042-a1a4508f1a65 \
  --status todo \
  --priority <urgent|high|medium|low> \
  --output json
```

Сразу после создания найти канонический Label, прикрепить его, записать
числовое зеркало и перепроверить совпадение Label, текста и metadata до
назначения или запуска:

```bash
multica label list --output json
multica issue label add FAN-123 <uuid-label-SP:N> --output json
multica issue metadata set FAN-123 --key story_points --value <1|2|3|5|8|13> --type number
multica issue metadata set FAN-123 --key estimation_model \
  --value "CUE Fibonacci 1,2,3,5,8,13" --type string
multica issue label list FAN-123 --output json
multica issue metadata list FAN-123 --output json
```

Если требования недостаточны для обоснованной оценки, issue остаётся
неисполняемой до уточнения. Существующие `backlog`/`todo` без канонического SP
Label оцениваются до следующего dispatch; `in_progress`/`in_review` — при
ближайшем содержательном обновлении. Исторические `done`/`cancelled` и Jira
Archive массово не переоцениваются.

`backlog` используется только для явно отложенной работы, freeze/hold или
ожидания зависимости, когда issue ещё не готова к dispatch. Реальный blocker,
который остановил executable acceptance, фиксируется отдельным статусом
`blocked` с точной причиной и условием разблокировки. Эти состояния записываются
в issue description/comment и metadata, а не в Jira sprint.

## Два режима исполнения

### Multica daemon agent

CLI пока не имеет compare-and-swap claim, поэтому свободные задачи назначает
ровно один активный dispatcher. Он резервирует parked issue без запуска daemon,
перепроверяет exact UUID и только затем ставит `todo`:

```bash
multica issue update FAN-123 --status backlog \
  --assignee-id 4eccbced-60b5-4e7a-87fd-d9f3699d3bed --output json
multica issue get FAN-123 --output json
multica issue comment add FAN-123 --content-file ./assignment.md
multica issue status FAN-123 todo
```

Переход зарезервированной назначенной issue в `todo` создаёт task в очереди.
Перед reservation dispatcher обязан подтвердить ровно один канонический
`SP:<N>` Label, совпадающие `story_points`/description и отсутствие оценки выше
`13 SP`; иначе issue возвращается PM на оценку или декомпозицию.
Обычный daemon worker начинает работу только после повторной проверки
собственного exact assignee UUID; он не ищет и не claim'ит свободную issue.
Единственное исключение — отдельный автономный QA queue-sweep ниже. QA всегда
владеет проверкой через child review issue и не перезаписывает owner реализации.
Параллельные dispatchers запрещены, пока сервер не поддерживает
`claim-if-unassigned/expected-status`. Нельзя одновременно назначить issue
daemon-агенту и выполнять тот же scope вручную в другом чате.

### Автономный QA queue-sweep

QA Codex Sol (`f992a646-a8ea-4935-ba94-212595803052`) является единственным
writer review-очереди и работает с `max_concurrent_tasks = 1`. Общий dispatcher
может разбудить QA или сообщить, что появился `in_review`, но не создаёт QA child,
не переназначает parent и не отправляет ту же проверку другому reviewer.

В queue-sweep run QA:

1. Читает `AGENTS.md`, этот workflow и `docs/process/qa_protocol.md`, проверяет
   собственные active tasks, QA children и их `qa_owner_id` / `qa_run_id`
   metadata. Если кроме текущего run есть активный QA claim, новый не создаётся.
2. Сканирует все страницы `in_review` и выбирает ровно один eligible parent:
   сначала higher priority, затем самый старый ready item. Перед claim читает
   parent, recent comments, children, metadata и candidate evidence. Parent
   должен иметь exact pushed SHA, завершённую implementation работу, отсутствие
   blocker/dependency, существующего verdict, живой QA child или другого reviewer
   claim; implementation author не может быть независимым reviewer.
3. Пишет в parent `QA claim` comment через `--content-file` с QA UUID, текущим
   run/session, exact candidate SHA, environment/workdir и review scope. Затем
   создаёт отдельную unassigned QA child в `backlog` или переиспользует только
   эквивалентную inactive child на том же SHA. До смены статуса он записывает в
   child metadata `qa_owner_id=f992a646-a8ea-4935-ba94-212595803052`,
   `qa_run_id=<current-task-id>`, `qa_candidate_sha=<exact-sha>` и
   `qa_claim_mode=autonomous_unassigned`, а также CUE/Fibonacci
   `story_points`/`estimation_model` по `docs/process/story_points.md`; QA
   прикрепляет ровно один совпадающий `SP:<N>` Label, а description содержит ту
   же оценку и обоснование. Затем QA добавляет owner/run/SHA claim-comment. Это
   поддерживаемая замена self-assignment: live Multica ACL запрещает agent actor
   назначить child самому себе.
4. Повторно читает parent, children, child metadata и comments. Claim валиден,
   только если все четыре metadata exact, comment совпадает, current run жив,
   SHA не изменился и нет второго claim/verdict. При любом конфликте QA отменяет
   собственную duplicate child и не тестирует stale candidate. Иначе переводит
   child напрямую в `in_progress` и выполняет её в текущем queue-sweep run;
   `todo` не используется, чтобы не породить второй daemon task.
5. Держит parent assignee/status неизменными до verdict. QA не делает production
   fix в review scope и не держит больше одной review child `in_progress`.

Это узкое исключение не разрешает self-claim implementation задачам, другим
role agents или второму QA dispatcher. Single-writer + runtime concurrency `1`
снижают риск гонки при отсутствии server-side compare-and-swap; обязательный
post-claim re-read остаётся последним guard. General dispatcher и другие агенты
обязаны считать QA child с полным metadata claim живым owner signal, даже когда
`assignee_id` равен `null`.

### Текущий пользовательский control chat

Если Codex/Claude уже получил прямой запрос пользователя и выполняет его в
текущем чате, issue создаётся или обновляется без agent assignment, переводится
в `in_progress` только после duplicate/lock audit и записи обязательной оценки
из `docs/process/story_points.md`, а первый комментарий через `--content-file`
содержит:

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
| `backlog` | намеренно отложено, hold/freeze или ждёт зависимости; не готово к dispatch |
| `todo` | готово к назначению |
| `in_progress` | один живой owner выполняет задачу |
| `in_review` | реализация запушена и ждёт независимой проверки |
| `blocked` | executable acceptance остановлен конкретным blocker; записаны причина, owner/condition разблокировки и evidence |
| `done` | acceptance выполнен; обязательный QA PASSED зафиксирован |

`in_progress` — живой lock, а не парковка. Комментарий-heartbeat нужен минимум
раз в 60 минут и перед переключением контекста. Он должен сообщать текущую фазу,
SHA/branch, locks, пройденный gate, blocker и следующий шаг.

Перед завершением любого run issue должна оказаться в правдивом состоянии:

- `in_review` с commit/push/tests evidence;
- `done` после QA PASSED;
- `todo`, если claim освобождён без результата;
- `backlog` с точным hold/dependency и правдивым assignee;
- `blocked` с точным blocker, evidence и условием/owner разблокировки;
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
Готовый зелёный результат коммитится только в task-owned scope. Gate, sync,
push и exact-SHA GitHub check выполняются синхронно; background autoland/hooks
запрещены.

Issue нельзя считать review-ready или done, пока комментарий не содержит:

- exact commit SHA и подтверждение push/ancestor `origin/dev`;
- команды и результаты тестов;
- обновлённую документацию;
- residual risks или `none`;
- `Disk cleanup: removed <paths> | none created | blocked by lock <path>`.

## QA

Реализация переводит issue в `in_review`. QA Codex Sol автономно выбирает один
eligible parent по протоколу выше и создаёт/переиспользует отдельную child review
issue с exact metadata ownership текущего QA run. Это не отменяет task владельца
исходной issue и сохраняет отдельную историю claim, run, evidence и usage.

QA самостоятельно строит risk-based test plan и проверяет acceptance фактически:
читает тесты, запускает focused и certifying gates на exact SHA, добавляет
integration/negative/edge/manual/windowed/performance/platform coverage по риску.
Developer report, code review и CI без фактического QA не считаются verdict.
Для visual/UI/runtime acceptance QA прикладывает screenshots/video, rect dumps,
logs, traces или profiler evidence, когда они materially доказывают результат.

QA пишет подробный verdict в child и итоговую ссылку/summary в parent:

```text
QA verdict: PASSED|FAILED
Verified SHA: <sha>
Environment: <OS/Godot/build/config>
Acceptance traceability: <criterion -> check/evidence>
Checks: <commands/results + manual scenarios>
Evidence: <Multica attachments and/or repo paths>
Findings: <passed/failed/blocked/not tested>
Follow-ups: <linked BUG/IMPROVEMENT FAN IDs or none>
Residual risk: <explicit>
Release recommendation: Go|Go with known risks|No-Go
Disk cleanup: <result>
```

Каждый подтверждённый дефект или обязательное улучшение создаётся QA как linked
child issue исходного implementation parent (`BUG:` / `IMPROVEMENT:`) с
reproduction, expected/actual, exact SHA/environment, severity/priority,
evidence, affected scope, acceptance criteria и recommended implementation role.

При `PASSED` QA child и parent становятся `done`. При `FAILED` QA child также
закрывает свой run в `done` с правдивым verdict, parent остаётся `in_review`, а
все follow-up issues линкуются в обоих отчётах. Возврат parent в `todo` выполняет
dispatcher/PM или новый implementation owner, но не QA в review scope.

## Handoff и зависимости

Cross-discipline handoff сначала создаётся как Multica child issue с точным
scope, role/agent, dependency, acceptance и locked paths. В parent issue
добавляется ссылка/идентификатор child и объяснение, что может продолжаться
параллельно. Локальный `.md` handoff допустим как подробная spec, но не заменяет
Multica issue.

## Комментарии, runs и usage

```bash
multica issue comment add FAN-123 --content-file ./evidence.md
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

`docs/process/jira_sync.md` сохранён как история. `tools/jira_next_task.py`,
`tools/jira_board_sync.py`, `tools/jira_qa_next.py`, `tools/jira_qa_helper.py` и
`tools/jira_release_stuck.py` — fail-closed stubs без credentials/network и не
могут читать или изменять Jira. `tools/jira_to_multica.py` — единственное
исключение: GET-only importer завершённой истории в точный Multica project
`Jira Archive`; он никогда не изменяет Jira и не может писать в live FantasyDisk
project.

Плановый cutover gate из `multica_migration_and_ai_operations.md` superseded
прямой пользовательской директивой 2026-07-13. Возврат к Jira возможен только по
новой явной директиве пользователя; локальный сбой Multica сам по себе не даёт
агенту права вести работу в двух трекерах.
