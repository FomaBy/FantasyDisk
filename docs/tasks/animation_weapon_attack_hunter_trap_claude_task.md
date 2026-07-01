# Animation: Охотничий капкан (hunter_trap) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Claude
Контур: Claude
Owner: claude-animator
Thread: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-750
Locked paths: assets/sprites/effects/vfx_weapon_hunter_trap.png, docs/design/references/weapon_attack_animations/hunter_trap/, docs/design/previews/weapon_attack_animations/hunter_trap_contact.png, scenes/HunterTrap.tscn, assets/sprites/weapons/hunter_trap.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `hunter_trap` / **Охотничий капкан** класса **Рейнджер**.
Текущая механическая роль: Deploy trap: burst + knockback; stance charge усиливает.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/hunter_trap/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_hunter_trap.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `hunter_trap` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Охотничий капкан**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Deploy trap: burst + knockback; stance charge усиливает. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `hunter_trap` использовать reference `assets/sprites/weapons/hunter_trap.png` и текущую сцену `scenes/HunterTrap.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [ ] `assets/sprites/effects/vfx_weapon_hunter_trap.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [ ] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [ ] Attack VFX уникально отражает **Охотничий капкан**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [ ] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [ ] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `hunter_trap` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## QA-Вердикт

Статус: PASSED

QA claude-qa 2026-07-01. Проверено на HEAD origin/dev (commit 6dc43827 влит; local файл байт-в-байт == origin/dev).

- `assets/sprites/effects/vfx_weapon_hunter_trap.png`: 256x256, углы прозрачны, 50% полностью прозрачно, видимое покрытие 46.1%, median saturation 87 (насыщенный, low-sat<15 всего 4.3%, high-sat>60 = 63.7% → без запечённого нейтрального фона).
- Визуал: стальной капкан, захлопывающийся кольцом зубьев, + яркий electric-blue shockwave наружу (knockback-радиус, роль «deploy trap: burst + knockback»), разлетающиеся debris-чанки, blue-gem акценты, молнии, светящаяся paw-эмблема в центре. Уникально читается как Охотничий капкан, зона (burst+knockback) видна, отличим от соседних VFX.
- Тесты через `tools/godot_gate.py` (семафор): `unique_weapon_vfx_assets_test.gd` PASS (51 plates, включает hunter_trap), `attack_vfx_smoke_test.gd` PASS, `runtime_smoke_test.gd` PASS.
- Геймплейные параметры/shared runtime не изменены.

Замечание (не блокер): покрытие плотнее среднего по батчу (46% vs ~13-33%) из-за радиального burst; кадр остаётся 50% прозрачным, эффект кратковременный (attack flash), автоматический VFX-гейт (unique_weapon_vfx_assets_test) принимает alpha/coverage. Центр занят вспышкой захлопывания капкана — суть эффекта.

QA-блок добавлен, чтобы board_sync не откатывал тикет из «Готово».
