# UI Screens Inventory — FantasyDisk

Создано: 2026-06-27. Канонический список ВСЕХ уникальных экранов/UI-состояний игры
для глобального редизайна интерфейса (база 2K). Источник: `scripts/ui_screens.gd`,
`scripts/main.gd`.

## Базовое разрешение и масштабирование (политика редизайна)

- **База дизайна: 2K = 2560×1440 (16:9).** Все элементы проектируются под этот размер.
- **Full HD (1920×1080)** — ужимает 2K (тот же 16:9, uniform downscale).
- **4K (3840×2160)** — растягивает 2K (тот же 16:9, uniform upscale).
- **Другие соотношения сторон** (ultrawide 21:9, 16:10, 4:3) в фуллскрине — **чёрные
  полосы** (letterbox сверху/снизу или pillarbox по бокам, в зависимости от лишнего).
- Реализация в Godot: `display/window/size/viewport_width=2560`, `viewport_height=1440`,
  `stretch/mode=canvas_items`, `stretch/aspect=keep` (keep = uniform scale + чёрные полосы).
- **Инварианты для КАЖДОГО элемента:** ничего не вылазит за экран; элементы не
  наслаиваются; текст не выходит за рамки фрейма; ассеты рендерятся в свой точный
  размер (без растяжения орнамента).

## A. Полноэкранные экраны (19)

| # | Экран | Корневая нода | Вход | Файл |
|---|---|---|---|---|
| 1 | Главное меню | `MainMenuScreen` | `_show_main_menu` | ui_screens.gd:291 |
| 2 | Выбор героя (портрет/радар/досье) | `HeroSelectScreen` | `_show_character_select` → `_build_character_select_v4` | ui_screens.gd:969 / 704 |
| 3 | Выбор оружия | — | `_show_weapon_select` | ui_screens.gd:3803 |
| 4 | Карта маршрута | `RouteMapScreen` | `_show_battle_map` | main.gd:962 |
| 5 | Бой / HUD (таймер, статы, дамаг-флэш) | `CombatTimerPanel`, `DerivedStatsPanel`, `DamageFlashOverlay` | in-run | ui_screens.gd |
| 6 | Событие | `EventScreen` | `_show_event_screen` | ui_screens.gd:4911 |
| 7 | Отдых / костёр | — | `_show_rest_screen` | ui_screens.gd:4870 |
| 8 | Магазин | `ShopScreen` | `_show_shop_screen` | ui_screens.gd:4395 |
| 9 | Докача (атрибут-шоп) | `AttributeShopScreen` | `_show_attribute_shop` | ui_screens.gd:1755 |
| 10 | Дерево навыков | `SkillTreeScreen` | `_show_skill_tree_screen` | ui_screens.gd:1967 |
| 11 | Повышение уровня | `LevelUpOverlay` / `LevelUpPanel` | `_show_level_up_screen` | ui_screens.gd:3953 |
| 12 | Награда (обычная) | — | `_show_reward_screen` | ui_screens.gd:3919 |
| 13 | Награда элитки / артефакт | `EliteArtifactRewardScreen` | `_show_elite_artifact_reward` | ui_screens.gd:4039 |
| 14 | Улучшение | — | `_show_upgrade_screen` | ui_screens.gd:4894 |
| 15 | Кодекс (+ разделы) | `CodexScreen` (`CodexNav/Main/Detail`) | `_show_codex_screen` / `_show_codex_section` | ui_screens.gd:2282 |
| 16 | Настройки | `SettingsContentPanel` | `_show_settings_menu` | ui_screens.gd:3011 |
| 17 | Что нового / патч-ноуты | `PatchNotesScreen` | `_show_patch_notes_screen` | ui_screens.gd:2215 |
| 18 | Победа | — | `_show_victory_screen` | ui_screens.gd:5003 |
| 19 | Смерть | — | `_show_death_screen` | ui_screens.gd:5038 |

**Разделы Кодекса** (под-вкладки одного экрана, не отдельные экраны): персонажи
(`_build_codex_characters`), монстры, артефакты, вознесения, статы, глоссарий.

## B. Паузы / модалки / оверлеи (6)

| # | Экран | Корневая нода | Вход | Файл |
|---|---|---|---|---|
| 20 | Пауза в забеге | `RunPauseMenuPanel` | `_show_pause_menu` → `_build_run_pause_menu` | ui_screens.gd:3497 / 3513 |
| 21 | Пауза — досье | — | `_show_pause_dossier_menu` | ui_screens.gd:3590 |
| 22 | Подтверждение выхода | `QuitConfirmationPanel` | `_show_quit_confirmation_dialog` | ui_screens.gd:423 |
| 23 | Продолжить забег | `ContinueRunPanel` | `_show_continue_run_dialog` | ui_screens.gd:532 |
| 24 | Форма фидбэка | `FeedbackOverlay` / `FeedbackPanel` | `_show_feedback_overlay` | ui_screens.gd:5940 |
| 25 | Конфликт переназначения клавиш | — | `_show_rebind_conflict` (в настройках) | ui_screens.gd:5846 |

## C. Тултипы / транзиентные баннеры (5)

| # | Элемент | Корневая нода | Вход | Файл |
|---|---|---|---|---|
| 26 | Тултип глоссария | `GlossaryTooltipPanel` | `_show_glossary_tooltip` | ui_screens.gd:2722 |
| 27 | Тултип статов | `StatTooltipPanel` | — | ui_screens.gd |
| 28 | Тост повышения уровня | — | `_show_level_up_toast` | ui_screens.gd:5361 |
| 29 | Баннер заголовка боя | — | `_show_combat_title_banner` | ui_screens.gd:5396 |
| 30 | Баннер победы | — | `_show_victory_banner` | ui_screens.gd:1686 |

## Итого
**30 уникальных UI-состояний:** 19 полноэкранных + 6 модалок/пауз + 5 тултипов/баннеров.

## Следующий шаг (для рисующего скрипта)
Под каждый экран — таблица элементов с **точными координатами контента @2560×1440**
(`x, y, w, h` каждого слота: панели, кнопки, тексты, портреты, иконки, списки) +
safe-area фрейма. Эти координаты помечаются константами в коде (рядом с билдером
экрана) и отдаются скрипту генерации ассетов, чтобы он рисовал в точный размер.
