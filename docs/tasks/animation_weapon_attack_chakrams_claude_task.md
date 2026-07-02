# Animation: Чакрамы (chakrams) attack VFX redraw

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
Jira: SCRUM-736
Locked paths: assets/sprites/effects/vfx_weapon_chakrams.png, docs/design/references/weapon_attack_animations/chakrams/, docs/design/previews/weapon_attack_animations/chakrams_contact.png, scenes/Chakrams.tscn, assets/sprites/weapons/chakrams.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `chakrams` / **Чакрамы** класса **Ассасин**.
Текущая механическая роль: Boomerang-коридор туда и обратно; критовые попадания дают shadow burst у цели без перемещения героя.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/chakrams/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_chakrams.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `chakrams` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Чакрамы**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Boomerang-коридор туда и обратно; критовые попадания дают shadow burst у цели без перемещения героя. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `chakrams` использовать reference `assets/sprites/weapons/chakrams.png` и текущую сцену `scenes/Chakrams.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [ ] `assets/sprites/effects/vfx_weapon_chakrams.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [ ] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [ ] Attack VFX уникально отражает **Чакрамы**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [ ] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [ ] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `chakrams` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## QA-Вердикт
Статус: PASSED
Дата: 2026-07-01
QA: claude-qa
Проверено на HEAD origin/dev (commit 5011c1b4). Runtime PNG 256×256 RGBA, border alpha=0 (нет запечённого фона), полупрозрачный (mean alpha 42), интерьер петли прозрачен. Визуал уникально читается как Чакрамы: бумеранг-коридор с двумя лезвийными дисками, magenta трейлы, violet shadow burst (крит). Readability на dark/light/gray подтверждена, HUD не перекрывается. Баланс/shared runtime не тронуты. Smoke: unique_weapon_vfx_assets_test PASS (51 plates), attack_vfx_smoke_test PASS.
