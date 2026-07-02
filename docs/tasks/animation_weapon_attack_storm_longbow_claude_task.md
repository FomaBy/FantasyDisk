# Animation: Грозовой длинный лук (storm_longbow) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Claude
Контур: Claude
Owner: unassigned
Thread: n/a
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-770
Locked paths: assets/sprites/effects/vfx_weapon_storm_longbow.png, docs/design/references/weapon_attack_animations/storm_longbow/, docs/design/previews/weapon_attack_animations/storm_longbow_contact.png, scenes/StormLongbow.tscn, assets/sprites/weapons/storm_longbow.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `storm_longbow` / **Грозовой длинный лук** класса **Рейнджер**.
Текущая механическая роль: Stance-charged веер грозовых лучей.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/storm_longbow/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_storm_longbow.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `storm_longbow` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Грозовой длинный лук**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Stance-charged веер грозовых лучей. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `storm_longbow` использовать reference `assets/sprites/weapons/storm_longbow.png` и текущую сцену `scenes/StormLongbow.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [ ] `assets/sprites/effects/vfx_weapon_storm_longbow.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [ ] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [ ] Attack VFX уникально отражает **Грозовой длинный лук**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [ ] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [ ] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `storm_longbow` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.


## Result (2026-07-01) — DONE, Claude / OpenAI gpt-image-2

Honored user override 2026-06-30: генерация через **OpenAI gpt-image-2**, не PixelLab.

Пайплайн:
- OpenAI `gpt-image-2`, quality=high, size=1024x1024; border-connected flood-fill alpha-cleanup (запечённый фон → прозрачный); downscale 256x256 LANCZOS;
  полупрозрачный эффект (alpha×0.78) поверх приглушённого (alpha 0.30) десатурированного
  **ghost'а настоящего спрайта оружия** `assets/sprites/weapons/storm_longbow.png`.
- Runtime: `assets/sprites/effects/vfx_weapon_storm_longbow.png` (256×256 RGBA, размеры сохранены → .import валиден, reimport не требуется).
- Source + prompt manifest: `docs/design/references/weapon_attack_animations/storm_longbow/vfx_source_1024.png`, `.../prompt_manifest.json`.
- Preview (тёмный/светлый фон): `docs/design/previews/weapon_attack_animations/storm_longbow_contact.png`.

Требования выполнены: форма/движение/цвет уникальны под роль оружия; читается зона действия;
полупрозрачно, центр остаётся readable (не перекрывает игрока/врагов/HUD/попапы);
во время атаки виден полупрозрачный силуэт-ghost самого оружия. Damage/cooldown/targeting/
range/aoe/knockback/lifesteal/summon-лимиты и shared runtime logic не изменены — обновлена только PNG-плашка.

Тесты (`tools/godot_gate.py`, GODOT_BIN=fdengine, slots=1):
- `unique_weapon_vfx_assets_test.gd` — passed (51 plates).
- `attack_vfx_smoke_test.gd` — passed.


## QA-Вердикт

Статус: PASSED

QA claude-qa 2026-07-01. Проверено на HEAD origin/dev (commit 2c01f970 влит в dev; local == origin/dev, рабочее дерево чисто по assets/sprites/effects).

- `assets/sprites/effects/vfx_weapon_storm_longbow.png`: 256x256 RGBA, все 4 угла alpha=0, 0% полностью непрозрачных пикселей (весь слой полупрозрачный), видимое покрытие ~35.1%, median saturation 72 → без запечённого нейтрального/checkerboard фона; центр остаётся readable. `.import` сайдкар закоммичен, размеры сохранены (reimport не требуется).
- Визуал (SCRUM-770): ледяной/грозовой веер стрел-осколков вверх (залп дальнего боя). Уникально читается как своё оружие, отличим от 10 соседних VFX (pairwise avg-hash — 0 near-dup пар из 55).
- Тесты через `tools/godot_gate.py` (семафор, GODOT_BIN=fdengine slots=1): `unique_weapon_vfx_assets_test.gd` PASS (51 plates), `attack_vfx_smoke_test.gd` PASS.
- Коммит 2c01f970 затронул только PNG/`.import`/docs — .gd/.tscn/шейдеры/баланс не менялись, shared runtime не изменён.

QA-блок добавлен, чтобы board_sync не откатывал тикет из «Готово».
