# Animation: Реакторное Ядро (robot_reactor_core) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/Codex `codex-vfx-auto-18-20260701`
Thread: one-off Codex worker
Branch/worktree: `codex/scrum-761-robot-reactor-core-vfx` at `/Users/sergeyfomin/.codex/worktrees/ebc1/AI Agent`
Blocked: none for asset production; Godot smoke rerun needs an import-ready `.godot` cache/environment.
Next verification: QA rerun of `unique_weapon_vfx_assets_test.gd` and `attack_vfx_smoke_test.gd` after Godot import cache is available.
Версия: 0.1.8
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-761
Locked paths: assets/sprites/effects/vfx_weapon_robot_reactor_core.png, docs/design/references/weapon_attack_animations/robot_reactor_core/, docs/design/previews/weapon_attack_animations/robot_reactor_core_contact.png, scenes/RobotReactorCore.tscn, assets/sprites/weapons/robot_reactor_core.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `robot_reactor_core` / **Реакторное Ядро** класса **Робот**.
Текущая механическая роль: Reactor vent: четыре направленных выброса вокруг корпуса чистят ближний круг и отталкивают толпу.

## Обязательный пайплайн генерации

Superseding override 2026-07-01: старый OpenAI-only путь больше не является
блокером. Direct user directive in dispatcher chat сняла blockers и задала
production path через PixelLab MCP / `fantasydisk-asset-generator`; OpenAI Images,
`image_gen` и manual drawing pipeline не используются.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/robot_reactor_core/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_robot_reactor_core.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `robot_reactor_core` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Реакторное Ядро**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Reactor vent: четыре направленных выброса вокруг корпуса чистят ближний круг и отталкивают толпу. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `robot_reactor_core` использовать reference `assets/sprites/weapons/robot_reactor_core.png` и текущую сцену `scenes/RobotReactorCore.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_robot_reactor_core.png` обновлен с новым PixelLab source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Реакторное Ядро**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`: attempted / needs QA rerun. Gate import exited `143` with no output and direct Godot failed before assertions because `.godot/imported/*.ctex` cache was absent in this disposable worktree.
- [x] Обновлены task evidence/manifest; `docs/design/content_registry.md` и `docs/design/current_game_state.md` не менялись, потому что runtime path/contract не изменились.

## QA Notes

QA проверяет именно `robot_reactor_core` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Result / 2026-07-01 PixelLab Override

Result: asset production complete; ready for QA rerun of Godot smokes in an
import-ready environment.

Direct user directive on 2026-07-01 superseded the stale OpenAI Images-only
mirror text. This run used PixelLab MCP through `fantasydisk-asset-generator`.
No OpenAI Images, `image_gen`, or manual drawing pipeline was used.

PixelLab evidence:
- PixelLab object ID/job: `a5e165f2-6609-45f7-b099-71361a68a0d0`.
- Tool: `create_map_object`, `256x256`, high top-down, medium detail/shading,
  lineless, transparent metadata.
- Raw PixelLab download: `docs/design/references/weapon_attack_animations/robot_reactor_core/robot_reactor_core_pixellab_source_raw.png`.
- Alpha-clean accepted source: `docs/design/references/weapon_attack_animations/robot_reactor_core/robot_reactor_core_pixellab_source.png`.
- Manifest/prompt notes/static report: `docs/design/references/weapon_attack_animations/robot_reactor_core/manifest.json`, `prompt_notes.md`, `static_alpha_readability_report.json`.

Runtime/preview:
- Runtime PNG: `assets/sprites/effects/vfx_weapon_robot_reactor_core.png`.
- Preview/contact sheet: `docs/design/previews/weapon_attack_animations/robot_reactor_core_contact.png`.
- Runtime visual: four teal reactor exhaust arms, a close-range cross-shaped
  knockback read, softened transparent center, and low-opacity ghost silhouette
  from `assets/sprites/weapons/robot_reactor_core.png`.
- No damage, cooldown, targeting, balance, scene, shared runtime logic, or other
  weapon VFX files changed.

Static validation:
- PASS — `python3 -m json.tool docs/design/references/weapon_attack_animations/robot_reactor_core/manifest.json`.
- PASS — `python3 -m json.tool docs/design/references/weapon_attack_animations/robot_reactor_core/static_alpha_readability_report.json`.
- PASS — `file assets/sprites/effects/vfx_weapon_robot_reactor_core.png` reports
  PNG image data, `256 x 256`, `8-bit/color RGBA`, non-interlaced.
- PASS — `sips` reports runtime/source PNGs are `256x256` with alpha and the
  contact sheet is `1280x284` with alpha.
- PASS — static alpha/readability metrics: `max_alpha=172`,
  `center_64_mean_alpha=118.27`, `visible_pixel_ratio_alpha_gt_8=0.3309`,
  transparent corners `[0, 0, 0, 0]`.

Godot verification:
- Attempted — `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`; gate/import path exited `143` with no test output while `.godot` import cache was absent.
- Attempted — direct `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`; failed before the asset assertion because required `.godot/imported/*.ctex` resources were absent, then was interrupted after hanging post-diagnostic.
- Not rerun — `attack_vfx_smoke_test.gd`, because it preloads the same texture set through `scripts/attack_vfx.gd` and would hit the same import-cache failure in this worktree.

Disk cleanup: no disposable clones or task caches created; direct hung Godot
process from this worker was interrupted; no `.godot/`, generated `.import`,
`.uid`, or `__pycache__` files are part of the task result.
