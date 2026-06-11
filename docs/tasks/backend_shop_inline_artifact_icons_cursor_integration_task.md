# Задача Для Back-end-Агента: Интегрировать Иконки Артефактов В Магазин И Добавить Игровой Курсор

Дата: 2026-06-11

Статус: done

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках этой задачи. Не спрашивай подтверждение: интегрируй ассеты, перестрой магазин, добавь курсор, обнови тесты и документацию. Спрашивать нужно только при реальном блокере, обязательной sandbox/security эскалации или потенциально разрушительном действии вне scope.

## Контекст

Магазин должен показывать артефакты не в отдельном окне, а прямо на экране магазина. В центре магазинного фона есть свободное место: там нужно разместить артефакты и их цену. Описание предмета должно показываться только при наведении мыши.

Также нужно добавить уникальный игровой курсор, чтобы его было видно во время игры и он был в стиле FantasyDisk.

Design dependency:

```text
docs/tasks/design_artifact_icons_shop_cursor_task.md
```

## Главная Цель

После задачи:

- все artifact/shop items в магазине имеют иконки;
- магазин показывает предметы прямо поверх shop background;
- нет отдельного тяжелого shop window/card modal, который закрывает фон;
- у предметов видна цена;
- описание показывается только hover tooltip;
- купленные/недоступные предметы имеют понятное состояние;
- в игре используется уникальный курсор.

## Обязательные Документы Перед Работой

Перед началом прочитать:

- `AGENTS.md`;
- `docs/process/agent_role_boundaries_and_handoffs.md`;
- `docs/design/content_registry.md`;
- `docs/design/current_game_state.md`;
- `docs/design/mechanics_extract.md`;
- `docs/tasks/design_artifact_icons_shop_cursor_task.md`;
- `docs/tasks/design_event_shop_campfire_backgrounds_style_unification_task.md`.

## Shop UI Requirements

Перестроить магазин:

- предметы располагаются в центральной свободной области магазинного фона;
- каждый предмет показывает:
  - иконку;
  - цену;
  - purchased/unavailable state, если применимо;
- описание не показывается постоянно;
- описание появляется только при hover;
- tooltip должен быть читаемым и не выходить за экран;
- магазин должен работать на `1600x900` и `2560x1440`;
- layout не должен перекрывать HUD HP/XP/money, если он виден на shop screen.

Можно показывать короткое название предмета только если это не перегружает экран. Главный user request: иконка + цена, описание только hover.

## Remove Separate Shop Window Feeling

Убрать ощущение отдельного окна:

- не использовать большую default panel поверх всего магазина;
- не закрывать фон магазина;
- shop item slots должны быть частью scene composition;
- кнопка выхода из магазина может оставаться как аккуратная UI-кнопка;
- если нужен container, он должен быть визуально прозрачным/встроенным, а не отдельным modal.

## Artifact Icon Mapping

Создать централизованный icon mapping:

```gdscript
artifact_id -> Texture2D
shop_item_id -> Texture2D
```

Не размазывать пути по UI code. Использовать helper/cache/preload/scene references.

Если Design assets еще не готовы:

- подготовить mapping structure;
- использовать temporary fallback only for development;
- создать/обновить handoff для Design с недостающими IDs;
- не сдавать финальную задачу с default placeholders, если можно дождаться assets.

## Hover Tooltip

Tooltip должен показывать:

- название;
- описание;
- эффект;
- цену, если нужно;
- class restriction, если есть;
- purchased/unavailable reason, если применимо.

Tooltip появляется только при наведении мыши на предмет.

Tooltip исчезает, когда mouse leaves item.

## Cursor Integration

Добавить уникальный курсор игры:

- использовать asset `ui_game_cursor` от Design;
- настроить hotspot;
- курсор должен быть видим в бою, меню, магазине, карте;
- не должен быть слишком большим;
- если есть hover/attack variants, переключать их аккуратно;
- если variants нет, использовать один универсальный cursor.

Проверить Godot API для custom mouse cursor и использовать правильный способ для Godot 4.

## Files To Check

Обязательно проверить:

- `scripts/main.gd`;
- shop screen creation/rendering code;
- `scripts/progression_data.gd`;
- `scripts/player.gd`, если покупка влияет на деньги/артефакты;
- `scenes/Main.tscn`;
- UI asset loading/cache;
- `tests/runtime_smoke_test.gd`.

Если есть отдельные UI scenes/scripts для shop/cursor, обновить их.

## Acceptance Criteria

Задача готова, если:

- магазин показывает item/artifact icons прямо на shop background;
- магазин больше не выглядит как отдельное большое окно поверх фона;
- у каждого shop offer есть иконка и цена;
- описание предмета показывается только при hover;
- покупка предмета работает;
- purchased/unavailable state понятен;
- layout читается на `1600x900` и `2560x1440`;
- уникальный курсор используется в игре;
- курсор хорошо виден во время боя и в меню;
- runtime smoke test обновлен и проходит;
- документация обновлена.

## Проверка

Запустить:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Ручная проверка:

- открыть магазин;
- проверить размещение предметов на фоне;
- навести на каждый предмет;
- убедиться, что описание появляется только hover;
- купить предмет;
- проверить деньги;
- проверить purchased state;
- проверить cursor в бою;
- проверить cursor на route map;
- проверить cursor в магазине;
- проверить `1600x900`;
- проверить `2560x1440`.

## Документация

После реализации обновить:

- `docs/design/current_game_state.md`;
- `docs/design/content_registry.md`;
- `docs/design/fantasydisk_design_brief.md`;
- после domain split: `docs/design/systems/menus_ui.md` и `docs/design/systems/technical_architecture.md`.

Не оставлять shop/cursor изменения только в коде.

## Result 2026-06-11

Back-end integration complete:
- `scripts/ui_screens.gd` renders shop offers inline on `screen_shop_background.png` instead of a large modal window.
- Each offer shows icon + price only; title/description/effect/class restriction/purchased/unavailable reason are in hover tooltip.
- Shop item icon resolution is centralized through real `artifact_<artifact_id>.png` / `shop_<shop_item_id>.png` mapping with effect-based fallback through `scripts/ui_icon_registry.gd` only as fail-safe.
- Shop slot, hover, price badge and purchased/unavailable overlay use Design PNG paths with safe StyleBoxFlat fallback only if an asset is temporarily missing.
- `scripts/main.gd` / `scripts/ui_screens.gd` apply custom mouse cursor via Godot 4 `Input.set_custom_mouse_cursor` with hotspot `(5, 4)`.
- `tests/runtime_smoke_test.gd` covers inline shop layout, dedicated artifact/shop asset completeness, dedicated shop icon usage, Design StyleBoxTexture frames, icon/price/tooltip, purchased state and existing shop purchase flow.

Verification:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Result: passed.

Design dependency resolved:
- The current checkout now contains the actual PNG files under `assets/sprites/ui/icons/artifacts/`, `assets/sprites/ui/icons/shop/`, `assets/sprites/ui/shop/` and `assets/sprites/ui/cursor/`.
- Godot `.import` files exist for all artifact icons, shop-only icons, shop UI PNGs and cursor variants.
- Back-end hooks should now load the real Design PNGs; fallback remains only a fail-safe.

## Design Assets Ready / Handoff 2026-06-11

Design подготовил полный artifact/shop/cursor visual kit.

Каноническая спецификация и полный mapping:

```text
docs/design/artifact_shop_cursor_visual_kit.md
```

Generator / source of deterministic assets:

```text
tools/generate_artifact_shop_cursor_assets.py
```

Asset folders:

| Group | Path / pattern | Count / size |
| --- | --- | --- |
| Artifact icons | `assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png` | `46`, `128x128` |
| Shop-only icons | `assets/sprites/ui/icons/shop/shop_<shop_item_id>.png` | `7`, `128x128` |
| Shop UI frames | `assets/sprites/ui/shop/` | slot/hover/price/overlay/tooltip |
| Cursor variants | `assets/sprites/ui/cursor/` | `48x48` |
| Preview | `assets/sprites/ui/icons/artifact_shop_cursor_preview.png` | design reference |

Shop UI assets:

| Asset ID | File | Use |
| --- | --- | --- |
| `ui_shop_artifact_slot_frame` | `assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png` | normal item slot |
| `ui_shop_artifact_slot_hover` | `assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png` | hover/clickable state |
| `ui_shop_price_badge` | `assets/sprites/ui/shop/ui_shop_price_badge.png` | price badge |
| `ui_shop_purchased_overlay` | `assets/sprites/ui/shop/ui_shop_purchased_overlay.png` | purchased/unavailable overlay |
| `ui_shop_tooltip_frame` | `assets/sprites/ui/shop/ui_shop_tooltip_frame.png` | hover tooltip frame |

Cursor assets:

| Asset ID | File | Hotspot |
| --- | --- | --- |
| `ui_game_cursor` | `assets/sprites/ui/cursor/game_cursor.png` | `(5, 4)` |
| `ui_game_cursor_hover` | `assets/sprites/ui/cursor/game_cursor_hover.png` | `(5, 4)` |
| `ui_game_cursor_attack` | `assets/sprites/ui/cursor/game_cursor_attack.png` | `(5, 4)` |

Recommended shop layout:

- place 4 offers inline in the central free counter area of `screen_shop_background.png`;
- use a `2x2` grid or gentle horizontal arc, not a large modal panel;
- `1600x900`: slot visual size `118-136`, icon `76-88`, price badge `92-112` wide;
- `2560x1440`: slot visual size `150-176`, max offer group width around `960-1100`;
- show item description/effects only through hover tooltip;
- keep HP/XP/money HUD visible where current UI requires it.

Important naming note:

Shop item filenames intentionally follow the requested scheme `shop_<shop_item_id>.png`, so `shop_damage` maps to:

```text
assets/sprites/ui/icons/shop/shop_shop_damage.png
```

Back-end should create one centralized mapping/cache for artifact and shop item icon textures and avoid loading the same textures repeatedly.
