# QA Review: Level-Up FAB Return Button Dedup

Статус: done 2026-06-12 (PM: процессный дубликат)
Создано: 2026-06-12
Автор: Codex Dispatcher
Jira: SCRUM-124

## Source Task
- `docs/tasks/ux_levelup_fab_return_button_dedup_task.md`

## Status Note
Source Back-end UX task marked `done` 2026-06-12; ready for QA review.

## QA Scope
Проверить, что level-up имеет ровно одну точку возврата при pending level-ups и при этом докачка атрибутов за золото не потеряна.

## Acceptance Criteria
- [ ] При `pending_level_ups > 0` видна ровно одна кнопка-вход в level-up.
- [ ] Докачка атрибутов за золото по-прежнему доступна, когда level-up pending нет.
- [ ] Бейдж pending, отложенный выбор и фиксация набора не регресснули.
- [ ] Runtime smoke зеленый или заведены bug tasks.

## QA-Вердикт (2026-06-12)
Статус: PASSED

Независимая проверка (вариант A фикса):
- `_create_upgrade_fab` (ui_screens.gd:780-785): при `pending_level_ups > 0` —
  early-return после `_update_level_up_button()`, FAB (`UpgradeFabButton`) НЕ
  создаётся. Единственная точка входа в level-up — нижняя кнопка `LevelUpPlusButton`
  с бейджем `LevelUpPlusBadge` (счётчик pending сохранён, :2588-2615). VERIFIED.
- При `pending_level_ups == 0` FAB создаётся для докачки атрибутов за золото
  (второй режим не потерян, :787+). VERIFIED.
- Тест (runtime_smoke:3240-3252) реальный: ассертит отсутствие `UpgradeFabButton`
  при pending + наличие нижней кнопки с бейджем + возврат FAB при pending==0.
Req#3 «не дублировать» выполнено. runtime smoke зелёный. Багов нет.

## QA-Вердикт (2026-06-12)
Статус: PASSED (закрыта PM как процессный дубликат)
Парные qa_review-файлы упразднены: КАЖДАЯ done-задача автоматически тестируется
QA-воркером по docs/process/qa_protocol.md — отдельный файл-двойник не нужен.
Целевая задача получает/получила собственный QA-Вердикт обычным потоком.
