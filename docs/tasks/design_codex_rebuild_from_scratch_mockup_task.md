# ART/UX: Окно кодекса — ПОЛНОСТЬЮ переделать по макапу (с нуля)

Статус: in_progress
Приоритет: high
Роль: Designer (Codex) → Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-438
QA: in_progress (2026-06-15)
Связано: SCRUM-345 (кодекс новые текстуры — поглощается), SCRUM-384 (единый фрейм), ui-director

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Переделать полностью окно кодекса, полностью сделать по макапу».

Кодекс: scripts/ui_screens.gd `_show_codex_screen` + `_show_codex_section` (секции:
персонажи/монстры/артефакты/характеристики/глоссарий/возвышения).

## ОБЯЗАТЕЛЬНО — ui-director (макап сначала)
Скилл `fantasydisk-ui-director`: сначала сгенерировать OpenAI-макап окна кодекса
(все секции, табы, карточки, портреты, описания, тултипы; content-зоны, safe-margins,
responsive), показать превью PNG, затем воспроизвести в Godot строго по макапу.
Арт — `fantasydisk-asset-generator` (прозрачный фон), единый стиль D&D Dark Fantasy.

## Требования
1. Полностью пересобрать окно кодекса по макапу: навигация секций, списки/карточки,
   портреты персонажей/монстров, артефакты, тексты; единый фрейм (SCRUM-384).
2. Персонажи/арт и описания НЕ накладываются на UI/орнамент (глоб. правило фреймов);
   весь текст читаем; адаптив 1280×720/1920×1080/2560×1440.
3. Старые текстуры/слои кодекса — в бэкап (вне сборки), убрать из кода.
4. Не ломать навигацию (табы/back/тултипы глоссария), клава+геймпад.
5. Тест (smoke+no-overlap): кодекс и все секции строятся по макету; no-overlap; текст в зонах. Макап+скрины в build/qa/.
6. CHANGELOG; menus_ui; content_registry.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_codex_screen; _show_codex_section; _codex_portrait/_codex_label)
- assets/sprites/ui/ (новые по макапу) + бэкап; docs/design/references/codex_v2/ (макап)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [x] Сгенерирован макап кодекса; единый стиль и rebuild layout зафиксированы в Design spec.
- [x] Все секции, портреты/арт и текст имеют content-зоны/safe rects для 1280x720, 1920x1080 и 2560x1440.
- [ ] Runtime окно собрано строго по макапу; старое в бэкап; navigation/smoke/no-overlap matrix зелёные. Отложено до Back-end integration, потому что этот pass Design-only.

## Документация
docs/design/systems/menus_ui.md, content_registry, current_game_state.

## Dispatcher Dispatch (2026-06-15)
Передано Design main (`019eabf1-6d54-7561-8af9-ce25cdf483a9`) как 0.1.6 UI/UX
Design-first row.

Scope for this pass: generate the required Codex v2 mockup/spec with exact content
zones, safe margins, responsive rules, and any needed transparent UI source assets
using the mandated UI/asset skills. Runtime rebuilding in `scripts/ui_screens.gd`,
smokes, and no-overlap matrix are Back-end follow-up after the Design mockup/spec is
accepted. Keep reasoning High/no low.

## Результат Design Mockup/Spec (2026-06-15)

Статус: `review` — Design-first package готов для PM/Back-end review. Runtime
интеграция, backup старых live Codex textures, `scripts/ui_screens.gd`,
smoke/no-overlap matrix и навигационные проверки не выполнялись в этом thread,
потому что это Back-end scope после принятия mockup/spec.

Generated / QA paths:
- OpenAI source mockup:
  `docs/design/references/codex_v2/codex_v2_full_window_mockup_1920x1088.png`;
- base mockup:
  `docs/design/mockups/scrum438_codex_v2/codex_v2_mockup_1920x1080.png`;
- chat/Design preview:
  `docs/design/previews/scrum438_codex_v2_mockup_preview.png`;
- safe-zone overlay:
  `docs/design/mockups/scrum438_codex_v2/codex_v2_safe_zones_annotated_1920x1080.png`;
- safe-zone preview:
  `docs/design/previews/scrum438_codex_v2_safe_zones.png`;
- spec:
  `docs/design/mockups/scrum438_codex_v2/spec.md`;
- machine-readable metadata:
  `docs/design/mockups/scrum438_codex_v2/codex_v2_layout_metadata.json`;
- QA copies:
  `build/qa/scrum438_codex_v2/codex_v2_mockup_1920x1080.png`,
  `build/qa/scrum438_codex_v2/codex_v2_safe_zones_annotated_1920x1080.png`.

Design decisions:
- Codex v2 uses a full-window dark-fantasy library layout: left six-section nav,
  center scrollable list/card area, right selected-entry detail panel, top header
  and back button, plus glossary tooltip safe-zone.
- The mockup contains no readable baked runtime text. Back-end must insert all
  Russian labels/descriptions/icons/portraits as runtime Controls.
- The full mockup PNG is not a runtime atlas. It is a reference/spec only.
- Old SCRUM-345/SCRUM-403 Codex textures remain live until Back-end consumes this
  handoff and backs up/removes/replaces them in a runtime integration task.

Safe-zone highlights at 1920x1080:
- outer safe: `Rect2(72,64,1776,980)`;
- nav safe: `Rect2(88,198,258,720)`;
- list safe: `Rect2(424,204,736,796)`;
- detail safe: `Rect2(1290,214,514,780)`;
- portrait safe: `Rect2(1396,226,320,300)`;
- tooltip safe: `Rect2(1058,540,192,92)`.

Responsive matrix:
- 1280x720 uses scale `0.6667`;
- 1920x1080 uses scale `1.0`;
- 2560x1440 uses scale `1.3333`;
- exact scaled rects are recorded in
  `docs/design/mockups/scrum438_codex_v2/codex_v2_layout_metadata.json` and
  summarized in the spec.

Docs updated:
- `docs/design/mockups/scrum438_codex_v2/spec.md`;
- `docs/design/systems/menus_ui.md`;
- `docs/design/content_registry.md`;
- `docs/design/current_game_state.md`;
- `CHANGELOG.md`;
- `docs/process/task_board.md`.

Back-end handoff:
- Rebuild `_show_codex_screen` / `_show_codex_section` around the SCRUM-438
  Control layout and safe rects.
- Preserve existing data sections: characters, monsters, artifacts, stats,
  glossary, ascensions.
- Preserve Escape/back behavior, keyboard/gamepad focus, lazy section building,
  SCRUM-416 portrait paths and SCRUM-417 covered portrait scaling.
- Implement old texture backup outside Godot import scope only during the
  runtime replacement pass.
- Run `tests/runtime_smoke_test.gd`, `tests/runtime_smoke_ui_test.gd` and
  `tests/ui_no_overlap_matrix_test.gd` after integration.

## QA-Вердикт (2026-06-15)
Статус: PASSED (Design-scope: codex v2 rebuild mockup + spec + safe-zones); Back-end runtime build — pending

Проверено (фактически):
- **Mockup готов** `scrum438_codex_v2/codex_v2_mockup_1920x1080.png`: раскладка
  «открытая книга/том» — 6 вкладок секций слева (персонажи/монстры/артефакты/
  характеристики/глоссарий/возвышения), список записей на пергаментной левой странице,
  портрет-слот + стат-иконки + описание справа; единый D&D dragon-орнамент (тёмный
  металл/красные самоцветы/золото). Полный rebuild, не старый кодекс.
- **Safe-zones + metadata**: `codex_v2_safe_zones_annotated_1920x1080.png` +
  `codex_v2_layout_metadata.json` + `spec.md` — content-зоны/safe rects для
  1280×720/1920×1080/2560×1440 (контент в зонах, не на орнаменте).

⚠️ **Runtime окно ещё НЕ собрано** по макапу — отложено до **Back-end integration**
(этот pass Design-only): сборка `_show_codex_screen`/секций строго по макапу, бэкап
старого, navigation/smoke/no-overlap. НЕ промоутил в Готово — тикет ждёт Back-end фазу.

Acceptance:
- [x] Макап кодекса + единый rebuild-стиль зафиксированы в Design spec.
- [x] Секции/портреты/текст имеют content-зоны/safe rects на 3 разрешениях.
- [ ] Runtime по макапу + navigation/smoke/no-overlap — Back-end follow-up (pending).

Статус: Design-source PASS, ждёт Back-end integration. Баги: нет (Design-scope).

## Dispatcher Back-end Dispatch (2026-06-15)

Передано Back-end (`019eabd9-780b-78a2-9f4b-e7203d659ef2`) как следующая
готовая UI runtime-интеграция без активного владельца.

Scope for this pass: rebuild the live Codex runtime around
`docs/design/mockups/scrum438_codex_v2/spec.md`, preserving all existing Codex
data sections, navigation/back/Escape behavior, glossary tooltip semantics,
keyboard/gamepad focus, SCRUM-416 portrait paths and SCRUM-417 covered portrait
scaling. Do not wire the mockup PNG as a single atlas; build runtime Controls
inside the documented safe zones and keep all text/icons/portraits off frame
ornaments. Back up/remove old Codex live textures only during the runtime
replacement pass and keep backups outside Godot import scope.

Required verification after integration: `tests/runtime_smoke_test.gd`,
`tests/runtime_smoke_ui_test.gd`, `tests/ui_no_overlap_matrix_test.gd`, with
Codex screenshots/dumps under `build/qa/scrum438/`. Keep reasoning High/no low.
Do not touch Settings/SCRUM-439, Hero Select/SCRUM-436, Berserk/SCRUM-420,
Animator work, balance, or unrelated UI surfaces in this pass.
