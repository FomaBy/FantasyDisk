# Animation: Осколочные Патроны (sniper_shatter_rounds) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/VFX Codex / codex-vfx-auto-15-20260701
Thread: codex-vfx-auto-15-20260701
Branch: codex/SCRUM-764-sniper-shatter-rounds-vfx
Blocked: none for asset production; old OpenAI billing blocker superseded by direct user directive 2026-07-01 and PixelLab MCP override.
Next verification: QA rerun of `unique_weapon_vfx_assets_test.gd` and `attack_vfx_smoke_test.gd` after the shared Godot import slots clear.
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-764
Locked paths: assets/sprites/effects/vfx_weapon_sniper_shatter_rounds.png, docs/design/references/weapon_attack_animations/sniper_shatter_rounds/, docs/design/previews/weapon_attack_animations/sniper_shatter_rounds_contact.png, scenes/SniperShatterRounds.tscn, assets/sprites/weapons/sniper_shatter_rounds.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `sniper_shatter_rounds` / **Осколочные Патроны** класса **Снайпер**.
Текущая механическая роль: Sniper split round: основной дальний выстрел раскалывается по соседним целям или продолжает линию при отсутствии целей.

## Обязательный пайплайн генерации

Superseding override 2026-07-01: старый OpenAI-only путь больше не является
блокером. Direct user directive in dispatcher chat removed blockers and set the
production path to PixelLab MCP through the `fantasydisk-asset-generator` skill;
OpenAI Images, `image_gen`, and manual drawing pipelines were not used.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/sniper_shatter_rounds/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_sniper_shatter_rounds.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `sniper_shatter_rounds` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Осколочные Патроны**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Sniper split round: основной дальний выстрел раскалывается по соседним целям или продолжает линию при отсутствии целей. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `sniper_shatter_rounds` использовать reference `assets/sprites/weapons/sniper_shatter_rounds.png` и текущую сцену `scenes/SniperShatterRounds.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_sniper_shatter_rounds.png` обновлен с новым PixelLab source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Осколочные Патроны**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [x] Обновлены task evidence/manifest; `docs/design/content_registry.md` и `docs/design/current_game_state.md` не менялись, потому что runtime path/contract не изменились.

## QA Notes

QA проверяет именно `sniper_shatter_rounds` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Result / 2026-07-01 PixelLab Override

Result: asset production complete; ready for QA rerun of Godot smokes.

Direct user directive on 2026-07-01 removed the stale OpenAI Images
`billing_hard_limit_reached` blocker and instructed agents to continue through
PixelLab MCP. This run used PixelLab via `fantasydisk-asset-generator`; OpenAI
Images, `image_gen`, and manual drawing were not used.

PixelLab evidence:
- Selected PixelLab object ID/job: `cfd56c4b-35e0-4dfd-88ef-de0e1f7fc462`.
- Rejected first candidate: `5f80744f-01e0-47be-a100-68d940669ead` because it
  read as a centered burst instead of a directional split-round trail.
- Tool: `create_map_object`, `256x256`, high top-down, transparent metadata.
- Raw PixelLab source: `docs/design/references/weapon_attack_animations/sniper_shatter_rounds/sniper_shatter_rounds_pixellab_source.png`.
- Alpha-clean accepted source: `docs/design/references/weapon_attack_animations/sniper_shatter_rounds/sniper_shatter_rounds_pixellab_alpha_clean.png`.
- Manifest/prompt notes: `docs/design/references/weapon_attack_animations/sniper_shatter_rounds/manifest.json`, `docs/design/references/weapon_attack_animations/sniper_shatter_rounds/prompt_notes.md`.

Runtime/preview:
- Runtime PNG: `assets/sprites/effects/vfx_weapon_sniper_shatter_rounds.png`.
- Preview/contact sheet: `docs/design/previews/weapon_attack_animations/sniper_shatter_rounds_contact.png`.
- Runtime visual: long lower-left to upper-right icy sniper shot trail with
  shatter sparks and a low-opacity ghost silhouette from
  `assets/sprites/weapons/sniper_shatter_rounds.png`.
- No damage, cooldown, targeting, balance, scene, shared runtime logic, or other
  weapon VFX files changed.

Static validation:
- JSON validation passed for `manifest.json` and
  `static_alpha_readability_report.json`.
- Runtime PNG check: `256 x 256`, `RGBA`, alpha range `0..237`.
- `static_alpha_readability_report.json`: runtime `alpha_mean=36.006`,
  `coverage_alpha_gt_0=0.3765`, `coverage_alpha_ge_64=0.1093`, calm mean alpha
  below previous runtime.

Godot smoke status:
- Attempted `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`.
- First attempt exited `143` with no test verdict during shared gate/import
  contention.
- Retry acquired the gate and entered first-time Godot import; output reached
  first filesystem scan completion and emitted pre-existing duplicate-UID
  warnings from `docs/design/references/chars_cartoon/...`, not from this VFX
  path. The process remained stuck in Godot `--import --quit` while other
  concurrent workers occupied/imported through the same smoke path, so this
  worker terminated only its own abandoned gate/import PIDs `43190`/`43204`.
  Exit code: `130` / `KeyboardInterrupt`.
- `attack_vfx_smoke_test.gd` was not started after the first smoke could not
  reach a verdict, to avoid adding more load to the saturated shared Godot import
  queue.
- QA next step after slots/cache are healthy:

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd
```

Disk cleanup: removed transient `.godot/` import cache and ignored
`build/qa/scrum764/` duplicate report created during local evidence generation;
no extra clone/worktree was created.
