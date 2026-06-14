# Задача Для Design-Агента: Внедрить сгенерированный фрейм вкладок настроек

Статус: new
Создано: 2026-06-14
Автор: Codex asset generator workflow
Исполнитель: Design / Codex. Интеграция в код — через Back-end handoff при необходимости.
Версия: 0.1.5
Jira: SCRUM-325

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Пользователь запросил фрейм для переключения вкладок в настройках в стиле D&D + Dark Fantasy по уже существующим референсам из `docs/design/references/`.

Из-за отсутствия `OPENAI_API_KEY` и Python-пакета `openai` в текущем shell новый skill-скрипт `generate_asset.py` не смог быть запущен против OpenAI Images API. Визуальная генерация выполнена доступным image generation tool и локально доведена до project reference/preview по workflow skill-а.

## Source Asset
- Reference sheet: `docs/design/references/settings_tab_switcher_frame/settings_tab_switcher_frame_reference.png`
- Transparent production candidate: `docs/design/references/settings_tab_switcher_frame/settings_tab_switcher_frame_transparent.png`
- Preview on settings screen: `docs/design/previews/settings_tab_switcher_frame_preview.png`
- Intended skill/script model: `gpt-image-2`
- Intended size: `1536x1024`
- Intended quality: `high`
- Source anchors:
  - `docs/design/references/ui_dark_fantasy_2026_06/screen_settings_full_reference.png`
  - `docs/design/references/UiFrame/frame_kit_ornate_dark_sheet_b_spec.png`
  - `docs/design/references/Buttons/button_kit_red_gold_dragon_sheet.png`

## Prompt / Direction

```text
D&D + Dark Fantasy settings tab switcher frame for FantasyDisk. Four connected top tabs, one active tab raised and crimson-gold with ruby/gold glow, three inactive tabs dark leather/black stone/iron, engraved gold/brass bevels, ruby gemstones, gothic ornamental corner accents, no baked text in production asset, suitable for Settings tabs.
```

## Что Нужно Сделать
1. Проверить визуальное качество и соответствие текущему settings UI-канону.
2. При необходимости доработать `settings_tab_switcher_frame_transparent.png` как финальный runtime asset.
3. Если фрейм принимается, перенести финальный PNG в `assets/sprites/ui/frames/settings/` с каноничным именем.
4. Если для подключения нужны изменения `scripts/ui_screens.gd`/theme mapping — создать Back-end handoff или передать в Back-end.
5. Обновить `docs/design/content_registry.md`, релевантные UI docs и `CHANGELOG.md`, если ассет войдет в игру.
6. Соблюдать глобальное правило UI-фреймов от 2026-06-14: runtime-текст вкладок,
   иконки/состояния/кликабельные зоны и любой другой контент должны находиться
   только в пустой content-zone фрейма (прозрачный центр/плоская подложка/
   явно заданная safe-area). Не накладывать контент на декоративную окантовку,
   углы, самоцветы, металл, шипы, печати или орнамент; в результате записать
   content margins/safe-area для Back-end/QA.

## Acceptance Criteria
- [ ] Новый фрейм вкладок визуально согласован с settings screen, Ornate Dark и Red&Gold Dragon референсами.
- [ ] В production asset нет baked text; подписи вкладок остаются runtime-текстом.
- [ ] Активное, hover/pressed/disabled направления состояния понятны из reference sheet.
- [ ] Runtime-текст/иконки/кликабельные зоны вкладок находятся в content-zone и не перекрывают декоративную рамку.
- [ ] Runtime integration, если выполняется, не ломает layout и не создаёт overlap на 1152x648 и wide-low viewport.
- [ ] Jira и task-файл синхронизированы после смены статуса.

## Передача 2026-06-14

Передано в Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` по запросу пользователя:
дизайнер должен принять/доработать новый вид tabs для настроек, перенести финальный
PNG в runtime assets и зафиксировать content-zone/safe-area для Back-end/QA.
