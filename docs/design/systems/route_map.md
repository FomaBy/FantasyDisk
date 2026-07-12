# Route Map

Обновлено: 2026-07-12

Route map — full-screen экран выбора пути между боями. Реализация: `scripts/route_map_screen.gd`, делегирующие методы в `scripts/main.gd`.

## Layout

- Карта открывается во весь экран, не в маленькой panel.
- SCRUM-1057/1079: карта горизонтальная — start-колонка слева, boss справа,
  X строго растёт с каждым step, а ветки step разнесены по Y.
- `RouteMapScroll` использует только horizontal auto-scroll в нижней authored
  lane; vertical scrollbar отключён и `scroll_vertical` всегда равен 0.
- Текущая доступная колонка автофокусируется и возвращается в видимую
  область при open/return/live resize.
- Точные header/HUD/map/node/scrollbar/FAB zones заданы для
  1152×648, 1280×720, 1600×900, 1920×1080 и 2560×1440 в SCRUM-1057 spec.

## Interaction

- Доступные узлы подсвечены, locked nodes визуально приглушены.
- Hover показывает tooltip.
- Узлы кликабельны после scroll/pan.
- Линии и иконки внутри узлов игнорируют mouse input, чтобы не перехватывать клик.
- Зажатая левая кнопка мыши панорамирует по X; wheel/trackpad над картой
  также двигает horizontal offset. После drag threshold click по узлу
  подавляется.
- Left/Right ищут ближайшую focusable колонку, Up/Down — соседнюю ветку
  в текущей колонке; A/Enter подтверждает выбор.

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

- SCRUM-1058: забег состоит ровно из 2 актов (`Акт 1/2` → `Акт 2/2`).
- Каждый акт генерирует отдельную route map с неизменными 8 activity rows + boss
  row. После победы над boss Act 1 билд игрока сохраняется, один раз выдаются
  межактовая награда и лечение, создаётся новая route map, `route_stage`
  сбрасывается в 0, а `current_act` становится 2. Победа над boss Act 2 завершает
  забег или запускает разрешённого secret boss; третья карта не создаётся.
- UI route map показывает текущий акт и `Сила маршрута`: это глобальный scaling
  stage для экономики/врагов, чтобы Act 2 не превращался в повтор tutorial.
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

## SCRUM-1057 Horizontal PixelLab Source Package

Accepted visual contract: `docs/design/mockups/scrum1057_route_map_horizontal/spec.md`
and `responsive_matrix.json`; PixelLab source ID
`0a5d3c83-3592-430d-b733-82128c86aa5b`. Runtime screenshots for all five
targets are under `docs/design/previews/scrum1079_route_map_horizontal_runtime/`.
The production shell remains `assets/sprites/ui/meta40/frame_border.png`; the
PixelLab image is a textless layout reference, not a runtime texture replacement.

## SCRUM-563 Route Map 2K Source Package (historical)

SCRUM-563 adds the Route Map 2K UI Director source package. The approved
geometry and safe-zone plan lives in `docs/design/mockups/scrum563_route_map_2k/`,
the OpenAI Images API mockup is
`docs/design/references/scrum563_route_map_2k/route_map_2k_mockup.png`, and QA
previews are `docs/design/previews/scrum563_route_map_2k_plan_guide.png` plus
`docs/design/previews/scrum563_route_map_2k_mockup_safe_zones.png`.

The package documented the previous SCRUM-489 vertical runtime geometry and is
superseded for active geometry by SCRUM-1057/1079. Its frame-safety rule remains:
header
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
  route branching, Act 1 boss → Act 2 route transition и Act 2 boss → victory/
  secret-boss follow-up. `tests/two_act_run_progression_scrum1058_test.gd`
  дополнительно гейтит отсутствие третьей карты и неизменную длину каждого акта.
- `tests/scrum1079_route_map_horizontal_test.gd` гейтит five-target
  left-to-right geometry, non-overlapping Y branches, horizontal-only pan,
  line input transparency and initial gamepad focus.
