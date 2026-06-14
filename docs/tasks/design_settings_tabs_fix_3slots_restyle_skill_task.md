# BUG/ART: Настройки — 4 вкладки вместо 3; пересоздать свитчер скиллом (3 слота)

Статус: done
Приоритет: high
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-341
Связано: SCRUM-324 (asset-skill), SCRUM-327 (опорная стиля), SCRUM-329 (кластер меню/настройки)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Исправить баг в настройках, где 4 вкладки, хотя надо только 3. А ещё изменить
стиль вкладок, используя новый скилл — должно быть реалистично, в цветах текущих
референсов».

Причина бага (scripts/ui_screens.gd): свитчер вкладок настроек нарисован на
4 слота — `SETTINGS_TAB_SWITCHER_SAFE_RECTS` (64) содержит 4 Rect2, а ассет
`assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher.png` (1280×256)
имеет 4 компартмента. Кода же только 3 вкладки (labels = ["Экран","Звук",
"Управление"], _make_settings_tab_switcher 1841; tabs_visible=false). Итог:
3 кнопки + пустой 4-й слот = визуально «4 вкладки».

## ОБЯЗАТЕЛЬНО — скилл генерации (директива пользователя)
Новый фрейм свитчера СОЗДАВАТЬ скиллом `fantasydisk-asset-generator`
(`scripts/generate_asset.py --prompt "<...>" --output settings/tab_switcher_3
--size 1280x256 --quality high`, OpenAI Images, `gpt-image-2`, PNG, ПРОЗРАЧНЫЙ
фон). Реалистичный стиль в цветах текущих референсов (см.
docs/design/references/settings_tab_switcher_frame/ и общий UI-стиль
D&D + Dark Fantasy Dragon, опорная SCRUM-327). Старый ассет — в бэкап.

## Требования
1. Пересоздать ассет свитчера вкладок ровно на **3 слота** (Экран / Звук /
   Управление), без пустого 4-го. Тот же путь
   (ui_frame_settings_tab_switcher.png) или новый файл с обновлением константы.
2. Обновить `SETTINGS_TAB_SWITCHER_SAFE_RECTS` (ui_screens.gd:64) до **3** Rect2,
   точно по позициям слотов нового ассета (кнопки/текст центрированы в слотах,
   не наезжают на орнамент — глобальное правило фреймов).
3. Стиль вкладок — реалистичный, в цветах текущих референсов; согласован с
   кластером меню/настроек (SCRUM-329) и опорной (SCRUM-327). Состояния
   selected/hover/pressed читаемы; hover без жёлтого свечения (SCRUM-318).
4. Сохранить логику: 3 вкладки, переключение по кнопкам, скролл «Управление»
   (SCRUM-275) не сломан.
5. Тест (smoke): настройки строятся; ровно 3 видимые вкладки, пустого слота нет;
   кнопки в слотах, no-overlap. Скрин настроек в build/qa/.
6. CHANGELOG; menus_ui; current_game_state.

## Files / Assets / IDs
- scripts/ui_screens.gd (SETTINGS_TAB_SWITCHER_* 61-64; _make_settings_tab_switcher
  1821; labels 1841; _settings_tab_button_style 1887)
- assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher.png (+ бэкап)
- docs/design/references/settings_tab_switcher_frame/ (референс/исходник скилла)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] В настройках ровно 3 вкладки, пустого 4-го слота нет; SAFE_RECTS = 3.
- [x] Свитчер пересоздан скиллом, реалистичный стиль в цветах референсов; кнопки в слотах, no-overlap.
- [x] Логика 3 вкладок/скролл не сломаны; smoke зелёные; скрин; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Blocker History — 2026-06-14
Design/Codex проверил обязательный генерационный шаг. Новый 3-slot settings tab
switcher должен быть пересоздан через `fantasydisk-asset-generator`, но в shell
нет `OPENAI_API_KEY`, а Python-пакет `openai` не установлен. Без production PNG
нельзя корректно зафиксировать `SAFE_RECTS=3` и content-zone под новый ассет.
Задача заблокирована до доступности skill; runtime-интеграция/SAFE_RECTS после
готовности ассета должна идти как UI/Back-end integration.

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
Design queue audit after SCRUM-352 confirmed this task still requires the new
3-slot settings tab switcher to be generated through
`fantasydisk-asset-generator` / OpenAI Images (`gpt-image-2`) and disallows
old/local/random generators. The current approved env source is available, but
OpenAI Images returns:

```text
billing_hard_limit_reached
```

Task is blocked until OpenAI image generation billing is available again or PM
provides an approved alternative generation source.

## Разблокировано 2026-06-14 (PM)
Биллинг OpenAI восстановлен и ПРОВЕРЕН: тестовая генерация gpt-image-2 успешна. Блок `billing_hard_limit_reached` устарел — снят. Можно генерить скиллом.

## Closure Note — Covered By SCRUM-391 / SCRUM-396

Статус: done / superseded-by-completed-work.

Эта задача является дублем уже завершенной пары:

- Design SCRUM-391:
  `docs/tasks/design_settings_menu_unified_restyle_task.md` — создал
  production 3-slot Settings tab switcher
  `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png`
  через `fantasydisk-asset-generator`, metadata safe rects и previews.
- Back-end SCRUM-396:
  `docs/tasks/backend_settings_menu_unified_restyle_integration_task.md` —
  подключил 3-slot switcher в runtime, заменил `SETTINGS_TAB_SWITCHER_SAFE_RECTS`
  на ровно три rects, удалил пустой четвертый слот и прогнал
  `runtime_smoke_ui`, `ui_no_overlap_matrix` и `runtime_smoke` PASS.

Дополнительная генерация не требуется и была бы дублированием уже принятого
asset/runtime результата.
