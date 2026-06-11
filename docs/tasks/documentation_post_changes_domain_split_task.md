# Финальная Задача: Обновить И Разбить Документацию По Областям Игры

Дата: 2026-06-10

Статус: done 2026-06-11. Результат: создана доменная структура `docs/design/systems/` с файлами `combat.md`, `route_map.md`, `menus_ui.md`, `characters_weapons.md`, `enemies_bosses.md`, `progression_balance.md`, `visual_style_assets.md`, `animation.md`, `technical_architecture.md`; overview-документы `fantasydisk_design_brief.md`, `current_game_state.md`, `mechanics_extract.md` получили ссылки на domain docs. Task board синхронизирован с фактическими done backend-задачами. Дополнительно обновлен устаревший `tests/melee_weapon_targeting_test.gd` под новую sword strip identity. Проверки: runtime, animation, attack VFX, meta progression и melee targeting smoke tests проходят.

## Autonomy / Approval

Пользователь заранее одобрил все изменения в рамках этой задачи. Не спрашивай подтверждение: обнови документацию, разнеси ее по областям игры, проверь ссылки и зафиксируй актуальное состояние проекта. Спрашивать нужно только при реальном блокере, обязательной sandbox/security эскалации или потенциально разрушительном действии вне scope.

## Контекст

После серии изменений от `Back-end`, `Design` и `Animator` документация должна быть полностью обновлена. Сейчас часть информации находится в больших общих файлах, и со временем это станет неудобно для агентов и разработчиков.

Нужно не только обновить существующие документы, но и разбить документацию по областям игры:

- бой;
- карта маршрута;
- меню и UI;
- персонажи и оружие;
- враги, элитки и боссы;
- прогрессия, характеристики и баланс;
- визуальный стиль и ассеты;
- анимация;
- техническая архитектура и performance.

## Когда Выполнять

Выполнять после завершения активных задач:

- performance/code quality review;
- sprite quality audit;
- UI icons/HUD integration;
- route map fixes;
- Dark Mage/Guitarist rebalance;
- animation movement work;
- design redraw/style work;
- event/shop/campfire backgrounds.

Если какая-то из этих задач еще не завершена, можно подготовить структуру документации, но финальный фактический контент должен обновляться после merge/применения изменений.

## Главная Цель

Сделать документацию удобной для будущих агентов:

- каждый домен игры имеет свой `.md` файл;
- текущие большие документы становятся entry point / overview;
- все новые mechanics/features/assets отражены в документации;
- канонические ID и имена сущностей остаются в `content_registry.md`;
- устаревшие фичи не описываются как активные;
- ссылки между документами работают;
- будущий агент быстро понимает, какой файл читать перед задачей.

## Предлагаемая Структура

Создать папку:

```text
docs/design/systems/
```

И добавить/обновить файлы:

```text
docs/design/systems/combat.md
docs/design/systems/route_map.md
docs/design/systems/menus_ui.md
docs/design/systems/characters_weapons.md
docs/design/systems/enemies_bosses.md
docs/design/systems/progression_balance.md
docs/design/systems/visual_style_assets.md
docs/design/systems/animation.md
docs/design/systems/technical_architecture.md
```

Если при работе появится более удачная структура, можно адаптировать, но домены `бой`, `карта`, `меню/UI` обязательно должны быть отдельными файлами.

## Что Должно Быть В Документах

### `combat.md`

Описать:

- core combat loop;
- player movement;
- auto attacks;
- weapon timing;
- projectiles;
- AoE;
- damage windows;
- enemy spawn/waves;
- pause behavior during combat;
- cleanup of temporary effects;
- current combat balance notes.

### `route_map.md`

Описать:

- full-screen route map;
- node types;
- click/hover behavior;
- drag-scroll/pan;
- route branching;
- event/shop/rest/boss transitions;
- route map icons;
- current known UX rules.

### `menus_ui.md`

Описать:

- main menu;
- settings;
- character select;
- weapon select;
- HUD HP/XP/money;
- Escape stats menu;
- level-up UI;
- shop UI;
- event UI;
- campfire/rest UI;
- death/victory screens;
- UI icons usage.

### `characters_weapons.md`

Описать:

- Берсерк;
- Темный маг;
- Гитарист;
- все 9 оружий;
- роли, сильные/слабые стороны;
- текущие weapon configs;
- class-specific cleanup notes.

### `enemies_bosses.md`

Описать:

- все стандартные монстры;
- элитки;
- боссы;
- spawn roles;
- behavior patterns;
- balance notes;
- canonical names from `content_registry.md`.

### `progression_balance.md`

Описать:

- базовые характеристики;
- производные атрибуты;
- формулы;
- level-up rewards;
- artifacts;
- shop items;
- XP/money;
- meta progression / ascension status.

### `visual_style_assets.md`

Описать:

- текущий art direction;
- cartoon hero style;
- monsters/bosses style;
- UI style;
- screen backgrounds;
- sprite QA rules;
- asset folders;
- naming conventions.

### `animation.md`

Описать:

- текущую animation architecture;
- rig/cutout/sprite sheet approach;
- player movement states;
- enemy movement archetypes;
- pause behavior for animations;
- handoff rules between Design and Animator.

### `technical_architecture.md`

Описать:

- основные сцены и скрипты;
- lifecycle/run state;
- cleanup conventions;
- resource loading/preload rules;
- performance guardrails;
- smoke tests;
- documentation update rules.

## Обновить Существующие Документы

После создания domain docs обновить:

- `docs/design/fantasydisk_design_brief.md`
  - оставить как короткий overview и entry point;
  - добавить ссылки на domain docs.
- `docs/design/current_game_state.md`
  - оставить как snapshot текущей версии;
  - убрать чрезмерные детали, которые переехали в domain docs, или заменить ссылками.
- `docs/design/content_registry.md`
  - сохранить как канонический реестр ID/имен/ассетов.
- `docs/design/mechanics_extract.md`
  - сохранить таблицу и актуальный mechanics overlay;
  - ссылки на `progression_balance.md`.
- `docs/design/gdd_source.md`
  - оставить исходный GDD и актуальное дополнение;
  - добавить ссылки на domain docs, если нужно.

## Правила Переноса

- Не потерять информацию из текущих документов.
- Не дублировать огромные блоки без необходимости.
- Если информация нужна в нескольких местах, в одном месте она должна быть source of truth, в других - ссылка.
- Устаревшие фичи помечать как `отключено`, `устарело` или `планируется`, а не удалять бесследно, если они важны для истории решений.
- Ямы и колонны, если они уже убраны, не описывать как активную фичу.
- Все новые имена, ID и asset paths сверить с `content_registry.md`.

## Acceptance Criteria

Задача готова, если:

- создана доменная структура документации;
- есть отдельные документы минимум для боя, карты и меню/UI;
- все активные изменения последних задач отражены в документации;
- `fantasydisk_design_brief.md` стал понятным entry point;
- `current_game_state.md` не противоречит domain docs;
- `content_registry.md` содержит актуальные сущности и ассеты;
- нет описания удаленных/отключенных фич как активных;
- ссылки между документами актуальны;
- будущий агент понимает, какие документы читать для своей области.

## Проверка

Проверить:

```bash
rg -n "яма|колонн|pit|column|TODO|placeholder|устарело|отключено" docs/design
```

Проверить, что новые domain docs существуют:

```bash
find docs/design/systems -maxdepth 1 -type f
```

Проверить ссылки на новые документы из:

- `docs/design/fantasydisk_design_brief.md`
- `docs/design/current_game_state.md`
- `AGENTS.md`, если нужно.

## Handoff

После выполнения кратко написать:

- какие документы созданы;
- какие документы обновлены;
- какие фичи помечены отключенными/устаревшими;
- какие области документации еще требуют отдельного уточнения после будущих задач.
