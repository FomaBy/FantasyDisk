# Agent Role Boundaries And Handoffs

Обновлено: 2026-06-14

Этот документ задает правило работы для всех специализированных чатов FantasyDisk:
`Design`, `Back-end`, `Animator`, `QA`.

Задачи формирует PM-чат/другая LLM по регламенту `docs/process/pm_workflow.md`.
Codex Documentation dispatcher может создавать новые задачи в active sprint
`0.1.5`, если они относятся к текущему patch scope, или как явно текущие bug/QA
defect/regression/release blocker задачи. Во время будущего freeze новые
не-баговые задачи снова уходят в backlog следующей версии. Статусы всех задач
отслеживаются на доске `docs/process/task_board.md`: при взятии задачи
исполнитель ставит в файле задачи `Статус: in_progress`, по завершении —
`done` (или `review`) с коротким резюме результата. Закрытие задачи —
ответственность исполнителя/ревьюера: dispatcher не ставит `done` за агента, а
только синхронизирует уже записанный результат или QA-вердикт.

Все задачи также синхронизируются с Jira проектом `SCRUM` по
`docs/process/jira_sync.md`. Любой агент, меняющий task status или создающий
handoff/bug/QA task, обязан проверить наличие `Jira: SCRUM-*`, обновить Jira
status/comment или явно передать это dispatcher/PM. Jira API token нельзя
записывать в репозиторий или task-файлы.

## Живая Синхронизация Jira (директива пользователя 2026-06-13)

Пользователь управляет разработкой по Jira — она ОБЯЗАНА всегда отражать
реальность. На каждом шаге работы агент держит Jira синхронной:
- взял задачу → `in_progress` + `python3 tools/jira_board_sync.py`;
- завершил → `done` + sync (тикет «Контроль качества» → после QA PASSED «Готово»);
- **передаёшь основную работу другому агенту** → создаёшь handoff-`.md` (его тикет
  синк создаст автоматически с нужным эпиком/ролью) И комментарием в ИСХОДНОМ
  Jira-тикете отмечаешь, кому и что передано (ключ handoff'а), чтобы цепочка
  передачи была видна в Jira;
- заблокировал/дубль/superseded → отрази статусом и комментарием в Jira.
Правило: «не закрыл/не передал в Jira — работа не считается сделанной».

## Главное Правило

Каждый агент делает только свою часть работы. Если для завершения задачи нужен кусок работы другого специалиста, агент не должен сам делать чужую часть "как получится". Он должен:

1. Выполнить свою часть.
2. Создать или обновить `.md` задачу в `docs/tasks/`.
3. Четко описать, что нужно другому специалисту.
4. Передать задачу в нужный чат.
5. В своей финалке указать, что передано и куда.

Пользователь заранее одобрил in-scope изменения, поэтому агенты не спрашивают разрешение на работу. Но cross-discipline работу нужно передавать правильному агенту.

## Design

ПРАВИЛО «UI не наползает» (пользователь, 2026-06-12): любой UI/HUD-лейаут
проектируется так, чтобы элементы не пересекались ни на одном поддерживаемом
разрешении (включая узкие 1152x648 и широкие-низкие окна). Это требование
acceptance для Design И Back-end UI-работ; QA проверяет фактические rect'ы
и заваливает задачу при пересечении.

ПРАВИЛО «контент только в пустой зоне фрейма» (пользователь, 2026-06-14):
нельзя накладывать элементы интерфейса на декоративную рамку фрейма ни при
каких обстоятельствах. Кнопки, герои/портреты, области выбора, иконки, текст,
карточки, радары, миниатюры и любые интерактивные или информационные элементы
размещаются только во внутренней пустой зоне фрейма: прозрачном центре, плоской
внутренней подложке или явно заданной safe-area. Декоративные борта, углы,
самоцветы, шипы, печати, гребни, металл и орнамент должны оставаться полностью
видимыми и не перекрытыми. Design обязан задавать content-zone/margins для
каждого UI frame; Back-end обязан соблюдать их в layout; QA обязан завалить
задачу при любом наложении контента на рамку, даже если no-overlap между
отдельными плашками прошёл.

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
- применение skill `~/.codex/skills/fantasydisk-animation-director/` для всех
  задач по персонажам, монстрам, элиткам и боссам: минимум `move/walk` 5+ кадров
  и `attack_primary` 5+ кадров; для элиток/боссов — full-frame sprite-sheet без
  production cutout-разрезания статичного спрайта и отдельные attack-паттерны
  под разные skill/phase.

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

## QA

QA отвечает за:

- приемочное ревью задач после реализации;
- проверку acceptance criteria из task-файлов;
- проверку smoke/regression результатов, логов и артефактов;
- поиск регрессий в бою, карте, меню, UI, анимациях, арте и балансе;
- фиксацию найденных багов отдельными `backend_`, `design_` или `animation_`
  handoff-задачами;
- подтверждение, что документация и CHANGELOG обновлены для выполненной работы.

QA не должен самостоятельно делать:

- gameplay/code implementation;
- перерисовку ассетов;
- animation/rig правки;
- баланс-изменения;
- коммиты релизов или merge/tag операции.

Парные qa_review-задачи НЕ создаются (упразднено PM 2026-06-12): каждая задача
после `done` автоматически тестируется QA-воркером по `docs/process/qa_protocol.md`.
Исключение — повторная проверка после вердикта FAILED: на нее заводится отдельная
qa_review-задача (QA-воркер не перепроверяет файлы с уже выданным вердиктом).

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
- `qa`

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
- `QA` для приемочного ревью и регрессий; если отдельного QA-чата нет, задача
  фиксируется на доске для Claude-QA board worker.

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
- QA: результат проверки в task-файле, найденные дефекты отдельными handoff
  задачами; продуктовую документацию QA не переписывает вместо владельца.

Если документация еще не разбита по доменам, обновить существующие документы и отметить, что после batch changes нужно выполнить `docs/tasks/documentation_post_changes_domain_split_task.md`.
