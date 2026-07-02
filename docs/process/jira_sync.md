# Jira Sync — FantasyDisk

Обновлено: 2026-07-02

## Назначение

С 2026-06-27 Jira является единым authoritative task queue/status/ownership
source для FantasyDisk. Это нужно, чтобы AI-агенты могли работать с разных
устройств и не зависели от локального состояния одного Mac.

Все задачи ведутся так:

- Jira проект `SCRUM` (`FantasyDisk`) — источник очереди, статуса, owner,
  labels, sprint/release tracking и cross-device PM overview.
- `.md` task-файлы в `docs/tasks/` — локальные spec/evidence mirrors для
  подробного ТЗ, acceptance criteria, handoff notes, QA evidence и результата.
- `docs/process/task_board.md` — локальный read-only dashboard/cache для
  удобства агентов; он не является источником новых задач.

Новая или измененная задача считается корректно оформленной только если сначала
есть Jira issue `SCRUM-*`, а локальные `.md`/board mirrors синхронизированы с
этим issue. Агенты берут работу из Jira, не из локальной доски.

## Jira Проект

- Site: `https://fantasydisk.atlassian.net`
- Project key: `SCRUM`
- Board: `1`
- Current active sprint: Jira board `1` active sprint (`Спринт 0.2.0` on
  2026-07-02; check live Jira before dispatch/claim if the numeric id matters).
- `0.1.8` and `0.1.9` are skipped/superseded planning versions. New local task
  mirrors, Jira fixVersions, sprint notes and release/freeze notes must target
  `0.2.0` or the later SemVer patch line (`0.2.1`, `0.2.2`, ...).
- Feature block: v0.1.5 freeze is lifted by the v0.1.5 release (2026-06-15).
  Current-sprint Jira issues may be claimed/dispatched in dependency order after
  duplicate and active-owner audit. The freeze mechanism remains for the next
  release stabilization window.

## Безопасность Доступа

API token нельзя коммитить, вставлять в task-файлы, changelog, docs или логи.
Исполнитель должен получать доступ через локальную переменную окружения или
безопасный секрет окружения:

```bash
export JIRA_BASE_URL="https://fantasydisk.atlassian.net"
export JIRA_EMAIL="<atlassian email>"
export JIRA_API_TOKEN="<token>"
```

Если токен был случайно опубликован в чате или файле, его нужно отозвать в
Atlassian и создать новый.

Для кросс-девайсного Jira-pull helper `tools/jira_next_task.py` сначала читает
`JIRA_API_TOKEN`, `JIRA_EMAIL`, `JIRA_BASE_URL` и optional `JIRA_ACCOUNT_ID`.
На macOS допускается fallback через Keychain service `fantasydisk-jira`. Токены
и account ids не коммитить.

## Маппинг Задач

| Тип task-файла | Jira issue type | Labels |
| --- | --- | --- |
| `backend_*_task.md` | `Задача` | `backend`, `fantasydisk` |
| `design_*_task.md` | `Задача` | `design`, `fantasydisk` |
| `animation_*_task.md` | `Задача` | `animator`, `fantasydisk` |
| `codex_design_*_task.md` | `Задача` | `design`, `codex`, `fantasydisk` |
| `qa_review_*_task.md` | `Задача` | `qa`, `fantasydisk` |
| `bug_*_task.md` | `Баг` | `bug`, role label, `fantasydisk` |
| `test_*_task.md` | `Задача` | `test`, role label, `fantasydisk` |

Приоритет из `.md` переносить в Jira только если безопасно и доступное поле
приоритета уже известно. Иначе хранить приоритет в описании.

## Execution Lane / Owner Metadata

Чтобы Codex и Claude Code/воркеры не конфликтовали в одной ветке `dev`, каждая
активная задача должна содержать в `.md` и быть отражена в board/Jira comment:

```text
Контур: Codex | Claude
Owner: <роль>/<thread или worker> | unassigned
Thread: <Codex thread id> | <Claude chat/worker id> | n/a
Locked paths: <основные файлы/папки/ассеты/экраны>
```

Jira sync/dispatcher rules:

- `Контур: Codex` получает label `codex`; `Контур: Claude` получает label
  `claude`. Если контур не указан, dispatcher не должен маршрутизировать задачу
  до уточнения lane.
- При dispatch Jira comment должен назвать lane, owner/thread, task path и
  locked paths.
- Если task status меняется на `in_progress`, Jira должна отражать того же owner
  в comment/status. Другой контур считает такой тикет занятым.
- Review/fix после результата другого контура оформляется отдельным Jira issue
  или отдельной `.md` bug/follow-up task, а не переприсваиванием исходной задачи
  без результата owner.
- Blocked по причине пересечения dirty worktree/locked paths должен иметь Jira
  comment с конфликтующим owner или файлом.
- Role agents may claim new current-sprint work directly from Jira only through
  Jira-pull claim-first (`tools/jira_next_task.py`). Local board rows never grant
  ownership.

## Спринт = Релиз (правило пользователя, 2026-06-12)

Каждый Jira-спринт соответствует релизу: «Спринт X.Y.Z» закрывается выпуском
версии X.Y.Z. В проекте SCRUM ведутся Jira Releases (versions): на каждую
версию — запись с описанием (краткий ченджлог + заметки обновления; полный
текст — releases/vX.Y.Z/CHANGELOG-X.Y.Z.md). sync-скрипт проставляет новым
тикетам fixVersion по имени активного спринта. При релизе версия помечается
released, создаётся следующая. Игровые патч-ноуты для игрока — экран
«Что нового» (данные обновляются в релизном чек-листе).

## Jira-first Intake И Обновления

1. Новые задачи создаются сначала в Jira. PM/другая LLM/dispatcher формирует
   Jira issue с summary, role, lane, owner/unassigned state, locked paths,
   acceptance criteria и sprint/release context.
2. Локальный `.md` task-файл создаётся или обновляется только после появления
   Jira key и служит подробной спецификацией/evidence mirror. Нельзя создавать
   исполнимую задачу только в `docs/tasks/` без Jira issue.
3. `docs/process/task_board.md` обновляется как кэш/дашборд по Jira, но не
   используется как источник очереди. Если board и Jira расходятся, Jira
   побеждает, а board/task mirror нужно привести в соответствие.
4. Codex Documentation dispatcher может создавать active-sprint Jira
   issues только после duplicate/owner/lane/locked-path audit. Обычная сверка
   dispatcher может идти через `python3 tools/jira_board_sync.py --no-create`;
   после намеренного создания Jira issue нужно синхронизировать локальные
   mirrors.
5. Role agents/heartbeats/Claude workers may auto-take one eligible current-sprint
   Jira issue when it has the matching role label and execution-lane label, no
   assignee, no hold/blocker and no locked-path overlap. They must claim in Jira
   before touching files:

   ```bash
   python3 tools/jira_next_task.py \
     --role <backend|design|animator|qa> \
     --lane <codex|claude|otherai> \
     [--required-label <worker-scope>] \
     --claim \
     --worker <thread-or-worker-id> \
     --json
   ```

   The helper reads the active sprint from Jira board `1`, filters To Do issues,
   transitions the selected issue to «В работе», optionally assigns via
   `JIRA_ACCOUNT_ID`, and adds a Jira-pull owner comment.
   Design pool workers must use `--required-label design-main` or
   `--required-label designer2` so Design main and Designer 2 do not race for a
   generic `design` issue.
6. Во время будущего feature block задачи текущей версии остаются current-sprint
   work только если они уже есть на board или являются bug/QA defect/regression/
   release blocker. Новые не-баговые задачи получают следующую `Версия` и
   остаются без active sprint assignment до PM override.
7. В `.md` task-файле рядом с метаданными добавить строку:

   ```text
   Jira: SCRUM-123
   ```

8. В `docs/process/task_board.md` в примечании к строке задачи добавить Jira key:

   ```text
   Jira: SCRUM-123
   ```

   Для active rows board note также должна показывать `Контур`, owner/thread и
   главные locked paths, если они не очевидны из названия задачи.

9. При изменении статуса сначала обновить Jira, затем локальные mirrors:
   - `new` — issue создана и находится в backlog/sprint To Do.
   - `in_progress` — перевести issue в In Progress, если переход доступен.
   - `review` — перевести в review/QA статус, если такой статус есть; иначе оставить
     In Progress и добавить comment.
   - `done` — перевести в Done, если acceptance/QA позволяют.
   - `blocked` — оставить в текущем workflow status и добавить comment с причиной.

10. При добавлении `## Результат` или `## QA-Вердикт` в `.md` добавить Jira comment
   с кратким резюме и ссылкой на локальный task-файл.
11. При релизе версии все связанные Jira issues должны иметь release note/комментарий
   или Fix Version, если версия заведена в Jira.

## Обязательство Агентов

Каждый агент, который берет задачу в работу или завершает ее, обязан:

1. Начинать с Jira: найти issue `SCRUM-*`, проверить status, assignee, labels,
   comments, sprint, lane/owner/locked paths.
2. Если Jira issue отсутствует — не начинать реализацию. Создать Jira issue
   через PM/dispatcher или самому, если роль это разрешает, и только затем
   создать/обновить локальный `.md` mirror.
3. При изменении статуса обновить Jira status/comment первым, затем `.md` и
   board mirror.
4. Если задача переносится, блокируется или требует handoff — отразить это
   сначала в Jira comment/status, затем в локальном mirror.
5. Не закрывать задачу полностью без синхронизации Jira и QA state.
6. Закрывать только свои задачи или задачи своего ревью-контура. Dispatcher/PM
   не закрывает задачу за исполнителя; он синхронизирует Jira только после того,
   как исполнитель записал результат в task-файл/board или QA добавил verdict.
7. Codex Documentation dispatcher не маршрутизирует задачу без `Контур`, owner
   state и locked-path проверки. Во время будущего feature block он не создает
   новые active-sprint feature tasks без PM override.
8. Role agents may claim unowned current-sprint Jira issues for their role/lane
   through `tools/jira_next_task.py`, but must not start from local board rows
   or from Jira issues missing matching lane metadata unless PM explicitly allows
   `--allow-unlabeled-lane`.
9. Codex role agents и Claude Code/воркеры обязаны пропускать задачи чужого
   `Контур` или чужого `Owner`, даже если Jira status выглядит как To Do.

## Проверка Дубликатов

Dispatcher при регулярной сверке обязан искать дубли сначала в Jira, затем в local mirrors:

- одинаковый task-файл или source task path;
- одинаковый Jira summary/почти одинаковая формулировка проблемы;
- две активные задачи на одни и те же файлы, ассеты, экран или баг;
- backlog-задача будущей версии, случайно продублированная в active sprint.

Если найден дубль, dispatcher не раздает его исполнителю. Нужно оставить один
canonical Jira issue, а остальные пометить `duplicate` или `superseded`, добавить
ссылку на основной Jira issue/local mirror и комментарий в Jira. Если непонятно,
какая задача главная, оставить обе без dispatch и эскалировать PM.

## Feature Block / Sprint Policy

Фриз 0.1.5 снят релизом v0.1.5 (2026-06-15). Сейчас активен live Jira sprint
на board 1 (`Спринт 0.2.0` на 2026-07-02).
Агенты и dispatcher обязаны:

1. Проверять тип задачи перед dispatch.
2. Дожимать активные задачи текущего sprint, баги, QA-дефекты, регрессии,
   release blockers и уже записанные executor results до Jira/QA sync.
3. Маршрутизировать/current-sprint claim обычным порядком только после проверки
   дублей, зависимостей и active owner.
4. Если PM включает новый freeze перед релизом, новые не-баговые задачи
   следующей версии остаются в backlog без dispatch до PM override.
5. Для багов, QA-дефектов, регрессий и release blockers текущего scope
   использовать текущий sprint и обычный QA flow.

## Jira Description Минимум

Jira issue должна содержать:

- ссылку/путь на `.md` task-файл;
- роль владельца;
- краткий контекст;
- ключевые требования;
- acceptance criteria;
- документацию/тесты, которые нужно обновить или прогнать;
- текущий sprint/release context.

## Аджайл-эпики (с 2026-06-13, запрос пользователя «работать по аджайлу»)

Все задачи Jira сгруппированы под 10 функциональных эпиков (тип «Эпик»):

| Код | Эпик | Ключ |
| --- | --- | --- |
| CHARS | Персонажи и классы | SCRUM-212 |
| COMBAT | Бой, враги, боссы и события | SCRUM-213 |
| BALANCE | Баланс и экономика | SCRUM-214 |
| UI | Интерфейс, экраны и локализация | SCRUM-215 |
| ART | Арт и спрайты | SCRUM-216 |
| ANIM | Анимация и риги | SCRUM-217 |
| AUDIO | Звук и музыка | SCRUM-218 |
| META | Мета-прогрессия | SCRUM-219 |
| QUALITY | Качество кода, тесты, аудиты | SCRUM-220 |
| RELEASE | Релиз и процессы | SCRUM-221 |

Карта кодов→ключей — `docs/process/jira_epics.json`. Новые тикеты автоматически
привязываются к parent-эпику классификатором `epic_for()` в
`tools/jira_board_sync.py` (по имени task-файла + заголовку). При добавлении
новых тем эпиков — обновить `jira_epics.json` и классификатор.
## SCRUM-635 Safe Scoped `jira_board_sync.py`

Since SCRUM-635, `python3 tools/jira_board_sync.py --no-create` is safe for
routine broad checks: without `--task` or `--issue`, it does not move Jira
statuses and does not rewrite Jira descriptions. Dispatcher-only maintenance
that intentionally wants broad mutation must pass `--allow-broad-status-sync`.

Worker completion sync must be scoped to the worker's own task:

```bash
python3 tools/jira_board_sync.py --no-create --issue SCRUM-123
python3 tools/jira_board_sync.py --no-create --task docs/tasks/SCRUM-123_short_name.md
```

If Jira returns HTTP 404 or the issue is otherwise inaccessible, the helper logs
`SKIP_INACCESSIBLE`, skips that item, and continues. This prevents stale local
mirrors such as unavailable historical issues from aborting the whole safe sync.
