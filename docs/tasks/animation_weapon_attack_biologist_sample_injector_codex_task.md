# Animation: Инъектор Образцов (biologist_sample_injector) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/Codex
Thread: codex-anim-vfx-biologist-sample-20260701
Версия: 0.1.8
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-730
Locked paths: assets/sprites/effects/vfx_weapon_biologist_sample_injector.png, docs/design/references/weapon_attack_animations/biologist_sample_injector/, docs/design/previews/weapon_attack_animations/biologist_sample_injector_contact.png, docs/tasks/animation_weapon_attack_biologist_sample_injector_codex_task.md, docs/process/jira_sync_map.json (scoped only)

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `biologist_sample_injector` / **Инъектор Образцов** класса **Биолог**.
Текущая механическая роль: Sample dart: берет образец у цели, затем два анализа бьют ее и ближайшие ткани.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/biologist_sample_injector/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_biologist_sample_injector.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `biologist_sample_injector` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Инъектор Образцов**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Sample dart: берет образец у цели, затем два анализа бьют ее и ближайшие ткани. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `biologist_sample_injector` использовать reference `assets/sprites/weapons/biologist_sample_injector.png` и текущую сцену `scenes/BiologistSampleInjector.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [ ] `assets/sprites/effects/vfx_weapon_biologist_sample_injector.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [ ] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [ ] Attack VFX уникально отражает **Инъектор Образцов**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [ ] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [ ] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `biologist_sample_injector` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Результат

Статус: done / ready for QA.
Дата: 2026-07-01.
Исполнитель: Animator/Codex `codex-anim-vfx-biologist-sample-20260701`.
Branch: `codex/SCRUM-730-attack-vfx-biologist-sample`.
Commit: будет зафиксирован в Jira final comment / финальном ответе после commit+push этого результата.

Что сделано:
- Перерисован `assets/sprites/effects/vfx_weapon_biologist_sample_injector.png` как уникальный attack VFX Инъектора Образцов: sample dart/injection line летит к ткани цели, рядом видны два biochemical analysis echoes, в фоне есть полупрозрачный ghost-силуэт фактического инъектора.
- Использован user override: source сгенерирован через OpenAI Images helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2`, `--quality high`, `--no-task`; PixelLab для SCRUM-730 не использовался.
- OpenAI source вернулся RGB с baked checkerboard, поэтому сохранён как source evidence и дополнительно очищен в RGBA alpha-clean source перед promotion в runtime PNG.
- Runtime API, gameplay code, damage/cooldowns/targeting/attack shapes/shared VFX hooks не менялись.

Source / evidence:
- `docs/design/references/weapon_attack_animations/biologist_sample_injector/biologist_sample_injector_openai_source.png`
- `docs/design/references/weapon_attack_animations/biologist_sample_injector/biologist_sample_injector_openai_source_alpha_clean.png`
- `docs/design/references/weapon_attack_animations/biologist_sample_injector/prompt_notes.md`
- `docs/design/references/weapon_attack_animations/biologist_sample_injector/manifest.json`
- `docs/design/previews/weapon_attack_animations/biologist_sample_injector_contact.png`

Runtime asset:
- `assets/sprites/effects/vfx_weapon_biologist_sample_injector.png` — `256x256` RGBA, transparent corners, no text/watermark, no fully opaque pixels (`alpha >= 250`: `0`), sparse readable footprint.

Docs:
- `docs/design/current_game_state.md` Combat VFX section updated with SCRUM-730 visual contract/evidence note.
- `docs/design/content_registry.md` not changed: canonical weapon ID/runtime path contract did not change.

Tests:
- PASS — `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd` (`Unique weapon VFX assets smoke passed: 51 plates.`)
- PASS — `python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd` (`Attack VFX smoke test passed.`)
- `runtime_smoke_test.gd` not run: no runtime/shared hooks changed.

Disk cleanup:
- Removed `.godot/` import cache created by focused Godot tests.
- Restored 119 tracked `.import` sidecars rewritten by Godot import and removed 43 untracked `.import` sidecars outside SCRUM-730 scope.
- Removed ignored `.import` sidecars generated inside the new injector reference/preview folders.
- Removed `__pycache__/` directories found in the worktree.
- Left pre-existing unrelated dirty `source_docs/FantasyDisk_GDD.txt` untouched and unstaged because it is outside SCRUM-730 locked paths.

## Integration Delivery Strand

2026-07-01: delivery-only integration by `codex-strand-vfx-integration-20260701`.

- Source branch content from `origin/codex/SCRUM-730-attack-vfx-biologist-sample` was cherry-picked onto a clean integration worktree branch `codex/strand-vfx-728-730` from current `origin/dev`.
- Delivery QA failure was addressed as a strand/integration problem only; VFX art was not regenerated.
- Branch content is ready to fast-forward into `origin/dev` together with SCRUM-728.
- Verification on the integration worktree:
  - PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`
  - PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd`

## QA-Вердикт
Статус: PASSED
Дата: 2026-07-01
QA: claude-qa

Проверено на origin/dev. Redraw влит коммитом b57a5eee (vfx_weapon_biologist_sample_injector.png, .import в индексе). PNG 256x256 RGBA, alpha 0..220 (0% непрозрачных, 85.5% прозрачных) — уникальный VFX инъектора: ghost-силуэт шприца + зелёный впрыск в фиолетовое кольцо-зону. Полупрозрачно, геймплей/shared runtime не менялись. Тесты PASS: unique_weapon_vfx_assets_test.gd (51 plates), attack_vfx_smoke_test.gd.
