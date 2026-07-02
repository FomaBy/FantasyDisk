# Animation: Магнитный Якорь (robot_magnetic_anchor) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/Codex codex-vfx-auto-11-20260701
Thread: codex-vfx-auto-11-20260701
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-760
Locked paths: assets/sprites/effects/vfx_weapon_robot_magnetic_anchor.png, docs/design/references/weapon_attack_animations/robot_magnetic_anchor/, docs/design/previews/weapon_attack_animations/robot_magnetic_anchor_contact.png, scenes/RobotMagneticAnchor.tscn, assets/sprites/weapons/robot_magnetic_anchor.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `robot_magnetic_anchor` / **Магнитный Якорь** класса **Робот**.
Текущая механическая роль: Magnetic anchor: якорь стягивает врагов к центру и бьет импульсом.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/robot_magnetic_anchor/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_robot_magnetic_anchor.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `robot_magnetic_anchor` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Магнитный Якорь**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Magnetic anchor: якорь стягивает врагов к центру и бьет импульсом. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `robot_magnetic_anchor` использовать reference `assets/sprites/weapons/robot_magnetic_anchor.png` и текущую сцену `scenes/RobotMagneticAnchor.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [ ] `assets/sprites/effects/vfx_weapon_robot_magnetic_anchor.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [ ] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [ ] Attack VFX уникально отражает **Магнитный Якорь**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [ ] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [ ] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `robot_magnetic_anchor` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Codex Start — 2026-07-01

Claimed via Jira-pull by `codex-vfx-auto-11-20260701` on branch
`codex/SCRUM-760-robot-magnetic-anchor-vfx` from synced `origin/dev`
(`42faa829`). Locked paths stay limited to the `robot_magnetic_anchor` VFX
runtime PNG, PixelLab source/evidence folder, contact preview, this mirror, and
Jira sync metadata if changed. Next verification: PixelLab source generation,
static alpha/readability report, then `unique_weapon_vfx_assets_test.gd` and
`attack_vfx_smoke_test.gd` through `tools/godot_gate.py`.

## Результат — 2026-07-01

Result: done / ready for QA.

- Runtime VFX updated: `assets/sprites/effects/vfx_weapon_robot_magnetic_anchor.png`.
- PixelLab MCP source: `80184364-0712-4722-85f0-2dbcdcbe1363`
  (`create_map_object`, `256x256`, high top-down).
- Source/evidence:
  `docs/design/references/weapon_attack_animations/robot_magnetic_anchor/`.
- Preview:
  `docs/design/previews/weapon_attack_animations/robot_magnetic_anchor_contact.png`.
- Static alpha/readability:
  `static_alpha_readability_report.json` -> `pass`; runtime `256x256 RGBA`,
  alpha extrema `[0, 162]`, transparent corners, center 64x64 mean alpha `79.77`,
  no edge alpha pixels.
- Visual intent: cyan magnetic pull ring with inward field structure and a
  low-opacity ghost of the canonical Magnetic Anchor weapon silhouette under
  the PixelLab field.
- Scope: no gameplay, balance, targeting, cooldown, scene, shared script, broad
  design doc, `.import`, `.uid`, or `.godot` changes kept.

Tests:

- `python3 -m json.tool docs/design/references/weapon_attack_animations/robot_magnetic_anchor/manifest.json`
  — PASS.
- `python3 -m json.tool docs/design/references/weapon_attack_animations/robot_magnetic_anchor/static_alpha_readability_report.json`
  — PASS.
- PNG static check — PASS (`runtime/source` are `256x256 RGBA`; runtime corners
  are transparent).
- `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`
  — PASS (`Unique weapon VFX assets smoke passed: 51 plates.`).
- `python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd`
  — PASS (`Attack VFX smoke test passed.`).

Disk cleanup: removed task-created `.godot/` import cache and `build/qa/scrum457`;
removed generated `.import` sidecars from task-specific source/preview paths;
none kept or committed.
