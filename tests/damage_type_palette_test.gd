extends SceneTree

# SCRUM-523: инвариант «цвет ↔ тип урона».
# Палитра боевых цифр живёт В ОДНОМ месте — scripts/enemy.gd::COMBAT_FEEDBACK_DAMAGE_COLORS,
# доступ через статический Enemy.damage_type_color(). Этот тест фиксирует:
#   1) каждый тип отдаёт ожидаемый стабильный цвет;
#   2) неизвестный/непроставленный тип откатывается на "true" (чистый/белый);
#   3) class_weapon маршрутизирует КАНАЛ урона (damage_parameter) в строковый тип,
#      т.е. магия/звук/физика не схлопываются в "true".
# Чистый unit без RNG/сцены → стабилен в фокус-прогоне tools/run_focused_tests.sh.

const EnemyScript := preload("res://scripts/enemy.gd")
const ClassWeaponScript := preload("res://scripts/class_weapon.gd")

const EXPECTED_COLORS := {
	"physical": Color(1.0, 0.84, 0.42, 1.0),
	"magic": Color(0.68, 0.46, 1.0, 1.0),
	"dot": Color(0.46, 1.0, 0.42, 1.0),
	"sound": Color(0.30, 0.86, 1.0, 1.0),
	"true": Color(1.0, 0.96, 0.82, 1.0),
}


func _init() -> void:
	var failures: Array[String] = []

	# 1) Палитра: тип → стабильный цвет.
	for damage_type in EXPECTED_COLORS.keys():
		var got: Color = EnemyScript.damage_type_color(damage_type)
		if not got.is_equal_approx(EXPECTED_COLORS[damage_type]):
			failures.append("color[%s]: expected %s, got %s" % [damage_type, EXPECTED_COLORS[damage_type], got])

	# 2) Fallback неизвестного типа → "true".
	var fallback: Color = EnemyScript.damage_type_color("__nope__")
	if not fallback.is_equal_approx(EXPECTED_COLORS["true"]):
		failures.append("fallback: expected true-color %s, got %s" % [EXPECTED_COLORS["true"], fallback])

	# 3) class_weapon: канал (damage_parameter) → строковый тип.
	var channel_to_type := {
		"magic_damage": "magic",
		"sound_wave_damage": "sound",
		"damage": "physical",
		"some_unknown_param": "physical",  # дефолт — физика, не "true".
	}
	var weapon := ClassWeaponScript.new()
	for channel in channel_to_type.keys():
		weapon.damage_parameter = channel
		var resolved := str(weapon.call("_weapon_damage_type"))
		if resolved != channel_to_type[channel]:
			failures.append("channel[%s]: expected %s, got %s" % [channel, channel_to_type[channel], resolved])
	weapon.free()

	if failures.is_empty():
		print("damage_type_palette_test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("damage_type_palette_test: " + failure)
		print("damage_type_palette_test: FAIL (%d)" % failures.size())
		quit(1)
