# ART/UX: Перерисовать ВЕСЬ интерфейс — аккуратно и минималистично (красные кнопки оставить)

Статус: done
Приоритет: high
Роль: Designer 2 (Codex) → Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-448

## SUPERSEDED серией UI Simplification (2026-06-15)
Заменён 3 задачами: опорная минимал-металлик + кнопки по референсам + роллаут рамок.
Связано: SCRUM-384 (единый фрейм — переосмысляется в минимализм), SCRUM-273 (красные кнопки — СОХРАНИТЬ), SCRUM-324 (asset-skill)

## QA-Вердикт (закрыт как superseded 2026-07-02)
Статус: PASSED

claude-qa 2026-07-02: задача SUPERSEDED — интерфейс перерисован волной UI Overhaul 2K (программа SCRUM-481, 19 тикетов Готово) + серией UI Simplification (SCRUM-450/451/452). Отдельного deliverable по этой легаси-задаче не требуется. Закрыта (ревизия беклога 2026-07-02).
(PASSED здесь = идиома закрытия board_sync для superseded-задачи без остаточного deliverable, а не приёмка старого редизайна.)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Перерисовать весь интерфейс, КРОМЕ красных кнопок, аккуратно и минималистично».

Сейчас интерфейс перегружен орнаментом (драконьи рамки, самоцветы и т.п.).
Пользователь хочет чистый минимализм — но КРАСНЫЕ КНОПКИ (текущие Red&Gold/драконьи
кнопки, SCRUM-273) НРАВЯТСЯ и остаются как есть.

## ОБЯЗАТЕЛЬНО — скилл
Графику генерировать скиллом `fantasydisk-asset-generator` (gpt-image-2, PNG,
ПРОЗРАЧНЫЙ фон). Чистить прозрачность (`tools/strip_white_background.py`).

## Требования
1. **Минималистичный, аккуратный единый стиль** для ВСЕХ рамок/панелей/полей/
   тултипов/подложек интерфейса: тонкие чистые линии, спокойный тёмный фон,
   сдержанные акценты; УБРАТЬ тяжёлый орнамент/драконьи завитки/обилие самоцветов.
   Читаемость и воздух важнее декора. Единый язык на всех экранах.
2. **КРАСНЫЕ КНОПКИ НЕ ТРОГАТЬ** — текущие красные кнопки (SCRUM-273) остаются как
   есть; новый минимализм рамок/панелей должен с ними сочетаться (красный акцент
   кнопок = единственный яркий элемент на спокойном фоне).
3. Применить по ВСЕМ экранам: меню, настройки, выбор героя, кодекс, магазин, награды,
   повышение, события, пауза, финалы, бой-HUD, тултипы, диалоги.
4. Свести к единому минимал-фрейму (переосмыслить SCRUM-384 в минимализм):
   один стиль-билдер, тонкие content-margins, контент в content-зоне (правило фреймов).
   Старые орнаментальные ассеты — в бэкап (вне сборки), мёртвые пути убрать.
5. Ничего не накладывается, текст читаем, адаптив 1280×720/1920×1080/2560×1440.
6. Тест (smoke + no-overlap matrix): все экраны строятся в минимал-стиле, красные
   кнопки на месте, no-overlap. Контакт-лист стиля + скрины ключевых экранов в build/qa/.
7. CHANGELOG; menus_ui + visual_style_assets; content_registry.

## Files / Assets / IDs
- scripts/ui_screens.gd (единый стиль-билдер фрейма; _make_button/красные кнопки — НЕ трогать;
  GLOBAL_*_FRAME_PATH; _unified_frame_style)
- assets/sprites/ui/frames/ (новый минимал-набор) + бэкап орнаментальных; красные кнопки оставить
- docs/design/references/ui_minimal/ (исходники/контакт-лист)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [x] Весь интерфейс получил Design-source направление и единый аккуратный
      МИНИМАЛ-kit для рамок/панелей/тултипов/подложек; runtime применение
      передано Back-end.
- [x] КРАСНЫЕ КНОПКИ явно сохранены: `assets/sprites/ui/frames/red_gold/` не
      менялись, SCRUM-273 остаётся каноном.
- [x] Единый минимал-фрейм описан через metadata/spec; контентные зоны и
      responsive-правила для 1280×720/1920×1080/2560×1440 зафиксированы.
- [x] Контакт-лист, alpha audit и Design docs обновлены; бэкап старого
      орнаментального runtime, smoke/matrix и скриншоты переданы Back-end.

## Документация
docs/design/systems/visual_style_assets.md, docs/design/systems/menus_ui.md, content_registry.

## Результат

Design-source пакет SCRUM-448 готов:

- OpenAI UI style-board/mockup:
  `docs/design/references/ui_minimal/scrum448_minimalist_ui_style_board.png`
- OpenAI frame source sheet:
  `docs/design/references/ui_minimal/scrum448_minimalist_frame_kit_source_sheet.png`
- UI-director spec:
  `docs/design/mockups/scrum448_ui_minimalist/spec.md`
- Mirror spec:
  `docs/design/references/ui_minimal/scrum448_minimalist_ui_spec.md`
- Frame metadata:
  `docs/design/references/ui_minimal/scrum448_minimal_ui_frame_metadata.json`
- Contact preview:
  `docs/design/previews/scrum448_minimal_ui_frame_contact.png`
- Alpha QA:
  `build/qa/scrum448_ui_minimalist/alpha_audit.md`

Runtime candidate PNGs:

- `assets/sprites/ui/frames/minimal/ui_frame_minimal_modal.png`
- `assets/sprites/ui/frames/minimal/ui_frame_minimal_panel.png`
- `assets/sprites/ui/frames/minimal/ui_frame_minimal_card.png`
- `assets/sprites/ui/frames/minimal/ui_frame_minimal_tooltip.png`
- `assets/sprites/ui/frames/minimal/ui_frame_minimal_hud_strip.png`
- `assets/sprites/ui/frames/minimal/ui_frame_minimal_field.png`

All six transparent frame PNGs pass the strict alpha audit:
`white_opaque_pixels=0`, `pale_visible_pixels_after_cleanup=0`,
`pale_edge_visible_pixels=0`.

Role-boundary note: Back-end runtime integration, old ornamental asset backup,
UI smoke/no-overlap matrix and screenshots are handed off to
`docs/tasks/backend_ui_minimalist_restyle_keep_red_buttons_integration_task.md`.
