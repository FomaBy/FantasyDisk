# Animation: Двуручный меч (sword) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/VFX Codex
Thread: fantasydisk-codex-scrum-772-agent
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-772
Locked paths: assets/sprites/effects/vfx_weapon_sword.png, docs/design/references/weapon_attack_animations/sword/, docs/design/previews/weapon_attack_animations/sword_contact.png, scenes/TwoHandedSword.tscn, assets/sprites/weapons/two_handed_sword.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `sword` / **Двуручный меч** класса **Берсерк**.
Текущая механическая роль: Усеченный замах 90 градусов, радиус 600, base width 150.

## Обязательный пайплайн генерации

Superseded: исходный OpenAI Images override 2026-06-30 был отменён
dispatcher unblock 2026-07-01 ниже, потому что OpenAI Images оставался
заблокирован `billing_hard_limit_reached`. Активный production path для этой
задачи: PixelLab MCP через `fantasydisk-asset-generator`.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/sword/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_sword.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `sword` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Двуручный меч**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Усеченный замах 90 градусов, радиус 600, base width 150. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `sword` использовать reference `assets/sprites/weapons/two_handed_sword.png` и текущую сцену `scenes/TwoHandedSword.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_sword.png` обновлен с новым PixelLab source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Двуручный меч**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [x] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; animation/runtime hooks не менялись, поэтому `animation_smoke_test.gd` и `runtime_smoke_test.gd` не требовались.
- [x] Broad docs не обновлялись: runtime path/contract не изменились, evidence сохранён в task mirror + manifest.

## QA Notes

QA проверяет именно `sword` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Claim — Codex worker (2026-07-01)

Owner: Animator/VFX Codex  
Thread/Worker: `fantasydisk-codex-scrum-772-agent`  
Branch/worktree: `codex/SCRUM-772-sword-vfx` at
`/Users/sergeyfomin/.codex/worktrees/9161/AI Agent`  
Locked paths: `assets/sprites/effects/vfx_weapon_sword.png`,
`docs/design/references/weapon_attack_animations/sword/`,
`docs/design/previews/weapon_attack_animations/sword_contact.png`, this task
mirror. `scenes/TwoHandedSword.tscn` and
`assets/sprites/weapons/two_handed_sword.png` are read/reference only unless
integration proves required.  
Next verification: PixelLab source/runtime PNG, static alpha/readability checks,
then `unique_weapon_vfx_assets_test.gd` and `attack_vfx_smoke_test.gd` through
`tools/godot_gate.py`.

## Результат (2026-07-01)

Статус: done → Jira `Контроль качества` после commit/push.

- Runtime: `assets/sprites/effects/vfx_weapon_sword.png` обновлён, 256x256 RGBA,
  corners alpha=0, max alpha=170, fully opaque pixels=0, visible coverage
  alpha>12 = 24.22%, transparent pixels = 63.53%.
- PixelLab MCP used:
  - selected source object `35b2c714-97cc-4e65-978d-dbb8b0b8241e`;
  - rejected source object `ede25074-3e87-4e18-b535-740d2e0b4d3a` because it
    had a baked square/border field.
- Source/evidence:
  - `docs/design/references/weapon_attack_animations/sword/manifest.json`;
  - `docs/design/references/weapon_attack_animations/sword/pixellab_source_object_35b2c714.png`;
  - `docs/design/references/weapon_attack_animations/sword/pixellab_source_object_35b2c714_alpha_cutout.png`;
  - `docs/design/references/weapon_attack_animations/sword/vfx_weapon_sword_pixellab_composite_256.png`;
  - `docs/design/previews/weapon_attack_animations/sword_contact.png`.
- Visual result: old bright magenta crescent replaced with a calmer steel/gold
  two-handed sword cleave. The final plate uses the PixelLab sword silhouette
  plus a transparent 90-degree frustum support layer to show the sword's
  direction/reach while staying semi-transparent.
- Mechanics/runtime: no scene, script, damage, cooldown, targeting, radius,
  knockback, balance, or shared runtime logic changed.
- Tests:
  - `GODOT_BIN=/private/tmp/fsd_godot_sem/bin/fdengine FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/unique_weapon_vfx_assets_test.gd` — PASS, 51 plates.
  - `GODOT_BIN=/private/tmp/fsd_godot_sem/bin/fdengine FSD_GODOT_SLOTS=1 python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd` — PASS.
  - Note: the gate's fresh import pre-step hung in this disposable worktree
    because Godot import did not write `.ctex` files after the first scan; I used
    a temporary asset-only `.godot/imported` cache copied from the main checkout
    for smoke execution, then removed it.
- Disk cleanup: removed temporary `.godot`, ignored `build/qa/scrum772`, and
  temporary `docs/design/references/chars_cartoon/.gdignore`; none left.
