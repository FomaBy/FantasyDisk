# Задача Для Design-Агента: 6 Дополнительных D&D-Фонов Арены 2K

Статус: done
Создано: 2026-06-12
Автор: direct user request
Роль: Design
Приоритет: high

## Запрос

Пользователь попросил нарисовать 6 фонов для боев в 2K в стилистике D&D, как самые первые удачные варианты, но с меньшим количеством больших камней и кустов. Фоны должны быть антуражные, красивые и пригодные для игрового поля.

## Result Summary

Добавлены 6 новых native 2560x1440 top-down battle backgrounds:

- `assets/backgrounds/field_ruined_courtyard.png`
- `assets/backgrounds/field_misty_marsh.png`
- `assets/backgrounds/field_dusty_badlands.png`
- `assets/backgrounds/field_enchanted_meadow.png`
- `assets/backgrounds/field_ashen_rift.png`
- `assets/backgrounds/field_cursed_grove.png`

Правила визуала:
- D&D/tabletop battlemap style;
- low-contrast gameplay-readable ground;
- без больших камней/кустов/стен/деревьев/объектов, которые читаются как препятствия;
- мелкая наземная фактура распределена по всей арене;
- нативный размер арены 2560x1440.

Integration:
- Новые фоны добавлены в `scripts/main.gd::ARENA_BACKGROUND_OPTIONS`.
- Обычные бои получают 10-фонный пул.
- Боссы получают более драматичный пул: `stone_garden`, `dry_road`, `ruined_courtyard`, `ashen_rift`, `cursed_grove`.

QA:
- Contact sheet: `docs/design/previews/arena_backgrounds_6_dnd_contact.png`.
- Все 6 PNG проверены как `2560x1440`.
- Godot import completed.

Docs:
- `docs/design/content_registry.md`
- `docs/design/current_game_state.md`
- `docs/design/systems/visual_style_assets.md`
- `CHANGELOG.md`
