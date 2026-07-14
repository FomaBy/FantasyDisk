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
  --project a2cb75b5-d6c9-451c-8a29-4d267f09d67d
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
python3 tools/jira_to_multica.py --apply \
  --project a2cb75b5-d6c9-451c-8a29-4d267f09d67d
```

С comments:

```bash
python3 tools/jira_to_multica.py \
  --apply \
  --project a2cb75b5-d6c9-451c-8a29-4d267f09d67d \
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
пропущены по state или найдены в Multica metadata. Если процесс был остановлен
между записью `jira_key` и остальных полей, выполнить scoped repair (например,
для pilot-диапазона):

```bash
python3 tools/jira_to_multica.py \
  --apply --repair --limit 10 \
  --project a2cb75b5-d6c9-451c-8a29-4d267f09d67d
```

Existing issue не дублируется: importer находит её по `jira_key` и восстанавливает
canonical metadata.

## 5. Проверка результата

```bash
python3 tools/jira_to_multica.py \
  --verify \
  --project a2cb75b5-d6c9-451c-8a29-4d267f09d67d
multica issue list --metadata jira_key=SCRUM-1 --output json
cat ~/.multica/fantasydisk-jira-migration-report.json
```

`--verify` сам читает Multica страницами по 100 строк (CLI ограничивает размер
одной страницы даже при большем `--limit`) и сравнивает полный набор Jira keys,
дубли, status, assignee и archival metadata. `--project` fail-closed принимает
только pinned ID `Jira Archive`, чтобы importer не мог писать в live project.

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

## Результат SCRUM-1077 — 2026-07-11

- baseline из тикета: `1 019 / 1 019`, failures `0`;
- live incremental pass после трёх новых QA-закрытий: Jira `1 022` = Multica
  `1 022`;
- типы live-набора: 824 задачи, 179 багов, 5 эпиков, 10 features, 1 story,
  3 subtask;
- `--verify`: PASSED — missing/extra/duplicates/without-key/not-done/assigned/
  not-archival/missing-url пусты;
- idempotent rerun: `created=0`, `resumed=1022`;
- interrupt/resume fixture: частичная SCRUM-24 найдена по синхронному `jira_key`,
  дубль не создан, canonical metadata восстановлена через `--repair`;
- comments и attachments не переносились; Jira URLs сохранены во всех issues;
- state, baseline report и live verification report остаются вне Git в
  `~/.multica/`.

Explicit cutover gate пройден 2026-07-13 (approver Sergey Fomin, project owner):
Multica (project `FantasyDisk`, issues `FAN-*`) теперь authoritative tracker, а
Jira (`SCRUM-*`) — read-only historical archive. См.
`docs/process/jira_to_multica_cutover.md`.
