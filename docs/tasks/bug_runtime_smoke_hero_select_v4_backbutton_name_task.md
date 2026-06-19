# BUG: runtime_smoke_test падает — back-button ноду переименовали в v4 (HS4BackButton), тест ищет старое имя HeroSelectBackButton

Статус: new
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-19
Найдено QA: при тестировании SCRUM-475
  (`docs/tasks/design_skeleton_friendly_dark_mage_knight_parts_task.md`)
Связано: SCRUM-343 (back-button frame), hero-select v3→v4 миграция

## Симптом

`tests/runtime_smoke_test.gd` детерминированно падает (exit 1):

```
ERROR: Expected hero select v4 to expose a back button.
   at: _fail (res://tests/runtime_smoke_test.gd) <- _test_back_button_frame_safety
```

Падает и на committed dev HEAD (проверено через stash всех несвязанных
WIP-правок рабочего дерева), то есть это не следствие незакоммиченных изменений
SCRUM-474/475, а регресс на самом dev.

## Корень

- `_test_back_button_frame_safety` (`tests/runtime_smoke_test.gd`) вызывает
  `_show_character_select()` и ищет `find_child("HeroSelectBackButton", ...)`.
- Активный экран выбора героя теперь строится в
  `scripts/ui_screens.gd:_build_character_select_v4()` (вызывается из
  `_show_character_select()` → `ui_screens.gd:985`), и его кнопка «Назад»
  называется **`HS4BackButton`** (`ui_screens.gd:745`).
- Имя `HeroSelectBackButton` принадлежит старому v3-билдеру
  (`ui_screens.gd:1225`), который `_show_character_select()` больше не вызывает.
- Итог: тест не находит ноду и падает. Сама кнопка «Назад» в v4 есть и работает
  (`pressed → _show_main_menu`), то есть функционально UI в порядке — красный
  даёт именно рассинхрон имени ноды в тесте после миграции v3→v4.

## Воспроизведение

1. На ветке dev (committed HEAD достаточно):
   `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/runtime_smoke_test.gd`
2. Тест валится на `_test_back_button_frame_safety` с
   «Expected hero select v4 to expose a back button.»

## Ожидание / Реальность

- Ожидание: umbrella `runtime_smoke_test` зелёный на dev.
- Реальность: красный, т.к. проверяется back-button по устаревшему имени ноды.

## Предлагаемый фикс (Back-end решает)

Один из двух (на усмотрение исполнителя, оба валидны):
- Обновить тест: искать `HS4BackButton` (каноническая v4-нода), а не
  `HeroSelectBackButton`; либо
- В `_build_character_select_v4()` присвоить back-кнопке стабильное канон-имя,
  ожидаемое тестом (и зафиксировать его как контракт).
Затем прогнать `runtime_smoke_test` + `animation_smoke_test` (оба зелёные).

## Окружение

- Ветка dev, commit 27e225d5 (+ незакоммиченный WIP SCRUM-474, но баг
  воспроизводится и без него — на чистом HEAD).
- Godot 4.6.3 headless, разрешение по умолчанию теста.
- Класс/уровень: не зависит (экран меню выбора героя).
