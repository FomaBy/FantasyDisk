# Задача Для Back-end-Агента: Source-Specific Спрайты Призывных Союзников

Статус: new
Версия: 0.1.4
Создано: 2026-06-12
Связано: SCRUM-152
Jira: TBD

## Autonomy / Approval

Пользователь заранее одобрил in-scope изменения. Подтверждение не спрашивать.

## Контекст

Design/Codex task `docs/tasks/design_codex_summon_allies_sprites_task.md` подготовила raster PNG для всех активных/ожидаемых союзных summon/deployable сущностей:

- `assets/sprites/allies/ally_druid_beast.png`;
- `assets/sprites/allies/ally_druid_pack_spirit.png`;
- `assets/sprites/allies/ally_homunculus.png`;
- `assets/sprites/allies/ally_leadership_echo.png`;
- `assets/sprites/allies/deploy_sound_amp_field.png`;
- `assets/sprites/allies/deploy_raven_totem_field.png`.

`scenes/AllyMinion.tscn` получил безопасный fallback visual `ally_druid_beast.png`, чтобы общий миньон больше не был Polygon2D-placeholder. Но `summon_amulet` и `homunculus_vial` сейчас оба инстанцируют один `AllyMinion.tscn`, поэтому Design не может различить источник без runtime selector.

## Что Нужно От Back-end

1. Добавить source-specific visual selection для `AllyMinion`:
   - `summon_amulet` -> `ally_druid_beast.png` или `ally_druid_pack_spirit.png` с легкой вариативностью;
   - `homunculus_vial` -> `ally_homunculus.png`;
   - будущие/универсальные Leadership echo nodes -> `ally_leadership_echo.png`.
2. Передавать source ID из `scripts/summoner_weapon.gd` в spawned ally (`weapon_id` или отдельный `ally_visual_id`).
3. Для deployable amp visuals:
   - `sound_amp` runtime deployable -> `deploy_sound_amp_field.png`;
   - `raven_totem` runtime deployable -> `deploy_raven_totem_field.png`.
   Сейчас `ClassWeapon._fire_amp()` берет `_weapon_visual_texture()`, то есть weapon icon/sprite; лучше добавить optional deploy texture path/config.
4. Если продуктово требуется видимая стая ульты Друида и полевые Leadership echoes, заменить instant-only behavior на короткоживущие визуальные ally/echo nodes без изменения баланса урона.

## Files / Assets / IDs

- `scripts/summoner_weapon.gd`
- `scripts/ally_minion.gd`
- `scenes/AllyMinion.tscn`
- `scripts/class_weapon.gd`
- `scenes/SoundAmp.tscn`
- `scenes/RavenTotem.tscn`
- `scripts/player.gd`
- `assets/sprites/allies/*.png`

## Acceptance Criteria

- Друидские питомцы, химикский гомункул, Leadership echo и deployable amp/totem визуально различаются по source.
- Fallback `ally_druid_beast.png` остается fail-safe, но не единственным runtime-визуалом.
- Cleanup groups (`allies`, `player_weapon_effects`, `deployed_sound_amps`) продолжают работать.
- Runtime smoke green после интеграции.

## Документация

Обновить `docs/design/current_game_state.md`, `docs/design/systems/characters_weapons.md` и `docs/design/content_registry.md`, если меняются runtime mappings.
