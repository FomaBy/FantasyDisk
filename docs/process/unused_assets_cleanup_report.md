# Отчет: Аудит И Очистка Неиспользуемых Ассетов

Дата: 2026-06-11
Исполнитель: Back-end-агент
Задача: `docs/tasks/backend_unused_assets_cleanup_task.md`

## Метод

Скрипт `tools/audit_unused_assets.py` построил карту ссылок: каждый файл из `assets/` и корня проверен по `scenes/*.tscn`, `scripts/*.gd`, `tests/*.gd`, `tools/*`, `project.godot`, `export_presets.cfg`. Динамические пути учтены:

- `assets/sprites/ui/icons/artifacts/` и `.../shop/` — имена строятся из игровых ID (`artifact_<id>.png`); файлы сверены с ID из `progression_data.gd`, лишних не найдено;
- каталоги `rig_parts/` (characters/enemies/elites/bosses) сохранены целиком — пути строятся динамически ригом и активно меняются Animator-агентом;
- иконки stats/derived/hud, фоны, map_icons, frames, effects, audio — ссылки найдены строками в коде.

Неиспользуемые файлы НЕ удалены, а перемещены в `build/unused_assets_backup/` с сохранением структуры каталогов и парных `.import`. Полный машинный список: `build/unused_assets_moved.txt`.

## Перемещено (46 файлов + парные .import, всего 91)

### Нет ссылок в tscn/gd/project.godot/export_presets (45)

- `assets/.DS_Store`
- `assets/sprites/boss_warden.svg`
- `assets/sprites/bosses/source/boss_disk_devourer_source.png`
- `assets/sprites/bosses/source/boss_rift_warden_source.png`
- `assets/sprites/characters/berserk_animated.png`
- `assets/sprites/characters/melee_axe.png`
- `assets/sprites/characters/ranged_bow.png`
- `assets/sprites/characters/summoner_staff.png`
- `assets/sprites/enemies/elite_armored.png`
- `assets/sprites/enemies/elite_commander.png`
- `assets/sprites/enemies/elite_poisoned.png`
- `assets/sprites/enemies/elite_stalker.png`
- `assets/sprites/enemies/source/elite_armored_source.png`
- `assets/sprites/enemies/source/elite_commander_source.png`
- `assets/sprites/enemies/source/elite_poisoned_source.png`
- `assets/sprites/enemies/source/elite_stalker_source.png`
- `assets/sprites/enemies/source/enemy_bruiser_slow_source.png`
- `assets/sprites/enemies/source/enemy_melee_source.png`
- `assets/sprites/enemies/source/enemy_ranged_source.png`
- `assets/sprites/enemies/source/enemy_suicide_runner_source.png`
- `assets/sprites/enemies/source/enemy_summoner_source.png`
- `assets/sprites/enemy_biter.png`
- `assets/sprites/enemy_bruiser.svg`
- `assets/sprites/enemy_mage.png`
- `assets/sprites/enemy_melee.svg`
- `assets/sprites/enemy_runner.svg`
- `assets/sprites/enemy_shield.png`
- `assets/sprites/enemy_shooter.svg`
- `assets/sprites/enemy_spitter.png`
- `assets/sprites/map_icons/source/map_battle_skull_source.png`
- `assets/sprites/map_icons/source/map_boss_disk_devourer_source.png`
- `assets/sprites/map_icons/source/map_boss_rift_warden_source.png`
- `assets/sprites/map_icons/source/map_elite_skull_bones_source.png`
- `assets/sprites/map_icons/source/map_event_question_source.png`
- `assets/sprites/map_icons/source/map_shop_tent_source.png`
- `assets/sprites/player_berserk.svg`
- `assets/sprites/player_ranger.svg`
- `assets/sprites/player_summoner.svg`
- `assets/sprites/projectiles/enemy_projectile_magic.png`
- `assets/sprites/projectiles/enemy_projectile_magic_128.png`
- `assets/sprites/projectiles/enemy_projectile_magic_cropped.png`
- `assets/sprites/projectiles/enemy_projectile_magic_minimal.png`
- `assets/sprites/ui/source/derived_icons_source.png`
- `assets/sprites/ui/source/hud_icons_source.png`
- `assets/sprites/ui/source/stats_icons_source.png`

### Дубликат icon.svg в корне проекта (1)

- `icon 2.svg`

## Оставлено Сознательно

- `assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png` и `ui_stat_value_state_swatches.png` — задокументированы в `docs/design/escape_stats_visual_kit.md` как design reference (not required at runtime);
- все каталоги `rig_parts/` — динамический rig-каркас;
- `.keep-awake.sh.swp` в корне — vim swap-файл пользователя, не ассет (рекомендуется удалить вручную).

## Сверка С content_registry

Перемещенные файлы — устаревшие прототипные спрайты (svg-болванки, старые elite/enemy версии до редизайна, `*_source.png` исходники до visual redesign, старые варианты снарядов) и дубль `icon 2.svg`. Ни один не является активным ассетом сущности из реестра: активные пути реестра указывают на новые версии в `assets/sprites/elites/`, `assets/sprites/enemies/` и т.д. Расхождений «реестр ссылается на перемещенный файл» не найдено.

## Проверка

- `runtime_smoke_test.gd` — пройден;
- `animation_smoke_test.gd` — пройден;
- `meta_progression_smoke_test.gd` — пройден;
- консоль без ошибок загрузки текстур (missing texture).

## Восстановление

Любой файл можно вернуть из `build/unused_assets_backup/` обратно по тому же относительному пути.
