# FantasyDisk: переход с Jira на Multica и инструкции для AI-агентов

Статус: план миграции и операционный регламент  
Дата проверки Multica: 2026-07-11  
Jira migration task: SCRUM-1076

## Назначение документа

Этот документ можно передать Codex, Claude Code или другому AI-агенту на Mac как
самодостаточную инструкцию по внедрению Multica в FantasyDisk. Цель — заменить
Jira как ежедневный task tracker, запускать локальные Codex и Claude через
Multica и объективно измерять качество, скорость, стоимость и автономность.

Переход выполняется поэтапно. Пока cutover явно не объявлен, Jira остаётся
authoritative source. AI-агент не должен самостоятельно отключать Jira,
переписывать процессные документы или удалять Jira credentials до успешного
пилота и зафиксированного решения о переключении.

## Что такое Multica

[Multica](https://multica.ai/) — open-source платформа совместной работы людей и
AI-агентов. Multica server хранит workspaces, issues, comments, task queue и
usage, а локальный daemon на Mac запускает установленные AI coding tools. Код,
репозиторий, ключи и toolchain остаются на локальной машине.

Основные источники:

- [Multica Docs](https://multica.ai/docs)
- [How Multica works](https://multica.ai/docs/how-multica-works)
- [Cloud quickstart](https://multica.ai/docs/cloud-quickstart)
- [Desktop app](https://multica.ai/docs/desktop-app)
- [AI coding tools matrix](https://multica.ai/docs/providers)
- [CLI reference](https://multica.ai/docs/cli)
- [GitHub repository](https://github.com/multica-ai/multica)
- [Codex CLI documentation](https://developers.openai.com/codex/cli)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code/overview)
- [GitHub documentation](https://docs.github.com/)
- [FantasyDisk repository](https://github.com/FomaBy/FantasyDisk)
- [эта инструкция в `dev`](https://github.com/FomaBy/FantasyDisk/blob/dev/docs/process/multica_migration_and_ai_operations.md)

На дату проверки Multica нативно поддерживает Claude Code и Codex, назначение
issues агентам, автоматический запуск, session resume, task runs, task messages,
per-issue token usage, runtime usage, project/workspace trends и agent ranking.

## Целевая архитектура на Mac

```text
Multica Cloud или self-hosted server
                 ↕
        Multica Desktop/daemon
          ↙                ↘
  Codex CLI             Claude Code
          ↘                ↙
       отдельные Git worktrees
                 ↓
       tests → commit → origin/dev
                 ↓
           независимый QA
```

Для первого пилота использовать Multica Cloud с локальным daemon. Self-hosting
рассматривать после пилота, если нужен полный контроль над БД и backup.

## Фаза 1. Подготовка Mac

Перед установкой проверить Git, Homebrew, Python, Godot 4.7, Codex CLI и Claude
Code. Не помещать API keys или access tokens в репозиторий.

```bash
brew install multica-ai/tap/multica
multica version
multica setup cloud
multica auth status

which codex
which claude
codex --version
claude --version

multica daemon status
multica runtime list
multica workspace list --output json
multica workspace switch <fantasydisk-workspace-id>
```

В проверенном CLI `0.3.43` короткая команда `multica setup` эквивалентна
`multica setup cloud`, но в инструкциях и automation лучше явно указывать
`cloud` или `self-host`. Перед автоматизацией сверять фактический синтаксис
установленной версии через `multica <command> --help`.

### Провайдер-аутентификация и версии CLI

Успешный вход в Claude Desktop или Codex Desktop ещё не доказывает, что
headless-процесс Multica daemon сможет авторизоваться. После setup проверить
именно CLI-контур:

```bash
claude auth status --text
codex login status
claude --version
codex --version
```

Если Claude task завершается `401 Invalid authentication credentials`, типичная
причина на Mac — Desktop использует host-managed OAuth refresh в памяти, а
запущенный daemon процесс вызывает headless `claude -p` и не видит эту сессию.
Создать долгоживущий токен CLI (нужна подходящая Claude subscription), не
копировать его в issue, shell history или репозиторий, затем перезапустить
daemon:

```bash
claude setup-token
multica daemon restart
```

Если Codex task завершается `400` с сообщением, что выбранная модель требует
более новую версию Codex, обновить CLI и перезапустить daemon:

```bash
codex update
codex --version
multica daemon restart
```

На проверочном Mac ошибка воспроизводилась с Codex CLI `0.139.0` и исчезла после
обновления до `0.144.1`; это зафиксированный пример, а не вечный minimum version.
Для нового пилота устанавливать последнюю доступную версию обоих provider CLI и
запускать по одной безопасной read-only smoke issue для Codex и Claude до
реальных задач.

После установки или обновления provider CLI:

```bash
multica daemon restart
multica daemon logs -f
```

Multica Desktop содержит собственный daemon profile. Не запускать одновременно
Desktop daemon и standalone daemon без осознанной причины: Multica покажет их
как разные runtimes, что может раздвоить очередь и usage.

## Фаза 2. Workspace, проекты и классификация

Создать workspace `FantasyDisk` и начальные проекты:

- `Active Release — 0.2.x`;
- `Backlog`;
- `Release & QA`;
- `Infrastructure`;
- `Art & UI`.

Использовать labels:

```text
role:backend       role:design       role:animator      role:qa
lane:codex         lane:claude       lane:other-ai
state:qa           state:blocked     state:hold         state:handoff
type:feature       type:bug          type:balance       type:ui
type:animation     type:docs         type:infrastructure
complexity:xs      complexity:s      complexity:m       complexity:l
complexity:xl      agent-eval        blind-qa           release-blocker
```

Если Multica instance не поддерживает пользовательский status `QA`, применять
`In Progress + state:qa + QA assignee`. Issue становится `Done` только после
QA PASSED.

## Обязательная схема issue

Каждая исполнимая issue должна содержать:

```yaml
role: backend|design|animator|qa|pm
lane: codex|claude|other-ai
worker: <agent-or-runtime-name>
locked_paths:
  - <repository path>
branch: <task branch or detached worktree>
base_branch: dev
sprint: <active sprint/release>
release: <target version>
complexity: XS|S|M|L|XL
task_type: <domain>
qa_required: true
jira_legacy_key: <SCRUM-N or empty>
acceptance_criteria:
  - <verifiable outcome>
```

При завершении добавить:

```yaml
commit: <sha>
push_target: origin/dev
tests:
  - <command and result>
qa_result: PASSED|FAILED|NOT_RUN
usage_verified: true|false
disk_cleanup: <removed paths|none created|blocked reason>
```

## Фаза 3. Агенты

Начальный набор:

- `Codex Backend`;
- `Claude Backend`;
- `Codex QA`;
- `Claude QA`;
- `Dispatcher`;
- `Release Agent`.

Добавлять Design и Animator agents после стабилизации backend/QA pilot. Для
каждого implementation agent установить concurrency limit `1`.

### Общая system instruction для implementation agent

```text
Ты работаешь над FantasyDisk только через issues Multica.

1. Бери не более одной активной issue.
2. Перед claim проверь assignee, labels, comments, dirty worktrees и пересечение
   locked_paths. При пересечении не начинай работу.
3. При старте запиши Owner, Worker, Lane, locked paths, branch/worktree и
   следующий test step.
4. Создай чистый worktree от свежего origin/dev. Не изменяй dirty main checkout.
5. Читай AGENTS.md и обязательные domain docs/skills репозитория.
6. Изменяй только task-owned files. Обновляй относящуюся к изменению документацию.
7. Параллельные Godot tests запускай только через tools/godot_gate.py.
8. Выполни focused tests и обязательный runtime smoke.
9. Сделай intentional commit с issue key и отправь зелёный результат в origin/dev.
10. Не переводи issue в Done самостоятельно. Передай её в QA с commit, push,
    tests, limitations и disk cleanup evidence.
11. При blocker оставь точную причину и освободи issue, если больше не работаешь.
12. Не выводи и не сохраняй secrets. Не используй force push или destructive reset.
```

### System instruction для QA agent

```text
Ты независимый QA FantasyDisk. Не исправляй реализацию в проверяемой issue.

1. Проверяй результат из свежего origin/dev или изолированного QA worktree.
2. Сверяй каждый acceptance criterion с фактическим результатом.
3. Проверяй commit/push evidence, focused tests, runtime smoke и отсутствие
   изменений вне locked paths.
4. Для UI применяй hard-rule: контент не перекрывает орнамент или границы frame.
5. Вердикт только PASSED или FAILED с точными командами и evidence.
6. PASSED переводит issue в Done. FAILED возвращает её исполнителю или создаёт
   отдельную linked bug issue.
7. После проверки очищай disposable worktree, .godot и временные userdata/logs.
```

## Фаза 4. Отображение текущего Jira-процесса

| Jira/FantasyDisk сейчас | Multica после cutover |
|---|---|
| Jira issue | Multica issue |
| Project SCRUM | Workspace FantasyDisk |
| Active sprint | project + `sprint:*` metadata/label |
| Fix Version | metadata `release` |
| Assignee | Multica human/agent assignee |
| Codex/Claude contour | `lane:codex` / `lane:claude` |
| Role label | `role:*` |
| Claim-first lock | assignment + atomic start comment |
| Locked paths | issue metadata + start comment |
| Heartbeat | runtime activity + periodic comment |
| Контроль качества | `state:qa` + QA assignee |
| Готово | Done only after QA PASSED |
| Handoff | child/linked issue + comment |
| Jira evidence | Multica timeline + commit/tests fields |

Workflow:

```text
Todo → In Progress → QA → Done
                 ↘ Blocked / Hold / Cancelled
```

## Фаза 5. Пилот и миграция данных

Пилот длится 7–14 дней и включает минимум 30 завершённых issues.

Во время пилота:

1. Jira остаётся authoritative source.
2. Активные Jira issues зеркалируются в Multica с `jira_legacy_key`.
3. Исполнение запускается только через Multica.
4. Результат и конечный статус возвращаются в Jira.
5. Multica собирает runs, time, tokens и cost.
6. Ежедневно проверяются расхождения Jira ↔ Multica.

Переносить:

- все открытые issues;
- активные epics/projects;
- release blockers;
- текущий и один предыдущий sprint для baseline;
- важные QA comments и commit/test evidence.

Не переносить всю историческую Jira автоматически. Jira оставить read-only
архивом, а старый ключ сохранить в metadata.

Для безопасного архивного импорта уже есть repo-owned dry-run-first инструменты:

- [`tools/jira_to_multica.py`](../../tools/jira_to_multica.py) — идемпотентный
  importer завершённых Jira issues, по умолчанию ничего не записывает;
- [`multica_jira_completed_migration_runbook.md`](multica_jira_completed_migration_runbook.md)
  — пилот, проверка, resume и rollback исторического импорта.

Исторический импорт сам по себе **не является cutover** и не меняет
authoritative source.

## Фаза 6. Метрики Codex против Claude

Multica предоставляет task runs, messages, token usage и runtime activity. В
проверенном CLI `0.3.43` команда `issue usage` возвращает input/output/cache
tokens, но не гарантирует денежную стоимость. Поэтому фактический cost брать из
provider billing/export (или вычислять по зафиксированной model-price table с
датой действия), а источник стоимости хранить рядом с benchmark result. Для
объективного результата дополнительно записывать outcome/QA metrics.

| Метрика | Формула |
|---|---|
| Lead time | assignment → QA PASSED |
| Active execution time | суммарное runtime time |
| First-pass QA rate | first-run PASSED / completed issues |
| Rework rate | issues with rerun / completed issues |
| Failure rate | failed or blocked runs / all runs |
| Human intervention | ручные корректировки / issue |
| Token efficiency | tokens / accepted complexity point |
| Cost efficiency | verified provider cost / accepted complexity point |
| Throughput | accepted complexity points / active day |
| Regression rate | post-Done bugs / completed issues |
| Scope accuracy | accepted criteria / all criteria |

Complexity points:

```text
XS=1, S=2, M=3, L=5, XL=8
```

```text
accepted_throughput = sum(points with QA PASSED) / active_hours
cost_per_accepted_point = total_cost / sum(points with QA PASSED)
tokens_per_accepted_point = total_tokens / sum(points with QA PASSED)
```

Для token efficiency отдельно хранить `input`, `output`, `cache_read` и
`cache_write`; не складывать их вслепую в один показатель. Перед сравнением
проверять аномальные значения usage по provider export. Денежные результаты без
указания модели, валюты, периода тарифа и источника billing считать `N/A`, а не
нулевой стоимостью.

Не использовать строки кода, количество commits или просто число закрытых
issues как показатель качества.

Для обзорного composite score допустимы веса:

```text
quality 35% + speed 25% + cost 20% + autonomy 10% + predictability 10%
```

Окончательное решение принимать по отдельным метрикам и типам задач, а не только
по composite score.

### Правила честного сравнения

- сравнивать внутри одинаковых task types и complexity;
- использовать одинаковые acceptance criteria и доступ к tools;
- применять сопоставимый thinking/effort level;
- чередовать назначение задач;
- QA не должен видеть исполнителя до вердикта (`blind-qa`);
- собрать не менее 15–20 задач на агента в каждой важной категории;
- считать все попытки, включая provider/runtime failures и автоматические
  rerun, а не только успешный финальный run;
- фиксировать одинаковый стартовый commit, tool permissions, timeout и
  acceptance criteria для парных A/B задач;
- для A/B benchmark использовать отдельные worktrees от одного base commit;
- не сливать проигравший benchmark-вариант;
- учитывать регрессии, обнаруженные после Done.

Полезные команды:

```bash
multica issue runs MUL-123
multica issue run-messages <task-id>
multica issue usage MUL-123
multica agent tasks <agent-slug>
multica runtime list --output json
multica runtime usage <runtime-id> --output json
multica runtime activity <runtime-id> --output json
```

## Фаза 7. FantasyDisk automation helpers

После успешного ручного пилота реализовать:

```text
tools/multica_next_task.py
tools/multica_claim.py
tools/multica_finish.py
tools/multica_qa_verdict.py
tools/multica_usage_export.py
tools/multica_stale_claim_cleanup.py
tools/multica_jira_migrate.py
```

Helpers должны выбирать одну eligible issue, проверять role/lane/hold/assignee,
не допускать locked-path overlap, записывать evidence, освобождать stale claims и
экспортировать usage в JSON/CSV. Использовать публичные CLI/API Multica; не
разбирать daemon logs как основной источник данных.

## Cutover gate

До прохождения gate действует однозначное правило источника истины:

| Этап | Authoritative source | Обязательная запись результата |
|---|---|---|
| До пилота | Jira | Jira status/comments |
| Пилот | Jira; Multica только execution mirror и telemetry | итог Multica run возвращается в Jira |
| После явно одобренного cutover | Multica | Multica issue/timeline |
| Rollback | Jira после объявления rollback | незавершённые issues восстановлены по `jira_legacy_key` |

Наличие импортированных issues, работающего daemon или успешных agent runs не
переключает источник истины автоматически.

Multica становится authoritative source только когда одновременно выполнено:

- не менее 30 реальных issues прошли полный workflow;
- Codex и Claude usage привязан к issues без существенных пропусков;
- QA-gate нельзя обойти случайным переводом в Done;
- claim предотвращает двойного владельца;
- stale-claim cleanup проверен;
- GitHub commits/push и tests evidence доступны;
- все открытые Jira issues перенесены и сверены;
- создан backup/export Multica;
- инструкция проверена на чистом Mac profile;
- владелец проекта явно одобрил cutover.

Решение фиксируется отдельной cutover issue: дата/время, approver, результаты
всех пунктов gate, backup location и rollback owner. Без такой записи gate
считается не пройденным, даже если техническая миграция завершилась.

В день cutover:

1. Остановить создание новых Jira issues.
2. Сделать финальный Jira export и сверку открытых задач.
3. Объявить Multica authoritative tracker.
4. Переключить dispatcher и role agents.
5. Отдельным task обновить `AGENTS.md` и process docs с Jira на Multica.
6. Отключить Jira sync automations.
7. Оставить Jira read-only минимум на 30 дней.
8. После стабилизации удалить локальные Jira credentials, не историю.

## Rollback

До конца 30-дневного периода Jira-архива rollback должен быть возможен. Если
Multica теряет issues, usage, assignment locks или QA evidence:

1. остановить новые Multica assignments;
2. экспортировать текущие Multica issues/runs;
3. вернуть незавершённые issues в Jira по `jira_legacy_key`;
4. восстановить Jira-first dispatcher;
5. записать incident и причину rollback;
6. не удалять Multica data до анализа.

## Что Multica не заменяет

Multica не отменяет:

- `AGENTS.md` и repo-owned skills;
- role boundaries и handoffs;
- Git worktrees и locked paths;
- green smoke перед push в `dev`;
- `tools/godot_gate.py` для параллельных Godot runs;
- PixelLab/OpenAI asset routing;
- UI frame content-zone QA;
- disk/worktree cleanup;
- release engineering и human approval релиза.

Критические правила должны оставаться version-controlled в репозитории, а не
существовать только в настройках Multica.

## Рекомендуемый календарь

```text
Неделя 1: Mac setup, agents, labels, 10 controlled tasks
Неделя 2: 20–30 real tasks, Jira mirror, metrics validation
Конец недели 2: go/no-go review
Неделя 3: Multica authoritative при успешном gate, Jira read-only
Через 30 дней: финальная проверка и отключение Jira integrations
```

Искомая цепочка наблюдаемости после перехода:

```text
issue → agent → runtime run → time/tokens/cost
      → commit → tests → QA → regressions → accepted value
```

Только эта полная цепочка позволяет обоснованно решить, кто — Codex или Claude —
лучше, быстрее и эффективнее в каждом типе работ FantasyDisk.
