# Задача Для Design/Codex: Полная Перегенерация Attack VFX Через Skill

Статус: blocked
Создано: 2026-06-14
Автор: Codex handoff из SCRUM-335
Исполнитель: Design / Codex
Версия: 0.1.5
Jira: SCRUM-337

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Блокер
В текущем окружении отсутствует `OPENAI_API_KEY`, поэтому skill `fantasydisk-asset-generator` не может вызвать OpenAI Images API (`gpt-image-2`). Старые локальные генераторы `tools/generate_*vfx*.py` не использовать: пользовательская директива требует генерацию графики/ассетов только через skill.

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
