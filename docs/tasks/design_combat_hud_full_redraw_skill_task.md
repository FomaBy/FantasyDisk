# ART/UX: Полная перерисовка боевого HUD (HP/опыт/золото/ульта/таймер + кнопка повышения)

Статус: done
Приоритет: high
Роль: Designer (Codex) → Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Связано: SCRUM-326 (UI Overhaul: combat HUD), SCRUM-373/384 (единый фрейм), SCRUM-278/348 (кнопка повышения), SCRUM-324 (скилл)
Jira: SCRUM-390
QA: in_progress (2026-06-14)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Полностью перерисовать интерфейс/UX во время боя: ХП-бар, полоска Опыта, Золото,
Накопление ульты и Таймер. Плюс справа снизу НЕпрозрачная кнопка повышения уровня.
Всё перерисовать, используя референсы текущего проекта».

Боевой HUD: ui_screens.gd `_create_hud` (5550+). Элементы: таймер
(CombatTimerPanel/CombatTimerLabel), бейдж возвышения (AscensionHudBadge),
артефакты (ArtifactHudRow), полоски ресурсов HP/опыт/золото/ульта, кнопка
повышения (LevelUpPlusButton, правый-нижний угол). HUD уже частично использует
`_unified_frame_style` (единый фрейм SCRUM-373/384).

## ОБЯЗАТЕЛЬНО — скилл + референсы проекта
Перерисовывать скиллом `fantasydisk-asset-generator` (gpt-image-2, PNG, ПРОЗРАЧНЫЙ
фон) по РЕФЕРЕНСАМ текущего проекта (docs/design/references/ + общий стиль
D&D + Dark Fantasy Dragon, единый фрейм). Старые HUD-ассеты — в бэкап. Биллинг OK.

## Требования
1. **Полностью перерисовать все элементы боевого HUD** в едином стиле:
   - **ХП-бар** (полоса здоровья — рамка/заливка/иконка сердца/черепа), читаемо;
   - **полоска Опыта** (XP, прогресс к уровню);
   - **Золото** (иконка монеты + счётчик);
   - **Накопление ульты** (charge-бар, заметное «готово» при заполнении);
   - **Таймер** (CombatTimerPanel) + бейдж возвышения рядом.
   Единый визуальный язык, тонкие металлические рамки (единый фрейм SCRUM-384),
   читаемость поверх боя, контент в content-зоне (правило фреймов).
2. **Кнопка повышения уровня — справа снизу, НЕпрозрачная**: перерисовать красиво
   (стиль кнопок меню), без жёлтого свечения (SCRUM-318), бейдж счётчика читаем;
   согласовать с SCRUM-278 (позиция/непрозрачность) и SCRUM-348 (красивость) — не
   дублировать, а довести визуал.
3. Композиция HUD не перекрывает геймплей и сама не накладывается (no-overlap);
   адаптивно на 1280×720 / 1920×1080 / 2560×1440 (см. позиционирование таймера/
   ресурсов 5660+).
4. Анимация заполнения баров (плавный tween HP/опыт/ульты) — опционально, аккуратно.
5. Не ломать логику обновления (значения HP/XP/money/ult/таймер, _update_*).
6. Тест (smoke + no-overlap): HUD строится, все элементы читаемы, бары обновляются,
   кнопка повышения справа-снизу непрозрачная; no-overlap на 3 разрешениях.
   Скрин боевого HUD в build/qa/.
7. CHANGELOG; menus_ui; visual_style_assets; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (_create_hud 5550+; CombatTimerPanel/Label; AscensionHudBadge;
  ArtifactHudRow; ресурс-бары HP/XP/gold/ult; LevelUpPlusButton; _unified_frame_style;
  позиционирование 5660+)
- scripts/main.gd (timer_label; level_up_button; обновление значений)
- assets/sprites/ui/ (HUD-бары/иконки/рамки, скиллом) + бэкап
- docs/design/references/hud/ (исходники скилла)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [x] HP/опыт/золото/ульта/таймер полностью перерисованы скиллом в едином стиле (рамки единого фрейма), читаемы поверх боя.
- [x] Кнопка повышения справа-снизу непрозрачная и красивая (стиль меню), бейдж читаем, без жёлтого hover.
- [x] Контент в content-зоне; no-overlap на 3 разрешениях; логика обновления цела.
- [ ] smoke + no-overlap matrix зелёные; скрин HUD; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, docs/design/systems/visual_style_assets.md, current_game_state.

## Progress Log

- 2026-06-14 — Взято в работу Design/Codex. Scope подтвержден: создать новый визуальный HUD-kit и metadata/safe-zones; runtime wiring/layout останется Back-end handoff, если потребуется менять `scripts/ui_screens.gd`.
- 2026-06-14 — Сгенерирован reference sheet через `fantasydisk-asset-generator`:
  `docs/design/references/combat_hud_redraw/combat_hud_redraw_reference_sheet.png`.
  Source принят как art direction, но не как runtime asset из-за baked checkerboard.
- 2026-06-14 — Reference alpha-cleaned and cut into 17 production candidates:
  `assets/sprites/ui/frames/combat_hud/` and `assets/sprites/ui/hud/combat_hud/`.
  Metadata/safe zones: `docs/design/references/combat_hud_redraw/combat_hud_redraw_metadata.json`.
- 2026-06-14 — Created previews:
  `docs/design/previews/combat_hud_redraw_contact.png`,
  `docs/design/previews/combat_hud_redraw_safe_zones.png`,
  `build/qa/scrum390/combat_hud_mock_1280x720.png`,
  `build/qa/scrum390/combat_hud_mock_1920x1080.png`,
  `build/qa/scrum390/combat_hud_mock_2560x1440.png`.
- 2026-06-14 — Godot import PASS for new PNG assets.
- 2026-06-14 — Runtime wiring is not done in Design scope. Created Back-end handoff:
  `docs/tasks/backend_combat_hud_redraw_integration_task.md`. Final live
  no-overlap/runtime smoke belongs to that handoff because `ui_screens.gd`
  owns HUD layout and update logic.
- 2026-06-14 — Validation: PNG RGBA/alpha check PASS; Godot import PASS;
  `tests/ui_no_overlap_matrix_test.gd` PASS; `tests/runtime_smoke_ui_test.gd`
  PASS; `tests/runtime_smoke_test.gd` PASS. These validate current runtime and
  imported Design assets; live SCRUM-390 asset wiring is tracked by SCRUM-400.

## Result

Design-ready combat HUD redraw kit is ready for Back-end integration. The pack
contains:

- resource strip frame;
- HP/XP/money/ultimate card frames;
- timer frame and ascension badge;
- opaque bottom-right level-up plus button in normal/hover/pressed/disabled;
- painterly HP/XP/ULT/gold fill textures and a gold medallion;
- exact texture margins, content margins and safe rects in metadata.

The live game is intentionally not rewired by this Design task. Back-end must
integrate the paths and run live HUD no-overlap/smoke checks through
`backend_combat_hud_redraw_integration_task.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED (Design-scope: HUD redraw kit + метаданные + Back-end handoff)

Проверено (фактически):
- **16 HUD-кандидатов** в `assets/sprites/ui/frames/combat_hud/` +
  `assets/sprites/ui/hud/combat_hud/`: resource strip, HP/XP/ULT/Gold cards
  (цветокодированы), timer (драконья рамка), asc badge, **level-up button** в 4
  состояниях (plus/hover/pressed/disabled), 4 fill-текстуры + золотой медальон.
- **Визуал** `combat_hud_redraw_contact.png` (+ safe-zones + моки 1280/1920/2560):
  когерентный D&D dragon-стиль, тонкие металлические рамки + красные самоцветы,
  **level-up = непрозрачный золотой драконий медальон с плюсом** (требование
  непрозрачности соблюдено).
- **Метаданные** `combat_hud_redraw_metadata.json` (texture/content margins, safe
  rects); Godot import PASS.
- **Back-end handoff** `backend_combat_hud_redraw_integration_task.md` / SCRUM-400
  создан (статус **in_progress** — рантайм-проводка идёт).
- **Тесты** (текущий рантайм): `ui_no_overlap_matrix_test` + `runtime_smoke_test`
  — passed.

⚠️ **Видимый HUD redraw ещё НЕ в рантайме**: live HUD не переписан (Design-scope не
трогает ui_screens.gd layout). Проводка ассетов + live no-overlap/smoke — Back-end
SCRUM-400 (in_progress). Проверю при готовности 400.

Acceptance (Design-scope):
- [x] HP/XP/gold/ult/timer + level-up перерисованы скиллом в едином dragon-стиле; кит когерентен.
- [x] Level-up button непрозрачный (медальон) в 4 состояниях; метаданные safe-rect.
- [x] Godot import + текущие no-overlap/runtime smoke зелёные; превью/моки.
- [~] Live HUD wiring + финальные скрины боя — Back-end SCRUM-400.

Статус review→done (Design-source). Баги: нет (видимая проводка — delegated SCRUM-400).
