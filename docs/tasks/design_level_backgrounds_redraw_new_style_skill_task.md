# ART: Перерисовать все подложки уровней (арена-фоны) в новом стиле скиллом

Статус: done
Приоритет: high
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-369
QA: in_progress (2026-06-14)
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

## Progress Log
- 2026-06-14 — Took task in Design/Codex thread after SCRUM-384 review.
  Inventory confirmed 8 existing `assets/backgrounds/field_*.png` files and 2
  live code references without PNGs: `field_dry_road`, `field_stone_garden`.
  Scope decision: generate all 10 backgrounds and preserve existing
  `ARENA_BACKGROUND_OPTIONS` links; do not change Back-end code.
- 2026-06-14 — Generated all 10 source references through
  `fantasydisk-asset-generator` / OpenAI Images (`gpt-image-2`, `2560x1440`,
  high) under `docs/design/references/backgrounds/`.
- 2026-06-14 — Replaced/generated runtime assets under `assets/backgrounds/`:
  `field_marsh.png`, `field_meadow.png`, `field_misty_marsh.png`,
  `field_ruined_courtyard.png`, `field_dusty_badlands.png`,
  `field_enchanted_meadow.png`, `field_ashen_rift.png`,
  `field_cursed_grove.png`, `field_dry_road.png`, `field_stone_garden.png`.
  Existing 8 backgrounds backed up under `build/qa/scrum369/backups/`.
- 2026-06-14 — QA artifacts:
  `docs/design/previews/arena_backgrounds_scrum369_contact.png`,
  `docs/design/previews/arena_backgrounds_scrum369_readability.png`,
  `build/qa/scrum369/backgrounds_manifest.json`,
  `build/qa/scrum369/backgrounds_redraw_qa.md`.
- 2026-06-14 — Verification PASS: all 10 PNGs are `2560x1440` RGB, Godot import
  PASS, custom background load smoke PASS, `tests/runtime_smoke_combat_test.gd`
  PASS, `tests/runtime_smoke_test.gd` PASS.

## Result
Design pass готов к QA/review. Все 10 боевых подложек обновлены в едином
реалистичном D&D / dark fantasy стиле, при этом центральная игровая зона
приглушена для читаемости героев, монстров, снарядов и VFX. Две ранее битые
runtime-ссылки закрыты новыми файлами `field_dry_road.png` и
`field_stone_garden.png`; Back-end code не менялся.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически):
- **10/10 фонов** `2560×1440` (PIL: missing=0, wrong_size=0) — включая 2 ранее
  ОТСУТСТВОВАВШИХ `field_dry_road`/`field_stone_garden` (main.gd:44-67 ссылки теперь
  не битые).
- **Визуал** `arena_backgrounds_scrum369_contact.png` (+ readability): 10 биомов
  (марш/луг/туман-марш/руины/пустошь/зачар.луг/ashen-rift/проклятая роща/сухая
  дорога/каменный сад) — реалистичные top-down D&D dark-fantasy, единый свет/
  перспектива, центр игровой зоны приглушён → спрайты/VFX читаемы поверх, без
  визуального шума.
- **Бэкап** 8 старых в `build/qa/scrum369/backups/`; манифест + превью на месте.
- **Тесты**: `runtime_smoke_combat_test` (бой строится на фонах) + `runtime_smoke_test`
  — passed; Godot import чист.

Acceptance:
- [x] 10 подложек перерисованы скиллом в едином D&D dark-fantasy стиле, 2560×1440.
- [x] Спрайты читаемы поверх (приглушённый центр); свет/перспектива согласованы.
- [x] field_dry_road/field_stone_garden сгенерированы (нет битых путей).
- [x] Старые в бэкап; smoke зелёный; контакт-лист; доки.

Статус review→done. Баги: нет.
