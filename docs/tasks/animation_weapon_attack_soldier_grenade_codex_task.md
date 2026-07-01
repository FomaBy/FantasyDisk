# Animation: Граната с фитилем (soldier_grenade) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/VFX Codex worker
Thread: disposable Codex worker worktree 816b (delegated from 019f1eac-35c3-7323-9067-8b7c2b88ab33)
Версия: 0.1.8
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-767
Locked paths: assets/sprites/effects/vfx_weapon_soldier_grenade.png, docs/design/references/weapon_attack_animations/soldier_grenade/, docs/design/previews/weapon_attack_animations/soldier_grenade_contact.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `soldier_grenade` / **Граната с фитилем** класса **Солдат**.
Текущая механическая роль: Delayed ground explosion: телеграф, короткий фитиль, falloff урона к краю.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/soldier_grenade/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_soldier_grenade.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `soldier_grenade` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Граната с фитилем**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Delayed ground explosion: телеграф, короткий фитиль, falloff урона к краю. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `soldier_grenade` использовать reference `assets/sprites/weapons/soldier_grenade.png` и текущую сцену `scenes/SoldierGrenade.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_soldier_grenade.png` обновлен с новым PixelLab source/evidence по dispatcher unblock 2026-07-01.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Граната с фитилем**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [x] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; animation/runtime hooks не менялись.
- [x] `docs/design/content_registry.md` / `docs/design/current_game_state.md` не обновлялись: runtime path/contract не менялись, evidence сохранён в task-specific paths.

## QA Notes

QA проверяет именно `soldier_grenade` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Результат — Codex worker 816b (2026-07-01)

- Pipeline: PixelLab MCP `create_map_object` -> flat background alpha removal -> calm alpha clamp -> canonical `soldier_grenade` weapon ghost composite.
- PixelLab object: `6adea276-bd23-49ed-ba8e-893e1c820ca8` (`256x256`, high top-down, created 2026-07-01 18:20).
- Runtime: `assets/sprites/effects/vfx_weapon_soldier_grenade.png`.
- Evidence: `docs/design/references/weapon_attack_animations/soldier_grenade/manifest.json`, `pixellab_source_256.png`, `soldier_grenade_vfx_runtime_candidate_256.png`, `soldier_grenade_vfx_alpha_debug.png`, and `docs/design/previews/weapon_attack_animations/soldier_grenade_contact.png`.
- Visual result: circular ember grenade telegraph with fuse spark, smoke/dust falloff, readable center, transparent corners, and no fully opaque pixels.
- Alpha/readability stats: size `256x256`, alpha min/max `0/188`, alpha mean `84.25`, nonzero alpha `60.6%`, opaque pixels `0.0%`, bbox `[18,18,241,244]`, corner alpha `[0,0,0,0]`.
- Gameplay/runtime: no damage, cooldown, targeting, radius, balance, scene, script, or shared runtime changes.
- Tests: `FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd` PASS; `FSD_GODOT_SLOTS=6 python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd` PASS.
- Disk cleanup: removed `.godot`, `build/qa/scrum767`, `build/qa/scrum457`, generated `__pycache__` folders, and generated Godot `.import` sidecars outside tracked task files.
