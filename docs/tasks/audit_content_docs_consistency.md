# Аудит: консистентность контента и документации

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя: полный аудит и рефакторинг проекта)
Jira: SCRUM-175
Эпик: epic_full_project_quality_pass

Dispatcher: sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13.

## Autonomy / Approval
Пользователь заранее одобрил ВСЁ. Работать автономно без вопросов и ожидания
инпута (директива полной автономии). Тупик = blocked с причиной + handoff.

## Роль
Back-end (Claude)
## Контекст
Быстрый рост контента мог расфазировать `content_registry.md`, `current_game_state.md`,
`mechanics_extract.md` с фактическим состоянием кода/ассетов.

## Что сделать (READ-ONLY + отчёт + дочерние задачи)
1. Сверить content_registry со фактическими ID/путями (персонажи, оружие, враги,
   ассеты): отсутствующие, мёртвые, переименованные, неверные пометки статуса.
2. Сверить current_game_state и mechanics_extract с реальными системами/формулами.
3. Найти осиротевшие ассеты (есть файл — нет ссылки) и битые ссылки (есть ссылка —
   нет файла), доп. к tools/audit_unused_assets.py.
4. **Отчёт** `docs/design/reviews/content_docs_audit_2026_06.md`.
5. **Породить** задачи на актуализацию доков и чистку (0.1.4).

## Acceptance Criteria
- [ ] Расхождения реестр↔код↔ассеты перечислены; осиротевшие/битые ссылки найдены.
- [ ] Созданы дочерние задачи на правки доков/чистку.

## Документация
docs/design/reviews/, затем целевые доки (отдельными задачами).

## Результат — 2026-06-13

Read-only аудит завершен. Отчет создан:
`docs/design/reviews/content_docs_audit_2026_06.md`.

Ключевые выводы:
- Найден P1 drift: несколько новых `CHARACTER_CONFIGS[id].sprite_path` указывают на старые proxy sprites, хотя registry/current state говорят о финальных PNG.
- Exact reference scan дает ожидаемые false positives для dynamic patterns (`artifact_%s`, shop icons, cutout families), поэтому cleanup tool нужен manifest/allowlist.
- Реальные cleanup-кандидаты: `.DS_Store`, старые placeholder sprites, legacy root enemy duplicates, legacy `boss_warden.png`; удаление не выполнялось в рамках аудита.
- `current_game_state.md` остается слишком плотным и требует domain-doc pass после текущего batch.

Созданы child task specs 0.1.4:
- `docs/tasks/backend_content_character_sprite_registry_alignment_task.md`
- `docs/tasks/backend_content_unused_asset_audit_manifest_task.md`
- `docs/tasks/backend_content_safe_cleanup_followup_task.md`
- `docs/tasks/backend_docs_domain_consistency_update_task.md`

Jira для child tasks: pending PM sync, потому что текущий Back-end toolset не имеет Jira connector/API.

Verification: runtime, animation, meta progression, meta skill tree, melee targeting, attack VFX and hazard VFX smoke suites passed on 2026-06-13.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Read-only аудит контента/доков. Deliverables: отчёт
`docs/design/reviews/content_docs_audit_2026_06.md` + 4 дочерние задачи.
Действенность подтверждена: породил SCRUM-195 (docs domain consistency, зачтён
PASSED в этой сессии) и content/registry задачи. Баги: нет. Примечание: сам
этот audit-review всё ещё перечисляет старые имена `progression_economy/
ui_menus` (исторический артефакт, не живой системный док — отмечено в QA SCRUM-195).
