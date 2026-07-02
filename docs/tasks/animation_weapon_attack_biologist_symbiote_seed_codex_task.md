# Animation: Семя Симбионта (biologist_symbiote_seed) attack VFX redraw

Статус: new
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: Codex Animator
Thread: codex-animator-auto
Версия: 0.2.0
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-732
Locked paths: assets/sprites/effects/vfx_weapon_biologist_symbiote_seed.png, docs/design/references/weapon_attack_animations/biologist_symbiote_seed/, docs/design/previews/weapon_attack_animations/biologist_symbiote_seed_contact.png, scenes/BiologistSymbioteSeed.tscn, assets/sprites/weapons/biologist_symbiote_seed.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `biologist_symbiote_seed` / **Семя Симбионта** класса **Биолог**.
Текущая механическая роль: Symbiote web: первичная цель связывается с соседними врагами и делит биоурон по сети.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/biologist_symbiote_seed/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_biologist_symbiote_seed.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `biologist_symbiote_seed` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Семя Симбионта**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Symbiote web: первичная цель связывается с соседними врагами и делит биоурон по сети. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `biologist_symbiote_seed` использовать reference `assets/sprites/weapons/biologist_symbiote_seed.png` и текущую сцену `scenes/BiologistSymbioteSeed.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [ ] `assets/sprites/effects/vfx_weapon_biologist_symbiote_seed.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [ ] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [ ] Attack VFX уникально отражает **Семя Симбионта**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [ ] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [ ] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `biologist_symbiote_seed` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Result 2026-07-01 — Blocked

Worker: `codex-animator-auto`
Issue: SCRUM-732

Attempted the mandated OpenAI Images override through the repository helper:

```bash
python3 skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py --no-task --quality high --size 1024x1024 --output docs/design/references/weapon_attack_animations/biologist_symbiote_seed/biologist_symbiote_seed_openai_source.png --prompt "<symbiote web VFX prompt>"
```

The helper failed before writing a source PNG because OpenAI returned
`billing_hard_limit_reached` (`Billing hard limit has been reached`). Per the
helper and active task rules, no hand-drawn or non-OpenAI substitute was created.

Generated/runtime files: none.
Tests: not run; blocked before asset generation.
Disk cleanup: none created.

## Result 2026-07-01 — Blocked Retry

Worker: `codex-animator-auto`
Issue: SCRUM-732

Retried the mandated OpenAI Images override through the repository helper after
claiming the Jira issue:

```bash
python3 skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py --no-task --quality high --size 1024x1024 --output docs/design/references/weapon_attack_animations/biologist_symbiote_seed/biologist_symbiote_seed_openai_source.png --prompt "<symbiote seed web VFX prompt>"
```

The helper failed before writing a source PNG because OpenAI returned
`billing_hard_limit_reached` (`Billing hard limit has been reached`). Per the
task override and helper rules, no PixelLab, hand-drawn, or non-OpenAI substitute
was created.

Generated/runtime files: none.
Tests: not run; blocked before asset generation.
Disk cleanup: removed the empty retry-only evidence directory; no other transient
artifacts created.

## Dispatcher Unblock — PixelLab path (2026-07-01)

Direct user directive 2026-07-01: remove blockers and continue autonomously.
The previous OpenAI Images-only path remains blocked by `billing_hard_limit_reached`,
so Jira was unblocked by switching this attack-VFX task to the mandatory
PixelLab MCP / `fantasydisk-asset-generator` production path. Future workers must
record the PixelLab object/job id, source/runtime paths, static alpha/readability
evidence, Godot smoke results, and `Disk cleanup:` in the final result.
