# Animation: Светлый Реликварий (priest_reliquary) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/Codex `codex-vfx-auto-12-20260701`
Thread: one-off Codex worker
Branch/worktree: detached dev at `/Users/sergeyfomin/.codex/worktrees/272f/AI Agent`
Next verification: QA rerun of `unique_weapon_vfx_assets_test.gd` and `attack_vfx_smoke_test.gd` after shared Godot import slots clear.
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-756
Locked paths: assets/sprites/effects/vfx_weapon_priest_reliquary.png, docs/design/references/weapon_attack_animations/priest_reliquary/, docs/design/previews/weapon_attack_animations/priest_reliquary_contact.png, scenes/PriestReliquary.tscn, assets/sprites/weapons/priest_reliquary.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `priest_reliquary` / **Светлый Реликварий** класса **Священник**.
Текущая механическая роль: Sanctify: отмечает цель священным знаком, затем взрыв по области лечит часть нанесенного урона.

## Обязательный пайплайн генерации

Superseding override 2026-07-01: старый OpenAI-only путь больше не является
блокером. Direct user directive for this attack-VFX batch: production path is
PixelLab MCP through the `fantasydisk-asset-generator` skill; OpenAI Images,
`image_gen` and manual drawing pipelines are not used.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/priest_reliquary/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_priest_reliquary.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `priest_reliquary` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Светлый Реликварий**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Sanctify: отмечает цель священным знаком, затем взрыв по области лечит часть нанесенного урона. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `priest_reliquary` использовать reference `assets/sprites/weapons/priest_reliquary.png` и текущую сцену `scenes/PriestReliquary.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_priest_reliquary.png` обновлен с новым PixelLab source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Светлый Реликварий**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [x] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [x] Обновлены `docs/design/content_registry.md` и `docs/design/current_game_state.md` для targeted VFX redraw evidence/contract.

## QA Notes

QA проверяет именно `priest_reliquary` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Result / 2026-07-01 PixelLab Override

Result: asset production complete; ready for QA rerun of Godot smokes.

This run used PixelLab MCP through `fantasydisk-asset-generator` instead of the
stale OpenAI helper. No OpenAI Images, `image_gen`, manual drawing, gameplay
logic, scene, cooldown, damage, targeting, healing, balance or shared runtime
scripts were changed.

PixelLab evidence:
- Selected PixelLab object ID/job: `722346d1-554d-4ecd-8970-b2a6e154b543`.
- Tool: `create_map_object`, `256x256`, high top-down, transparent requested.
- Raw PixelLab download: `docs/design/references/weapon_attack_animations/priest_reliquary/priest_reliquary_pixellab_source_raw.png`.
- Alpha-clean accepted source: `docs/design/references/weapon_attack_animations/priest_reliquary/priest_reliquary_pixellab_source.png`.
- Manifest/prompt notes: `docs/design/references/weapon_attack_animations/priest_reliquary/manifest.json`, `docs/design/references/weapon_attack_animations/priest_reliquary/prompt_notes.md`.

Runtime/preview:
- Runtime PNG: `assets/sprites/effects/vfx_weapon_priest_reliquary.png`.
- Preview/contact sheet: `docs/design/previews/weapon_attack_animations/priest_reliquary_contact.png`.
- Runtime visual: golden-white sanctify seal with softened center and a low-opacity actual Светлый Реликварий ghost silhouette from `assets/sprites/weapons/priest_reliquary.png`.

Static validation:
- `file assets/sprites/effects/vfx_weapon_priest_reliquary.png` -> PNG image data, `256 x 256`, `8-bit/color RGBA`, non-interlaced.
- `static_alpha_readability_report.json`: runtime `max_alpha=170`, `mean_alpha_all_pixels=77.95`, `mean_alpha_visible_pixels=133.53`, `center_64_mean_alpha=88.78`, `outer_ring_mean_alpha=113.93`, readability decision `pass`.
- JSON validation passed for `manifest.json` and `static_alpha_readability_report.json`.

Godot smoke status:
- Attempted `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`.
- The run stayed queued before slot acquisition and was interrupted after shared semaphore/import contention; exit code `130` / `KeyboardInterrupt` from `tools/godot_gate.py` wait loop, not from a Godot assertion.
- Concurrent process evidence while blocked: multiple gated Godot imports/smokes occupied shared slots for `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd` and another worktree import for 8+ minutes.
- QA next step:

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd
```

Disk cleanup: none created; this worker did not acquire a Godot slot and did not create `.godot/` in this worktree.

## QA-Вердикт: PASSED / 2026-07-01

Статус: PASSED

QA worker: `codex-qa-scrum756-vfx-20260701`, Lane: Codex.

Scope verified:
- Jira SCRUM-756 implementation result and pushed commit `39fca93cd7ff04139ed6032bcefdf157ba8261dd` inspected.
- Runtime PNG: `assets/sprites/effects/vfx_weapon_priest_reliquary.png`.
- PixelLab/source evidence: `docs/design/references/weapon_attack_animations/priest_reliquary/`.
- Preview/contact sheet: `docs/design/previews/weapon_attack_animations/priest_reliquary_contact.png`.
- Result scope contains no `.import`, `.uid`, `.godot`, cache, temp, log, secret, or unrelated files.

Static PNG/readability checks:
- Runtime PNG is `256 x 256` RGBA, non-interlaced.
- Runtime bbox: `[17, 18, 239, 238]`.
- `max_alpha=170`, `visible_ratio_alpha_gt_8=0.5837`, `mean_alpha_all_pixels=77.95`, `mean_alpha_visible_pixels=133.53`, `center_64_mean_alpha=88.78`, `outer_32_border_mean_alpha=21.49`.
- Visual preview reads as a golden-white sanctify seal with a transparent center and low-opacity Светлый Реликварий ghost silhouette on checker, dark, and light backgrounds.

Godot gate verification:

```bash
FSD_GODOT_SLOTS=6 python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd
# PASSED: Unique weapon VFX assets smoke passed: 51 plates.

FSD_GODOT_SLOTS=6 python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd
# PASSED: Attack VFX smoke test passed.
```

No gameplay/runtime hooks changed in SCRUM-756, so broader runtime/animation smoke was not required. Cold Godot import emitted existing duplicate UID warnings from reference folders, but both requested gated tests exited successfully.

Bugs: none.

Disk cleanup: removed `.godot/` transient import cache, restored/removed generated `.import` sidecars from the QA cold import, and removed `build/qa/scrum457/` transient smoke output. Current Codex worktree retained for the QA mirror commit/push.
