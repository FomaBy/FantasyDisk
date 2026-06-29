extends SceneTree

# SCRUM-594: live-регресс на то, что ульта Доктора уважает healing_multiplier.
#
# _activate_doctor_ultimate был ЕДИНСТВЕННЫМ хилом в player.gd, который лил
# лечение прямо в health БЕЗ умножения на run_modifiers["healing_multiplier"]:
#   health = minf(max_health, health + healed)   # healed — «сырой»
# Все остальные хилы (регенерация :890, вампиризм :904, drain :925, прочие ульты
# :1115/1135/1193, heal_percent :1569) множат на healing_multiplier. Из-за этого
# артефакты/мета на «+лечение» усиливали ВСЕ хилы, кроме ульты Доктора —
# концептуальная дыра и недобор силы у healing-класса.
#
# Фикс: множим healed ОДИН раз на healing_multiplier и используем его и для
# health, и для overflow→absorb (чтобы и щит-перелив считался от усиленного хила).
#
# Гейт гоняет НАСТОЯЩЕГО Player.configure_character("doctor", ...) + живых врагов
# в радиусе ульты и проверяет два инварианта на боевом коде:
#   A. SCALES: при healing_multiplier=2.0 ульта восстанавливает ~вдвое больше HP,
#      чем при 1.0 (т.е. множитель реально применяется). До фикса — поровну.
#   B. OVERFLOW-FROM-MULTIPLIED: перелив сверх max_health (→ absorb_flat) считается
#      от УМНОЖЕННОГО хила: при max_health чуть выше базового хила mult=1.0 даёт 0
#      перелива, а mult=2.0 — заметный absorb_flat.
#
# Митигация лечения изолируется: max_health ставим заведомо больше любого хила в
# инварианте A, health=1, чтобы весь хил влился без клампа и дельта == влитому HP.
#
# Запуск: Godot --headless --path . --script res://tests/doctor_ult_healing_multiplier_test.gd

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const EPS := 0.01
const ENEMY_COUNT := 5


func _spawn_doctor(holder: Node2D) -> Node2D:
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	return player


# Ставит N живучих врагов ровно в точку игрока (всегда в радиусе ульты) и держит
# их живыми между прогонами: их HP заведомо больше урона ульты, так что во втором
# прогоне набор целей тот же.
func _spawn_tanky_enemies(holder: Node2D, at: Vector2, count: int) -> Array:
	var spawned: Array = []
	for _i in range(count):
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		holder.add_child(enemy)
		enemy.add_to_group("enemies")
		enemy.global_position = at
		enemy.set("max_health", 1.0e9)
		enemy.set("health", 1.0e9)
		spawned.append(enemy)
	return spawned


# Прогоняет ульту Доктора ОДИН раз при заданном healing_multiplier и возвращает
# фактический прирост health за каст. health сбрасываем в 1, max_health — в
# big_max (чтобы без клампа), absorb_flat обнуляем для чистоты инварианта B.
func _run_ult_once(player: Node2D, config: Dictionary, multiplier: float, healing_mult: float, big_max: float) -> float:
	var rm: Dictionary = player.get("run_modifiers")
	rm["healing_multiplier"] = healing_mult
	rm["absorb_flat"] = 0.0
	player.set("run_modifiers", rm)
	player.set("max_health", big_max)
	player.set("health", 1.0)
	var before := float(player.get("health"))
	player.call("_activate_doctor_ultimate", config, multiplier)
	return float(player.get("health")) - before


func _initialize() -> void:
	seed(594594)
	var errors: Array = []

	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame

	var player := _spawn_doctor(holder)
	await process_frame
	if not player.has_method("configure_character") or not player.has_method("_activate_doctor_ultimate"):
		push_error("Doctor ult healing-mult: Player без configure_character/_activate_doctor_ultimate — гейт невозможен.")
		quit(1)
		return
	player.configure_character("doctor", "restore_potion")
	await process_frame

	var config: Dictionary = player.call("_ultimate_config")
	var ult_multiplier := float(player.get("derived_parameters").get("ultimate_multiplier", 1.0))
	_spawn_tanky_enemies(holder, player.global_position, ENEMY_COUNT)
	await process_frame

	# Большой max_health, чтобы весь хил влился без клампа (инвариант A).
	var big_max := 1.0e6

	# --- A. SCALES: mult 2.0 лечит ~вдвое больше mult 1.0 ---
	var heal_at_1 := _run_ult_once(player, config, ult_multiplier, 1.0, big_max)
	var heal_at_2 := _run_ult_once(player, config, ult_multiplier, 2.0, big_max)

	if heal_at_1 <= EPS:
		errors.append("SCALES: базовый хил ульты = %.4f (нет врагов/урона?) — гейт не сработал" % heal_at_1)
	else:
		var ratio := heal_at_2 / heal_at_1
		if absf(ratio - 2.0) > 0.05:
			errors.append("SCALES: healing_multiplier не применён — heal×2.0/heal×1.0 = %.3f (ждали ~2.0); base=%.3f, x2=%.3f" % [ratio, heal_at_1, heal_at_2])

	# --- B. OVERFLOW-FROM-MULTIPLIED: перелив→absorb считается от умноженного хила ---
	# max_health чуть выше базового (mult=1.0) хила: тогда mult=1.0 не переливает,
	# а mult=2.0 (вдвое больший хил) — переливает, и absorb_flat растёт.
	var tight_max := 1.0 + heal_at_1 + 2.0  # ~базовый хил + запас → mult1 без перелива

	# mult=1.0: переливаться почти нечему → absorb_flat ~0.
	var rm1: Dictionary = player.get("run_modifiers")
	rm1["healing_multiplier"] = 1.0
	rm1["absorb_flat"] = 0.0
	player.set("run_modifiers", rm1)
	player.set("max_health", tight_max)
	player.set("health", 1.0)
	player.call("_activate_doctor_ultimate", config, ult_multiplier)
	var absorb_after_1 := float(player.get("run_modifiers").get("absorb_flat", 0.0))

	# mult=2.0: хил вдвое больше → заметный перелив → absorb_flat > 0.
	var rm2: Dictionary = player.get("run_modifiers")
	rm2["healing_multiplier"] = 2.0
	rm2["absorb_flat"] = 0.0
	player.set("run_modifiers", rm2)
	player.set("max_health", tight_max)
	player.set("health", 1.0)
	player.call("_activate_doctor_ultimate", config, ult_multiplier)
	var absorb_after_2 := float(player.get("run_modifiers").get("absorb_flat", 0.0))

	if not (absorb_after_2 > absorb_after_1 + EPS):
		errors.append("OVERFLOW: absorb_flat при mult=2.0 (%.4f) не больше mult=1.0 (%.4f) — перелив не считается от умноженного хила" % [absorb_after_2, absorb_after_1])

	print("Doctor ult heal: x1.0=%.3f, x2.0=%.3f (ratio %.3f); overflow→absorb: x1.0=%.4f, x2.0=%.4f" % [
		heal_at_1, heal_at_2, (heal_at_2 / heal_at_1 if heal_at_1 > EPS else 0.0), absorb_after_1, absorb_after_2])

	for child in holder.get_children():
		child.queue_free()
	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Doctor ult healing-mult: %s" % e)
		push_error("Doctor ult healing-multiplier test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Doctor ult healing-multiplier test passed: ульта уважает healing_multiplier (хил масштабируется, перелив→absorb считается от умноженного хила).")
	quit(0)
