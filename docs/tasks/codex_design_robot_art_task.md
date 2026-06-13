# Codex Design Task: Robot Character And Weapon Art

Статус: review
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end handoff для `backend_add_character_robot_task.md`
Jira: SCRUM-166

## Цель

Создать canonical D&D/dark-fantasy art для нового класса `robot` и трех его оружий.
Back-end уже подключает documented fallbacks; после готовности ассеты должны лечь по
стабильным путям ниже без изменения gameplay IDs.

## Required Assets

- `assets/sprites/characters/robot.png` — 512x512 RGBA, прозрачный фон, нейтральная стойка с разделенными ногами.
- `assets/sprites/weapons/robot_magnetic_anchor.png` — 256x256 RGBA.
- `assets/sprites/weapons/robot_hydraulic_press.png` — 256x256 RGBA.
- `assets/sprites/weapons/robot_reactor_core.png` — 256x256 RGBA.

## Gameplay Identity

- `robot` — тяжелый tank-класс, пара Рыцаря, но не medieval shield/counter.
- `robot_magnetic_anchor`: магнитный якорь, который стягивает врагов и бьет импульсом.
- `robot_hydraulic_press`: гидравлический пресс/зажим, который визуально читает сжатие линии.
- `robot_reactor_core`: реакторный модуль, который выпускает короткие направленные выбросы вокруг корпуса.

## Style Direction

- D&D-canonical FantasyDisk style from `docs/design/visual_style_assets.md`.
- Нужен не sci-fi chrome, а fantasy construct: латунь/вороненая сталь/рунические катушки/магнитные кристаллы.
- Силуэт должен читаться сверху в 2D top-down: массивный корпус, тяжелые плечи, видимый реакторный центр.
- Подготовить референсы перед image generation/review; не уходить во flat/vector/grimdark.

## Acceptance

- PNG существуют по required paths и импортированы Godot.
- Персонаж и оружие читаются в hero select, бою и кодексе.
- Обновить `docs/design/content_registry.md` / visual docs при handoff completion.

## Result

2026-06-13: Design art kit generated and imported for review.

- Added canonical character sprite: `assets/sprites/characters/robot.png` (`512x512`, RGBA, transparent).
- Added canonical weapon sprites:
  - `assets/sprites/weapons/robot_magnetic_anchor.png` (`256x256`, RGBA, transparent).
  - `assets/sprites/weapons/robot_hydraulic_press.png` (`256x256`, RGBA, transparent).
  - `assets/sprites/weapons/robot_reactor_core.png` (`256x256`, RGBA, transparent).
- Added QA/contact preview: `docs/design/previews/robot_art_contact.png`.
- Art direction: D&D/tabletop FantasyDisk heavy fantasy construct, blackened steel, aged brass, rune coils, teal reactor core; distinct from Knight and not sci-fi chrome.
- Validation: Godot headless import completed successfully; all four gameplay PNGs have expected size, RGBA alpha, transparent background, non-empty alpha bbox, and generated `.import` files.
- Runtime smoke: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` passed.
- Scope note: Design did not change Back-end gameplay/balance or implement rig/motion. `docs/tasks/animation_robot_rig_motion_task.md` is now ready for Animator handoff.
