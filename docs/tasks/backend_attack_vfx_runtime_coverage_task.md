# Задача Для Back-end/Codex: Runtime-Покрытие VFX Атак Персонажей И Монстров

Статус: done
Создано: 2026-06-14
Автор: пользователь / Codex
Исполнитель: Codex
Версия: 0.1.5
Jira: SCRUM-335

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Пользователь попросил, используя skill `fantasydisk-asset-generator`, переработать все эффекты атак персонажей и монстров так, чтобы они выглядели реалистично и в стиле игры. Генерация новых PNG через skill сейчас заблокирована локальной средой: `OPENAI_API_KEY` не выставлен, а старый процедурный asset pipeline использовать нельзя по пользовательской директиве.

Чтобы не оставлять runtime без улучшений, этот Back-end/Codex проход закрывает доступную интеграционную часть: все существующие realistic/painterly VFX-ассеты должны использоваться на фактических путях атак, где они уже есть, но могли не подключаться.

## Требования
- Не менять урон, радиусы, cooldowns, target queries, wave balance или spawn logic.
- Подключить existing `vfx_weapon_<weapon_id>.png` signature layer к melee/BerserkWeapon атакам, которые обходили `ClassWeapon`.
- Улучшить enemy projectile runtime feedback существующими textured effects: trail во время полета и impact flash при попадании.
- Сохранить pause-aware/self-cleaning lifecycle.
- Обновить документацию по фактическому VFX-покрытию и явно зафиксировать blocker генерации новых ассетов через Images API.

## Acceptance Criteria
- [x] `BerserkWeapon` / melee weapons показывают dedicated weapon signature VFX для `sword`, `axe`, `hammer`, `long_spear`, `tower_shield`, `holy_flail`.
- [x] Enemy projectile имеет textured trail и impact feedback без изменения gameplay.
- [x] `attack_vfx_smoke_test`, `enemy_projectile_smoke_test`, `hazard_vfx_smoke_test` проходят.
- [x] Обновлены docs/current state или domain docs, если меняется runtime visual coverage.
- [x] Jira sync запущен после смены статуса.

## Решение / Ограничение
- Новые PNG через `fantasydisk-asset-generator` не генерируются в этом прогоне, потому что в среде отсутствует `OPENAI_API_KEY`.
- Старые локальные генераторы `tools/generate_*vfx*.py` не запускаются, чтобы не нарушать правило проекта: графика/ассеты генерируются только skill-ом.

## Результат 2026-06-14

- `scripts/berserk_weapon.gd` получил `_show_weapon_signature()`: melee/BerserkWeapon path теперь вызывает `AttackVfx.weapon_signature()` и показывает existing `vfx_weapon_*` plates для Berserk и Knight melee scenes без изменения урона, зон, cooldowns или targeting.
- `scripts/enemy_projectile.gd` получил textured `ProjectileTrailVfx` на `beam_strip.png` и self-cleaning `EnemyProjectileImpactVfx` на `impact_flash.png` + `impact_ring.png` при попадании по игроку. Collision mask, one-hit guard, lifetime, speed и damage не менялись.
- Тесты расширены: `tests/attack_vfx_smoke_test.gd` проверяет dedicated signatures для Berserk/Knight melee, `tests/enemy_projectile_smoke_test.gd` проверяет trail/impact.
- Документация обновлена: `CHANGELOG.md`, `docs/design/current_game_state.md`, `docs/design/content_registry.md`, `docs/design/systems/visual_style_assets.md`.
- Полная новая перегенерация attack VFX через skill вынесена в blocked Design/Codex handoff `docs/tasks/design_attack_vfx_full_asset_regeneration_skill_task.md` / Jira SCRUM-337, потому что `OPENAI_API_KEY` отсутствует в окружении.

Проверки:
- `attack_vfx_smoke_test` — PASS.
- `enemy_projectile_smoke_test` — PASS.
- `hazard_vfx_smoke_test` — PASS.
- `runtime_smoke_test` — PASS.
