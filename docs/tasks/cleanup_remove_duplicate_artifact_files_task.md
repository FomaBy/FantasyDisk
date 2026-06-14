# Cleanup: удалить дубли-артефакты `« N.ext»` (275 файлов)

Статус: done (2026-06-14, Claude Fable 5)
Приоритет: high
Роль: Back-end
Версия: 0.1.5
Создано: 2026-06-14
Автор: Back-end audit SCRUM-267 (Quality Pass v2)
Jira: SCRUM-270
Эпик: CLEANUP — рефакторинг и чистка v2 (SCRUM-266)
Порождена: docs/design/reviews/cleanup_code_audit_2026_06.md (P1)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст
Случайная операция копирования продублировала ~275 файлов дерева с суффиксом
` 2`/` N` (docs/tests/scripts/scenes/assets/tools). Дубли НЕ ссылаются никем
(реальные файлы используются по базовому имени), раздувают репо и дают ложные
срабатывания asset-аудита.

## File-изоляция
НЕ блокируется балансовым патчем 0.1.5: удаляются ТОЛЬКО ` N.`-копии; реальные
файлы (`progression_data*.gd`, `player.gd`, и т.д.), которые правит патч, НЕ
трогаются. Diff содержит только удаления дублей.

## Требования
1. Список: `git ls-files | grep -E ' [0-9]\.[a-z]+$'` (≈275 файлов).
2. Выборочно подтвердить НЕссылаемость 2-3 code-дублей (`grep -rl "combat_target_query 2.gd"` → пусто).
3. Бэкап в `build/cleanup_backup_dupes_2026_06_14/` (необратимого удаления нет), затем `git rm` всех.
4. Verify: runtime smoke + animation smoke + content_registry зелёные после удаления.
5. CHANGELOG.

## Acceptance Criteria
- [ ] ~275 ` N.`-дублей удалены (с бэкапом); реальные файлы не тронуты.
- [ ] runtime + animation + content_registry smoke зелёные.

## Dispatcher Sync Note (2026-06-14)

Task file already marked `done (2026-06-14, Claude Fable 5)` and the matching
` N.` duplicate-file deletions are present in the working tree. Dispatcher did
not redispatch this as new work; board/Jira bookkeeping was aligned to the
existing recorded status. QA/owner still needs to verify the acceptance checklist
before final closure if not already recorded elsewhere.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 2981acf8 (ветка dev; удаления закоммичены)

Проверено (фактически):
- **Дубли удалены**: `git ls-files | grep ' [0-9]\.ext'` → **0** оставшихся
  ` N.`-дублей (было ~275). Удаления закоммичены (0 pending в дереве).
  `scripts/combat_target_query 2.gd` и пр. больше не существуют.
- **Обратимость**: бэкап `build/cleanup_backup_dupes_2026_06_14/` содержит ровно
  **275 файлов** — удаление не необратимо.
- **Реальные файлы целы** (не удалены вместе с дублями): `combat_target_query.gd`,
  `player.gd`, `progression_data.gd`, `ui/hero_stat_radar.gd` — на месте.
- **Acceptance #2 — smoke после удаления зелёные**: `runtime_smoke_test`,
  `animation_smoke_test`, `content_registry_consistency_test` (**0 allowlisted** —
  ни одной сломанной/осиротевшей ссылки) — все passed.

Acceptance:
- [x] ~275 ` N.`-дублей удалены (с бэкапом 275 файлов); реальные файлы не тронуты.
- [x] runtime + animation + content_registry smoke зелёные.

Баги: нет. Минор: исполнитель оставил acceptance-чекбоксы `[ ]` без Result-секции;
QA подтвердил фактическое выполнение. Это закрывает P1-находку аудита SCRUM-267
(и совпадает с корраптацией ` 2.gd`, которую QA поймал ранее в дереве).
