# Animation: Плащ Захода (thief_shadow_cloak) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/VFX Codex disposable worker
Thread: current Codex worker (delegated from 019f1eac-35c3-7323-9067-8b7c2b88ab33)
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-774
Locked paths: assets/sprites/effects/vfx_weapon_thief_shadow_cloak.png, docs/design/references/attack_vfx/thief_shadow_cloak/, docs/design/references/weapon_attack_animations/thief_shadow_cloak/, docs/design/previews/weapon_attack_animations/thief_shadow_cloak_contact.png, assets/vfx/attacks/thief_shadow_cloak/, scenes/ThiefShadowCloak.tscn only if runtime rewiring is required

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `thief_shadow_cloak` / **Плащ Захода** класса **Вор**.
Текущая механическая роль: Shadow backstab: мгновенный заход за ближайшую цель, усиленный удар и малый splash рядом.

## Обязательный пайплайн генерации

Initial 2026-06-30 OpenAI-only generation path was blocked by
`billing_hard_limit_reached`. Direct dispatcher/user unblock 2026-07-01 switched
this issue back to the mandatory PixelLab-first redraw path. Do not use OpenAI
Images unless a new Jira comment explicitly records a fresh override.

Source PNG, prompt notes, manifest, and alpha/readability evidence are saved in
`docs/design/references/attack_vfx/thief_shadow_cloak/` with a mirror under
`docs/design/references/weapon_attack_animations/thief_shadow_cloak/`. Accepted
runtime PNG updates only `assets/sprites/effects/vfx_weapon_thief_shadow_cloak.png`;
no backend/runtime handoff was needed.

## Требования

1. Сделать attack VFX/animation для `thief_shadow_cloak` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Плащ Захода**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Shadow backstab: мгновенный заход за ближайшую цель, усиленный удар и малый splash рядом. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `thief_shadow_cloak` использовать reference `assets/sprites/weapons/thief_shadow_cloak.png` и текущую сцену `scenes/ThiefShadowCloak.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_thief_shadow_cloak.png` обновлен с новым PixelLab source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Плащ Захода**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [x] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; animation/runtime hooks не менялись.
- [x] `docs/design/content_registry.md` и `docs/design/current_game_state.md` не требовали обновления: runtime path/contract не изменились.

## QA Notes

QA проверяет именно `thief_shadow_cloak` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные PixelLab/Godot/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Codex Claim — 2026-07-01

- Owner: Animator/VFX Codex disposable worker.
- Lane: Codex.
- Worktree: `/Users/sergeyfomin/.codex/worktrees/fcf1/AI Agent`, detached HEAD synced to `origin/dev` `42faa829d2f2ef4956ebdf90e2769ba70209d0e8`.
- Scope decision: keep the existing runtime contract `assets/sprites/effects/vfx_weapon_thief_shadow_cloak.png`; add task-specific PixelLab/source evidence under `docs/design/references/attack_vfx/thief_shadow_cloak/` and mirror notes under `docs/design/references/weapon_attack_animations/thief_shadow_cloak/`.

## Result — 2026-07-01

- PixelLab object: `35360c9c-d67b-4f84-8fc5-6041c87db9e9`; source download archived as `thief_shadow_cloak_pixellab_source_raw.png`, cleaned source archived as `thief_shadow_cloak_pixellab_source.png`.
- Runtime integration: replaced only `assets/sprites/effects/vfx_weapon_thief_shadow_cloak.png`; `scripts/attack_vfx.gd`, `scenes/ThiefShadowCloak.tscn`, damage/cooldown/targeting/range/AoE/balance values unchanged.
- Visual decision: semi-transparent violet-black cloak/backstab crescent with a ghost cloak silhouette, small splash/target ring, and open center readability for world elements.
- Static alpha/readability: runtime `256x256` RGBA, `max_alpha=174`, `mean_alpha=36.98`, `visible_ratio_alpha_gt_8=0.3864`, `center64_mean_alpha=68.51`, `center64_max_alpha=174`; report saved in both evidence folders.
- Tests: `python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd` passed (`Unique weapon VFX assets smoke passed: 51 plates.`); `python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd` passed, then passed again cleanly after import cache settled.
- Disk cleanup: removed `.godot`, restored 119 tracked Godot-generated `.import/.uid` sidecar changes, removed 215 untracked generated `.import/.uid` sidecars; no SCRUM-774 task sidecar cache remains.
