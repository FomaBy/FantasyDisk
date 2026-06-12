# QA Review: Back-end Project Folder Cleanup

Статус: done
Создано: 2026-06-12
Автор: Codex Dispatcher
Jira: SCRUM-127

## Source Task
- `docs/tasks/backend_project_folder_cleanup_unused_files_task.md`

## Ready For QA
Исходная Back-end задача получила `done` 2026-06-12.

## QA Scope
Проверить, что чистка проекта выполнена безопасно, без потери живых ассетов и без ошибок загрузки ресурсов.

## Expected Deliverables
1. В исходном task-файле статус `done` или `review` и краткое резюме.
2. Отчет `docs/process/project_cleanup_report_2026_06_12.md` со списком кандидатов, категориями, причинами и сверкой с `content_registry`.
3. Backup `build/cleanup_backup_2026_06_12/` с сохраненной структурой перемещенных файлов.
4. Отсутствие осиротевших `.import` без исходника и `.uid` без скрипта.
5. Отсутствие старых preview/debug assets в `assets/**`, если они не используются игрой.
6. Зафиксированные результаты 4 smoke-тестов и оконного прогона меню -> выбор героя -> карта -> бой -> магазин -> кодекс.
7. Обновленные CHANGELOG/документация, если исходная задача потребовала это по факту расхождений.

## Acceptance Criteria
- [ ] Ничего не удалено безвозвратно: удаленные/перемещенные candidates доступны в backup.
- [ ] Живые ассеты, динамически загружаемые пути и canonical IDs не сломаны.
- [ ] Проект запускается без missing resource errors, розовых текстур и сломанных импортов.
- [ ] `docs/**`, `tools/*`, `tests/**`, `source_docs/**`, `releases/**`, `.claude/**`, `keep-awake.sh`, `build/qa/` не были ошибочно почищены.
- [ ] Отчет объясняет спорные/оставленные расхождения с `content_registry`.
- [ ] Git diff соответствует только безопасной чистке и связанным отчетам/докам.

## QA Notes
QA не выполняет cleanup сам. Если найдены дефекты, завести отдельные bug/handoff задачи на доску по роли владельца.

## Result Summary — 2026-06-12

QA выполнена, вердикт `FAILED` зафиксирован в исходном файле
`docs/tasks/backend_project_folder_cleanup_unused_files_task.md`. По результату
заведен bug-таск `bug_cleanup_artifact_iteration_previews_left_in_assets_task.md`.
