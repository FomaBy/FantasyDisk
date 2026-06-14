# Cleanup: удалить дубли-артефакты `« N.ext»` (275 файлов)

Статус: done (2026-06-14, Claude Fable 5)
Приоритет: high
Роль: Back-end
Версия: 0.1.5
Создано: 2026-06-14
Автор: Back-end audit SCRUM-267 (Quality Pass v2)
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
