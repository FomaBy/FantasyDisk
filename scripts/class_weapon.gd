class_name ClassWeapon
extends "res://scripts/classes/thief_weapon.gd"

# Классовое оружие: 43 attack-mode исполнителя 17 классов, общий слой
# целей/урона/статусов/луж/созвездий и жизненный цикл боевых эффектов.
#
# FAN-3840: монолит class_weapon.gd разрезан на модули scripts/classes/**.
# Этот файл — тонкий фасад: он ЗАВЕРШАЕТ линейную extends-цепочку модулей и
# остаётся единственной точкой входа (class_name ClassWeapon; прямые
# preload("res://scripts/class_weapon.gd") и наследники, например
# robot_hydraulic_press_weapon.gd, работают без изменений). Класс в рантайме
# один, поэтому весь публичный контракт — методы, свойства, константы,
# ATTACK_MODE_EXECUTORS, has_method/call, Callable(self, ...) — сохранён 1:1.
#
# Состав цепочки (базовый → верхний):
#    1. scripts/classes/class_weapon_state.gd — разделяемое состояние: preload-константы, @export-конфиг, runtime-переменные и реестр ATTACK_MODE_EXECUTORS
#    2. scripts/classes/class_weapon_shared_api.gd — автогенерируемые forward-объявления кросс-модульных методов (виртуальная диспетчеризация)
#    3. scripts/classes/class_weapon_core.gd — жизненный цикл и конвейер атаки: _ready/_attack/configure_weapon, эхо классовых артефактов, заряд, реестр эффектов
#    4. scripts/classes/class_weapon_combat.gd — общий боевой слой: цели/урон/статусы/лужи/капы ширины и диспетчеризация событий созвездий
#    5. scripts/classes/assassin_weapon.gd — класс assassin: исполнители режимов и приватные хелперы
#    6. scripts/classes/biologist_weapon.gd — класс biologist: исполнители режимов и приватные хелперы
#    7. scripts/classes/chemist_weapon.gd — класс chemist: исполнители режимов и приватные хелперы
#    8. scripts/classes/dark_mage_weapon.gd — класс dark_mage: исполнители режимов и приватные хелперы
#    9. scripts/classes/doctor_weapon.gd — класс doctor: исполнители режимов и приватные хелперы
#   10. scripts/classes/druid_weapon.gd — класс druid: исполнители режимов и приватные хелперы
#   11. scripts/classes/elementalist_weapon.gd — класс elementalist: исполнители режимов и приватные хелперы
#   12. scripts/classes/engineer_weapon.gd — класс engineer: исполнители режимов и приватные хелперы
#   13. scripts/classes/guitarist_weapon.gd — класс guitarist: исполнители режимов и приватные хелперы
#   14. scripts/classes/priest_weapon.gd — класс priest: исполнители режимов и приватные хелперы
#   15. scripts/classes/ranger_weapon.gd — класс ranger: исполнители режимов и приватные хелперы
#   16. scripts/classes/robot_weapon.gd — класс robot: исполнители режимов и приватные хелперы
#   17. scripts/classes/sniper_weapon.gd — класс sniper: исполнители режимов и приватные хелперы
#   18. scripts/classes/soldier_weapon.gd — класс soldier: исполнители режимов и приватные хелперы
#   19. scripts/classes/thief_weapon.gd — класс thief: исполнители режимов и приватные хелперы
#
# Как добавить класс/режим:
#   1. Создай scripts/classes/<class_id>_weapon.gd c
#      `extends "res://scripts/classes/<последний-модуль>.gd"` и перенаправь
#      extends этого фасада на новый модуль (одна строка).
#   2. Зарегистрируй режим в ATTACK_MODE_EXECUTORS
#      (scripts/classes/class_weapon_state.gd).
#   3. Кросс-модульные методы объяви forward-стабом в
#      class_weapon_shared_api.gd, если их зовут общие модули.
#   4. Владение: класс-модуль принадлежит домену class/<class_id>
#      (docs/process/ownership_map.md); общий слой и фасад — бюджетные
#      общие файлы.
