# Agent Role Boundaries And Handoffs

Обновлено: 2026-06-11

Этот документ задает правило работы для всех специализированных чатов FantasyDisk: `Design`, `Back-end`, `Animator`.

Задачи формирует PM-чат по регламенту `docs/process/pm_workflow.md`. Статусы всех задач отслеживаются на доске `docs/process/task_board.md`: при взятии задачи исполнитель ставит в файле задачи `Статус: in_progress`, по завершении — `done` (или `review`) с коротким резюме результата.

## Главное Правило

Каждый агент делает только свою часть работы. Если для завершения задачи нужен кусок работы другого специалиста, агент не должен сам делать чужую часть "как получится". Он должен:

1. Выполнить свою часть.
2. Создать или обновить `.md` задачу в `docs/tasks/`.
3. Четко описать, что нужно другому специалисту.
4. Передать задачу в нужный чат.
5. В своей финалке указать, что передано и куда.

Пользователь заранее одобрил in-scope изменения, поэтому агенты не спрашивают разрешение на работу. Но cross-discipline работу нужно передавать правильному агенту.

## Design

Design отвечает за:

- арт-дирекшен;
- спрайты персонажей, монстров, элиток, боссов;
- иконки характеристик, предметов, узлов карты;
- UI visual style, panels, frames, buttons, backgrounds;
- event/shop/campfire backgrounds;
- route map visuals;
- projectiles/VFX visual assets;
- sprite quality audit;
- исправление visual artifacts: лишние куски текстуры, dirty pixels, halos, crop issues;
- content registry для asset paths и visual entities.

Design не должен самостоятельно делать:

- gameplay logic;
- баланс урона/HP/спавна;
- route map click/scroll logic;
- Godot backend systems;
- cleanup runtime objects;
- сложную animation state machine, если это не просто подготовка ассетов.

Если Design нужно подключить ассеты в игру, но требуется логика или сцены/скрипты:

- подготовить ассеты;
- описать file paths и asset IDs;
- создать handoff для `Back-end`.

Если Design видит, что спрайт нельзя красиво анимировать без другой нарезки/rig:

- подготовить части/референсы;
- создать handoff для `Animator`.

## Back-end

Back-end отвечает за:

- Godot/GDScript gameplay logic;
- route map, clicks, scroll/pan, node transitions;
- combat systems;
- balance numbers and formulas;
- characters/weapons/enemies/boss behavior;
- spawn/waves;
- pause/game state;
- UI integration;
- cleanup/lifecycle of nodes/effects;
- performance/code quality;
- tests;
- documentation updates for implemented systems.

Back-end не должен самостоятельно делать:

- финальный арт;
- перерисовку персонажей/монстров;
- полноценную animation polish/art motion design;
- visual style decisions beyond integration and layout;
- complex rig animation, если это не техническая интеграция готовых animation assets.

Если Back-end нужны новые картинки, иконки, фоны, VFX или исправление спрайта:

- создать handoff для `Design`;
- указать размеры, IDs, paths, где будут использоваться ассеты.

Если Back-end видит, что движение выглядит плохо и нужна animation work:

- создать handoff для `Animator`;
- указать сцены, персонажей, состояния, acceptance criteria.

## Animator

Animator отвечает за:

- движение персонажей и врагов;
- rig/cutout/skeleton/sprite sheet animation;
- AnimationPlayer/AnimationTree setup;
- animation states: idle, walk, attack, cast, hit, death;
- pivot points;
- плавность, направление взгляда, body lean, secondary motion;
- animation smoke tests;
- совместимость animation с pause/game state;
- handoff требований к ассетам, если текущие спрайты нельзя анимировать красиво.

Animator не должен самостоятельно делать:

- финальную перерисовку персонажей в новом стиле;
- баланс классов/урона/спавна;
- route map/gameplay systems;
- UI visual design;
- крупные backend refactors вне animation needs.

Если Animatorу нужны новые или перерисованные спрайты:

- создать handoff для `Design`;
- описать нужные poses, parts, directions, pivots, размеры и file naming.

Если Animatorу нужна поддержка кода, cleanup, pause integration или scene lifecycle:

- создать handoff для `Back-end`;
- описать, какая API/scene structure нужна.

## Handoff Формат

Любой cross-agent handoff должен быть `.md` файлом в `docs/tasks/`.

Название:

```text
docs/tasks/<role>_<short_task_name>.md
```

Где `<role>`:

- `design`
- `backend`
- `animation`

Минимальная структура:

```md
# Задача Для <Role>-Агента: <Название>

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи...

## Контекст

## Что Уже Сделано

## Что Нужно От Другого Агента

## Files / Assets / IDs

## Acceptance Criteria

## Документация
```

## Правило Передачи В Чат

После создания handoff-файла агент должен отправить задачу в соответствующий чат:

- `Design` для визуала и ассетов;
- `Back-end` для кода, логики, интеграции, тестов;
- `Animator` для движения и animation systems.

Сообщение в чат должно содержать:

- путь к `.md` файлу;
- короткое резюме;
- что уже готово;
- что требуется;
- зависимости;
- напоминание, что пользователь дал approval на in-scope изменения.

## Если Задача Смешанная

Если задача затрагивает несколько областей:

1. Главный агент делает свою часть.
2. Создает отдельные handoff tasks для остальных.
3. Не делает чужую работу "на глаз".
4. Документирует зависимости.
5. После получения результата другого агента интегрирует только свою часть, если это его зона ответственности.

## Когда Можно Коснуться Чужой Области

Допустимо минимально коснуться чужой области только если это нужно для связи:

- Back-end может подключить готовый asset в сцену.
- Animator может добавить технические animation nodes.
- Design может создать preview scene/reference layout без gameplay logic.

Но агент не должен принимать ключевые решения за другую роль.

## Документация

Каждый агент обновляет документы только в части своей работы:

- Design: `content_registry.md`, `visual_style_assets.md`, visual sections.
- Back-end: `current_game_state.md`, system docs, mechanics/balance docs, tests.
- Animator: `animation.md`, animation architecture, animation asset status.

Если документация еще не разбита по доменам, обновить существующие документы и отметить, что после batch changes нужно выполнить `docs/tasks/documentation_post_changes_domain_split_task.md`.
