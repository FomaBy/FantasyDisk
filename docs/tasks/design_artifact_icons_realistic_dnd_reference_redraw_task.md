# Задача Для Design-Агента: Реалистичные Epic D&D-Style Иконки Артефактов

Статус: done
Создано: 2026-06-12
Автор: пользователь / Codex dispatcher
Роль: Design
Приоритет: high

Dispatch 2026-06-12: передано в Design чат `019eabf1-6d54-7561-8af9-ce25cdf483a9`.
Эта задача supersedes `codex_design_artifact_icons_per_item_regen_task.md`: предыдущий
per-item pass не принимать как финальный арт, направление изменено пользователем.

## Autonomy / Approval
Пользователь заранее одобрил все in-scope изменения. Не спрашивать подтверждений.
Работать до финального набора иконок.

## Контекст
Пользователь хочет удалить/заменить текущий набор иконок артефактов и нарисовать
каждую заново, одну за другой, строго исходя из названия и смысла артефакта.

Новое направление: **реалистичные, эпичные предметы в духе Dungeon & Dragons /
tabletop fantasy magic items**. Это не cartoon-pictogram и не простой UI-symbol.
Каждая иконка должна выглядеть как настоящий ценный магический предмет из
фэнтези-сеттинга.

## Главное Требование
Перерисовать заново все активные `artifact_<id>.png` в:

```text
assets/sprites/ui/icons/artifacts/
```

Старые иконки не использовать как основу, кроме проверки имени/смысла. Файлы
заменить на месте с теми же именами.

## Обязательный Reference Research
Перед генерацией провести web/image research по референсам:

- Dungeon and Dragons magic items;
- D&D 5e wondrous items;
- fantasy RPG artifact icons;
- realistic magic item concept art;
- medieval fantasy relics, cursed artifacts, enchanted equipment.

Для каждого типа предмета искать 2-5 визуальных референсов по смыслу:
например `cursed crown dnd magic item`, `leech fang fantasy artifact`,
`old codex dnd magic book`, `glass orb magic item`, `warrior charm fantasy talisman`.

Важно:
- референсы использовать только для понимания формы, материалов, композиции и
  уровня детализации;
- не копировать конкретные copyrighted изображения и не делать recognizable copies;
- итоговые ассеты должны быть оригинальными для FantasyDisk.

## Источник Смысла Артефактов
Для каждого id смотреть:

- `scripts/progression_data.gd` (`ProgressionData.ARTIFACTS`);
- `docs/design/content_registry.md`;
- имя файла `artifact_<id>.png`.

Если название и эффект расходятся, приоритет:
1. gameplay effect;
2. русское/английское название;
3. filename id.

## Art Direction
Стиль: **realistic epic dark fantasy / D&D magic item icon**.

Требования к виду:

1. Предмет реалистичный и материальный:
   - металл, кожа, кость, стекло, камень, дерево, ткань, пергамент;
   - физически понятный объем;
   - believable lighting;
   - аккуратная светотень.
2. Эпичность:
   - предмет выглядит редким, мощным, дорогим или проклятым;
   - допускается магическое свечение, руны, трещины, инкрустации;
   - каждый artifact должен вызывать желание взять его в игре.
3. Читаемость:
   - один главный предмет по центру;
   - предмет целиком помещается в кадр;
   - силуэт читается на 40px;
   - без визуального мусора вокруг.
4. Без фона:
   - прозрачный фон;
   - без пьедесталов, земли, камней, дыма вокруг, случайных осколков;
   - допустима только тонкая внутренняя магическая аура, если она не мешает
     прозрачности и не касается краев.
5. Без UI-рамки:
   - рамку дает интерфейс;
   - иконка — только предмет.

## Технические Требования
- PNG.
- `256x256`.
- RGBA, прозрачный фон.
- Файлы заменить на месте.
- Имена файлов не менять.
- `.import` вручную не редактировать.
- Без текста, watermark, букв, цифр.
- Bbox предмета не должен касаться краев.
- Не должно быть detached garbage components, halos, белых контуров, обрезанных частей.

## Порядок Работы
1. Собрать актуальный список всех `artifact_<id>.png` из данных/папки.
2. Зафиксировать текущие иконки как заменяемые; не считать их финальным стилем.
3. Идти **строго по одной иконке**:
   - прочитать название/эффект;
   - найти референсы;
   - сформировать предмет;
   - сгенерировать/нарисовать;
   - проверить размер, alpha, bbox, связность, 40px readability;
   - только потом переходить к следующей.
4. Каждые 10 иконок дописывать progress log в этот файл.
5. После всех иконок создать preview/contact sheet:

```text
assets/sprites/ui/icons/artifact_realistic_dnd_preview.png
```

В preview должны быть крупный вид и 40px вид.

## Самопроверка
Для каждой иконки проверить:

- соответствует ли названию;
- выглядит ли как реалистичный D&D/fantasy artifact;
- не похожа ли на плоскую пиктограмму;
- предмет целиком в кадре;
- нет ли фона/мусора/ореолов;
- читается ли на 40px.

## Документация
Обновить:

- `docs/design/content_registry.md`;
- `docs/design/current_game_state.md`;
- `docs/design/systems/visual_style_assets.md`;
- `CHANGELOG.md`;
- этот task-файл с progress log и итоговым summary.

Также отметить, что `codex_design_artifact_icons_per_item_regen_task.md`
superseded новым realistic D&D-reference pass.

## Acceptance Criteria
- [x] Все активные artifact PNG заменены новым realistic epic D&D-style набором.
- [x] Каждая иконка основана на названии/эффекте конкретного артефакта.
- [x] Для каждого типа предмета использованы web/image references как inspiration.
- [x] Все файлы `256x256`, RGBA, transparent background.
- [x] Нет обрезки, detached мусора, пьедесталов, фона, текста, watermark.
- [x] Предметы читаются на 40px.
- [x] Preview sheet создан.
- [x] Документация обновлена.
- [x] Smoke/asset validation зеленые.

## Progress Log 2026-06-12

- Reference research complete: просмотрены D&D/tabletop/fantasy magic item направления по группам амулетов, сапог, сфер, книг, компасов, тотемов, проклятых корон, кровавых/шипастых реликвий, зелий, кристаллов, ремней, монет и инструментов. Референсы использовались только как inspiration по форме, материалам, композиции и уровню детализации; recognizable copies не делались.
- Procedural/pictogram pass rejected during self-QA: выглядел как простые иконки/пентаграммы, поэтому не принят как финал.
- Обработано 10/53: `warrior_charm`, `fox_boots`, `glass_orb`, `hawk_lens`, `ember_core`, `old_codex`, `stone_heart`, `banner_seed`, `red_whetstone`, `star_compass`.
- Обработано 20/53: `living_root`, `captains_coin`, `quickstring`, `heavy_totem`, `splinter_gloves`, `wide_sigil`, `swift_ink`, `summoners_bell`, `blood_sigil`, `void_ink`.
- Обработано 30/53: `echo_pick`, `sturdy_amulet`, `fast_boots`, `magnetic_buckle`, `silver_coin`, `survival_manual`, `cracked_shield`, `sharp_talisman`, `jagged_blade`, `heavy_grip`.
- Обработано 40/53: `war_belt`, `warriors_rage`, `dark_crystal`, `ash_page`, `skull_resonator`, `ink_candle`, `copper_string`, `broken_pick`, `loud_amp`, `bass_cable`.
- Обработано 50/53: `cursed_crown`, `fragile_heart`, `greedy_purse`, `burning_shard`, `golden_route_mark`, `glass_edge`, `echo_core`, `split_core`, `blood_pact`, `leech_heart`.
- Обработано 53/53: `thorn_pact`, `phantom_step`, `leech_fang`.
- Вырезка и нормализация: `tools/extract_realistic_dnd_artifact_icons.py` создает активные `artifact_<id>.png`, убирает chroma key, центрирует предмет, строит `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png` и проверяет `256x256`/RGBA/alpha/40px.
- QA correction: вручную исправлен маппинг первых source-листов, чтобы `old_codex` был книгой, `red_whetstone` — точильным камнем, `stone_heart` — каменным сердцем, `hawk_lens` — линзой/амулетом, `ember_core` — огненным ядром, `banner_seed` — зеленой реликвией.
- Итог: 53/53 активных PNG заменены на красивые raster painted magic items без пентаграмм/плоских символов; preview создан: `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png`.
- Validation: custom asset check passed (`53` ids from `ProgressionData.ARTIFACTS`, all `256x256`, RGBA, transparent, readable at 40px).
- Smoke: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` -> `Runtime smoke test passed.`
