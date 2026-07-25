extends SceneTree

# FAN-1449: матрица ручного прицеливания 51/51.
#
# Для КАЖДОГО оружия проекта прогоняем три запуска одной и той же атаки —
# авто-наводка, ручная мышь, ручной правый стик — и проверяем контракт:
#
#   1) ручной режим действительно спрашивает канонический провайдер наводки;
#   2) направление/точка атаки берутся из наводки, а не из ближайшего врага;
#   3) паритет: cooldown, урон, радиусы, дальность и капы совпадают во всех
#      трёх запусках — различаются только направление и точка;
#   4) один тик атаки остаётся одним кастом (ручной режим не множит атаки).
#
# Владелец здесь — тонкий фейк с тем же адаптером, что и `player.gd`: сам
# провайдер настоящий, поэтому проверяется контракт пакета, а не заглушка.
# Боевая проводка провайдера в Player (устройство, hot-plug, прицел) закрыта
# `tests/aim_controller_runtime_test.gd`.

const ProgressionData := preload("res://scripts/progression_data.gd")
const AimController := preload("res://scripts/input/aim_controller.gd")

const OWNER_POSITION := Vector2(1200.0, 900.0)
# Враг стоит строго вверх: авто-наводка обязана целиться в него, а обе ручные
# наводки — в свою сторону, поэтому подмену режима видно по знаку.
const ENEMY_OFFSET := Vector2(0.0, -170.0)
const MOUSE_OFFSET := Vector2(420.0, 0.0)
const STICK_INPUT := Vector2(0.0, 0.94)

# Паритетные поля: если ручная наводка их трогает, ломается баланс оружия.
const PARITY_FIELDS := [
	"fire_interval", "attack_range", "aoe_radius", "damage", "projectile_speed",
	"charge_seconds", "charge_damage_multiplier", "max_targets", "max_summons",
	"summon_leash_radius", "summon_damage_multiplier", "knockback",
	"arc_degrees", "strip_width", "pierce_count", "heal_percent_on_attack",
	"status_chance", "status_duration", "burn_damage", "slow_multiplier",
]

var _errors: Array[String] = []
# Оружие вешает снаряды/зоны на `current_scene`. В script-режиме её нет, поэтому
# поднимаем настоящую арену-Node2D: иначе VFX уезжают в Window и падают типом.
var _arena: Node2D = null


class AimProbeOwner:
	extends CharacterBody2D

	# Тот же адаптер, что и в player.gd: три метода поверх провайдера.
	var aim := AimController.new()
	var facing := Vector2.RIGHT
	var mouse_point := Vector2.ZERO
	var direction_calls := 0
	var position_calls := 0
	var last_direction := Vector2.ZERO
	var animation_calls := 0
	var cast_calls := 0

	var weapon_id := ""
	var character_id := ""
	var derived_parameters := {
		"magic_damage": 12.0,
		"damage": 10.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.5,
	}
	var run_modifiers := {
		"extra_projectile": 0,
		"knockback_multiplier": 1.0,
		"healing_multiplier": 1.0,
	}

	func reset_probe() -> void:
		direction_calls = 0
		position_calls = 0
		animation_calls = 0
		cast_calls = 0
		last_direction = Vector2.ZERO

	func attack_aim_mode() -> String:
		return aim.mode()

	func attack_aim_direction(default_direction := Vector2.RIGHT, range_limit := 999999.0) -> Vector2:
		direction_calls += 1
		return aim.aim_direction(global_position, default_direction, range_limit, facing, mouse_point)

	func attack_aim_position(range_limit := 999999.0) -> Vector2:
		position_calls += 1
		return aim.aim_point(global_position, range_limit, facing, mouse_point)

	func play_action_animation(_action_id: String, direction := Vector2.ZERO, _phase := "", _duration := 0.0, _metadata := {}) -> void:
		animation_calls += 1
		if direction.length_squared() > 0.0:
			last_direction = direction.normalized()

	func record_weapon_cast(_weapon_id: String, _attack_mode: String, _action: String, _windup: float) -> void:
		cast_calls += 1

	# Сигнатура зеркалит player.on_weapon_hit — иначе оружие ближнего боя
	# роняет SCRIPT ERROR прямо в прогоне матрицы.
	func on_weapon_hit(_enemy: Node2D, _dealt_damage := 0.0, _was_crit := false, _hit_context := {}) -> void:
		pass

	func heal_percent(_amount: float) -> void:
		pass

	func heal_percent_capped(_amount: float) -> void:
		pass


func _initialize() -> void:
	await _run()
	if not _errors.is_empty():
		for error in _errors:
			push_error("aim_controller_weapon_matrix_test: %s" % error)
		quit(1)
		return
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _run() -> void:
	_arena = Node2D.new()
	_arena.name = "Arena"
	root.add_child(_arena)
	current_scene = _arena
	await process_frame

	var entries := _all_weapons()
	_expect(entries.size() == 51, "матрица обязана покрывать все 51 оружие, найдено %d" % entries.size())

	var covered_modes := {}
	for entry in entries:
		var config: Dictionary = entry["config"]
		covered_modes[_attack_kind(config)] = true
		await _check_weapon(entry)

	# Матрица обязана дотянуться до каждого семейства атак, а не до трёх
	# удобных: melee/сектор/круг, снаряды, лучи, отложенное AoE, деплой,
	# ловушки, призывы и орбиты.
	for required_kind in ["sweep", "circle", "strip", "aoe_projectile", "dot_beam",
			"grenade_fuse", "trap", "amp", "summon", "elemental_orbit", "engineer_orbit_drone"]:
		_expect(covered_modes.has(required_kind), "матрица не покрыла семейство атак %s" % required_kind)

	if _errors.is_empty():
		print("aim_controller_weapon_matrix_test passed: %d/%d оружий, %d семейств атак." % [
			entries.size(), entries.size(), covered_modes.size()
		])


func _all_weapons() -> Array:
	var entries := []
	for character_id in ProgressionData.WEAPONS_BY_CLASS:
		var weapons: Dictionary = ProgressionData.WEAPONS_BY_CLASS[character_id]
		for weapon_id in weapons:
			entries.append({
				"character_id": str(character_id),
				"weapon_id": str(weapon_id),
				"config": (weapons[weapon_id] as Dictionary),
			})
	entries.sort_custom(func(a, b): return str(a["weapon_id"]) < str(b["weapon_id"]))
	return entries


func _attack_kind(config: Dictionary) -> String:
	var attack_mode := str(config.get("attack_mode", ""))
	if attack_mode != "":
		return attack_mode
	var attack_shape := str(config.get("attack_shape", ""))
	if attack_shape != "":
		return attack_shape
	# Призывное оружие описывается ростером саммонов, а не режимом атаки.
	return "summon" if config.has("max_summons") else "unknown"


func _check_weapon(entry: Dictionary) -> void:
	var weapon_id: String = entry["weapon_id"]
	var config: Dictionary = entry["config"]

	var auto_run := await _run_attack(entry, AimController.MODE_AUTO, AimController.DEVICE_MOUSE)
	var mouse_run := await _run_attack(entry, AimController.MODE_MANUAL, AimController.DEVICE_MOUSE)
	var stick_run := await _run_attack(entry, AimController.MODE_MANUAL, AimController.DEVICE_GAMEPAD)
	if auto_run.is_empty() or mouse_run.is_empty() or stick_run.is_empty():
		_expect(false, "%s: оружие не удалось поднять для проверки наводки" % weapon_id)
		return

	# 1) Ручной режим обязан спросить провайдер (направление и/или точку).
	_expect(int(mouse_run["direction_calls"]) + int(mouse_run["position_calls"]) > 0,
		"%s: ручная мышь не обратилась к провайдеру наводки" % weapon_id)
	_expect(int(stick_run["direction_calls"]) + int(stick_run["position_calls"]) > 0,
		"%s: ручной стик не обратился к провайдеру наводки" % weapon_id)
	_expect(int(auto_run["direction_calls"]) == 0,
		"%s: авто-наводка не должна спрашивать направление прицела (%d вызовов)" % [weapon_id, int(auto_run["direction_calls"])])

	# 2) Геометрия: авто целится во врага сверху, ручные — по своей наводке.
	var mouse_expected := MOUSE_OFFSET.normalized()
	var stick_expected := STICK_INPUT.normalized()
	if bool(auto_run["has_direction"]):
		_expect(Vector2(auto_run["direction"]).dot(ENEMY_OFFSET.normalized()) > 0.9,
			"%s: авто-наводка обязана целиться в ближайшего врага, получено %s" % [weapon_id, auto_run["direction"]])
		_expect(Vector2(mouse_run["direction"]).dot(mouse_expected) > 0.99,
			"%s: ручная мышь обязана целиться в курсор, получено %s" % [weapon_id, mouse_run["direction"]])
		_expect(Vector2(stick_run["direction"]).dot(stick_expected) > 0.99,
			"%s: ручной стик обязан целиться по стику, получено %s" % [weapon_id, stick_run["direction"]])
	else:
		# Призывное оружие направления не публикует — проверяем точку наводки.
		_expect(int(mouse_run["position_calls"]) > 0 and int(stick_run["position_calls"]) > 0,
			"%s: призывное оружие обязано спрашивать точку наводки в ручном режиме" % weapon_id)
		var range_limit := float(config.get("attack_range", 999999.0))
		var mouse_point: Vector2 = OWNER_POSITION + mouse_expected * minf(range_limit, MOUSE_OFFSET.length())
		_expect(Vector2(mouse_run["aim_point"]).distance_to(mouse_point) < 1.0,
			"%s: точка наводки мыши %s не совпала с ожидаемой %s" % [weapon_id, mouse_run["aim_point"], mouse_point])
		_expect((Vector2(stick_run["aim_point"]) - OWNER_POSITION).normalized().dot(stick_expected) > 0.99,
			"%s: точка наводки стика обязана лежать по стику, получено %s" % [weapon_id, stick_run["aim_point"]])

	# 3) Паритет: наводка не трогает пейсинг, урон, радиусы и капы.
	for run in [mouse_run, stick_run]:
		var label := str(run["label"])
		_expect(is_equal_approx(float(auto_run["cooldown"]), float(run["cooldown"])),
			"%s/%s: cooldown после атаки разошёлся (%.4f против %.4f)" % [
				weapon_id, label, float(auto_run["cooldown"]), float(run["cooldown"])])
		var auto_parity: Dictionary = auto_run["parity"]
		var run_parity: Dictionary = run["parity"]
		_expect(auto_parity.size() == run_parity.size(),
			"%s/%s: набор паритетных полей разошёлся" % [weapon_id, label])
		for field in auto_parity:
			_expect(is_equal_approx(float(auto_parity[field]), float(run_parity.get(field, INF))),
				"%s/%s: поле %s разошлось (%s против %s)" % [
					weapon_id, label, field, auto_parity[field], run_parity.get(field, "нет")])

		# 4) Один тик атаки — ровно один каст в любом режиме. Считаем именно
		# касты: число анимационных фаз target-зависимо (детонация мины или
		# попадание по врагу доливает свои события) и режимом не управляется.
		_expect(int(auto_run["cast_calls"]) == int(run["cast_calls"]),
			"%s/%s: число кастов разошлось (%d против %d)" % [
				weapon_id, label, int(auto_run["cast_calls"]), int(run["cast_calls"])])
		_expect(int(run["cast_calls"]) <= 1,
			"%s/%s: ручная наводка размножила касты (%d)" % [weapon_id, label, int(run["cast_calls"])])
		# Призывное оружие командует стаей и своей анимации атаки не играет.
		_expect(not bool(auto_run["has_direction"]) or int(run["animation_calls"]) > 0,
			"%s/%s: ручная наводка не проиграла ни одной анимации атаки" % [weapon_id, label])


func _run_attack(entry: Dictionary, mode: String, device: String) -> Dictionary:
	var config: Dictionary = entry["config"]
	var owner := AimProbeOwner.new()
	owner.character_id = str(entry["character_id"])
	owner.weapon_id = str(entry["weapon_id"])
	_arena.add_child(owner)
	owner.global_position = OWNER_POSITION
	owner.mouse_point = OWNER_POSITION + MOUSE_OFFSET
	owner.aim.set_mode(mode)
	owner.aim.set_device(device)
	if device == AimController.DEVICE_GAMEPAD:
		owner.aim.update_stick(STICK_INPUT)

	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate()
	_arena.add_child(enemy)
	enemy.global_position = OWNER_POSITION + ENEMY_OFFSET
	enemy.add_to_group("enemies")
	enemy.set_physics_process(false)

	var weapon_scene := load(str(config.get("scene_path", ""))) as PackedScene
	if weapon_scene == null:
		_cleanup([owner, enemy])
		return {}
	var weapon := weapon_scene.instantiate()
	owner.add_child(weapon)
	if weapon.has_method("configure_weapon"):
		weapon.configure_weapon(config)
	weapon.set_process(false)
	await process_frame

	owner.reset_probe()
	# Часть оружия расставляет заряды/мины через randf(). Одинаковое зерно на
	# каждый прогон делает эти броски идентичными, поэтому любое расхождение
	# между режимами — следствие наводки, а не RNG.
	seed(1449)
	if weapon.has_method("_attack"):
		weapon.call("_attack")
	elif weapon.has_method("_command_existing_summons"):
		weapon.call("_command_existing_summons")
	else:
		_cleanup([owner, enemy])
		return {}
	# Перезарядку снимаем сразу после тика: дальше её штатно съедает _process,
	# и сравнивать через кадр можно было бы только с точностью до delta.
	var cooldown_after_attack: float = float(weapon.get("_cooldown")) if weapon.get("_cooldown") != null else 0.0
	await process_frame

	var raw_direction: Variant = weapon.get("_last_direction")
	var has_direction: bool = raw_direction is Vector2 and (raw_direction as Vector2).length_squared() > 0.001
	var result := {
		"label": "%s/%s" % [mode, device],
		"direction": (raw_direction as Vector2) if has_direction else Vector2.ZERO,
		"has_direction": has_direction,
		"aim_point": owner.aim.aim_point(OWNER_POSITION, float(config.get("attack_range", 999999.0)), owner.facing, owner.mouse_point),
		"direction_calls": owner.direction_calls,
		"position_calls": owner.position_calls,
		"animation_calls": owner.animation_calls,
		"cast_calls": owner.cast_calls,
		"cooldown": cooldown_after_attack,
		"parity": _parity_snapshot(weapon),
	}
	_cleanup([owner, enemy])
	return result


func _parity_snapshot(weapon: Node) -> Dictionary:
	var snapshot := {}
	for field in PARITY_FIELDS:
		var value: Variant = weapon.get(field)
		if value == null:
			continue
		var value_type := typeof(value)
		if value_type == TYPE_INT or value_type == TYPE_FLOAT or value_type == TYPE_BOOL:
			snapshot[field] = float(value)
	return snapshot


func _cleanup(nodes: Array) -> void:
	for node in nodes:
		var target := node as Node
		if target == null or not is_instance_valid(target):
			continue
		if target.get_parent() != null:
			target.get_parent().remove_child(target)
		target.queue_free()
	# Снаряды/зоны/призывы живут отдельными узлами арены — уносим их вместе с
	# прогоном, иначе следующая итерация увидит чужие цели и эффекты.
	if _arena != null and is_instance_valid(_arena):
		for child in _arena.get_children():
			child.queue_free()
