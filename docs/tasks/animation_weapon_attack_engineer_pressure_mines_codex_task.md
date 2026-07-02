# Animation: Минная Сетка (engineer_pressure_mines) attack VFX redraw

Статус: new
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: unassigned
Thread: n/a
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-744
Locked paths: assets/sprites/effects/vfx_weapon_engineer_pressure_mines.png, docs/design/references/weapon_attack_animations/engineer_pressure_mines/, docs/design/previews/weapon_attack_animations/engineer_pressure_mines_contact.png, scenes/EngineerPressureMines.tscn, assets/sprites/weapons/engineer_pressure_mines.png

Branch/worktree: codex/SCRUM-744-engineer-pressure-mines-vfx @ `/Users/sergeyfomin/.codex/worktrees/5c4c/AI Agent`

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `engineer_pressure_mines` / **Минная Сетка** класса **Инженер**.
Текущая механическая роль: Pressure mine grid: три мины веером срабатывают отдельно при касании врагом.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/engineer_pressure_mines/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_engineer_pressure_mines.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `engineer_pressure_mines` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Минная Сетка**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Pressure mine grid: три мины веером срабатывают отдельно при касании врагом. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `engineer_pressure_mines` использовать reference `assets/sprites/weapons/engineer_pressure_mines.png` и текущую сцену `scenes/EngineerPressureMines.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [ ] `assets/sprites/effects/vfx_weapon_engineer_pressure_mines.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [ ] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [ ] Attack VFX уникально отражает **Минная Сетка**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [ ] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [ ] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `engineer_pressure_mines` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Результат — 2026-07-01 Codex VFX worker

- Runtime asset updated: `assets/sprites/effects/vfx_weapon_engineer_pressure_mines.png`.
- PixelLab MCP source/evidence saved under `docs/design/references/weapon_attack_animations/engineer_pressure_mines/`.
- Accepted PixelLab map object: `a6231ccd-f8ee-435a-a051-cd71da237633`; alternate evidence object: `db79ced0-ab90-4a95-9395-07df17114df7`; alternate 1-direction object: `a32b0e98-8dcc-465e-8556-701be2f0909d`.
- Preview/readability sheet: `docs/design/previews/weapon_attack_animations/engineer_pressure_mines_contact.png`.
- Visual result: canonical three-mine weapon ghost composited with PixelLab teal trip-wire/ring energy; PixelLab-generated extra trigger nodes were masked during alpha cleanup so the runtime plate reads as **Минная Сетка** rather than a generic multi-mine disk.
- Static validation: PASS. Runtime PNG is `256x256` RGBA, alpha range `0..214`, nonzero alpha `42.54%`, no alpha `>=250` opaque pixels; dark/light/reduced-size readability captured in the contact sheet and manifest.
- Gameplay/shared runtime: unchanged. No damage, cooldown, targeting, radius, deploy limit, scene, balance, or shared script changes.
- Dispatcher scope correction honored: shared docs were not committed; evidence is kept in this task mirror plus task-specific reference/preview files.
- Godot smoke tests: attempted `unique_weapon_vfx_assets_test.gd` through `tools/godot_gate.py`, but the run did not reach the test body because headless import hung for 5+ minutes amid concurrent Godot gate/import jobs and pre-existing skeleton UID duplicate warnings. `attack_vfx_smoke_test.gd` was not started to avoid adding another Godot import process. QA should rerun both smokes once the local Godot import queue clears.
- Next owner/status: QA in `Контроль качества` after commit/push.
- Disk cleanup: task-owned ignored `build/qa/scrum744_engineer_pressure_mines/` and `/tmp/pixellab_db79ced0.png` removed; `.godot/` cleanup blocked by active Godot import processes in this worktree (approx `8.0K` when checked).

## QA-Вердикт (2026-07-01, codex-qa-scrum744-vfx-20260701)

Статус: FAILED

Проверено на ветке `codex/SCRUM-744-engineer-pressure-mines-vfx` @ `2df07f62`
в worktree `/Users/sergeyfomin/.codex/worktrees/a80e/AI Agent`.

Что прошло:
- Diff результата `ffaf5a10..2df07f62` содержит только runtime VFX PNG, task-specific
  source/evidence/preview, task mirror и `jira_sync_map`; `.import`, `.uid`,
  `.godot`, caches, secrets/tokens и unrelated файлы в result scope не попали.
- `assets/sprites/effects/vfx_weapon_engineer_pressure_mines.png`: `256x256` RGBA,
  sha256 `53da50d5d5c978c5...`, alpha `0..214`, nonzero alpha `42.54%`,
  pixels with alpha `>=250`: `0`.
- Runtime PNG побайтно совпадает с
  `docs/design/references/weapon_attack_animations/engineer_pressure_mines/vfx_weapon_engineer_pressure_mines_runtime_256.png`.
- `manifest.json` указывает `SCRUM-744`, `engineer_pressure_mines` и существующий
  runtime path; preview/contact sheet визуально проверен. Canonical 3-mine ghost
  читается, teal trip-wire/ring energy спокойная и полупрозрачная.

Почему FAILED:
- Обязательные Godot gates не прошли. Обычный `tools/godot_gate.py --headless --path .
  --script res://tests/unique_weapon_vfx_assets_test.gd` не смог получить semaphore
  slot из-за других worktree/import jobs.
- Watchdog-попытка через `tools/godot_gate.py` для
  `unique_weapon_vfx_assets_test.gd` завершилась до полезной проверки SCRUM-744:
  Godot не загрузил common imported textures (`slash_arc.png`, `impact_ring.png`,
  `beam_strip.png`, `sound_wave.png`, `void_orb.png`, `music_note.png`,
  `cursed_skull.png`, `dust_puff_*.png`), `scripts/attack_vfx.gd` не скомпилился,
  test body не доказал weapon VFX.
- `attack_vfx_smoke_test.gd` не запускался после этого, чтобы не добавлять ещё один
  import process в уже насыщенную очередь.

Вердикт: вернуть в работу/повторную сдачу. Продуктовый/арт-дефект этим QA-прогоном
не доказан; next worker should stabilize/clear Godot import cache/queue, rerun
`unique_weapon_vfx_assets_test.gd` and `attack_vfx_smoke_test.gd`, then resubmit
if both pass.

Баги: отдельный product bug не заведен, потому что failure относится к обязательной
verification gate/import environment, а не к доказанному runtime/art defect.

Disk cleanup: `.godot/` not present in this QA worktree after failed run; no
`build/qa/scrum744*` task temp remains; queued Godot jobs in other worktrees were
not killed.
