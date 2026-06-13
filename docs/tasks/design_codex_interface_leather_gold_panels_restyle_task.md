# Задача Для Design-Агента: Переделать интерфейс — панели/окна в стиле «кожа+золото» (референсы пользователя)

Статус: new
Приоритет: high
Роль: Design (Claude-Designer обработка/9-slice/интеграция) → Back-end handoff
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-229

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Роль И Границы
Владелец — Claude-Designer (обработка сырого арта, 9-slice, ревью, интеграция,
коммит). Доп. генерация при нехватке — Codex Design с этими референсами.
Интеграция стайлбоксов в код — handoff Back-end (или Designer сам, если просто
замена panel-stylebox).

## Контекст (запрос пользователя)
«Переделать интерфейс — файлы PNG интерфейса лежат в папке references/interface».
Это `docs/design/references/interface/` — 5 PNG: цельный кит ПАНЕЛЕЙ/РАМОК
«тёмная кожа + золотая гравированная окантовка» (угловые кронштейны, заклёпки,
свечение по канту, прозрачный фон). Состав — см. README папки.

Связь с SCRUM-147: тот рестайл сведён к «кнопки = Parchment&WaxSeal, панели =
legacy». Этот кит — именно для ПАНЕЛЕЙ/ОКОН, которые остались legacy. Итог:
кнопки — пергамент+печать, панели/окна/плашки — кожа+золото (единый dark fantasy).

## Требования
1. **Обработать сырьё**: 5 ChatGPT-PNG (имена с пробелами) → отобрать, обрезать,
   привести к каноничным именам (например `ui_panel_leather_gold_square.png`,
   `ui_panel_leather_gold_wide.png`, `ui_bar_leather_gold_thin.png`,
   `ui_window_leather_gold_main.png`, `ui_check_leather_gold.png`), проверить
   alpha. Сырьё НЕ кладётся в live-ассеты — финал в `assets/sprites/ui/frames/`.
2. **9-slice**: для каждой рамки задать nine-patch margins (тянущаяся середина,
   неискажаемые углы/кронштейны/заклёпки) — корректное растяжение под любой
   размер панели.
3. **Карта замены**: применить кит ко ВСЕМ панелям/окнам интерфейса —
   пауза-досье, level-up, докачка, магазин, события, награда элитки, настройки,
   кодекс, hero select, HUD-плашки, тултипы, чипы, разделители, чекбоксы
   (галочка из набора). Таблица «текущий panel-stylebox → новый ассет» в отчёте.
4. **Согласовать с кнопками**: панели — кожа+золото, кнопки — пергамент+печать
   (SCRUM-147). Чтобы вместе смотрелось как один dark fantasy канон.
5. **Удалить/заменить legacy panel-фреймы** после интеграции (старые в backup,
   content_registry почистить). «no junk UI» — без лишнего декора.
6. Правило «UI не наползает»: новые рамки не ломают раскладки/отступы на
   1280x720 и 2560x1440.
7. Канон: обновить docs/design/systems/visual_style_assets.md (панель-кит).
8. Тест (smoke): экраны грузят новые panel-стайлбоксы (фактическое дерево +
   загрузка текстур), no-overlap ключевых экранов; скриншоты до/после в build/qa/.
9. CHANGELOG; content_registry.

## Files / Assets / IDs
- Сырьё: docs/design/references/interface/ (5 PNG, см. README)
- Финал: assets/sprites/ui/frames/ (новые panel/window/bar/check ассеты)
- scripts/ui_screens.gd, scripts/pause_stats_menu.gd (потребители panel-styleboxes)
- docs/design/systems/visual_style_assets.md, content_registry.md

## Acceptance Criteria
- [ ] 5 рамок обработаны (имена/alpha/9-slice), в assets/sprites/ui/frames/.
- [ ] Панели/окна/плашки/тултипы/чекбоксы переведены на кит «кожа+золото»; карта замены полная.
- [ ] Согласовано с кнопками-пергаментом; legacy panel-фреймы убраны.
- [ ] no-overlap; 6 smoke зелёные; скриншоты до/после в build/qa/; CHANGELOG/registry.

## Документация
visual_style_assets.md, content_registry.md, current_game_state.md.
