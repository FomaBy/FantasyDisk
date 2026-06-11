# Route Map

Обновлено: 2026-06-11

Route map — full-screen экран выбора пути между боями. Реализация: `scripts/route_map_screen.gd`, делегирующие методы в `scripts/main.gd`.

## Layout

- Карта открывается во весь экран, не в маленькой panel.
- `RouteMapScroll` занимает почти весь viewport.
- Карта вертикальная: игрок движется снизу вверх к boss node.
- Текущий доступный ряд автоматически фокусируется при открытии.
- Игрок сразу видит несколько будущих рядов для планирования.

## Interaction

- Доступные узлы подсвечены, locked nodes визуально приглушены.
- Hover показывает tooltip.
- Узлы кликабельны после scroll/pan.
- Линии и иконки внутри узлов игнорируют mouse input, чтобы не перехватывать клик.
- Зажатая левая кнопка мыши перетаскивает карту; если drag превышает threshold, click по узлу подавляется.

## Node Types

| Type | Meaning |
| --- | --- |
| `battle` | обычный бой |
| `elite_battle` | усиленный бой с элиткой |
| `shop` | магазин |
| `event` | событие / question mark |
| `rest` | костер / отдых |
| `boss` | финальная битва маршрута |

Канонические иконки route nodes перечислены в `docs/design/content_registry.md`.

## Route Rules

- Стартовые узлы первого ряда доступны сразу после выбора персонажа и оружия.
- Пути ограничены через `next_branches`; карта не должна быть all-to-all.
- Назад возвращаться нельзя.
- Boss row находится в конце маршрута.
- Event/shop/rest node после выбора возвращает игрока на карту и открывает следующий ряд.

## Tests

- `tests/runtime_smoke_test.gd` проверяет full-screen scroll area, стартовый выбор, event click, drag suppression, thin route lines, tooltips и route branching.
