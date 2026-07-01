# Animation: Споровая Линза (biologist_spore_lens) attack VFX redraw

Статус: blocked
Приоритет: medium
Роль: Animator / VFX
Исполнитель: Codex
Контур: Codex
Owner: unassigned
Thread: n/a
Branch/worktree: detached dev at `/Users/sergeyfomin/.codex/worktrees/f057/AI Agent`
Blocked: OpenAI Images API billing hard limit still reached during repo helper generation on 2026-07-01; Jira returned to `К выполнению` with `blocked` label until billing/quota is restored or PM changes the generation pipeline.
Next verification: after unblock, generate OpenAI source via repo helper, postprocess to 256x256 transparent runtime VFX, then run unique weapon VFX and attack VFX smokes.
Версия: 0.1.8
Создано: 2026-06-30
Автор: Codex Documentation dispatcher (запрос пользователя)
Jira: SCRUM-731
Locked paths: assets/sprites/effects/vfx_weapon_biologist_spore_lens.png, docs/design/references/weapon_attack_animations/biologist_spore_lens/, docs/design/previews/weapon_attack_animations/biologist_spore_lens_contact.png, scenes/BiologistSporeLens.tscn, assets/sprites/weapons/biologist_spore_lens.png

## Контекст

Пользователь попросил отдельную задачу на каждое оружие: перерисовать анимацию атаки так, чтобы она отражала вид оружия, была уникальной, показывала область действия, оставалась полупрозрачной как текущие эффекты, не перекрывала важные элементы экрана и во время атаки показывала силуэт/призрак оружия на фоне эффекта.

Это задача только для `biologist_spore_lens` / **Споровая Линза** класса **Биолог**.
Текущая механическая роль: Spore bloom: три расширяющихся споровых кольца выращиваются на цели и наносят убывающий урон.

## Обязательный пайплайн генерации

User override 2026-06-30: для этой задачи использовать OpenAI image generation, а не PixelLab. Генерировать через репозиторный helper `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py` / `gpt-image-2` с `--quality high`, фиксируя override в result/evidence.

Source PNG и prompt notes сохранить в `docs/design/references/weapon_attack_animations/biologist_spore_lens/`. Accepted runtime PNG обновлять только по пути `assets/sprites/effects/vfx_weapon_biologist_spore_lens.png`, если не создан отдельный backend/runtime handoff.

## Требования

1. Сделать attack VFX/animation для `biologist_spore_lens` уникальным: форма, движение, цветовой акцент и weapon silhouette должны читаться как **Споровая Линза**, а не как generic recolor.
2. Визуально показать область действия из роли оружия: Spore bloom: три расширяющихся споровых кольца выращиваются на цели и наносят убывающий урон. Форма зоны должна помогать игроку понять направление/радиус/коридор/пул/цепь без изменения реальной механики.
3. Сохранить спокойную полупрозрачность текущего боевого слоя: эффект не должен закрывать игрока, врагов, projectiles, pickups, HP bars, HUD или popup UI; центр зоны по возможности остаётся readable/transparent.
4. Во время атаки должен появляться ghost/silhouette самого оружия на фоне эффекта, как уже сделано у части текущих персонажей. Для `biologist_spore_lens` использовать reference `assets/sprites/weapons/biologist_spore_lens.png` и текущую сцену `scenes/BiologistSporeLens.tscn`.
5. Не менять damage, cooldown, targeting, attack range, aoe radius, knockback, lifesteal, summon/deploy limits или баланс. Если для настоящей frame animation нужен общий runtime API, создать отдельный Back-end handoff и не править shared scripts в этой per-weapon задаче.
6. Не трогать VFX других оружий и не регенерировать общий pack. Один таск = один `weapon_id`.

## Acceptance Criteria

- [ ] `assets/sprites/effects/vfx_weapon_biologist_spore_lens.png` обновлен или подтверждён как accepted с новым OpenAI source/evidence.
- [ ] Source, prompt notes/manifest и preview/contact sheet сохранены в task-specific paths.
- [ ] Attack VFX уникально отражает **Споровая Линза**, показывает зону действия и содержит полупрозрачный фоновой силуэт оружия.
- [ ] Визуал не перекрывает HUD/важные world elements на боевом масштабе; alpha/readability проверены на тёмном и светлом фоне.
- [ ] Геймплейные параметры и shared runtime logic не изменены без отдельного handoff.
- [ ] Пройдены `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`; если менялись animation/runtime hooks — также `animation_smoke_test.gd` и `runtime_smoke_test.gd` через `tools/godot_gate.py`.
- [ ] Обновлены `docs/design/content_registry.md` или `docs/design/current_game_state.md`, если runtime path/contract/evidence изменились.

## QA Notes

QA проверяет именно `biologist_spore_lens` в игре: эффект виден при атаке, полупрозрачен, не заслоняет UI и отличим от соседних weapon VFX. Disk cleanup обязателен: удалить временные OpenAI/source scratch caches, оставить только committed source/evidence/runtime files.

## Blocker / 2026-07-01

Result: blocked / released from active worker.

Generation command attempted through the task-mandated OpenAI helper:

```bash
python3 skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py --prompt "<biologist_spore_lens spore bloom VFX prompt>" --output docs/design/references/weapon_attack_animations/biologist_spore_lens/biologist_spore_lens_openai_source.png --size 1024x1024 --quality high --no-task
```

The helper failed before writing a source PNG:

```text
OpenAI billing/quota problem: billing_hard_limit_reached / Billing hard limit has been reached.
```

Per the active task override and `fantasydisk-asset-generator` skill, no PixelLab/manual fallback was used. Jira `SCRUM-731` was returned to `К выполнению`, labelled `blocked`, and commented with the exact blocker.

Disk cleanup: none created.

## Unblocked / 2026-07-01

User removed hold/blockers and asked to continue. Jira `SCRUM-731` was claimed by
`codex-design-auto` for Animator/Codex work. Locked paths remain limited to the
task-specific VFX runtime asset, OpenAI source/evidence folder, contact preview,
and read-only weapon/scene references listed above.

## Blocker Retry / 2026-07-01

Result: blocked / released from active worker.

After user unhold, Codex retried the required OpenAI helper in worktree
`/Users/sergeyfomin/.codex/worktrees/f057/AI Agent`:

```bash
python3 skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py --prompt "<biologist_spore_lens spore bloom VFX prompt>" --output docs/design/references/weapon_attack_animations/biologist_spore_lens/biologist_spore_lens_openai_source.png --size 1024x1024 --quality high --no-task
```

The helper failed before writing a source PNG:

```text
OpenAI billing/quota problem: billing_hard_limit_reached / Billing hard limit has been reached.
```

Per the task override and `fantasydisk-asset-generator` skill, no PixelLab/manual
fallback was used. Jira `SCRUM-731` was returned to `К выполнению`, labelled
`blocked`, and commented with the exact blocker. The same verified blocker was
also recorded on the current-sprint `openai-images` attack VFX tasks so they are
not claimed until billing/quota is fixed or PM changes the generation pipeline.

Disk cleanup: none created.
