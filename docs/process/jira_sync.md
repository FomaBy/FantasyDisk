# Jira Sync — FantasyDisk

Обновлено: 2026-06-23

## Назначение

Все задачи FantasyDisk ведутся в двух местах:

- `.md` task-файлы в `docs/tasks/` — полный источник требований, acceptance criteria,
  handoff notes, QA verdict и детальный результат.
- Jira проект `SCRUM` (`FantasyDisk`) — sprint board, статус, release tracking и
  общий PM-обзор.

Новая или измененная задача считается корректно оформленной только если `.md`,
`docs/process/task_board.md` и Jira синхронизированы.

## Jira Проект

- Site: `https://fantasydisk.atlassian.net`
- Project key: `SCRUM`
- Board: `1`
- Current active sprint: `Спринт 0.1.6`
- Current active sprint id: Jira board `1` current sprint (check live Jira/map before
  dispatch if the numeric id matters).
- Feature block: v0.1.5 freeze is lifted by the v0.1.5 release (2026-06-15).
  0.1.6 rows may be dispatched in dependency order after duplicate and active-owner
  audit. The freeze mechanism remains for the next release stabilization window.

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

## Спринт = Релиз (правило пользователя, 2026-06-12)

Каждый Jira-спринт соответствует релизу: «Спринт X.Y.Z» закрывается выпуском
версии X.Y.Z. В проекте SCRUM ведутся Jira Releases (versions): на каждую
версию — запись с описанием (краткий ченджлог + заметки обновления; полный
текст — releases/vX.Y.Z/CHANGELOG-X.Y.Z.md). sync-скрипт проставляет новым
тикетам fixVersion по имени активного спринта. При релизе версия помечается
released, создаётся следующая. Игровые патч-ноуты для игрока — экран
«Что нового» (данные обновляются в релизном чек-листе).

## Правила Создания И Обновления

1. Новые `.md` task-файлы и Jira issues создает PM/другая LLM. Codex
   Documentation dispatcher может создавать active-sprint 0.1.6 задачи только
   после duplicate/owner/lane/locked-path audit. Обычная сверка dispatcher может
   идти через `python3 tools/jira_board_sync.py --no-create`; после намеренного
   создания задачи нужно запускать sync без `--no-create`, чтобы появился Jira
   issue.
2. Во время будущего feature block задачи текущей версии остаются current-sprint
   work только если они уже есть на board или являются bug/QA defect/regression/
   release blocker. Новые не-баговые задачи получают следующую `Версия` и
   остаются без active sprint assignment до PM override.
3. В `.md` task-файле рядом с метаданными добавить строку:

   ```text
   Jira: SCRUM-123
   ```

4. В `docs/process/task_board.md` в примечании к строке задачи добавить Jira key:

   ```text
   Jira: SCRUM-123
   ```

   Для active rows board note также должна показывать `Контур`, owner/thread и
   главные locked paths, если они не очевидны из названия задачи.

5. При изменении статуса `.md` обновить Jira:
   - `new` — issue создана и находится в backlog/sprint To Do.
   - `in_progress` — перевести issue в In Progress, если переход доступен.
   - `review` — перевести в review/QA статус, если такой статус есть; иначе оставить
     In Progress и добавить comment.
   - `done` — перевести в Done, если acceptance/QA позволяют.
   - `blocked` — оставить в текущем workflow status и добавить comment с причиной.

6. При добавлении `## Результат` или `## QA-Вердикт` в `.md` добавить Jira comment
   с кратким резюме и ссылкой на локальный task-файл.
7. При релизе версии все связанные Jira issues должны иметь release note/комментарий
   или Fix Version, если версия заведена в Jira.

## Обязательство Агентов

Каждый агент, который берет задачу в работу или завершает ее, обязан:

1. Проверить наличие `Jira: SCRUM-*` в task-файле.
2. Если Jira key отсутствует — передать PM/owner задачу на создание issue до
   начала работы. Исключение: Codex Documentation dispatcher может сам создать
   Jira issue для 0.1.6 task после duplicate/owner/lane/locked-path audit или
   для текущего bug/QA defect/regression/release blocker.
3. При изменении `.md` статуса обновить Jira status/comment.
4. Если задача переносится, блокируется или требует handoff — отразить это и в
   `.md`, и в Jira comment/status.
5. Не закрывать задачу полностью без синхронизации Jira.
6. Закрывать только свои задачи или задачи своего ревью-контура. Dispatcher/PM
   не закрывает задачу за исполнителя; он синхронизирует Jira только после того,
   как исполнитель записал результат в task-файл/board или QA добавил verdict.
7. Codex Documentation dispatcher не маршрутизирует задачу без `Контур`, owner
   state и locked-path проверки. Во время будущего feature block он не создает
   новые active-sprint feature tasks без PM override.
8. Codex role agents и Claude Code/воркеры обязаны пропускать задачи чужого
   `Контур` или чужого `Owner`, даже если Jira status выглядит как To Do.

## Проверка Дубликатов

Dispatcher при регулярной сверке обязан искать дубли в `.md` board и Jira:

- одинаковый task-файл или source task path;
- одинаковый Jira summary/почти одинаковая формулировка проблемы;
- две активные задачи на одни и те же файлы, ассеты, экран или баг;
- backlog-задача будущей версии, случайно продублированная в active sprint.

Если найден дубль, dispatcher не раздает его исполнителю. Нужно оставить один
source of truth, а остальные пометить `duplicate` или `superseded`, добавить
ссылку на основной `.md`/Jira issue и комментарий в Jira. Если непонятно, какая
задача главная, оставить обе без dispatch и эскалировать PM.

## Feature Block / Sprint Policy

Фриз 0.1.5 снят релизом v0.1.5 (2026-06-15). Сейчас активен `Спринт 0.1.6`.
Агенты и dispatcher обязаны:

1. Проверять тип задачи перед dispatch.
2. Дожимать активные задачи текущего sprint, баги, QA-дефекты, регрессии,
   release blockers и уже записанные executor results до Jira/QA sync.
3. Маршрутизировать 0.1.6 rows обычным порядком только после проверки дублей,
   зависимостей и active owner.
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
