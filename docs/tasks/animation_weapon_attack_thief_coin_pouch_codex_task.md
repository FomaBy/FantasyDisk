# Animation: Кошель Рикошета (thief_coin_pouch) attack VFX redraw

Статус: blocked
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: unassigned
Thread: n/a
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-773
Locked paths: assets/sprites/effects/vfx_weapon_thief_coin_pouch.png, docs/design/references/attack_vfx/thief_coin_pouch/, docs/design/previews/attack_vfx/thief_coin_pouch_contact.png, docs/tasks/animation_weapon_attack_thief_coin_pouch_codex_task.md

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `thief_coin_pouch` / **Кошель Рикошета** класса **Вор**.
Текущая механическая роль: Coin ricochet: цепь по ближайшим целям с убывающим уроном и малой кражей золота.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/attack_vfx/thief_coin_pouch/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_thief_coin_pouch.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `thief_coin_pouch` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Кошель Рикошета**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Coin ricochet: цепь по ближайшим целям с убывающим уроном и малой кражей золота. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `thief_coin_pouch` использовать reference `assets/sprites/weapons/thief_coin_pouch.png` и текущую сцену `scenes/ThiefCoinPouch.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [ ] `assets/sprites/effects/vfx_weapon_thief_coin_pouch.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [ ] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [ ] Attack VFX уникально отражает **Кошель Рикошета**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [ ] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [ ] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `thief_coin_pouch` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Claim — Codex Worker (2026-07-01)

Owner: Animator/VFX Codex worker.
Thread/Worker: current Codex worker in worktree `5b43`, delegated from
`019f1eac-35c3-7323-9067-8b7c2b88ab33`.
Lane: Codex.
Branch/worktree: `codex/SCRUM-773-thief-coin-pouch-vfx` at
`/Users/sergeyfomin/.codex/worktrees/5b43/AI Agent`.
Locked paths: `assets/sprites/effects/vfx_weapon_thief_coin_pouch.png`,
`docs/design/references/attack_vfx/thief_coin_pouch/`,
`docs/design/previews/attack_vfx/thief_coin_pouch_contact.png`, this mirror.
Next verification: PixelLab source/fetch, runtime PNG integration, static
alpha/readability check, `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`.

## Blocked Partial Result — Codex Worker (2026-07-01)

PixelLab/source integration complete on branch
`codex/SCRUM-773-thief-coin-pouch-vfx`, but the task is not moved to QA because
required Godot smokes could not start through the shared semaphore.

Completed:
- PixelLab MCP source generated with object ID
  `cb77b5fe-3669-4fdf-a269-42f2d999f9d5`.
- Raw PixelLab source, alpha-cleaned source, runtime candidate, manifest and
  prompt notes saved under `docs/design/references/attack_vfx/thief_coin_pouch/`.
- Runtime PNG updated only at
  `assets/sprites/effects/vfx_weapon_thief_coin_pouch.png`.
- Preview/contact sheet saved at
  `docs/design/previews/attack_vfx/thief_coin_pouch_contact.png`.
- Static PNG validation PASS: `256x256` RGBA, visible alpha `14.15%`,
  max alpha `218`, no alpha >=250 pixels, corner alpha `0`, bbox
  `[42, 23, 229, 228]`.

Blocked:
- `unique_weapon_vfx_assets_test.gd` was queued through `tools/godot_gate.py`
  but never acquired a semaphore slot; the run was interrupted before Godot
  launched to avoid adding more pressure to the saturated import queue.
- `attack_vfx_smoke_test.gd` was not started for the same reason.

No gameplay code, shared runtime API, damage, cooldown, targeting, range, radius
or balance changed.
