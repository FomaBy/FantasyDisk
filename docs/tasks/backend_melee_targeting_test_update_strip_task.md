# Задача Для Back-end-Агента: Обновить melee_weapon_targeting_test Под Новую Форму Меча "strip"

Статус: done 2026-06-11. Закрыта PM при сверке доски: tests/melee_weapon_targeting_test.gd уже обновлен под форму strip и проходит (проверено headless-прогоном 2026-06-11, exit 0). Handoff устарел — проблема была устранена в рамках backend-работ по оружию/ревью без обновления этого файла.
Создано: 2026-06-11
Автор: Design (handoff из sprite quality audit)

## Контекст
В `scripts/progression_data.gd` меч берсерка переведен на форму `"strip"`
(полоса 120x500: `inner_width = outer_width = 120`, `attack_range = 500`).
Тест `tests/melee_weapon_targeting_test.gd` все еще проверяет старую геометрию
усеченного конуса (inner 150 / outer 1200 / range 600) и стабильно падает:

- `close_side_probe` стоит в (365, 300) — 65px вбок от оси удара. Старый конус
  у основания имел полуширину 75 (попадание), новая полоса — 60 (законный промах).
  Падает assert "Expected sword truncated cone base to damage nearby enemies beside Berserk"
  (строка ~88).
- Дальше по тесту есть probes на радиус 600 и «широкую внешнюю дугу» (724, -124) —
  тоже рассчитаны на старый конус и должны быть пересмотрены под strip 120x500.

## Требования
1. Обновить позиции probe-врагов и ожидания теста под актуальную форму `strip`
   (полоса постоянной ширины 120, длина 500, start_distance 0).
2. Сохранить покрытие сценариев: попадание по ближайшей цели, промах вбок,
   попадание у дальнего края, промах за пределом дальности.
3. Прогнать все headless smoke-тесты.

## Проверка
`/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/melee_weapon_targeting_test.gd`

Остальные тесты (runtime, animation, attack_vfx) зеленые — падает только этот.
