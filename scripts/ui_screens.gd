extends "res://scripts/ui/screens/hud_overlays.gd"

# Меню, настройки, выбор персонажа/оружия, магазин, события, отдых,
# level-up, победа/смерть, HUD и общие UI-стили.
#
# FAN-3824: монолит ui_screens.gd разрезан на экранные модули
# scripts/ui/screens/**. Этот файл — тонкий фасад: он ЗАВЕРШАЕТ линейную
# extends-цепочку модулей и остаётся единственной точкой инстанцирования
# (main.gd: preload + .new(game)). Класс в рантайме один, поэтому весь
# публичный контракт — методы, свойства, has_method/call, Callable(self,...)
# — сохранён 1:1.
#
# Состав цепочки (базовый → верхний):
#    1. scripts/ui/screens/ui_screens_state.gd — разделяемое состояние, preload-константы и координатные спеки всего UI-класса
#    2. scripts/ui/screens/ui_screens_shared_api.gd — автогенерируемые forward-объявления кросс-модульных методов (виртуальная диспетчеризация)
#    3. scripts/ui/screens/ui_style_kit.gd — общий кит стилей: кнопки, панели, рамки, карточки, тултипы
#    4. scripts/ui/screens/shared_shell_kit.gd — общий каркас экранов: unified-фон/рамки, безопасные зоны, фокус-навигация
#    5. scripts/ui/screens/menu_shell_kit.gd — gold-shell меню и результаты: меню-боксы, раскладка, фоны экранов
#    6. scripts/ui/screens/main_menu.gd — главное меню, диалоги выхода и продолжения забега
#    7. scripts/ui/screens/hero_select_kit.gd — хелперы экрана выбора героя (hs4-стили, превью портретов)
#    8. scripts/ui/screens/hero_select.gd — экран выбора героя (Character Select v4)
#    9. scripts/ui/screens/attribute_shop.gd — лавка характеристик и цены вознесения
#   10. scripts/ui/screens/victory_death.gd — баннер победы, экраны победы/смерти и сводка забега
#   11. scripts/ui/screens/atlas_screen.gd — экран «Атлас героев»: показ, стили, чипы валют
#   12. scripts/ui/screens/atlas_canvas.gd — канвас Атласа: раскладка узлов, рёбра, вкладки, покупка, фокус
#   13. scripts/ui/screens/misc_screens.gd — патч-ноуты, титры и делегаты лор-экранов
#   14. scripts/ui/screens/codex.gd — Кодекс: сцена, вкладки, досье и разделы
#   15. scripts/ui/screens/codex_entries.gd — Кодекс: сборка списков записей по вкладкам
#   16. scripts/ui/screens/settings_screen.gd — экран настроек: показ, видео-настройки, возврат
#   17. scripts/ui/screens/settings_tabs.gd — вкладки настроек: игра, управление, аудио, стили v6
#   18. scripts/ui/screens/pause_menu.gd — пауза: меню, подтверждение завершения забега, досье
#   19. scripts/ui/screens/weapon_select.gd — выбор оружия и стартового дара
#   20. scripts/ui/screens/level_up_screen.gd — экран level-up: показ, метрики, интро-анимации
#   21. scripts/ui/screens/level_up_cards.gd — карточки наград level-up/боя/артефактов и превью эффектов
#   22. scripts/ui/screens/shop.gd — магазин: gold-shell, слоты, тултипы, покупки
#   23. scripts/ui/screens/run_encounters.gd — экраны узлов забега: событие, отдых, апгрейд и исходы событий
#   24. scripts/ui/screens/input_bindings.gd — клавиатурный и геймпадный ребинд, статус устройств
#   25. scripts/ui/screens/feedback.gd — оверлей обратной связи
#   26. scripts/ui/screens/battle_prayer.gd — выбор боевой молитвы
#   27. scripts/ui/screens/hud.gd — боевой и меню-HUD: панели, таймер, босс-бар, артефакты
#   28. scripts/ui/screens/hud_overlays.gd — HUD-оверлеи и ресурсы: виньетка, урон-вспышка, меню-HUD, обновление HUD
#
# Как добавить новый экран:
#   1. Создай scripts/ui/screens/<screen>.gd c `extends "res://scripts/ui/screens/hud_overlays.gd"`
#      и перенаправь extends этого фасада на новый модуль (одна строка).
#   2. Кросс-модульные методы нового экрана объяви forward-стабом в
#      ui_screens_shared_api.gd, если их зовут другие модули.
#   3. Владение: экранный модуль принадлежит домену ui/<screen>
#      (docs/process/ownership_map.md); общие киты и фасад — бюджетные
#      общие файлы.
