# BUG: Роза ветров в выборе героя залезает на рамку — опустить и увеличить с отступами

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-206

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«На странице выбора персонажа чуть опустить розу ветров — она залазит на рамку;
можно сделать её побольше, только помни об отступах к рамке».
Роза — плавающий виджет `HeroStatRadar` в правом верхнем углу
(ui_screens.gd:407-415: anchor right/top, custom_minimum_size 320x200).

## Требования
1. Опустить розу ниже, чтобы она НЕ перекрывала верхнюю рамку/шапку экрана.
2. Можно увеличить размер (например ~360-400px ширина) — но с явными ОТСТУПАМИ
   до рамок панели справа/сверху (не впритык, не за край). Подобрать значения,
   чтобы на 1280x720 и 2560x1440 роза целиком внутри своей зоны, с зазором.
3. Правило «UI не наползает» (qa_protocol): прогнать no-overlap хелпер для
   экрана выбора героя — роза не пересекает рамку/шапку/досье ни на одном
   поддерживаемом разрешении.
4. Тест: фактический global_rect розы внутри допустимой зоны с зазором ≥ N px
   до краёв рамки на 2-3 размерах.
5. CHANGELOG; скрин/дамп в build/qa/.

## Files / Assets / IDs
- scripts/ui_screens.gd (HeroStatRadar:55, размещение:407-415)
- tests/runtime_smoke_test.gd (no-overlap для hero select)

## Acceptance Criteria
- [x] Роза опущена, не залезает на рамку; увеличена с отступами.
- [x] no-overlap на hero select зелёный на 2-3 размерах.
- [x] 6 smoke зелёные; CHANGELOG; артефакт в build/qa/.

## Документация
docs/design/current_game_state.md (экран выбора героя).

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.

## Result Summary (Codex Back-end, 2026-06-13)

Done. `HeroStatRadar` увеличен до 370x230, опущен ниже шапки (`top=124`) и получил правый зазор 44px. Внутри досье добавлена reserved top-zone, чтобы радар не наползал на текст/кнопки; тест проверяет отступы от рамок и отсутствие пересечений с header/dossier content. QA dump: `build/qa/hero_select_radar_rects.md`.

Verification:
- `runtime_smoke_test.gd` — passed.
- `animation_smoke_test.gd` — passed.
- `melee_weapon_targeting_test.gd` — passed.
- `attack_vfx_smoke_test.gd` — passed.
- `hazard_vfx_smoke_test.gd` — passed.
- `meta_progression_smoke_test.gd` — passed.
- `meta_skill_tree_smoke_test.gd` — passed.

Docs updated: `CHANGELOG.md`, `docs/design/current_game_state.md`, `docs/process/task_board.md`, `docs/process/jira_sync_map.json`.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED

Это ровно тот borderline-overlap, что QA флагнул в SCRUM-141 — теперь закрыт.
Проверено код + dump + РЕАЛЬНЫЙ рендер 1280×720:
- Размещение: радар 370×230, anchor right/top, offset_top=124, offset_right=−44
  (ui_screens.gd:416-424). Увеличен и опущен.
- Замеры рендера: radar_top=124 vs header_bottom=84 → зазор сверху 40px;
  radar_right vs panel_right → зазор справа 20px; `intersects(header)=false`.
- Reserved top-zone в досье (radar_reserved_space 288px, :341) толкает текст/кнопки
  ниже → роза не наползает на контент досье. Визуально (build/qa/hero_select_radar_frame/):
  роза в правом-верхнем углу с явным зазором до рамки и шапки, текст слева чист.
- Dump `build/qa/hero_select_radar_rects.md` подтверждает зазоры на 1280/1600/2560.
- 6 smoke зелёные. Багов нет.
