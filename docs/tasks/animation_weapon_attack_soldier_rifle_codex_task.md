# Animation: Аркебуза строя (soldier_rifle) attack VFX redraw

Статус: done
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Animator/VFX Codex
Thread: codex-scrum-768-soldier-rifle-vfx-e7d2
Версия: 0.1.8
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-768
Locked paths: assets/sprites/effects/vfx_weapon_soldier_rifle.png, docs/design/references/weapon_attack_animations/soldier_rifle/, docs/design/previews/weapon_attack_animations/soldier_rifle_contact.png, scenes/SoldierRifle.tscn, assets/sprites/weapons/soldier_rifle.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `soldier_rifle` / **Аркебуза строя** класса **Солдат**.
Текущая механическая роль: Suppression burst: 3 коротких выстрела по линии; основная цель полный урон, соседи reduced damage.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/soldier_rifle/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_soldier_rifle.png`, если не создан отдельный backend/runtime handoff.

Superseded 2026-07-01: Jira dispatcher unblock and direct user delegation moved
this task back to the mandatory PixelLab-first path. No OpenAI Images fallback
or legacy generated asset helper was used in the completed implementation.

## Требования

1. Сделать attack VFX/animation для `soldier_rifle` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Аркебуза строя**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Suppression burst: 3 коротких выстрела по линии; основная цель полный урон, соседи reduced damage. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `soldier_rifle` использовать reference `assets/sprites/weapons/soldier_rifle.png` и текущую сцену `scenes/SoldierRifle.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [x] `assets/sprites/effects/vfx_weapon_soldier_rifle.png` обновлен с новым PixelLab source/evidence.
- [x] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [x] Attack VFX уникально отражает **Аркебуза строя**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [x] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [x] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [x] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [x] Broad docs не обновлялись: runtime path/contract не менялись, delegation запрещал broad shared docs без явной необходимости.

## QA Notes

QA проверяет именно `soldier_rifle` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.

## Result — 2026-07-01

- PixelLab object: `e259ff57-39e2-42d5-992b-fab02387b59b`.
- Runtime asset: `assets/sprites/effects/vfx_weapon_soldier_rifle.png`.
- Source/evidence:
  `docs/design/references/weapon_attack_animations/soldier_rifle/soldier_rifle_pixellab_source_raw.png`,
  `docs/design/references/weapon_attack_animations/soldier_rifle/soldier_rifle_pixellab_source.png`,
  `docs/design/references/weapon_attack_animations/soldier_rifle/manifest.json`,
  `docs/design/references/weapon_attack_animations/soldier_rifle/prompt_notes.md`,
  `docs/design/references/weapon_attack_animations/soldier_rifle/static_alpha_readability_report.json`.
- Preview/contact sheet:
  `docs/design/previews/weapon_attack_animations/soldier_rifle_contact.png`.
- Static alpha/readability: `256x256 RGBA`, corner alpha `[0, 0, 0, 0]`,
  visible pixel ratio `0.1578`, max alpha `178`, center 64px mean alpha
  `56.51`, decision `pass`.
- Visual result: narrow three-shot arquebus firing lane with smoke/sparks and a
  low-opacity canonical soldier rifle ghost; no opaque disk/frame/UI text.
- Gameplay/runtime: no damage, cooldown, targeting, range, AoE, knockback,
  balance, scene, or shared runtime logic changed.
- Tests:
  `FSD_GODOT_SLOTS=4 python3 tools/godot_gate.py --headless --user-data-dir /tmp/fantasydisk-godot-scrum768-unique --path . --script res://tests/unique_weapon_vfx_assets_test.gd` -> passed (`Unique weapon VFX assets smoke passed: 51 plates.`);
  `FSD_GODOT_SLOTS=4 python3 tools/godot_gate.py --headless --user-data-dir /tmp/fantasydisk-godot-scrum768-attack --path . --script res://tests/attack_vfx_smoke_test.gd` -> passed (`Attack VFX smoke test passed.`);
  static PNG/readability assertion -> passed.
- Disk cleanup: remove `.godot/`, `/tmp/fantasydisk-godot-scrum768-*`, and
  transient `build/qa/scrum768/` before final report; no disposable clone was
  created.
