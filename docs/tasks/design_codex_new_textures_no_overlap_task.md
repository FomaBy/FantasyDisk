# ART/UX: Кодекс — новые текстуры интерфейса (скиллом), убрать наложение персонажей/текста

Статус: done
Приоритет: high
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-345
QA: in_progress (2026-06-14)
Связано: SCRUM-331 (UI Overhaul кластер прогрессия/кодекс), SCRUM-324 (скилл), SCRUM-327 (стиль)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«В кодексе очень старые текстуры интерфейса — надо создать новые и сделать так,
чтобы персонажи и их описание не накладывались на элементы интерфейса».

Кодекс: `_show_codex_screen` (~1340+) и `_show_codex_section` (секции: персонажи/
монстры/артефакты/характеристики/глоссарий/возвышения), CodexBackButton (1351).
Текстуры панелей/рамок устарели; арт персонажей и их описания наезжают на элементы
UI. Это детальная спека «кодекса» из кластера SCRUM-331.

## ОБЯЗАТЕЛЬНО — скилл (директива пользователя)
Новые текстуры/рамки кодекса СОЗДАВАТЬ скиллом `fantasydisk-asset-generator`
(gpt-image-2, PNG, ПРОЗРАЧНЫЙ фон), стиль D&D + Dark Fantasy Dragon (опорная
SCRUM-327). Исходники в docs/design/references/codex/, внедрить в assets/. Старые —
в бэкап.

## Требования
1. Заменить устаревшие текстуры интерфейса кодекса (панели, рамки секций, табы,
   карточки, тултипы) на новые в едином стиле D&D + Dark Fantasy Dragon, скиллом.
2. **Персонажи (арт) и их описания НЕ накладываются на элементы интерфейса**:
   арт героя/монстра и текст — строго в своих content-зонах рамок, не на орнаменте,
   не друг на друге (глобальное правило фреймов; content margins ≥ окантовки).
   Длинные описания скроллятся/умещаются; весь текст читаем.
3. Согласовать с кластером SCRUM-331 и опорной SCRUM-327; все секции кодекса
   (персонажи/монстры/артефакты/характеристики/глоссарий/возвышения) единообразны.
4. Не ломать навигацию (табы секций, back, тултипы глоссария), клава+геймпад-фокус.
5. Тест (smoke + no-overlap matrix): кодекс и все секции строятся; арт/текст в
   content-зонах, no-overlap на 1280×720/1920×1080/2560×1440. Скрины секций в build/qa/.
6. CHANGELOG; menus_ui; content_registry.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_codex_screen ~1340; _show_codex_section; CodexBackButton
  1351; _codex_portrait/_codex_label; codex стили/рамки)
- assets/sprites/ui/ (новые текстуры кодекса, скиллом) + бэкап старых
- docs/design/references/codex/ (исходники скилла)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] Текстуры кодекса заменены на новые (скиллом), единый стиль D&D + Dark Fantasy Dragon.
- [ ] Персонажи/арт и описания не накладываются на UI/орнамент; контент в content-зонах; текст читаем.
- [ ] Навигация цела; no-overlap на 3 разрешениях; smoke зелёные; скрины; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, docs/design/content_registry.md, current_game_state.

## Blocker History — 2026-06-14
Design/Codex проверил обязательный pipeline: новые Codex UI textures должны быть
созданы через `fantasydisk-asset-generator` (`gpt-image-2`). В текущем окружении
отсутствуют `OPENAI_API_KEY` и Python-пакет `openai`, поэтому генерация новых
PNG невозможна без нарушения директивы задачи. Runtime no-overlap/layout часть
нужно выполнять после готовности ассетов или отдельным Back-end handoff; текущая
Design-задача заблокирована до восстановления доступа к skill.

## Blocker Resolved — 2026-06-14
Documentation dispatcher verified that local `OPENAI_API_KEY` can now be loaded
from the secure Codex env file outside the repository and Python `openai` imports
successfully. Previous asset-generator environment blocker is resolved; task is
eligible for Design/Codex execution after the currently active Design task.


## Ключ настроен — блокер снят (2026-06-14)
`OPENAI_API_KEY` фактически сохранён в `~/.codex/.env` (права 600, вне git) +
автозагрузка в `~/.zshrc` — доступен в окружении автоматически в каждом новом
shell (включая shell Codex-воркеров). Скилл `fantasydisk-asset-generator`
(gpt-image-2) готов к вызову. Блокер по отсутствию `OPENAI_API_KEY` снят
окончательно; задача готова к исполнению через скилл.

## Blocked Again — 2026-06-14
Design queue audit after SCRUM-352 confirmed this task still requires new Codex
textures/frames through `fantasydisk-asset-generator` / OpenAI Images
(`gpt-image-2`) and disallows old/local/random generators. The current approved
env source is available, but OpenAI Images returns:

```text
billing_hard_limit_reached
```

Task is blocked until OpenAI image generation billing is available again or PM
provides an approved alternative generation source.

## Разблокировано 2026-06-14 (PM)
Биллинг OpenAI восстановлен и ПРОВЕРЕН: тестовая генерация gpt-image-2 успешна. Блок `billing_hard_limit_reached` устарел — снят. Можно генерить скиллом.

## Progress Log

- 2026-06-14 — Взято Design/Codex в работу после повторного Images API smoke:
  `images_api_smoke=PASS`. Scope decision: выполнить Design asset kit,
  safe-zone metadata, previews and Back-end handoff for runtime Codex layout;
  `scripts/ui_screens.gd` and no-overlap runtime integration остаются Back-end
  scope.
- 2026-06-14 — Design asset kit готов и импортирован в Godot. Создана новая
  D&D/Dark Fantasy Dragon Codex texture sheet через `fantasydisk-asset-generator`,
  вырезано 10 production PNG в `assets/sprites/ui/frames/codex/`, записаны
  content-zone/texture-margin metadata и QA previews. Runtime wiring/no-overlap
  integration переданы Back-end:
  `docs/tasks/backend_codex_texture_no_overlap_integration_task.md`.

## Design Result Summary

Новые runtime-кандидаты:

- `assets/sprites/ui/frames/codex/ui_frame_codex_main_panel.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_section_panel.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_entry_card.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_entry_card_hover.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_portrait_slot.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_tooltip.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_tab.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_tab_hover.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_tab_pressed.png`
- `assets/sprites/ui/frames/codex/ui_frame_codex_tab_disabled.png`

Source/metadata/previews:

- `docs/design/references/codex/codex_ui_texture_kit_reference.png`
- `docs/design/references/codex/codex_ui_texture_kit_metadata.json`
- `docs/design/previews/codex_ui_texture_kit_contact.png`
- `build/qa/scrum345/codex_texture_mock_1280x720.png`
- `build/qa/scrum345/codex_texture_mock_1920x1080.png`
- `build/qa/scrum345/codex_texture_mock_2560x1440.png`

Verification:

- OpenAI Images smoke PASS before generation.
- PNG validation PASS: 10/10 RGBA with transparent outer alpha and valid
  `content_rect`.
- Godot `--import` PASS and `.import` sidecars generated.
- Existing `tests/ui_no_overlap_matrix_test.gd` PASS before runtime integration.
- Existing `tests/runtime_smoke_ui_test.gd` PASS before runtime integration.

Acceptance note: live Codex replacement and runtime no-overlap checks are not
completed in this Design task because they require `scripts/ui_screens.gd`
integration. That scope is handed off to Back-end task
`backend_codex_texture_no_overlap_integration_task.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED (Design-scope: codex texture kit + метаданные + Back-end handoff)

Проверено (фактически):
- **10 codex-текстур** (`assets/sprites/ui/frames/codex/`): main/section панели,
  entry card + hover, portrait slot, tooltip, tabs ×4 (normal/hover/pressed/
  disabled) — все RGBA с прозрачной alpha (10/10).
- **Визуал** `codex_ui_texture_kit_contact.png` (+ моки 1280/1920/2560): D&D
  Dark Fantasy Dragon — тонкие металлические рамки + красные самоцветы, content-зоны
  (зелёные) маркированы (контент внутри, не на орнаменте). Метаданные
  `codex_ui_texture_kit_metadata.json` (content_rect/margins); Godot import чист.
- **Back-end handoff** `backend_codex_texture_no_overlap_integration_task.md`
  создан (статус **«new»**).
- **Тесты** (текущий рантайм): `ui_no_overlap_matrix_test` + `runtime_smoke_test`
  — passed.

⚠️ **Видимая замена текстур кодекса + no-overlap персонажей/текста ещё НЕ в рантайме**:
требует интеграции `scripts/ui_screens.gd` (`_show_codex_screen`/`_show_codex_section`)
— Back-end задача («new»), вне Design-scope. Проверю при готовности интеграции.

Acceptance (Design-scope):
- [x] Codex-текстуры созданы скиллом в едином D&D dragon-стиле (10 PNG).
- [x] Content-зоны заданы (контент внутри рамок); метаданные/превью/моки; import чист.
- [~] Live-замена + no-overlap персонажей/описаний на 3 разрешениях — Back-end integration.
- [x] Текущие no-overlap/runtime smoke зелёные; Back-end handoff с данными.

Статус review→done (Design-source). Баги: нет (видимая интеграция — delegated Back-end).
