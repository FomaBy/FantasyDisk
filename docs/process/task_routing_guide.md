# Гид Диспетчера: Как Формировать Задачи И Куда Их Направлять (Claude vs Codex)

Обновлено: 2026-06-27

Для кого: PM, Codex Documentation dispatcher, Claude Code/Claude-чаты,
фоновые воркеры и будущие диспетчеры. Источники процесса:
`docs/process/ai_agent_memorandum.md`, `docs/process/pm_workflow.md`,
`docs/process/agent_role_boundaries_and_handoffs.md`, `docs/process/jira_sync.md`.

## Главная Модель

FantasyDisk работает в одной ветке `dev`, но задачи делятся на два независимых
execution lane:

| Контур | Когда использовать | Как не конфликтует |
| --- | --- | --- |
| `Codex` | автономные задачи с точным ТЗ, bounded scope, известными файлами, проверяемыми acceptance criteria, генерацией ассетов, механическими batch-правками, scoped bug/test fixes | получает явный dispatch в Codex role thread и locked paths; Claude пропускает эту задачу |
| `Claude` | архитектура, баланс с продуктовыми решениями, неочевидная отладка, широкий refactor, конфликт-резолюция, release decisions, review | получает `Контур: Claude`; Codex dispatcher/role threads пропускают эту задачу |
| `QA` | приемка после результата owner, регрессии, создание bug/follow-up задач | не чинит код/арт/анимацию в исходной задаче |

С 2026-06-27 маршрутизация начинается из Jira: все задачи создаются и берутся из
Jira project `SCRUM`. Локальные `docs/tasks/*.md` и `docs/process/task_board.md`
служат spec/evidence mirror и dashboard/cache, но не являются очередью задач.

Codex должен быть автономным внутри своих задач: после Jira dispatch он сам берёт
задачу, меняет Jira status/comment и локальный mirror, реализует scope, запускает проверки,
обновляет docs/CHANGELOG/task report и завершает или блокирует задачу. Его
автономия ограничена owner/locked-path правилами, а не ожиданием ручного
подтверждения.

## Обязательная Метадата Задачи

Каждый active Jira issue и его локальный mirror должны иметь:

```text
Статус: new | in_progress | review | done | blocked
Контур: Codex | Claude | OtherAI
Owner: <роль>/<thread или worker> | unassigned
Thread: <Codex thread id> | <Claude chat/worker id> | n/a
Locked paths: <основные файлы/папки/ассеты/экраны>
Jira: SCRUM-<номер>
```

Если `Контур`, `Owner/Thread` или `Locked paths` отсутствуют в Jira, dispatcher
не маршрутизирует задачу до заполнения. Local mirror/board note должны отражать
ту же информацию кратко.

## Правило Маршрутизации

Задача идёт в `Codex`, если выполняются все условия:

1. ТЗ можно выполнить без продуктовой развилки: точные файлы, expected behavior,
   acceptance criteria и проверки.
2. Scope ограничен и locked paths не пересекаются с активной Claude-задачей.
3. Ошибка результата обнаруживается тестом, валидатором, screenshot/manifest
   проверкой или чёткой визуальной QA.
4. Нужен Codex skill/pipeline: UI mockup, asset generation, animation director,
   class-balance harness, batch integration, scoped test update.

Задача идёт в `Claude`, если выполняется хотя бы одно условие:

1. Нужны архитектурные, балансные, UX или продуктовые решения.
2. Нужно исследовать неизвестную причину бага или широкий runtime/regression
   конфликт.
3. Задача затрагивает много подсистем и не делится на безопасные handoffs.
4. Нужно review/acceptance Codex-результата с возможной правкой.
5. Нужно разрешить конфликт dirty worktree, locked paths, Jira ownership или
   противоречие в требованиях.

## Dispatch Protocol

1. Dispatcher читает Jira issue/status/comments/assignee/labels/links first,
   затем local task mirror, board row, sync map, dirty worktree, recent role-thread
   status и active owners по той же роли.
2. Dispatcher выбирает `Контур` и locked paths. Нельзя оставлять active task без
   lane.
3. Для `Контур: Codex` dispatcher добавляет/обновляет в Jira и local mirror
   `Dispatch`, `Owner`, `Thread`, `Locked paths`, board note/Jira comment, затем отправляет ровно
   один handoff в нужный Codex role thread.
4. Для `Контур: Claude` task остаётся доступной Claude Code/Claude worker only;
   Codex Documentation dispatcher не отправляет её в Codex.
5. Исполнитель перед первой правкой переводит Jira issue/comment в `in_progress`,
   сохраняет owner metadata в Jira/local mirror, запускает sync и только потом работает.
6. По завершении owner пишет результат, проверки, docs changes и переводит
   задачу в `done` или `review`. Если scope не может быть завершён, ставит
   `blocked` с точной причиной и handoff/follow-up.

## Interlock Между Codex И Claude

- Один task = один owner = один контур. Нельзя, чтобы Codex и Claude одновременно
  выполняли одну задачу или одну проблему.
- Locked paths сильнее роли. Если `scripts/ui_screens.gd` уже locked Claude task,
  Codex не берёт UI integration task по этому файлу, даже если задача подходит
  Back-end.
- Dirty worktree считается сигналом активной работы. Если dirty files
  пересекаются с locked paths другого owner, новый исполнитель не стартует.
- Review не является разрешением на параллельную правку. Review создаётся после
  owner-result и оформляется отдельной review/bug/follow-up задачей.
- Если Codex во время работы обнаружил, что нужен Claude-level decision, он
  фиксирует результат своей части, создаёт Claude handoff и ставит исходную
  задачу `blocked` или `review`.
- Если Claude нужен asset/image/animation batch от Codex, Claude создаёт Codex
  handoff с точным ТЗ, locked paths и acceptance criteria.

## Как Доставить Задачу

- `Codex`: PM отправляет в Codex Documentation dispatcher Jira key и краткий
  scope. Documentation dispatcher делает audit и сам отправляет задачу в
  существующий role thread. Прямой dispatch в role thread допустим только если
  PM сразу заполняет в Jira/local mirror `Контур: Codex`, `Owner`, `Thread`,
  `Locked paths` и Jira comment.
- `Claude`: PM/другая LLM создаёт Jira issue с `Контур: Claude` и local mirror
  при необходимости. Claude Code/воркеры могут self-claim только такие issues и только если нет
  active owner/locked-path конфликта.
- `QA`: QA выбирает `done` без QA verdict по `docs/process/qa_protocol.md`.
  QA не редактирует реализацию, а создаёт bug/follow-up задачи.

## Review Policy

Codex-работа не требует параллельного Claude вмешательства во время исполнения.
После результата:

- high-risk code/runtime/balance/release changes получают отдельный Claude review
  или QA gate;
- isolated asset/source-pack/mechanical changes могут идти сразу в QA, если
  acceptance и валидаторы зелёные;
- любые найденные проблемы оформляются отдельной bug/follow-up task с новым
  owner и locked paths.

## Чего Диспетчеру Делать Нельзя

- Отправлять одну и ту же задачу в Codex и Claude.
- Оставлять active Jira issue/local `new` row без `Контур` и locked paths.
- Давать Codex задачу, где уже есть Claude owner, worker note, `in_progress`,
  Jira ownership или dirty overlap.
- Давать Claude worker задачу с `Контур: Codex` или dispatch на Codex thread.
- Закрывать задачу за исполнителя без результата owner или QA-вердикта.
- Смешивать Design main и Designer 2 в одной Design-задаче без явной PM-разбивки.
- Игнорировать USER HOLD, blocked reason, PM/QA acceptance gate или superseded
  note, даже если зависимость формально выглядит готовой.
