# Задача Для Back-end-Агента: Source-Specific Спрайты Призывных Союзников

Статус: done
Версия: 0.1.4
Создано: 2026-06-12
Связано: SCRUM-152
Jira: SCRUM-157

Dispatcher note 2026-06-13: Jira/task linkage is valid (`SCRUM-157`) and the
feature block is lifted. Added to the local board queue and dispatched to
Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`.

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

## Result Summary — 2026-06-13

Back-end integration complete.

- `AllyMinion` now exposes `ally_visual_id` and applies source-specific textures through a safe visual map with `ally_druid_beast` fallback.
- `summoner_weapon.gd` passes `ally_visual_id` / `ally_visual_ids` from weapon config into spawned allies.
- `summon_amulet` randomly uses `ally_druid_beast` or `ally_druid_pack_spirit`; `homunculus_vial` uses `ally_homunculus`; `leadership_echo` is reserved in the map for future echo summons.
- `class_weapon.gd` supports optional `deploy_texture_path`; `sound_amp` uses `deploy_sound_amp_field.png`, `raven_totem` uses `deploy_raven_totem_field.png`.
- Cleanup groups and balance values were not changed.
- Runtime smoke extended to verify sound amp deploy sprite, Druid summon sprite, Chemist homunculus sprite, and Raven totem deploy sprite.

Verification:

`/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`

Result: passed.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED (SCRUM-157)

Проверено фактически (код + рендер + smoke):
- Source-specific визуал: `ally_minion.gd` — `ALLY_VISUAL_PATHS` (druid_beast/pack_spirit/
  homunculus/leadership_echo), `@export ally_visual_id`, `set_visual_id()`+`_apply_visual()`
  (грузит Texture2D по пути, fallback на druid_beast). ✓
- Передача source: `summoner_weapon.gd` читает `ally_visual_id`/`ally_visual_ids` из
  config (27-31), `_selected_ally_visual_id()` (75) → `ally.set("ally_visual_id", ...)`
  (79). summon_amulet→druid beast/pack (вариативность), homunculus_vial→homunculus. ✓
- Deploy-текстуры: `deploy_texture_path` в progression_data (sound_amp:464,
  raven_totem:692) потребляется в `class_weapon._fire_amp` (1928-1929 load Texture2D). ✓
- РЕНДЕР AllyMinion(set_visual_id "druid_beast"): Sprite2D с texture=
  `ally_druid_beast.png`, **Polygon2D_count=0** — плейсхолдера больше нет, реальный
  спрайт виден. Скрин: build/qa/ally_sprite_integration/.
- 6 smoke зелёные (clean worktree). Багов нет.
