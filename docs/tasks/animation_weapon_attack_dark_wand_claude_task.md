# Animation: Темная палочка (dark_wand) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Claude
Контур: Claude
Owner: claude-animator
Thread: n/a
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-739
Locked paths: assets/sprites/effects/vfx_weapon_dark_wand.png, docs/design/references/weapon_attack_animations/dark_wand/, docs/design/previews/weapon_attack_animations/dark_wand_contact.png, scenes/DarkWand.tscn, assets/sprites/weapons/dark_wand.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `dark_wand` / **Темная палочка** класса **Темный маг**.
Текущая механическая роль: Два pierce-луча веером.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/dark_wand/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_dark_wand.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `dark_wand` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Темная палочка**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Два pierce-луча веером. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `dark_wand` использовать reference `assets/sprites/weapons/dark_wand.png` и текущую сцену `scenes/DarkWand.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [ ] `assets/sprites/effects/vfx_weapon_dark_wand.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [ ] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [ ] Attack VFX уникально отражает **Темная палочка**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [ ] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [ ] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `dark_wand` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## QA-Вердикт

Статус: PASSED

QA claude-qa 2026-07-01. Проверено на HEAD origin/dev (commit 735838d0 влит в dev; `git merge-base --is-ancestor 735838d0 origin/dev` = OK).

- `assets/sprites/effects/vfx_weapon_dark_wand.png`: 256x256, углы прозрачны, 85.5% полностью прозрачно, видимое покрытие 12.9%, median saturation 65 (не запечённый neutral фон) → полупрозрачный эффект, HUD/world не перекрывает.
- Визуал: два прямых пронзающих луча веером (shallow V, «<»-форма), cyan-white ядро + violet glow, arrowhead pierce-tips + after-streak, cyan origin-flash + ghost палочки с кристаллом. Уникально читается как Тёмная палочка, зона «два pierce-луча» видна, alpha/readability ок на тёмном и светлом фоне.
- Тесты через `tools/godot_gate.py` (семафор, live-editor рядом): `runtime_smoke_test.gd` PASS, `unique_weapon_vfx_assets_test.gd` PASS (51 plates), `attack_vfx_smoke_test.gd` PASS.
- Геймплейные параметры/shared runtime не изменены.

Тикет повторно принят после board_sync-реверта (в .md не было QA-блока) — блок добавлен, чтобы синк не откатывал в «Контроль качества».
