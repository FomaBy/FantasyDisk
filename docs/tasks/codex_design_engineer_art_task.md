# Codex Design Task: Engineer Character And Weapon Art

Статус: done (Design review approved 2026-06-12)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end handoff для `backend_add_character_engineer_task.md`
Jira: SCRUM-164
Dispatcher: sent to Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` on 2026-06-13.

## Цель

Создать canonical D&D/dark-fantasy art для нового класса `engineer` и трех его оружий.
Back-end временно использует documented Druid/Raven/Hunter placeholder visuals; после готовности ассеты должны лечь по стабильным путям ниже без изменения gameplay IDs.

## Required Assets

- `assets/sprites/characters/engineer.png` — 512x512 RGBA, прозрачный фон, нейтральная стойка с разделенными ногами.
- `assets/sprites/weapons/engineer_sentry_wrench.png` — 256x256 RGBA.
- `assets/sprites/weapons/engineer_repair_drone.png` — 256x256 RGBA.
- `assets/sprites/weapons/engineer_pressure_mines.png` — 256x256 RGBA.

## Gameplay Identity

- `engineer` — summoner/support класс, пара Друида, но вместо зверей использует механические устройства.
- `engineer_sentry_wrench`: ключ/модуль часовой турели, которая сама выбирает цели и стреляет точечными лучами.
- `engineer_repair_drone`: ремонтный дрон, связывающий врагов дугой и возвращающий часть урона как ремонт.
- `engineer_pressure_mines`: набор мин/датчиков давления для веерной сетки контроля подходов.

## Style Direction

- D&D-canonical FantasyDisk style from `docs/design/visual_style_assets.md`.
- Нужен fantasy tinkerer/artificer, не sci-fi engineer: кожа, латунь, рунические инструменты, механические талисманы, маленькие заводные устройства.
- Силуэт должен читаться сверху в 2D top-down: ремни/инструменты/рюкзак мастерской, ноги разделены для будущего cutout rig.
- Подготовить референсы перед image generation/review; не уходить во flat/vector/grimdark.

## Acceptance

- PNG существуют по required paths и импортированы Godot.
- Персонаж и оружие читаются в hero select, бою и кодексе.
- Обновить `docs/design/content_registry.md` / visual docs при handoff completion.

## Result

2026-06-13: Design art kit generated and imported for review.

- Added canonical character sprite: `assets/sprites/characters/engineer.png` (`512x512`, RGBA, transparent).
- Added canonical weapon sprites:
  - `assets/sprites/weapons/engineer_sentry_wrench.png` (`256x256`, RGBA, transparent).
  - `assets/sprites/weapons/engineer_repair_drone.png` (`256x256`, RGBA, transparent).
  - `assets/sprites/weapons/engineer_pressure_mines.png` (`256x256`, RGBA, transparent).
- Added QA/contact preview: `docs/design/previews/engineer_art_contact.png`.
- Art direction: D&D/tabletop FantasyDisk artificer/tinkerer, leather, brass, rune tools, mechanical talismans and clockwork devices; distinct from Druid and not sci-fi engineer.
- Validation: Godot headless import completed successfully; all four gameplay PNGs have expected size, RGBA alpha, transparent background, non-empty alpha bbox, and generated `.import` files.
- Runtime smoke: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` completed with `Runtime smoke test passed`; log still reports missing `assets/sprites/characters/cutout/engineer_*.png` preload warnings/errors until Animator creates cutout parts.
- Scope note: Design did not change Back-end gameplay/balance or implement rig/motion. `docs/tasks/animation_engineer_rig_motion_task.md` is now ready for Animator handoff.


## Design Review / 2026-06-12 — ПРИНЯТО (Claude-Designer)
- SCRUM-164 Инженер: engineer 512 + sentry_wrench/repair_drone/pressure_mines 256.
  Стимпанк-артифайсер латунь+бирюза, когерентен ростеру, отдельный силуэт от Робота.
- Тех: 512/256 RGBA, bbox в рамке, alpha чистая, .import готов; cutout-нарезка готова.
- Арт-ассеты закоммичены Design-ревью (были untracked). Геймплейные .tscn — Back-end.

## QA-Вердикт (2026-06-13)
Статус: PASSED (SCRUM-164)
4 PNG: `engineer.png` 512² + 3 оружия 256² RGBA, preview на месте. Канон D&D:
стимпанк-артифисер (латунь/бронза/аркан-кристаллы, механический ключ/клокворк-дрон/
мины) — единый стиль с Роботом, не sci-fi. Прозрачный фон, без watermark. Багов нет.
