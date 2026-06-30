# SCRUM-700: QA 1080p UI scale pass for HUD and menus

Статус: new
Приоритет: P1
Роль: QA / visual QA
Контур: Codex
Executor: Codex
Owner: unassigned
Thread/Worker: n/a
Locked paths: read-only UI screens; `docs/tasks/qa_ui_1080_scale_visual_task.md`; QA evidence under `build/qa/scrum700_1080_ui_scale/`; follow-up bugs may lock specific UI files separately
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя
Jira: SCRUM-700

## Контекст

После последних изменений читаемости/масштаба UI часть интерфейса выглядит
слишком крупной на 1920x1080. Пользовательские примеры: боевой HUD занимает
почти полэкрана, а стартовое меню визуально залезает на логотип. Нужен отдельный
QA-проход по всем основным экранам именно с фокусом на масштаб и занимаемую
площадь UI на 1080p.

## Что сделать

1. Прогнать визуальный QA-проход всех основных UI-состояний на 1920x1080.
2. Сравнить с 1280x720 и 2560x1440 только там, где нужно понять, это ожидаемая
   адаптивность или регрессия масштаба на 1080p.
3. Проверить как минимум: main/start menu, combat HUD, settings, hero select,
   weapon select, codex, skill tree/progression, shop/economy, rewards/level-up,
   event/rest/upgrade, pause/stats, victory/death, dialogs, tooltips and feedback
   overlays.
4. Отдельно подтвердить два пользовательских примера:
   - HUD в игре на 1920x1080 не должен доминировать над игровой областью или
     закрывать значимую часть поля.
   - стартовое меню на 1920x1080 не должно перекрывать логотип/заголовок и не
     должно быть визуально прижато к нему.
5. Проверить глобальное правило фреймов: текст, кнопки, иконки и контент должны
   оставаться во внутренней пустой зоне, не на орнаменте/окантовке.
6. QA в этой задаче не чинит runtime/UI. По каждой подтверждённой проблеме
   создаётся отдельный bug issue + local mirror с экраном, разрешением,
   screenshot path, expected/actual и рекомендуемой ролью владельца.

## Acceptance Criteria

- [ ] Есть 1920x1080 screenshot/contact-sheet pass для всех экранов из scope.
- [ ] По каждому экрану есть короткий PASS/FAIL verdict: масштаб, занятая
      площадь, читаемость, расстояния до логотипа/заголовков, content-zone rule.
- [ ] Combat HUD на 1920x1080 проверен отдельно; если он закрывает слишком
      большую часть игровой области, заведён отдельный bug с evidence.
- [ ] Main/start menu на 1920x1080 проверено отдельно; если меню перекрывает
      логотип или визуально наползает на него, заведён отдельный bug с evidence.
- [ ] Все подтверждённые проблемы заведены отдельными Jira bug/local mirrors.
- [ ] Если экран проблем не имеет, это явно записано как PASS, а не пропущено.
- [ ] Итоговый QA-комментарий содержит branch/commit, команды или capture
      harness, пути к evidence, список созданных bugs и `Disk cleanup:`.

## Evidence Targets

- `build/qa/scrum700_1080_ui_scale/`
- `build/qa/design_review/` допустим как источник, если QA перегенерит свежие
  скриншоты и явно укажет tested commit.

## Рекомендуемые Проверки

- `python3 tools/godot_gate.py --path . --script res://tests/design_review_screenshot_capture_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
