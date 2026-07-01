# Animation: Теневые кинжалы (shadow_daggers) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Claude
Контур: Claude
Owner: unassigned
Thread: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-762
Locked paths: assets/sprites/effects/vfx_weapon_shadow_daggers.png, docs/design/references/weapon_attack_animations/shadow_daggers/, docs/design/previews/weapon_attack_animations/shadow_daggers_contact.png, scenes/ShadowDaggers.tscn, assets/sprites/weapons/shadow_daggers.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `shadow_daggers` / **Теневые кинжалы** класса **Ассасин**.
Текущая механическая роль: Быстрые короткие multi-stabs в ближней зоне + crit shadow burst у цели.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/shadow_daggers/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_shadow_daggers.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `shadow_daggers` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Теневые кинжалы**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Быстрые короткие multi-stabs в ближней зоне + crit shadow burst у цели. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `shadow_daggers` использовать reference `assets/sprites/weapons/shadow_daggers.png` и текущую сцену `scenes/ShadowDaggers.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [ ] `assets/sprites/effects/vfx_weapon_shadow_daggers.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [ ] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [ ] Attack VFX уникально отражает **Теневые кинжалы**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [ ] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [ ] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `shadow_daggers` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.


## Result (2026-07-01) — DONE, Claude / OpenAI gpt-image-2

Honored user override 2026-06-30: генерация через **OpenAI gpt-image-2**, не PixelLab.

Пайплайн:
- OpenAI `gpt-image-2`, quality=high, size=1024x1024; border-connected flood-fill alpha-cleanup (запечённый фон → прозрачный); downscale 256x256 LANCZOS;
  полупрозрачный эффект (alpha×0.78) поверх приглушённого (alpha 0.30) десатурированного
  **ghost'а настоящего спрайта оружия** `assets/sprites/weapons/shadow_daggers.png`.
- Runtime: `assets/sprites/effects/vfx_weapon_shadow_daggers.png` (256×256 RGBA, размеры сохранены → .import валиден, reimport не требуется).
- Source + prompt manifest: `docs/design/references/weapon_attack_animations/shadow_daggers/vfx_source_1024.png`, `.../prompt_manifest.json`.
- Preview (тёмный/светлый фон): `docs/design/previews/weapon_attack_animations/shadow_daggers_contact.png`.

Требования выполнены: форма/движение/цвет уникальны под роль оружия; читается зона действия;
полупрозрачно, центр остаётся readable (не перекрывает игрока/врагов/HUD/попапы);
во время атаки виден полупрозрачный силуэт-ghost самого оружия. Damage/cooldown/targeting/
range/aoe/knockback/lifesteal/summon-лимиты и shared runtime logic не изменены — обновлена только PNG-плашка.

Тесты (`tools/godot_gate.py`, GODOT_BIN=fdengine, slots=1):
- `unique_weapon_vfx_assets_test.gd` — passed (51 plates).
- `attack_vfx_smoke_test.gd` — passed.
