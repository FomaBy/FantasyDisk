# Jira Sync — FantasyDisk

Обновлено: 2026-06-13

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
- Current active sprint: `Спринт 0.1.5`
- Current active sprint id: `67`
- Feature block: **LIFTED** 2026-06-13 after release `v0.1.4`. Tasks with
  `Версия: 0.1.5` are current-sprint work and may be dispatched/transitioned to
  `in_progress` normally unless their task file has an explicit blocker.

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
   Documentation dispatcher также может создавать новые задачи для активного
   `Спринт 0.1.5`, если запрос относится к текущему patch scope, или как явно
   текущие bug/QA defect/regression/release blocker задачи. Обычная сверка
   dispatcher может идти через `python3 tools/jira_board_sync.py --no-create`;
   после намеренного создания задачи нужно запускать sync без `--no-create`,
   чтобы появился Jira issue.
2. Пока feature block снят, задачи с `Версия: 0.1.5` получают fixVersion
   `0.1.5` и active sprint assignment `Спринт 0.1.5`. Во время будущего freeze
   задачи следующей версии снова остаются backlog/fixVersion без active sprint.
3. В `.md` task-файле рядом с метаданными добавить строку:

   ```text
   Jira: SCRUM-123
   ```

4. В `docs/process/task_board.md` в примечании к строке задачи добавить Jira key:

   ```text
   Jira: SCRUM-123
   ```

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
   Jira issue для активной `0.1.5` задачи текущего patch scope или текущего
   bug/QA defect/release blocker.
3. При изменении `.md` статуса обновить Jira status/comment.
4. Если задача переносится, блокируется или требует handoff — отразить это и в
   `.md`, и в Jira comment/status.
5. Не закрывать задачу полностью без синхронизации Jira.
6. Закрывать только свои задачи или задачи своего ревью-контура. Dispatcher/PM
   не закрывает задачу за исполнителя; он синхронизирует Jira только после того,
   как исполнитель записал результат в task-файл/board или QA добавил verdict.
7. Codex Documentation dispatcher создает active-sprint feature tasks только в
   рамках текущего patch scope/PM-user directive. Его допустимые действия:
   route existing eligible задач, update existing status, Jira comments/status
   sync, duplicate/superseded marking, а также оформить текущий bug/QA defect/
   release blocker.

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

## Feature Block Обязательство

Сейчас feature block СНЯТ: активен `Спринт 0.1.5` (id 67), patch scope «Бой и
баланс». Задачи `Версия: 0.1.5` dispatch'ятся обычным порядком, кроме явно
`blocked` задач. Когда PM снова включает freeze, агенты и dispatcher обязаны:

1. Проверять тип задачи перед dispatch.
2. Дожимать активные задачи текущего sprint, баги, QA-дефекты, регрессии,
   release blockers и уже записанные executor results до Jira/QA sync.
3. Не начинать backlog-задачи следующей версии без PM override во время фриза.
4. Для новых не-баговых задач во время фриза создавать/оставлять `.md` task и
   Jira issue в backlog следующей версии, без sprint assignment.
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
