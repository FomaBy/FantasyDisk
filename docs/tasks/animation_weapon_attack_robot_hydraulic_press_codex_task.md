# Animation: Гидравлический Пресс (robot_hydraulic_press) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/Codex `codex-vfx-auto-13-20260701`
Thread: one-off Codex worker
Branch/worktree: `codex/SCRUM-759-robot-hydraulic-press-vfx` at `/Users/sergeyfomin/.codex/worktrees/08c8/AI Agent`
Blocked: none; stale OpenAI-only text superseded by direct user directive 2026-07-01 and PixelLab MCP production path.
Verification: passed focused static asset checks, `unique_weapon_vfx_assets_test.gd`, and `attack_vfx_smoke_test.gd`.
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-759
Locked paths: assets/sprites/effects/vfx_weapon_robot_hydraulic_press.png, docs/design/references/weapon_attack_animations/robot_hydraulic_press/, docs/design/previews/weapon_attack_animations/robot_hydraulic_press_contact.png, scenes/RobotHydraulicPress.tscn, assets/sprites/weapons/robot_hydraulic_press.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `robot_hydraulic_press` / **Гидравлический Пресс** класса **Робот**.
Текущая механическая роль: Compression line: две силовые губки сходятся по линии атаки, прижимают врагов к оси и бьют коридором.

## Обязательный пайплайн генерации

Superseding override 2026-07-01: старый OpenAI-only путь больше не является
блокером. Direct user directive in dispatcher chat removed blockers and set the
production path to PixelLab MCP through the `fantasydisk-asset-generator` skill.
OpenAI Images, `image_gen`, manual drawing and the legacy repo helper are not
used for this task.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/robot_hydraulic_press/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_robot_hydraulic_press.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `robot_hydraulic_press` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Гидравлический Пресс**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Compression line: две силовые губки сходятся по линии атаки, прижимают врагов к оси и бьют коридором. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `robot_hydraulic_press` использовать reference `assets/sprites/weapons/robot_hydraulic_press.png` и текущую сцену `scenes/RobotHydraulicPress.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_robot_hydraulic_press.png` обновлен с новым PixelLab source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Гидравлический Пресс**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [x] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; animation/runtime hooks не менялись, поэтому `animation_smoke_test.gd`/`runtime_smoke_test.gd` не требовались.
- [x] `docs/design/content_registry.md` и `docs/design/current_game_state.md` не менялись: runtime path/contract сохранён, добавлена task-specific evidence.

## Result — 2026-07-01 PixelLab implementation

- PixelLab MCP object id: `99b9c7ec-23d3-4110-a22a-912cf8b455b8`.
- Runtime PNG: `assets/sprites/effects/vfx_weapon_robot_hydraulic_press.png`.
- Source/evidence: `docs/design/references/weapon_attack_animations/robot_hydraulic_press/manifest.json`, `prompt_notes.md`, `robot_hydraulic_press_pixellab_source_raw.png`, `robot_hydraulic_press_pixellab_source.png`, `static_alpha_readability_report.json`.
- Preview/contact sheet: `docs/design/previews/weapon_attack_animations/robot_hydraulic_press_contact.png`.
- Runtime metrics: 256x256 RGBA, visible alpha>8 ratio `0.6042`, max alpha `148`, center 64px mean alpha `90.34`, readability decision `pass`.
- Static checks: `file` confirmed 256x256 RGBA source/runtime PNGs and 1280x768 contact sheet; `python3 -m json.tool` passed for manifest/report; `git diff --check` passed.
- Godot smokes: `FSD_GODOT_MAXWAIT=75 python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd` passed (`51` plates); `FSD_GODOT_MAXWAIT=75 python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd` passed. The global semaphore was saturated by sibling worker imports, so `godot_gate.py` timed out and launched the cached lightweight smoke scripts itself; both returned exit code `0`.
- Gameplay/runtime: no damage, cooldown, targeting, range, knockback, balance, scene, shared runtime script, or other weapon VFX changes.
- Disk cleanup: removed temporary `.godot` cache copied for smoke verification; no `.godot/`, `.import`, `.uid`, source scratch cache, or disposable checkout left for this task.

## QA Notes

QA проверяет именно `robot_hydraulic_press` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.
