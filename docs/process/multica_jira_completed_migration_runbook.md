# Перенос выполненных Jira-задач FantasyDisk в Multica

Jira: SCRUM-1077  
Зафиксированный объём на 2026-07-11: 1 019 issues в категории Done.

## Безопасность импорта

Importer создаёт архивные Multica issues сразу в статусе `done` и без assignee.
Это принципиально: назначение issue Multica-агенту запускает задачу, поэтому при
историческом импорте assignee не переносится.

Importer:

- по умолчанию работает только как dry-run;
- использует metadata `jira_key` для защиты от дублей;
- сохраняет resume state после каждой issue;
- не изменяет Jira;
- не коммитит выгрузку, tokens или migration state;
- сохраняет Jira URL, key, type, labels и timestamps;
- может отдельно перенести comments с исходным author/time в тексте.

Attachments остаются в Jira и доступны по сохранённой ссылке. Перенос бинарных
attachments в первую миграцию не выполнять.

## 1. Подготовка Mac

```bash
brew install multica-ai/tap/multica
multica setup
multica auth status
multica workspace list --output json
multica workspace switch <fantasydisk-workspace>
```

Задать Jira token локально, не в репозитории:

```bash
export JIRA_API_TOKEN='<token>'
export JIRA_EMAIL='fomamoney@gmail.com'
export JIRA_BASE_URL='https://fantasydisk.atlassian.net'
```

## 2. Проверить dry-run

```bash
python3 tools/jira_to_multica.py
```

Ожидаемый итог: `issues: 1019`. Dry-run ничего не пишет в Multica.

## 3. Пилот из 10 issues

Создать в Multica проект `Jira Archive`, затем:

```bash
python3 tools/jira_to_multica.py \
  --apply \
  --limit 10 \
  --project 'Jira Archive'
```

В интерфейсе проверить:

- создано ровно 10 issues;
- status у всех `done`;
- assignee отсутствует;
- ни один agent run не запущен;
- title/description читаемы;
- metadata содержит `jira_key` и `jira_url`;
- повтор той же команды не создаёт дубли.

## 4. Полный импорт

Без comments:

```bash
python3 tools/jira_to_multica.py --apply --project 'Jira Archive'
```

С comments:

```bash
python3 tools/jira_to_multica.py \
  --apply \
  --project 'Jira Archive' \
  --include-comments
```

Перенос comments существенно увеличит число API calls. Сначала рекомендуется
перенести issues, проверить итог, затем решать, нужна ли полная история comments.

State и report сохраняются вне Git:

```text
~/.multica/fantasydisk-jira-migration-state.json
~/.multica/fantasydisk-jira-migration-report.json
```

После interruption повторить ту же команду: уже записанные `jira_key` будут
пропущены по state или найдены в Multica metadata.

## 5. Проверка результата

```bash
multica issue list --status done --project 'Jira Archive' --limit 2000 --output json
multica issue list --metadata jira_key=SCRUM-1 --output json
cat ~/.multica/fantasydisk-jira-migration-report.json
```

Критерии завершения:

- source count = 1 019;
- failed = 0;
- в Multica есть ровно одна issue на каждый `jira_key`;
- issues unassigned и `done`;
- agent tasks/runs из-за импорта отсутствуют;
- выборочно сверены задачи, баги, эпики и subtask;
- Jira остаётся доступна как read-only historical source.

## 6. Rollback

Не удалять Jira issues. Если pilot неверен, удалить только созданные issues
проекта `Jira Archive` через Multica UI/API после сохранения report. Удаление
Multica issue необратимо, поэтому full rollback выполнять только по списку IDs из
migration state и после ручной проверки workspace/project.

После успешного импорта Jira не отключается автоматически. Переключение
authoritative tracker оформляется отдельным cutover task после сверки данных.
