# BUG: Новые перерисованные персонажи не показаны (выбор героя, кодекс, миниатюры, выбор оружия)

Статус: done
Приоритет: high
Роль: Designer (Codex) → Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-15
Автор: PM (отчёт пользователя + диагностика)
Jira: SCRUM-416
Связано: SCRUM-411 (анимспрайт скрыт за ригом), SCRUM-412 (белый фон кадров), перерисовки 282-297

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Dispatch
- 2026-06-15T06:28Z — Board dispatcher routed to Back-end thread
  `019eabd9-780b-78a2-9f4b-e7203d659ef2` with reasoning High/no low, queued after
  the active SCRUM-415/SCRUM-414/SCRUM-412 bug work unless the same UI/data path is
  touched sooner. Active-owner audit: SCRUM-416 had no recent dispatch note or
  owner; Design main had completed SCRUM-412 Design phase; Designer 2 and Animator
  had no eligible owner work. Back-end owns the UI/data binding from old
  `sprite_path` assets to accepted transparent full-frame art. If a new cropped
  portrait asset is truly required, Back-end must record a precise Design handoff
  instead of generating Design assets. Animator is not routed.

## Контекст (отчёт пользователя + диагностика)
«Почему новые персонажи не показываются на экране выбора персонажа и в кодексе».

ДИАГНОСТИКА (PM): экран выбора героя (HeroSelectLargePortrait), кодекс, миниатюры
и выбор оружия рисуют статичный портрет из **`sprite_path`** (progression_data_characters.gd:142+),
который указывает на СТАРЫЕ PNG (`berserk_unarmed.png` 06-11, `assassin.png` 06-12,
`knight.png`, `dark_mage.png` …). Перерисовки (5 move/5 attack) легли в
`assets/sprites/characters/full_frame/<class>/` + `<class>_spriteframes.tres`
(анимации в бою), но **`sprite_path` НЕ обновлён** → во всех статичных портретах
показывается СТАРЫЙ арт.

## Требования
1. **Обновить статичный портрет каждого перерисованного персонажа** на НОВЫЙ арт
   (все 17 классов): либо задать `sprite_path` на новый портрет/представительный
   кадр (напр. чистый idle-кадр или отдельный портрет), либо рендерить из нового
   `<class>_spriteframes.tres` (idle frame) везде, где сейчас статичный портрет.
2. Затронутые поверхности: выбор героя (HeroSelectLargePortrait + миниатюры
   карусели), кодекс (раздел «Персонажи», _codex_portrait), выбор оружия (спрайт
   героя), и любые другие места `sprite_path`/`config["sprite"]`.
3. **Прозрачный фон**: портреты не должны быть на белом фоне (координация с
   SCRUM-412 — использовать очищенные кадры/портрет, а не «грязный» idle с белым
   фоном).
4. Без оружия в руках (как в перерисовках); единый стиль; узнаваемость классов.
5. Старые PNG (`berserk_unarmed.png` и т.п.) — в бэкап, если заменяются; не оставлять
   битых ссылок.
6. Тест (smoke): выбор героя/кодекс/миниатюры/выбор оружия строятся; для всех 17
   классов показан НОВЫЙ портрет (не старый), прозрачный фон, в content-зоне рамки.
   Скрины выбора героя и кодекса в build/qa/.
7. CHANGELOG; content_registry; current_game_state.

## Files / Assets / IDs
- scripts/progression_data_characters.gd (sprite_path всех классов 142+)
- scripts/ui_screens.gd (HeroSelectLargePortrait 752; миниатюры _make_hero_thumbnail_button;
  кодекс _codex_portrait; выбор оружия — спрайт; _cached_texture)
- assets/sprites/characters/ (новые портреты/кадры) + full_frame/<class>/ + бэкап старых
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Во всех статичных местах (выбор героя, миниатюры, кодекс, выбор оружия) показан НОВЫЙ перерисованный персонаж для всех 17 классов.
- [x] Портреты на прозрачном фоне (без белого, коорд. SCRUM-412), без оружия, в content-зоне; старые в бэкап, нет битых ссылок.
- [x] smoke зелёные; скрины выбора героя + кодекса; CHANGELOG.

## Документация
docs/design/content_registry.md, docs/design/systems/menus_ui.md, current_game_state.

## Result / Back-end report
- Updated all 17 `ProgressionData.character_config(...).sprite_path` values from legacy static PNGs to the accepted SCRUM-412-cleaned full-frame idle portraits:
  `res://assets/sprites/characters/full_frame/<class>/<class>_idle_00.png`.
- Existing static portrait surfaces now inherit the new art through the canonical config path: Hero Select large portrait, carousel thumbnails, Codex character portrait, pause/level-up/legacy portrait surfaces. Weapon select currently has no hero portrait surface and only renders weapon cards, so no feature UI was added during the freeze.
- Added regression coverage:
  `tests/character_sprite_registry_alignment_test.gd` now requires the full-frame idle portrait paths for all 17 classes, and `tests/runtime_smoke_test.gd` asserts actual Hero Select thumbnail/large portraits, Codex default portrait and level-up portrait texture paths.
- QA dumps:
  `build/qa/scrum416/character_portrait_registry_alignment.md`,
  `build/qa/scrum416/hero_select_portrait_runtime_paths.md`,
  `build/qa/scrum416/codex_character_portrait_runtime_paths.md`.
- Verification PASS:
  `character_sprite_registry_alignment_test.gd`,
  `content_registry_consistency_test.gd`,
  `ui_no_overlap_matrix_test.gd`,
  `runtime_smoke_ui_test.gd`,
  `animation_smoke_test.gd`,
  `runtime_smoke_test.gd`.
