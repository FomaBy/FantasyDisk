# Animation: Прицел Наводчика (sniper_spotter_scope) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/Codex `codex-vfx-auto-16-20260701`
Thread: one-off Codex worker
Branch/worktree: detached dev at `/Users/sergeyfomin/.codex/worktrees/99bb/AI Agent`
Blocked: none
Next verification: QA rerun of `unique_weapon_vfx_assets_test.gd` and `attack_vfx_smoke_test.gd` when shared Godot gate/import slots clear.
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-765
Locked paths: assets/sprites/effects/vfx_weapon_sniper_spotter_scope.png, docs/design/references/weapon_attack_animations/sniper_spotter_scope/, docs/design/previews/weapon_attack_animations/sniper_spotter_scope_contact.png, scenes/SniperSpotterScope.tscn, assets/sprites/weapons/sniper_spotter_scope.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `sniper_spotter_scope` / **Прицел Наводчика** класса **Снайпер**.
Текущая механическая роль: Sniper kill-zone: маркирует область у цели и вызывает несколько точных sky-beam попаданий по врагам внутри.

## Обязательный пайплайн генерации

Superseding override 2026-07-01: старый OpenAI-only путь больше не является
блокером. Production path for this task is PixelLab MCP through the
`fantasydisk-asset-generator` skill; OpenAI Images, `image_gen` and manual drawing
pipelines are not used.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/sniper_spotter_scope/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_sniper_spotter_scope.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `sniper_spotter_scope` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Прицел Наводчика**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Sniper kill-zone: маркирует область у цели и вызывает несколько точных sky-beam попаданий по врагам внутри. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `sniper_spotter_scope` использовать reference `assets/sprites/weapons/sniper_spotter_scope.png` и текущую сцену `scenes/SniperSpotterScope.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_sniper_spotter_scope.png` обновлен с новым PixelLab source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Прицел Наводчика**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`: Godot run attempted via `tools/godot_gate.py`, but this worker never reached an import/test slot because the shared semaphore was saturated by other worktrees. Static asset checks passed; QA rerun required.
- [x] Обновлены task evidence/manifest; `docs/design/content_registry.md` and `docs/design/current_game_state.md` intentionally not changed because runtime path/contract did not change.

## QA Notes

QA проверяет именно `sniper_spotter_scope` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Result / 2026-07-01 PixelLab Override

Result: asset production complete; ready for QA rerun of Godot smokes.

Direct user directive on 2026-07-01 superseded the stale OpenAI Images-only
wording and required the PixelLab MCP path for attack-VFX tasks. This run used
PixelLab MCP through `fantasydisk-asset-generator`; no OpenAI Images, `image_gen`,
manual drawing, shared VFX pack regeneration, gameplay tuning, scene edit, or
shared runtime logic change was used.

PixelLab evidence:
- Primary PixelLab object ID/job: `dce7e36f-bea9-4aee-b8f1-0cffd1c828f4`.
- Supporting reticle PixelLab object ID/job: `ce0de7cf-9a50-47ec-b19b-e46e63d3add2`.
- Tool: `create_map_object`, `256x256`, high top-down, transparent metadata.
- Raw PixelLab sources: `docs/design/references/weapon_attack_animations/sniper_spotter_scope/sniper_spotter_scope_pixellab_source_raw.png`, `docs/design/references/weapon_attack_animations/sniper_spotter_scope/sniper_spotter_scope_pixellab_candidate_beams_raw.png`.
- Alpha-clean accepted source: `docs/design/references/weapon_attack_animations/sniper_spotter_scope/sniper_spotter_scope_pixellab_source.png`.
- Manifest/prompt/static evidence: `docs/design/references/weapon_attack_animations/sniper_spotter_scope/manifest.json`, `prompt_notes.md`, `static_alpha_readability_report.json`, `static_asset_matrix_report.json`.

Runtime/preview:
- Runtime PNG: `assets/sprites/effects/vfx_weapon_sniper_spotter_scope.png`.
- Preview/contact sheet: `docs/design/previews/weapon_attack_animations/sniper_spotter_scope_contact.png`.
- Runtime visual: cyan-silver sniper kill-zone reticle, narrow sky-beam strike columns, faint star/smoke accents, and a low-opacity ghost silhouette from `assets/sprites/weapons/sniper_spotter_scope.png`.
- No damage, cooldown, targeting, attack range, AoE radius, balance, scene, shared script, or other weapon VFX file changed.

Static validation:
- `file assets/sprites/effects/vfx_weapon_sniper_spotter_scope.png` -> PNG image data, `256 x 256`, `8-bit/color RGBA`, non-interlaced.
- `manifest.json` and `static_alpha_readability_report.json` parse with `python3 -m json.tool`.
- `static_alpha_readability_report.json`: runtime `max_alpha=172`, `mean_alpha_all_pixels=47.37`, `mean_alpha_visible_pixels=107.32`, `center_64_mean_alpha=114.6`, `center_64_max_alpha=137`, all four corners alpha `0`, readability decision `pass`.
- `static_asset_matrix_report.json`: 51 weapon IDs from `scripts/progression_data_weapons.gd`, 51 matching `vfx_weapon_*.png` files, no missing/size problems, `sniper_spotter_scope` checked.

Godot smoke status:
- Attempted `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`.
- The run exited `143` before producing Godot output and before this worktree created `.godot/`; process audit showed the shared gate/import queue saturated by other worktrees running `unique_weapon_vfx_assets_test.gd` and Godot `--import --quit`.
- `attack_vfx_smoke_test.gd` was not launched afterward to avoid adding another competing job to the saturated semaphore.
- QA next step:

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd
```

Disk cleanup: removed empty ignored scratch dir `build/qa/scrum765_sniper_spotter_scope_vfx/`; no `.godot/`, temp clone, disposable worktree, or user-data cache was created by this worker.

## QA-Вердикт
Статус: PASSED
QA claude-qa 2026-07-01. Проверено на HEAD origin/dev (commit a83fb7a5 влит в dev).
Runtime `assets/sprites/effects/vfx_weapon_sniper_spotter_scope.png` = 256x256 RGBA + .import сайдкар присутствует.
Godot смоуки через `tools/godot_gate.py`:
- `res://tests/unique_weapon_vfx_assets_test.gd` → PASS ("Unique weapon VFX assets smoke passed: 51 plates").
- `res://tests/attack_vfx_smoke_test.gd` → PASS ("Attack VFX smoke test passed").
Static alpha/readability отчёт исполнителя валиден (max_alpha=172, transparent corners). Приёмка пройдена → Готово.
