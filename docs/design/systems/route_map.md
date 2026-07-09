# Route Map

Обновлено: 2026-06-28

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
| `hazard` | опасная развилка — фиксированное событие `sudden_fork` (event UI) |
| `altar` | алтарь жертвы — фиксированное событие `sacrifice_altar` (event UI) |
| `chest` | гарантированный сундук с выбором артефакта |
| `rest` | костер / отдых |
| `boss` | финальная битва маршрута |

Канонические иконки route nodes перечислены в `docs/design/content_registry.md`.

### Инвариант «elite = обязательный бой» (SCRUM-994)

- Узел типа `elite_battle` при активации может войти **только** в элитный бой
  (`_open_route_node` → `_start_combat(false, "elite")`) — никогда в событие,
  магазин или иной non-combat флоу. Legacy-алиас типа `elite` (дрейф данных
  старых сейвов) ведёт туда же.
- Иконка `map_elite_skull_bones.png` **эксклюзивна** для `elite_battle`: ни один
  другой тип узла не имеет права её носить. Узел «Алтарь жертвы» (открывает
  событие) раньше переиспользовал эту иконку и читался игроком как элитный бой —
  теперь он носит событийную `map_event_question.png` (как `hazard`) со своим
  кроваво-пурпурным тоном.
- Пост-генерация не переписывает элитки: `_place_altar_node` не ставит алтарь на
  `elite_battle`-ветку (защита наравне с гарантированными `shop`/`chest`).
  Сгенерированный элитный узел доживает до карты элитным боем.
- Элитный бой использует существующий elite flow: детерминированный от seed узла
  тип элитки (`node_elite_scene`), elite-скейлинг, награда «1 из 3 артефактов»
  (гейт `_elite_defeated`) и возврат на карту с продвижением ряда.
- Регресс-тест: `tests/route_elite_invariant_test.gd`.

## Route Rules

- Забег состоит из 3 актов (`Акт 1/3` → `Акт 2/3` → `Акт 3/3`).
- Каждый акт генерирует отдельную route map с теми же 10 activity rows + boss
  row. После победы над boss в Act 1/2 билд игрока сохраняется, создаётся новая
  route map, `route_stage` сбрасывается в 0 как act-local прогресс, а
  `current_act` увеличивается на 1. Победа над boss Act 3 завершает забег.
- UI route map показывает текущий акт и `Сила маршрута`: это глобальный scaling
  stage для экономики/врагов, чтобы Act 2/3 не превращались в повтор tutorial.
- Стартовые узлы первого ряда доступны сразу после выбора персонажа и оружия.
- Первые два selectable ряда после старта маршрута всегда состоят только из
  обычных `battle` узлов. `shop`, `event`, `rest` и `elite_battle` могут
  появляться только начиная с третьего selectable ряда, чтобы ранний забег
  сначала дал базовый combat tempo, XP и золото.
- На каждой generated route map ровно два `shop` узла: один в первой половине
  non-boss рядов и один во второй половине. Магазины размещаются через тот же
  seeded RNG, не попадают в первые два battle-only ряда и не заменяют boss row.
- На каждой generated route map ровно один `chest` узел: он ставится в
  lower-middle ряд non-boss маршрута после размещения магазинов и не заменяет
  shop. Для текущих 10 activity rows это row index `4` (пятый selectable ряд),
  то есть после двух battle-only рядов и максимально близко к геометрическому
  центру между рядами 4/5. Сундук открывает обязательный выбор 1 из 3
  артефактов и после выбора продвигает маршрут как noncombat node.
- Пути ограничены через `next_branches`; карта не должна быть all-to-all.
- Назад возвращаться нельзя, кроме текущего `shop`-узла после выхода из лавки:
  магазин можно повторно открыть до выбора следующего route node.
- Boss row находится в конце маршрута.
- Event/rest node после выбора возвращает игрока на карту и продвигает маршрут.
- Shop node после выхода возвращает игрока на карту без продвижения `route_stage`:
  тот же shop остается кликабельным с сохраненным стоком/покупками, отмечается
  completed-галочкой как уже посещенный, а следующий ряд уже доступен. Выбор
  любого узла следующего ряда финализирует магазин, очищает его stock state и
  становится точкой невозврата.

## Node Preview (SCRUM-499)

Чтобы выбор развилки был тактическим, а не угадайкой, tooltip узла показывает
**детерминированное превью** того, что реально ждёт внутри:

- **Per-node seed.** При генерации каждый узел получает стабильное поле `seed`
  (`game.rng.randi()`), которое сохраняется в автосейв вместе с `route_nodes`.
  Старые сейвы без `seed` получают детерминированный fallback от позиции/типа
  узла (`main.gd:fallback_node_seed`).
- **Превью == реальность by construction.** Выбор фона арены и типа элитки в бою
  и в тултипе идёт через одни и те же функции `main.gd`:
  `node_background_path(node_type, is_boss, seed)` и `node_elite_scene(seed)`.
  `combat_director` при входе в узел делегирует им же (через `current_node_seed`,
  который выставляется в `_activate_route_node`), поэтому превью гарантированно
  совпадает с тем, что стартует. Босс детерминирован отдельно — его `boss_id`
  фиксируется в узле ещё при генерации.
- **Что показывает tooltip:**
  - бой/элитка: биом/фон арены (`Арена:`) + краткий намёк на состав волны
    (`Угроза:`, например «в составе — стрелки») — намёк детерминирован от seed и
    глубины и отражает stage-веса спавна;
  - элитка дополнительно: тип элиты (`Элита:`) и гарантированный артефакт с
    ориентиром тира по глубине акта (`Награда: … тир …`), повторяющим
    depth-weighting из `ProgressionData.elite_artifact_choices`;
  - boss-узел: имя финального босса (`Босс:`), один из 5.

## SCRUM-563 Route Map 2K Source Package

SCRUM-563 adds the Route Map 2K UI Director source package. The approved
geometry and safe-zone plan lives in `docs/design/mockups/scrum563_route_map_2k/`,
the OpenAI Images API mockup is
`docs/design/references/scrum563_route_map_2k/route_map_2k_mockup.png`, and QA
previews are `docs/design/previews/scrum563_route_map_2k_plan_guide.png` plus
`docs/design/previews/scrum563_route_map_2k_mockup_safe_zones.png`.

The package keeps the existing SCRUM-489 runtime geometry: full-screen header,
full-width vertical scroll viewport, dynamic route canvas height, 88x88 route
nodes, and no horizontal scrolling. Future runtime wiring must keep header
labels, HUD text, tooltip text, node icons, route lines and the upgrade FAB
inside the declared interiors, never on frame rails, dragon ornaments, ruby pins
or corner metal.

## Tests

- `tests/route_node_preview_test.gd` (SCRUM-499) проверяет, что превью биома и
  типа элитки, посчитанное из `node["seed"]`, совпадает с реальным выбором
  `combat` для каждого узла; что каждый узел несёт `seed`; и что tooltip содержит
  ожидаемые поля (Арена/Угроза/Элита/артефакт/Босс).
- `tests/route_chest_artifact_test.gd` (SCRUM-537) проверяет ровно один chest в
  lower-middle row, сохранение двух shops и первых двух battle-only rows,
  canonical chest icon, tooltip, 3 artifact choice buttons, уникальные artifact
  IDs, применение одного артефакта и переход completed → следующий row.
- `tests/runtime_smoke_test.gd` проверяет full-screen scroll area, стартовый выбор,
  первые два battle-only ряда, ровно два магазина с half-placement, event click,
  shop re-entry до следующего узла, drag suppression, thin route lines, tooltips,
  route branching, Act 1 boss → Act 2 route transition и Act 3 boss → victory.
