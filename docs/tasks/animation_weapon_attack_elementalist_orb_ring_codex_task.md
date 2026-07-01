# Animation: Кольцо Трех Стихий (elementalist_orb_ring) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/Codex
Thread: codex-vfx-auto-3-20260701
Версия: 0.1.8
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-742
Locked paths: assets/sprites/effects/vfx_weapon_elementalist_orb_ring.png, docs/design/references/weapon_attack_animations/elementalist_orb_ring/, docs/design/previews/weapon_attack_animations/elementalist_orb_ring_contact.png, scenes/ElementalistOrbRing.tscn, assets/sprites/weapons/elementalist_orb_ring.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `elementalist_orb_ring` / **Кольцо Трех Стихий** класса **Элементалист**.
Текущая механическая роль: Elemental orbit: короткая орбита стихийных сфер вокруг героя с тиками AoE-урона.

## Обязательный пайплайн генерации

Superseded pipeline override 2026-07-01: Jira blocker снят, задача имеет label/comment `pixellab`; direct user directive for `codex-vfx-auto-3-20260701` requires PixelLab MCP through `fantasydisk-asset-generator`, no OpenAI Images/image_gen/manual drawing fallback.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/elementalist_orb_ring/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_elementalist_orb_ring.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `elementalist_orb_ring` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Кольцо Трех Стихий**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Elemental orbit: короткая орбита стихийных сфер вокруг героя с тиками AoE-урона. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `elementalist_orb_ring` использовать reference `assets/sprites/weapons/elementalist_orb_ring.png` и текущую сцену `scenes/ElementalistOrbRing.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_elementalist_orb_ring.png` обновлен с новым PixelLab source/evidence по direct override 2026-07-01.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Кольцо Трех Стихий**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [x] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; animation/runtime hooks не менялись, поэтому `animation_smoke_test.gd` и `runtime_smoke_test.gd` не требовались.
- [x] Shared docs не обновлялись по dispatcher scope correction 2026-07-01: runtime path/contract не изменились, evidence записан в mirror/Jira.

## QA Notes

QA проверяет именно `elementalist_orb_ring` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Result 2026-07-01

Result: qa-ready.

PixelLab source: `create_map_object` object `0deb7121-dd70-4040-a79a-6dce484b20c2`, saved as `docs/design/references/weapon_attack_animations/elementalist_orb_ring/elementalist_orb_ring_pixellab_source.png`.

Runtime: `assets/sprites/effects/vfx_weapon_elementalist_orb_ring.png` is still `256x256` RGBA on the existing runtime path, now a three-element fire/frost/storm orbit with transparent center and a low-opacity canonical weapon ghost from `assets/sprites/weapons/elementalist_orb_ring.png`.

Evidence: `docs/design/references/weapon_attack_animations/elementalist_orb_ring/manifest.json`, `docs/design/references/weapon_attack_animations/elementalist_orb_ring/prompt_notes.md`, `docs/design/references/weapon_attack_animations/elementalist_orb_ring/alpha_report.json`, `docs/design/previews/weapon_attack_animations/elementalist_orb_ring_contact.png`.

Validation:
- Static PNG/manifest validation PASS: runtime `256x256` RGBA, max alpha `190`, center mean alpha `0.04`, transparent corners and no lower-left PixelLab mark in cleaned/runtime output.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd` PASS: `Unique weapon VFX assets smoke passed: 51 plates.`
- `FSD_GODOT_SLOTS=8 python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd` PASS: `Attack VFX smoke test passed.`

Gameplay/shared runtime: no damage, cooldown, targeting, attack range, AoE radius, orbit duration, tick count, scene, weapon icon, shared script, or balance changes.

Docs scope: per dispatcher correction 2026-07-01, broad shared docs were left unchanged because the runtime path/API contract did not change; evidence is task-specific.

Disk cleanup: temporary `.godot` symlink to the main checkout import cache removed; no disposable clone created.

## QA-Вердикт 2026-07-01

Статус: PASSED

QA owner: `QA/Codex`, worker `codex-qa-scrum742-vfx-20260701`.

Проверено:
- Jira SCRUM-742 was in `Контроль качества`; implementation result points to branch `codex/SCRUM-742-attack-vfx-orb`, commits `5f7ba589` and `7bc23381`.
- Submitted scope is task-local: runtime PNG, task-specific source/manifest/preview, task mirror, and Jira sync map only. No `.import`, `.uid`, `.godot`, caches, secrets, token-looking files, shared scripts, scenes, or unrelated assets are in the result diff.
- Runtime visual inspected: `assets/sprites/effects/vfx_weapon_elementalist_orb_ring.png` reads as a three-element orbit with transparent center and canonical weapon ghost silhouette.
- Independent PNG alpha/readability check PASS: `256x256` RGBA, nonzero alpha `40.93%`, max alpha `190`, center mean alpha `1.106/255`, transparent corners, lower-left watermark cleanup region alpha `0`, readable on dark/light/green backgrounds.
- `FSD_GODOT_SLOTS=8 python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd` PASS: `Unique weapon VFX assets smoke passed: 51 plates.`
- `FSD_GODOT_SLOTS=8 python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd` PASS: `Attack VFX smoke test passed.`
- Broader `animation_smoke_test.gd` / `runtime_smoke_test.gd` not required: branch diff contains no `.gd`, `.tscn`, scene, script, balance, or runtime-hook changes.

Краевые случаи:
- Transparent-center readability over checker/dark arena/light sand/meadow green preview checked.
- Static scope audit confirmed no Godot import sidecars or cache files in the committed result.
- Repeated VFX spawning path covered by the 51-plate unique weapon VFX smoke and AttackVfx helper smoke.

Баги: нет.

Disk cleanup: temporary `.godot` symlink and generated `build/qa/scrum457/attack_vfx_calmness_dump.md` test scratch removed before final report; no disposable clone created.
