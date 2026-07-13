# Jira → Multica Cutover Record

Статус: **CUTOVER ЗАВЕРШЁН — Multica является authoritative tracker.**

Это финальная запись cutover gate из
[`multica_migration_and_ai_operations.md`](multica_migration_and_ai_operations.md)
(«Cutover gate») и
[`multica_jira_completed_migration_runbook.md`](multica_jira_completed_migration_runbook.md)
(«Jira остаётся authoritative tracker до отдельного explicit cutover gate»).
С этого момента источником истины задач/статусов/владельцев является Multica, а не Jira.

## Запись решения

| Поле | Значение |
|---|---|
| Дата/время cutover | 2026-07-13 |
| Approver (владелец проекта) | Sergey Fomin — `fomamoney@gmail.com` |
| Cutover task | FAN-1044 «Атомарный Jira → Multica cutover репозиторных процессов» |
| Authoritative tracker после cutover | **Multica** |
| Rollback owner | Sergey Fomin (владелец проекта) |
| Jira статус | read-only historical archive (минимум 30 дней) |

## Каноничный Multica-источник

Единственный authoritative источник задач/статусов/владельцев/evidence:

| Поле | Значение |
|---|---|
| Платформа | Multica (`https://multica.ai/`) |
| Workspace | `FantasyDisk` — `afa7a066-e0cb-4b55-a07d-41b361a8bb84` |
| Каноничный проект (live dev board) | **FantasyDisk** — `2ac963eb-b644-4540-8042-a1a4508f1a65` |
| Префикс issue | `FAN-*` (например, FAN-1044) |
| Интерфейс агента | `multica` CLI (`multica issue …`, `multica --help`) |

Исторический архив (только чтение, не источник новой работы):

| Поле | Значение |
|---|---|
| Проект | **Jira Archive** — `a2cb75b5-d6c9-451c-8a29-4d267f09d67d` |
| Содержимое | 1022+ завершённых Jira issues (`SCRUM-*`), unassigned, `done` |
| Прежний Jira-ключ | сохранён в metadata `jira_key` / `jira_url` |

## Новое правило источника истины

- **Брать / вести / закрывать работу — только в Multica** (проект FantasyDisk,
  `FAN-*`) через `multica` CLI. Ни один активный onboarding/worker/process
  документ или скилл не должен направлять агента claim'ить или синкать Jira.
- `docs/tasks/*.md` и `docs/process/task_board.md` — локальные spec/evidence
  **mirrors**, не источник новой работы.
- **Legacy Jira (`SCRUM-*`) — read-only исторический архив.** Не создавать, не
  claim'ить, не синкать и не закрывать работу в Jira. Исторические `SCRUM-*`
  ссылки в evidence и `task_board.md` сохраняются как история.

Соответствие понятий Jira → Multica — см. таблицу «Фаза 4» в
[`multica_migration_and_ai_operations.md`](multica_migration_and_ai_operations.md).

## Archive-only после cutover (убраны из normal startup/finish flow)

Эти хелперы и скиллы больше не входят в обычный старт/финиш задачи. Они сохранены
для истории и для одноразового архивного импорта, но НЕ используются как live tracker:

- `tools/jira_next_task.py` — claim-first авто-взятие Jira (заменено назначением
  Multica issue / `multica issue …`).
- `tools/jira_board_sync.py` — синк `.md` ↔ Jira (Multica timeline — сам record).
- `tools/jira_qa_next.py`, `tools/jira_qa_helper.py`, `tools/jira_release_stuck.py`
  — Jira QA/release хелперы.
- `tools/jira_to_multica.py` — одноразовый архивный importer (см. runbook); не
  cutover сам по себе.
- Скиллы `skills/codex/jira-create-ticket/`, `skills/codex/jira-move-children/`
  — generic Jira-tooling, не часть FantasyDisk Multica-потока.
- `docs/process/jira_sync.md`, `docs/process/jira_epics.json`,
  `docs/process/jira_sync_map.json` — legacy Jira-sync регламент/карта.

## Cutover gate — критерии (из migration doc)

- [x] исторический импорт выполнен и сверен (SCRUM-1077: 1022 = 1022, failures 0);
- [x] Jira Archive проект существует, issues unassigned + `done`, `jira_key`/`jira_url` в metadata;
- [x] live dev board ведётся в Multica (проект FantasyDisk, `FAN-*`);
- [x] QA-gate: Done только после QA PASSED (`in_review` → QA → `done`);
- [x] активные onboarding/process/worker инструкции переведены на Multica атомарно (FAN-1044);
- [x] Jira-хелперы/скиллы помечены archive-only и убраны из normal flow;
- [x] регрессионный тест не даёт направить нового агента (Codex/Claude) в Jira
      (`tests/test_multica_cutover_onboarding.py`);
- [x] онбординг проверен на чистом клоне (`bash scripts/onboard.sh`);
- [x] владелец проекта явно одобрил cutover (см. «Запись решения»).

## Rollback

Пока держится 30-дневное окно Jira-архива, rollback возможен по процедуре
«Rollback» в [`multica_migration_and_ai_operations.md`](multica_migration_and_ai_operations.md):
остановить новые Multica assignments, вернуть незавершённые issues в Jira по
сохранённому `jira_key`, восстановить Jira-first dispatcher, зафиксировать incident.
Multica-данные не удалять до анализа.
