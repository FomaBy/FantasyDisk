# Animation: Ядро Метеора (elementalist_meteor_core) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Codex Animator/VFX
Thread: codex-vfx-auto-2-20260701
Версия: 0.1.8
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-741
Locked paths: assets/sprites/effects/vfx_weapon_elementalist_meteor_core.png, docs/design/references/weapon_attack_animations/elementalist_meteor_core/, docs/design/previews/weapon_attack_animations/elementalist_meteor_core_contact.png, scenes/ElementalistMeteorCore.tscn, assets/sprites/weapons/elementalist_meteor_core.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `elementalist_meteor_core` / **Ядро Метеора** класса **Элементалист**.
Текущая механическая роль: Meteor shards: delayed impact в цель и вторичные осколочные взрывы рядом.

## Обязательный пайплайн генерации

Active directive 2026-07-01 supersedes the older OpenAI mirror text below:
this task is generated with PixelLab MCP via `fantasydisk-asset-generator`; no
OpenAI Images, `image_gen`, manual drawing, gameplay/balance/shared runtime
logic changes, or multi-weapon regeneration are allowed.

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/elementalist_meteor_core/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_elementalist_meteor_core.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `elementalist_meteor_core` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Ядро Метеора**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Meteor shards: delayed impact в цель и вторичные осколочные взрывы рядом. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `elementalist_meteor_core` использовать reference `assets/sprites/weapons/elementalist_meteor_core.png` и текущую сцену `scenes/ElementalistMeteorCore.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_elementalist_meteor_core.png` обновлен с новым PixelLab source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Ядро Метеора**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [x] Static PNG/manifest validation passed; `unique_weapon_vfx_assets_test.gd` and `attack_vfx_smoke_test.gd` were attempted through `tools/godot_gate.py` but blocked by Godot import-cache SIGTERM in this disposable worktree before the test bodies ran.
- [x] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `elementalist_meteor_core` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Результат 2026-07-01

- PixelLab-only override выполнен: старый OpenAI mirror text superseded активной директивой 2026-07-01.
- PixelLab source: 1-direction object `65fde13a-773c-421e-a7e5-06f4b2606001`; accepted source PNG сохранен как `docs/design/references/weapon_attack_animations/elementalist_meteor_core/pixellab_object_65fde13a_source.png`. Alternate PixelLab map-object attempt `fcffda75-dde7-4d59-907e-9744ae2bbec1` is retained as source evidence only.
- Runtime: заменен только `assets/sprites/effects/vfx_weapon_elementalist_meteor_core.png` (`256x256`, RGBA, alpha `0..165`).
- Evidence: `docs/design/references/weapon_attack_animations/elementalist_meteor_core/manifest.json`, `prompt_notes.md`, runtime candidate, alpha debug and `docs/design/previews/weapon_attack_animations/elementalist_meteor_core_contact.png`.
- QA report: `build/qa/scrum741_meteor_core/alpha_readability_report.json`.
- Visual result: calm meteor impact ring with secondary shard-burst markers and a faint ghost silhouette from `assets/sprites/weapons/elementalist_meteor_core.png`.
- Runtime/gameplay: no scene, damage, cooldown, targeting, radius, delay, balance, shared script, or runtime API changes.
- Tests:
  - PASS: static PNG/manifest validation (`runtime 256x256 RGBA`, alpha `0..165`, JSON manifests parse).
  - BLOCKED: `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd` did not reach the test body; the pre-test Godot import step repeatedly exited `143` after pre-existing UID duplicate warnings in unrelated skeleton reference assets.
  - BLOCKED: `python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd` hit the same import-cache failure before the test body.
  - Direct Godot script attempt confirmed the focused test cannot compile without `.godot/imported/*.ctex`; failures were missing imported resources such as `slash_arc.png.ctex`, not the SCRUM-741 PNG.
- Disk cleanup: `.godot/` and generated untracked `.uid` sidecars removed after test attempts; no disposable clone/worktree or task scratch cache left.
