# Задача Для Design-Агента: Иконки Всех Артефактов И Уникальный Игровой Курсор

Дата: 2026-06-11

Статус: done

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках этой задачи. Не спрашивай подтверждение: нарисуй ассеты, обнови registry/docs и передай handoff Back-end. Спрашивать нужно только при реальном блокере, обязательной sandbox/security эскалации или потенциально разрушительном действии вне scope.

## Контекст

Нужно сделать магазин красивее и понятнее: все возможные артефакты должны иметь собственные иконки, а магазин должен показывать артефакты прямо на экране поверх магазинного фона, не в отдельном окне. Также нужен уникальный курсор игры, который хорошо виден во время боя и соответствует стилю FantasyDisk.

Back-end integration task:

```text
docs/tasks/backend_shop_inline_artifact_icons_cursor_integration_task.md
```

## Главная Цель

Подготовить UI/asset pack:

- иконки для всех артефактов;
- иконки для shop-only предметов, если они используются в магазине;
- визуальные элементы/рамки для shop item slots;
- hover tooltip style, если нужен отдельный visual asset;
- уникальный cursor sprite в стиле игры.

## Обязательные Документы Перед Работой

Перед началом прочитать:

- `AGENTS.md`
- `docs/process/agent_role_boundaries_and_handoffs.md`
- `docs/design/content_registry.md`
- `docs/design/current_game_state.md`
- `docs/design/fantasydisk_design_brief.md`
- `docs/tasks/design_event_shop_campfire_backgrounds_style_unification_task.md`

## Artifact Icons Scope

Нарисовать иконки для всех артефактов, перечисленных в:

- `docs/design/content_registry.md`, раздел `Артефакты`;
- `scripts/progression_data.gd`, `ARTIFACTS`;

Также нарисовать иконки для shop-only items из:

- `scripts/progression_data.gd`, `SHOP_ITEMS`;
- `docs/design/content_registry.md`, раздел `Магазинные Предметы`.

Если списки расходятся, обновить `content_registry.md` и указать это в handoff для Back-end.

## Требования К Иконкам Артефактов

Каждый artifact/shop item должен иметь уникальную иконку:

- не использовать одну и ту же иконку с перекраской для разных предметов;
- иконка должна отражать эффект или фантазию предмета;
- стиль: stylized fantasy cartoon, как текущие персонажи/монстры;
- читаемость в маленьком размере;
- прозрачный фон;
- без текста внутри иконки;
- без emoji/default placeholders;
- без copyrighted assets.

Рекомендуемый размер:

- source: `128x128` PNG;
- можно экспортировать `64x64`, если backend попросит, но source quality должен быть выше.

## Имена Файлов

Использовать stable IDs:

```text
assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png
assets/sprites/ui/icons/shop/shop_<shop_item_id>.png
```

Примеры:

```text
artifact_warrior_charm.png
artifact_void_ink.png
artifact_greedy_purse.png
shop_shop_damage.png
shop_shop_heal.png
```

Если имя выглядит странно из-за `shop_shop_*`, можно предложить аккуратную схему, но Back-end должен получить точный mapping.

## Shop Slot Visuals

Подготовить визуальные элементы для размещения артефактов прямо на shop background:

- рамка слота предмета;
- hover/selected state;
- price badge/frame;
- unavailable/purchased state;
- tooltip frame, если текущий tooltip не подходит.

Важно: магазин не должен выглядеть как отдельное default окно. Артефакты должны располагаться на самом магазинном экране, в центральной свободной области фона.

Asset IDs:

| ID | Назначение |
| --- | --- |
| `ui_shop_artifact_slot_frame` | Рамка предмета |
| `ui_shop_artifact_slot_hover` | Hover state |
| `ui_shop_price_badge` | Рамка цены |
| `ui_shop_purchased_overlay` | Состояние куплено/недоступно |
| `ui_shop_tooltip_frame` | Tooltip описания |

## Уникальный Курсор

Нарисовать игровой курсор:

Asset ID:

```text
ui_game_cursor
```

Файл:

```text
assets/sprites/ui/cursor/game_cursor.png
```

Требования:

- хорошо виден во время боя;
- не сливается с фонами, монстрами, projectiles и UI;
- в стиле FantasyDisk;
- не слишком большой;
- pointer должен иметь понятную hot spot точку;
- желательно сделать hover/attack вариант, если это не сильно увеличивает scope.

Рекомендуемые размеры:

- `32x32` или `48x48` PNG;
- прозрачный фон;
- четкий контур/outline.

Дополнительные варианты, если есть время:

```text
assets/sprites/ui/cursor/game_cursor_hover.png
assets/sprites/ui/cursor/game_cursor_attack.png
```

## Handoff Для Back-end

Передать Back-end:

- полный mapping `artifact_id -> icon_path`;
- mapping `shop_item_id -> icon_path`;
- путь к cursor asset;
- hot spot координаты курсора;
- размеры иконок;
- рекомендуемый layout для центральной зоны магазина;
- какие assets использовать для slot/hover/price/tooltip.

## Acceptance Criteria

Задача готова, если:

- у каждого artifact из `ARTIFACTS` есть уникальная иконка;
- у каждого shop-only item из `SHOP_ITEMS` есть иконка;
- иконки выглядят в стиле FantasyDisk;
- иконки читаются в магазине;
- подготовлены shop slot/price/hover visual assets или четкое style описание;
- нарисован уникальный игровой курсор;
- курсор хорошо виден на игровых фонах;
- `content_registry.md` обновлен;
- Back-end получил понятный handoff.

## Документация

После реализации обновить:

- `docs/design/content_registry.md`;
- `docs/design/current_game_state.md`;
- `docs/design/fantasydisk_design_brief.md`;
- после domain split: `docs/design/systems/menus_ui.md` и `docs/design/systems/visual_style_assets.md`.

Не оставлять новые assets без registry и handoff.

## Design Deliverables / Готово 2026-06-11

Подготовлен полный visual kit для artifact/shop/cursor:

- `46` unique artifact icons для всех `ProgressionData.ARTIFACTS`;
- `7` unique shop-only icons для всех `ProgressionData.SHOP_ITEMS`;
- shop slot frame, hover frame, price badge, purchased/unavailable overlay и tooltip frame;
- custom game cursor, hover cursor и attack cursor;
- preview sheet для визуального QA.

Generator:

```text
tools/generate_artifact_shop_cursor_assets.py
```

Каноническая спецификация и полный mapping:

```text
docs/design/artifact_shop_cursor_visual_kit.md
```

Основные папки:

```text
assets/sprites/ui/icons/artifacts/
assets/sprites/ui/icons/shop/
assets/sprites/ui/shop/
assets/sprites/ui/cursor/
```

Preview:

```text
assets/sprites/ui/icons/artifact_shop_cursor_preview.png
```

Документация обновлена:

- `docs/design/content_registry.md`;
- `docs/design/current_game_state.md`;
- `docs/design/fantasydisk_design_brief.md`;
- `docs/design/systems/menus_ui.md`;
- `docs/design/systems/visual_style_assets.md`.

## Back-end Handoff / 2026-06-11

Back-end должен интегрировать ассеты через:

```text
docs/tasks/backend_shop_inline_artifact_icons_cursor_integration_task.md
```

Что подключить:

- artifact icons: `assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png`;
- shop-only icons: `assets/sprites/ui/icons/shop/shop_<shop_item_id>.png`;
- slot frame: `assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png`;
- hover frame: `assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png`;
- price badge: `assets/sprites/ui/shop/ui_shop_price_badge.png`;
- purchased/unavailable overlay: `assets/sprites/ui/shop/ui_shop_purchased_overlay.png`;
- tooltip frame: `assets/sprites/ui/shop/ui_shop_tooltip_frame.png`;
- cursor: `assets/sprites/ui/cursor/game_cursor.png`;
- cursor hover: `assets/sprites/ui/cursor/game_cursor_hover.png`;
- cursor attack: `assets/sprites/ui/cursor/game_cursor_attack.png`.

Cursor hotspot for all variants: `(5, 4)`.

Shop item filenames intentionally follow `shop_<shop_item_id>.png`, so `shop_damage` maps to `assets/sprites/ui/icons/shop/shop_shop_damage.png`.

## Back-end Audit Follow-up Resolved 2026-06-11

Back-end integration was already complete, but its audit originally saw missing Design PNG files. This follow-up is resolved:

- `46/46` artifact icons exist and have `.import` files;
- `7/7` shop-only icons exist and have `.import` files;
- `5/5` shop UI PNG assets exist and have `.import` files;
- `3/3` cursor PNG assets exist and have `.import` files;
- `docs/design/content_registry.md` statuses are updated to `Реализовано`.

Back-end can now load the real PNG assets through the stable paths above. Fallback remains only a fail-safe.

## User Feedback Rework / 2026-06-11

Пользователь отметил, что первая версия artifact icons, cursor и shop framing выглядит слишком простой и недостаточно fantasy. Design rework выполнен:

- artifact/shop icons перерисованы из flat symbolic look в richer FantasyDisk fantasy-medallion style;
- добавлены орнаментальные золотые рамки, темный металлический силуэт, gem anchors, рунические искры, glow, painted grain и более высокий контраст материалов;
- shop slot/hover/price/tooltip assets перерисованы с более выраженными fantasy-metal bevels, corner brackets, gems и glow;
- cursor variants перерисованы в fantasy dagger/quill pointer style с gem detail и state accents;
- `tools/generate_artifact_shop_cursor_assets.py` обновлен, все PNG перегенерированы и импортированы в Godot.

Preview после rework:

```text
assets/sprites/ui/icons/artifact_shop_cursor_preview.png
```
