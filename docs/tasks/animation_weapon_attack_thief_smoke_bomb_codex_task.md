# Animation: Дымовая Бомба (thief_smoke_bomb) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/VFX Codex worker
Thread: disposable codex worker delegated from 019f1eac-35c3-7323-9067-8b7c2b88ab33
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-775
Locked paths: assets/sprites/effects/vfx_weapon_thief_smoke_bomb.png, assets/sprites/effects/vfx_weapon_thief_smoke_bomb.png.import, docs/design/references/attack_vfx/thief_smoke_bomb/, docs/design/previews/attack_vfx/thief_smoke_bomb_contact.png, docs/tasks/animation_weapon_attack_thief_smoke_bomb_codex_task.md

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `thief_smoke_bomb` / **Дымовая Бомба** класса **Вор**.
Текущая механическая роль: Smoke bomb: delayed AoE + временное уклонение Вора.

## Обязательный пайплайн генерации

Superseded by dispatcher unblock 2026-07-01: the earlier OpenAI Images-only helper path is blocked by `billing_hard_limit_reached`. This task now uses the mandatory PixelLab MCP / `fantasydisk-asset-generator` production path; do not fall back to OpenAI Images unless Jira records a newer explicit override.

Source PNG, prompt notes, manifest, QA report, and contact/readability preview are saved in `docs/design/references/attack_vfx/thief_smoke_bomb/` and `docs/design/previews/attack_vfx/thief_smoke_bomb_contact.png`. Accepted runtime PNG updates only `assets/sprites/effects/vfx_weapon_thief_smoke_bomb.png`; no gameplay/runtime hooks are in scope.

## Требования

1. Сделать attack VFX/animation для `thief_smoke_bomb` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Дымовая Бомба**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Smoke bomb: delayed AoE + временное уклонение Вора. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `thief_smoke_bomb` использовать reference `assets/sprites/weapons/thief_smoke_bomb.png` и текущую сцену `scenes/ThiefSmokeBomb.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_thief_smoke_bomb.png` обновлен или подтверждён как accepted с новым PixelLab source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Дымовая Бомба**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [x] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [x] `docs/design/content_registry.md` и `docs/design/current_game_state.md` не обновлялись, потому что runtime path/contract не изменились; evidence добавлен в task-specific paths.

## QA Notes

QA проверяет именно `thief_smoke_bomb` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Result — 2026-07-01

Completed PixelLab-first redraw for `thief_smoke_bomb` attack VFX.

- Runtime asset: `assets/sprites/effects/vfx_weapon_thief_smoke_bomb.png`.
- Selected PixelLab object: `08edb666-7ad1-4675-a39a-d2190b042900`.
- Unused audit candidate: `5a68f6da-9a6a-46db-bb9e-e89de4ae4e4a`.
- Source/evidence: `docs/design/references/attack_vfx/thief_smoke_bomb/`.
- Preview/contact sheet: `docs/design/previews/attack_vfx/thief_smoke_bomb_contact.png`.
- Static alpha/readability report: `docs/design/references/attack_vfx/thief_smoke_bomb/static_alpha_readability_report.json`.

The accepted VFX is a broken grey-blue smoke ring with a readable transparent center, violet shadow motes, and a low-opacity canonical smoke bomb silhouette composited behind the effect. Runtime output is a `256x256` transparent RGBA PNG. Key runtime metrics: bbox `[19, 19, 237, 238]`, visible pixel ratio alpha > 8 `0.4918`, max alpha `172`, center 64px mean alpha `81.5`, dark arena luma delta `37.73`, light arena luma delta `22.55`.

No gameplay, balance, cooldown, targeting, scene, shared runtime logic, or broad design registry files changed.

Tests:

- PASS: static PNG validation for runtime/source alpha, bbox, transparency, and readability metrics.
- PASS: `FSD_GODOT_SLOTS=6 FSD_GODOT_MAXWAIT=86400 python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`.
- PASS: `FSD_GODOT_SLOTS=6 FSD_GODOT_MAXWAIT=86400 python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd`.

Disk cleanup: removed `.godot/` import cache (about 1.7 GB) and `build/qa/scrum775`; no disposable clone created.
