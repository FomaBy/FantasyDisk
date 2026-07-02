# Animation: Двуручный топор (axe) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/Codex
Thread: codex-anim-vfx-axe-20260701
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-728
Locked paths: assets/sprites/effects/vfx_weapon_axe.png, docs/design/references/weapon_attack_animations/axe/, docs/design/previews/weapon_attack_animations/axe_contact.png, docs/tasks/animation_weapon_attack_axe_codex_task.md, docs/process/jira_sync_map.json (scoped sync only)

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `axe` / **Двуручный топор** класса **Берсерк**.
Текущая механическая роль: Широкая дуга 140 градусов радиуса 320.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/axe/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_axe.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `axe` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Двуручный топор**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Широкая дуга 140 градусов радиуса 320. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `axe` использовать reference `assets/sprites/weapons/two_handed_axe.png` и текущую сцену `scenes/TwoHandedAxe.tscn` только как read-only контекст.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_axe.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Двуручный топор**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [x] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [x] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `axe` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Work Log

- 2026-07-01: Codex worker `codex-anim-vfx-axe-20260701` продолжил уже claimed Jira `SCRUM-728` на ветке `codex/SCRUM-728-attack-vfx-axe`. Scope tightened to explicit user locked paths; `source_docs/FantasyDisk_GDD.txt` is a pre-existing dirty file outside scope and must remain unstaged/uncommitted.

## Результат

Статус: done; готово к `Контроль качества` после push.

- OpenAI override: выполнено через `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`, `gpt-image-2`, `--quality high`, без PixelLab.
- Runtime asset: `assets/sprites/effects/vfx_weapon_axe.png` заменён на 256x256 RGBA semi-transparent axe cleave plate. Alpha max 188, nonzero alpha 39.35%, mean alpha 55.74.
- Source/evidence: `docs/design/references/weapon_attack_animations/axe/openai_axe_arc_source.png`, `axe_vfx_runtime_candidate_256.png`, `axe_vfx_alpha_debug.png`, `prompt_notes.md`, `manifest.json`.
- Preview/contact sheet: `docs/design/previews/weapon_attack_animations/axe_contact.png` with source, runtime alpha, dark/light readability, and 140-degree guide views.
- Visual contract: broad 140-degree axe arc, visible direction/area, calm crimson/iron smoke, canonical two-handed axe ghost silhouette composited from `assets/sprites/weapons/two_handed_axe.png`.
- Runtime/gameplay: no damage, cooldown, targeting, attack range, sweep angle/radius, balance, scene, shared script, or runtime API change.
- Documentation: `docs/design/current_game_state.md` Combat VFX section updated with SCRUM-728 evidence/contract note.
- Tests:
  - PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`
  - PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd`
  - Not run: `runtime_smoke_test.gd`; no runtime/shared hooks changed.
- Commit/push: implementation/evidence commit `e0f8c0c3` pushed on branch `codex/SCRUM-728-attack-vfx-axe`; follow-up bookkeeping commit may only record this line.
- Disk cleanup: removed `.godot` import cache (~1.2G) and untracked Godot `.import` sidecars generated by tests; none of those sidecars are committed. Pre-existing dirty `source_docs/FantasyDisk_GDD.txt` is outside SCRUM-728 and remains unstaged/uncommitted.

## Integration Delivery Strand

2026-07-01: delivery-only integration by `codex-strand-vfx-integration-20260701`.

- Source branch content from `origin/codex/SCRUM-728-attack-vfx-axe` was cherry-picked onto a clean integration worktree branch `codex/strand-vfx-728-730` from current `origin/dev`.
- Delivery QA failure was addressed as a strand/integration problem only; VFX art was not regenerated.
- Branch content is ready to fast-forward into `origin/dev` together with SCRUM-730.
- Verification on the integration worktree:
  - PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`
  - PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd`

## QA-Вердикт
Статус: PASSED
Дата: 2026-07-01
QA: claude-qa

Проверено на origin/dev @ d0dc04e4. Интеграция подтверждена (vfx_weapon_axe.png влит коммитом 3120aaaf, .import в индексе). PNG 256x256 RGBA полупрозрачный (alpha 0..188, нет запечённого фона). Тесты PASS: unique_weapon_vfx_assets_test.gd, attack_vfx_smoke_test.gd, runtime_smoke_test.gd. Геймплей/shared runtime не менялись.
