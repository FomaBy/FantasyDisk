# ART: Перерисовать все подложки уровней (арена-фоны) в новом стиле скиллом

Статус: new
Приоритет: high
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-369
Связано: SCRUM-324 (asset-skill), SCRUM-327 (стиль UI Overhaul), SCRUM-298 (перерисовка персонажей)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Перерисовать все подложки уровней (background images) в новом стиле по
референсам нашей игры, используя новый скилл — должно быть реалистично и подходить
под анимации монстров и персонажей».

Арена-фоны: `ARENA_BACKGROUND_OPTIONS` (scripts/main.gd:41+), файлы
`assets/backgrounds/field_*.png`, размер 2560×1440 (ARENA_SIZE). Подключаются в
бою через combat_director.gd:751. Прошлый проход — design_arena_backgrounds_2k_native (done);
сейчас обновляем под новый единый стиль.

## ОБЯЗАТЕЛЬНО — скилл генерации (директива пользователя)
Перерисовывать скиллом `fantasydisk-asset-generator`
(`generate_asset.py --prompt "<...>" --output backgrounds/<id> --size 2560x1440
--quality high`, OpenAI Images, `gpt-image-2`, PNG). ВАЖНО: это ОПАКОВЫЕ фоны
(не прозрачные — заливка всей сцены), а не UI-рамки. Исходники в
docs/design/references/backgrounds/, внедрить в assets/backgrounds/. Старые — в бэкап.

## Список подложек (10; 2 сейчас отсутствуют в ассетах)
field_marsh, field_meadow, field_misty_marsh, field_ruined_courtyard,
field_dusty_badlands, field_enchanted_meadow, field_ashen_rift, field_cursed_grove
(есть, 2560×1440) + field_dry_road, field_stone_garden (в коде есть, ФАЙЛОВ НЕТ —
сгенерировать тоже, либо убрать мёртвые ссылки в main.gd по согласованию).

## Требования
1. Перерисовать ВСЕ подложки уровней в едином стиле D&D + Dark Fantasy Dragon,
   **реалистично**, по референсам игры (docs/design/references/ + общий стиль
   SCRUM-327). Каждый биом узнаваем (марш/луг/руины/пустошь/проклятая роща/разлом и т.д.).
2. **Совместимость с геймплеем (top-down арена)**: фон читаем как пол арены сверху;
   персонажи/монстры/снаряды/VFX поверх ОСТАЮТСЯ ЧИТАЕМЫМИ — не слишком пёстрый/
   контрастный в игровой зоне, без визуального шума, забивающего спрайты.
3. **Подходить под анимации монстров и персонажей**: единое направление света и
   перспектива, согласованные с перерисованными спрайтами (SCRUM-298 персонажи,
   арт монстров) — чтобы герои/мобы «лежали» на фоне естественно, тени совпадали.
4. 2560×1440; края без резких швов (камера панорамирует по 2K-арене); запас по
   краям, чтобы не было пустот при зуме (см. backend_map_2k_camera_zoom).
5. Сгенерировать недостающие field_dry_road, field_stone_garden или убрать их из
   ARENA_BACKGROUND_OPTIONS (не оставлять битые ссылки на отсутствующие файлы).
6. Тест (smoke): бой строится на каждом фоне без ошибок; фон грузится, спрайты
   читаемы поверх. Контакт-лист всех фонов в docs/design/previews/ + скрин боя в build/qa/.
7. CHANGELOG; content_registry; current_game_state; systems/visual_style_assets.

## Files / Assets / IDs
- scripts/main.gd (ARENA_BACKGROUND_OPTIONS 41+; биомы default/battle/boss)
- scripts/combat_director.gd (751 выбор фона)
- assets/backgrounds/field_*.png (перерисовать; + бэкап старых)
- docs/design/references/backgrounds/ (исходники скилла)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Все 10 подложек уровней перерисованы скиллом в едином стиле D&D + Dark Fantasy Dragon, реалистично, 2560×1440.
- [ ] Спрайты персонажей/монстров читаемы поверх; свет/перспектива согласованы с анимациями (SCRUM-298).
- [ ] Недостающие field_dry_road/field_stone_garden сгенерированы или ссылки убраны (нет битых путей).
- [ ] Старые в бэкап; края без швов; smoke зелёный; контакт-лист+скрин боя; CHANGELOG.

## Документация
docs/design/systems/visual_style_assets.md, content_registry, current_game_state.
