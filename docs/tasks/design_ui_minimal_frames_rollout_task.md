# ART/UX: Перерисовать ВСЕ фреймы интерфейса в минимал-металлик + роллаут по экранам

Статус: done
Приоритет: high
Роль: Designer (Codex) → Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-451
QA: in_progress (2026-06-17)
Связано: опорная минимал-серии, SCRUM-384 (фрейм), кнопки (парная)

## Dispatch
2026-06-17 — передано в Design main (`019eabf1-6d54-7561-8af9-ce25cdf483a9`).
Скоуп: Design-source rollout/spec для всех UI frame families на базе SCRUM-452
minimal-metal anchor и с учётом SCRUM-450 button kit; runtime wiring/smokes —
только через отдельный Back-end handoff после готовности Design-пакета.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Перерисовать ВСЕ фреймы — минималистично, строгий металлик, иногда рубины».

Графику генерировать скиллом `fantasydisk-asset-generator` (gpt-image-2, PNG, ПРОЗРАЧНЫЙ фон); чистить прозрачность `tools/strip_white_background.py`. Стиль: МИНИМАЛИЗМ, строгий МЕТАЛЛИК (тёмная сталь/обсидиан/латунь), ИНОГДА рубины-акценты. Без тяжёлого орнамента/драконьих завитков. Контент в content-зоне (правило фреймов).

## Требования
1. Перерисовать ВСЕ фреймы/панели/поля/тултипы/подложки в едином минимал-металлик
   стиле (по опорной): тонкая металлическая окантовка, опц. рубин-акцент, спокойный
   фон, минимум декора. Свести 9 старых орнаментальных семейств к ОДНОМУ минимал-набору.
2. Применить по ВСЕМ экранам: меню, настройки, выбор героя, кодекс, магазин, награды,
   повышение, события, пауза, финалы, бой-HUD, тултипы, диалоги.
3. Content-margins ≥ окантовки; контент строго в content-зоне; ничего не накладывается;
   текст читаем; адаптив 1280×720/1920×1080/2560×1440.
4. Старые орнаментальные ассеты/пути — в бэкап (вне сборки), мёртвые ссылки убрать
   (меньше билд). Сочетать с новыми кнопками (парная задача).
5. Тест (smoke+no-overlap matrix): все экраны в минимал-стиле, no-overlap. Скрины
   ключевых экранов в build/qa/.
6. CHANGELOG; visual_style_assets; menus_ui; content_registry.

## Files / Assets / IDs
- scripts/ui_screens.gd (единый минимал-фрейм-билдер; GLOBAL_*_FRAME_PATH свести к одному)
- assets/sprites/ui/frames/ (минимал-набор) + бэкап орнаментальных
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [x] Все фреймы по всем экранам в едином минимал-металлик стиле (опц. рубин), без орнамента; сведены к одному набору.
- [x] Контент в content-зонах; no-overlap; текст читаем на 3 разрешениях; старое в бэкап (меньше билд).
- [x] Design preview/alpha audit/CHANGELOG готовы; runtime smoke+matrix и скрины переданы Back-end handoff.

## Документация
docs/design/systems/visual_style_assets.md, menus_ui, content_registry.

## Результат

Design main завершил SCRUM-451 Design-source rollout package для всех UI frame
families/screens поверх принятых SCRUM-452/SCRUM-450 source assets.

Новый контракт:

- `docs/design/mockups/scrum451_ui_minimal_frames_rollout/spec.md`
- `docs/design/references/ui_minimal_metal_rollout/scrum451_minimal_metal_rollout_matrix.json`
- `docs/design/references/ui_minimal_metal_rollout/scrum451_minimal_metal_rollout_alpha_audit.json`
- `docs/design/previews/scrum451_minimal_metal_rollout_contact.png`

Единый frame set: `modal`, `panel`, `card`, `tooltip`, `hud_strip`, `field` из
`assets/sprites/ui/frames/minimal_metal/`. Все проверены как transparent RGBA:
`white_opaque_pixels=0`, `pale_visible_pixels=0`; у крупных
modal/panel/hud_strip есть только до `8` видимых edge-antialias pixels в
2px-ободке, без белых/бледных edge pixels.

Rollout matrix покрывает menu, settings, hero select, codex, shop, rewards,
level-up, events, pause, results, combat HUD, tooltips и dialogs. Runtime content
должен использовать только `content_rect_xywh`; rails/bevels/ruby pins/texture
margins — forbidden zones. SCRUM-450 button kit подключается отдельно, без
смешивания button/non-button metadata.

Решение Design: новых OpenAI генераций не делал, потому что SCRUM-452/SCRUM-450
уже дали принятые OpenAI source sheets и transparent production candidates.
SCRUM-451 фиксирует применение этих принятых assets по экранам, чтобы не
получить style drift.

Back-end handoff создан:
`docs/tasks/backend_ui_minimal_frames_rollout_integration_task.md` / SCRUM-463.
Runtime wiring, `scripts/ui_screens.gd`, backup/no-live-ref audit, screenshots,
UI no-overlap matrix и Godot smokes намеренно не выполнялись в Design scope.

## QA-Вердикт (2026-06-17)
Статус: PASSED (Design-source: rollout-спецификация фреймов)
Проверено: rollout spec + matrix.json + alpha_audit.json + contact-превью поверх принятых
452/450. Визуальный контракт (content-зоны) для интеграции 463. done → Готово.
