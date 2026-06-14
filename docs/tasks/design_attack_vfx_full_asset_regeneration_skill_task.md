# Задача Для Design/Codex: Полная Перегенерация Attack VFX Через Skill

Статус: new
Создано: 2026-06-14
Автор: Codex handoff из SCRUM-335
Исполнитель: Design / Codex
Версия: 0.1.5
Jira: SCRUM-337

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Blocker History — 2026-06-14
В текущем окружении отсутствует `OPENAI_API_KEY`, поэтому skill `fantasydisk-asset-generator` не может вызвать OpenAI Images API (`gpt-image-2`). Старые локальные генераторы `tools/generate_*vfx*.py` не использовать: пользовательская директива требует генерацию графики/ассетов только через skill.

## Blocker Resolved — 2026-06-14
Documentation dispatcher verified that local `OPENAI_API_KEY` can now be loaded
from the secure Codex env file outside the repository and Python `openai` imports
successfully. Previous asset-generator environment blocker is resolved; task is
eligible for Design/Codex execution after the currently active Design task.

## Контекст
Пользователь попросил переработать все эффекты атак персонажей и монстров реалистично и в стиле игры. SCRUM-335 закрыл runtime-покрытие существующими ассетами: `BerserkWeapon` теперь использует `vfx_weapon_*` signature layer, а enemy projectile получил textured trail/impact. Эта задача остается для полноценного нового art pass через Images API skill.

## Scope
- Сгенерировать новый cohesive reference/source pack через:

```bash
python3 /Users/sergeyfomin/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py \
  --prompt "<attack VFX pack prompt>" \
  --output "attack_vfx_realistic_dark_fantasy/<file>.png" \
  --size <WxH> \
  --quality high
```

- Покрыть минимум:
  - generic player VFX: slash, impact ring/flash, beam strip, sound wave, void orb, music note, dust puffs;
  - 51 `vfx_weapon_<weapon_id>.png` signature plates;
  - enemy projectile magic orb/trail/impact;
  - elite/boss hazard textures and helper VFX currently routed through `HazardVfx`;
  - persistent pools: poison/spark/briar.
- Все source/reference PNG сохранять в `docs/design/references/attack_vfx_realistic_dark_fantasy/`.
- Финальные runtime PNG переносить в `assets/sprites/effects/` и `assets/sprites/projectiles/` только после visual QA/crop/alpha cleanup.
- Сохранить прозрачный фон, читаемый combat-scale silhouette, no text/watermark, D&D + Dark Fantasy Dragon style.

## Acceptance Criteria
- [ ] `OPENAI_API_KEY` доступен в окружении и generation script успешно создает reference PNG.
- [ ] Новый pack просмотрен, очищен под alpha и нарезан/экспортирован в runtime paths.
- [ ] Gameplay timing/damage/targeting не изменены.
- [ ] `attack_vfx_smoke_test`, `hazard_vfx_smoke_test`, `enemy_projectile_smoke_test`, `runtime_smoke_test` проходят.
- [ ] `docs/design/content_registry.md`, `docs/design/current_game_state.md`, `docs/design/systems/visual_style_assets.md` и `CHANGELOG.md` обновлены.


## Ключ настроен — блокер снят (2026-06-14)
`OPENAI_API_KEY` фактически сохранён в `~/.codex/.env` (права 600, вне git) +
автозагрузка в `~/.zshrc` — доступен в окружении автоматически в каждом новом
shell (включая shell Codex-воркеров). Скилл `fantasydisk-asset-generator`
(gpt-image-2) готов к вызову. Блокер по отсутствию `OPENAI_API_KEY` снят
окончательно; задача готова к исполнению через скилл.

## Blocked Again — 2026-06-14
Design queue audit after SCRUM-352 confirmed this task still requires full
attack VFX regeneration through `fantasydisk-asset-generator` / OpenAI Images
(`gpt-image-2`) and disallows old/local/random generators. The current approved
env source is available, but OpenAI Images returns:

```text
billing_hard_limit_reached
```

Task is blocked until OpenAI image generation billing is available again or PM
provides an approved alternative generation source.

## Разблокировано 2026-06-14 (PM)
Биллинг OpenAI восстановлен и ПРОВЕРЕН: тестовая генерация gpt-image-2 успешна. Блок `billing_hard_limit_reached` устарел — снят. Можно генерить скиллом.
