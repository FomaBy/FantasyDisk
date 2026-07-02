# Animation: Колокол Молитвы (priest_chime) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/Codex `codex-vfx-auto-10-20260701`
Thread: one-off Codex worker
Branch/worktree: detached dev at `/Users/sergeyfomin/.codex/worktrees/302d/AI Agent`
Blocked: none for asset production; old OpenAI billing blocker superseded by direct user directive 2026-07-01 and PixelLab MCP override. Godot smoke rerun blocked by shared semaphore/import saturation, see result notes.
Next verification: QA/dispatcher rerun of `unique_weapon_vfx_assets_test.gd` and `attack_vfx_smoke_test.gd` after shared Godot import slots clear.
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-755
Locked paths: assets/sprites/effects/vfx_weapon_priest_chime.png, docs/design/references/weapon_attack_animations/priest_chime/, docs/design/previews/weapon_attack_animations/priest_chime_contact.png, scenes/PriestChime.tscn, assets/sprites/weapons/priest_chime.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `priest_chime` / **Колокол Молитвы** класса **Священник**.
Текущая механическая роль: Prayer chain: молитвенная нить перескакивает между врагами и возвращает sustain.

## Обязательный пайплайн генерации

Superseding override 2026-07-01: старый OpenAI-only путь больше не является
блокером. Production path for this task is PixelLab MCP through the
`fantasydisk-asset-generator` skill; OpenAI Images, `image_gen` and manual drawing
pipelines are not used.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/priest_chime/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_priest_chime.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `priest_chime` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Колокол Молитвы**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Prayer chain: молитвенная нить перескакивает между врагами и возвращает sustain. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `priest_chime` использовать reference `assets/sprites/weapons/priest_chime.png` и текущую сцену `scenes/PriestChime.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_priest_chime.png` обновлен или подтверждён как accepted с новым PixelLab source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Колокол Молитвы**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`. Rerun blocked by shared Godot gate/import saturation; static VFX validation passed.
- [x] Task evidence/manifest updated. Broad docs (`docs/design/content_registry.md`, `docs/design/current_game_state.md`, visual-style docs) intentionally unchanged per dispatcher scope note because runtime path/contract did not change.

## QA Notes

QA проверяет именно `priest_chime` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

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
PixelLab MCP / `fantasydisk-asset-generator`. This run used PixelLab MCP, not
OpenAI Images, `image_gen`, or manual drawing. Dispatcher scope note also
confirmed this per-weapon task should not edit broad shared docs.

PixelLab evidence:
- Selected PixelLab object ID/job: `b5ef3873-53d2-4f45-bb1a-3f274c6186a7`.
- Tool: `create_map_object`, `256x256`, high top-down, transparent metadata.
- Raw PixelLab download: `docs/design/references/weapon_attack_animations/priest_chime/priest_chime_pixellab_source_raw.png`.
- Alpha-clean accepted source: `docs/design/references/weapon_attack_animations/priest_chime/priest_chime_pixellab_source.png`.
- Manifest/prompt notes: `docs/design/references/weapon_attack_animations/priest_chime/manifest.json`, `docs/design/references/weapon_attack_animations/priest_chime/prompt_notes.md`.

Runtime/preview:
- Runtime PNG: `assets/sprites/effects/vfx_weapon_priest_chime.png`.
- Preview/contact sheet: `docs/design/previews/weapon_attack_animations/priest_chime_contact.png`.
- Runtime visual: calm candle-gold/ivory/pale-blue prayer-bead ring and sustain
  loop, softened center, and a low-opacity ghost silhouette from
  `assets/sprites/weapons/priest_chime.png`.
- No damage, cooldown, targeting, balance, scene, shared runtime logic, broad
  docs, `.import`, `.uid`, or other weapon VFX files changed.

Static validation:
- `file assets/sprites/effects/vfx_weapon_priest_chime.png` -> PNG image data,
  `256 x 256`, `8-bit/color RGBA`, non-interlaced.
- `static_alpha_readability_report.json`: runtime `max_alpha=172`,
  `mean_alpha_all_pixels=31.28`, `mean_alpha_visible_pixels=116.34`,
  `center_64_mean_alpha=85.17`, readability decision `pass`.
- Local Python static VFX check: `51` weapon IDs, `0` missing VFX files,
  `0` bad PNGs, `priest_chime` `256x256 RGBA`, decision `pass`.

Godot smoke status:
- Attempted `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd`.
- The run entered first-time headless import and produced known pre-existing UID
  duplicate warnings from `docs/design/references/chars_cartoon/skeleton_parts/*`
  versus `assets/sprites/characters/skeleton_parts/*`; it was terminated with
  exit code `143` before test script execution.
- Retried with a heartbeat wrapper through the same `tools/godot_gate.py`. The
  wrapper waited behind many active shared gate/import jobs for more than seven
  minutes and was stopped to avoid leaving a hidden worker process. Process
  evidence at the stop: four lock holders under `/tmp/fsd_godot_sem/slot*.lock`
  and multiple queued `unique_weapon_vfx_assets_test.gd` /
  `attack_vfx_smoke_test.gd` jobs from other worktrees.
- `attack_vfx_smoke_test.gd` was not started for this worker after the unique
  VFX smoke could not reach execution. QA/dispatcher should rerun both required
  smokes after shared Godot import slots clear:

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd
```

Disk cleanup: removed transient `/tmp/fantasydisk_scrum755_unique*` logs and the
local incomplete `.godot/` import cache. No extra clone/worktree was created.

## QA-Вердикт
Статус: PASSED
QA claude-qa 2026-07-01. Проверено на HEAD origin/dev (commit 86204fef влит в dev).
Runtime `assets/sprites/effects/vfx_weapon_priest_chime.png` = 256x256 RGBA + .import сайдкар присутствует.
Godot смоуки через `tools/godot_gate.py`:
- `res://tests/unique_weapon_vfx_assets_test.gd` → PASS ("Unique weapon VFX assets smoke passed: 51 plates").
- `res://tests/attack_vfx_smoke_test.gd` → PASS ("Attack VFX smoke test passed").
Static alpha/readability отчёт исполнителя валиден (max_alpha=172, transparent center). Приёмка пройдена → Готово.
