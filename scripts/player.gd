extends CharacterBody2D

signal died
signal leveled_up
signal damaged(amount: float)

@export var max_health := 10.0
@export var speed := 260.0
@export var damage_invulnerability_time := 0.32

const BERSERK_SPRITE := preload("res://assets/sprites/characters/berserk_unarmed.png")
const BERSERK_ANIMATED_SPRITE := preload("res://assets/sprites/characters/berserk_walk_sheet_v2.png")
const DARK_MAGE_SPRITE := preload("res://assets/sprites/characters/dark_mage.png")
const GUITARIST_SPRITE := preload("res://assets/sprites/characters/guitarist.png")
const ASSASSIN_SPRITE := preload("res://assets/sprites/characters/assassin_placeholder.png")
const RANGER_SPRITE := preload("res://assets/sprites/characters/ranger_placeholder.png")
const DOCTOR_SPRITE := preload("res://assets/sprites/characters/doctor_placeholder.png")
const CHEMIST_SPRITE := preload("res://assets/sprites/characters/chemist_placeholder.png")
const KNIGHT_SPRITE := preload("res://assets/sprites/characters/knight_placeholder.png")
const DRUID_SPRITE := preload("res://assets/sprites/characters/druid_placeholder.png")
const PROGRESSION_DATA := preload("res://scripts/progression_data.gd")
const CUTOUT_RIG_SCRIPT := preload("res://scripts/cutout_rig_2d.gd")
const BERSERK_ANIMATION_FRAME_SIZE := Vector2i(384, 384)
const BASE_SPRITE_SCALE := Vector2(0.28, 0.28)

const CHARACTER_CONFIGS := {
	"berserk": {
		"display_name": "Берсерк",
		"color": Color(0.33, 0.65, 1.0, 1.0),
		"max_health": 88.0,
		"speed": 235.0,
		"sprite": BERSERK_SPRITE,
	},
	"dark_mage": {
		"display_name": "Темный маг",
		"color": Color(0.55, 0.33, 1.0, 1.0),
		"max_health": 42.0,
		"speed": 250.0,
		"sprite": DARK_MAGE_SPRITE,
	},
	"guitarist": {
		"display_name": "Гитарист",
		"color": Color(1.0, 0.72, 0.20, 1.0),
		"max_health": 60.0,
		"speed": 268.0,
		"sprite": GUITARIST_SPRITE,
	},
	"assassin": {"display_name": "Ассасин", "color": Color(0.66, 0.30, 0.95, 1.0), "max_health": 52.0, "speed": 285.0, "sprite": ASSASSIN_SPRITE},
	"ranger": {"display_name": "Рейнджер", "color": Color(0.40, 0.78, 0.42, 1.0), "max_health": 58.0, "speed": 262.0, "sprite": RANGER_SPRITE},
	"doctor": {"display_name": "Доктор", "color": Color(0.92, 0.94, 0.98, 1.0), "max_health": 64.0, "speed": 248.0, "sprite": DOCTOR_SPRITE},
	"chemist": {"display_name": "Химик", "color": Color(0.70, 0.95, 0.25, 1.0), "max_health": 50.0, "speed": 252.0, "sprite": CHEMIST_SPRITE},
	"knight": {"display_name": "Рыцарь", "color": Color(0.62, 0.70, 0.85, 1.0), "max_health": 95.0, "speed": 225.0, "sprite": KNIGHT_SPRITE},
	"druid": {"display_name": "Друид", "color": Color(0.52, 0.72, 0.34, 1.0), "max_health": 66.0, "speed": 255.0, "sprite": DRUID_SPRITE},
}

var health := 0.0
var character_id := "berserk"
var weapon_id := ""
var weapon_config := {}
var equipped_weapon: Node = null
var stats := {}
var run_modifiers := {
	"damage_multiplier": 1.0,
	"attack_speed_multiplier": 1.0,
	"range_multiplier": 1.0,
	"aoe_radius_multiplier": 1.0,
	"move_speed_multiplier": 1.0,
	"max_health_multiplier": 1.0,
	"summon_bonus": 0.0,
	"damage_flat": 0.0,
	"max_health_flat": 0.0,
	"pickup_radius_flat": 0.0,
	"defense_flat": 0.0,
	"crit_chance_flat": 0.0,
	"crit_damage_flat": 0.0,
	"dodge_flat": 0.0,
	"xp_gain_multiplier": 1.0,
	"money_gain_multiplier": 1.0,
	"healing_multiplier": 1.0,
	"enemy_health_multiplier": 1.0,
	"knockback_multiplier": 1.0,
}
var artifacts := []
var derived_parameters := {}
var xp := 0
var xp_to_next := 5
var level := 1
var money := 0
var pickup_radius := 115.0
var _animation_time := 0.0
var _movement_offset := Vector2.ZERO
var _movement_rotation := 0.0
var _movement_scale_delta := Vector2.ZERO
var _action_offset := Vector2.ZERO
var _action_rotation := 0.0
var _action_scale := Vector2.ONE
var _action_tween: Tween = null
var _hit_flash_tween: Tween = null
var _facing_direction := Vector2.RIGHT
var _damage_invulnerability_left := 0.0
var _echo_hit_counter := 0
var _dodge_rush_tween: Tween = null
var _low_hp_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_default_input_actions()
	if stats.is_empty():
		configure_character(character_id)


func configure_character(new_character_id: String, new_weapon_id := "") -> void:
	character_id = new_character_id
	weapon_id = ""
	weapon_config = {}
	var config: Dictionary = CHARACTER_CONFIGS.get(character_id, CHARACTER_CONFIGS["berserk"])

	stats = PROGRESSION_DATA.base_stats(character_id)
	artifacts.clear()
	run_modifiers = {
		"damage_multiplier": 1.0,
		"attack_speed_multiplier": 1.0,
		"range_multiplier": 1.0,
		"aoe_radius_multiplier": 1.0,
		"move_speed_multiplier": 1.0,
		"max_health_multiplier": 1.0,
		"summon_bonus": 0.0,
		"damage_flat": 0.0,
		"max_health_flat": 0.0,
		"pickup_radius_flat": 0.0,
		"defense_flat": 0.0,
		"crit_chance_flat": 0.0,
		"crit_damage_flat": 0.0,
		"dodge_flat": 0.0,
		"xp_gain_multiplier": 1.0,
		"money_gain_multiplier": 1.0,
		"healing_multiplier": 1.0,
		"enemy_health_multiplier": 1.0,
		"knockback_multiplier": 1.0,
	}
	xp = 0
	xp_to_next = 5
	level = 1
	money = 0
	_apply_stat_scaling(true)

	var visual_root := _visual_root()
	if visual_root != null:
		visual_root.position = Vector2.ZERO
		visual_root.rotation = 0.0
		visual_root.scale = Vector2.ONE
	var body := _animated_sprite()
	if body != null:
		body.sprite_frames = _character_sprite_frames(config)
		body.animation = "idle"
		body.play("idle")
		body.position = Vector2.ZERO
		body.rotation = 0.0
		body.scale = BASE_SPRITE_SCALE
		body.flip_h = false
		body.visible = false
	_configure_player_rig(config)
	var weapon_socket := _weapon_socket()
	if weapon_socket != null:
		weapon_socket.position = Vector2.ZERO
		weapon_socket.rotation = 0.0
		weapon_socket.scale = Vector2.ONE

	_movement_offset = Vector2.ZERO
	_movement_rotation = 0.0
	_movement_scale_delta = Vector2.ZERO
	_action_offset = Vector2.ZERO
	_action_rotation = 0.0
	_action_scale = Vector2.ONE
	_facing_direction = Vector2.RIGHT

	_clear_equipped_weapon()
	if new_weapon_id != "":
		equip_weapon(new_weapon_id)


func configure_berserk_subclass(subclass_id: String) -> void:
	equip_weapon(subclass_id)


func equip_weapon(new_weapon_id: String) -> void:
	var config := PROGRESSION_DATA.weapon(character_id, new_weapon_id)
	var weapon_scene := load(str(config.get("scene_path", ""))) as PackedScene
	if weapon_scene == null:
		return

	weapon_id = str(config["id"])
	weapon_config = config
	var old_max_health := max_health
	_apply_stat_scaling(false, old_max_health)
	_attach_weapon_scene(weapon_scene, weapon_config)


func _attach_weapon_scene(weapon_scene: PackedScene, config: Dictionary) -> void:
	_clear_equipped_weapon()
	var socket := _weapon_socket()
	var weapon := weapon_scene.instantiate()
	weapon.add_to_group("player_weapons")
	socket.add_child(weapon)
	equipped_weapon = weapon
	if weapon.has_method("configure_weapon") and not config.is_empty():
		weapon.configure_weapon(config)
	_apply_weapon_scaling(weapon)


func _clear_equipped_weapon() -> void:
	equipped_weapon = null
	for weapon in _equipped_weapons():
		var weapon_node := weapon as Node
		if weapon_node == null:
			continue
		if weapon_node.has_method("cleanup_effects"):
			weapon_node.cleanup_effects()
		if weapon_node.get_parent() != null:
			weapon_node.get_parent().remove_child(weapon_node)
		weapon_node.queue_free()
	_clear_detached_weapon_effects()


func _clear_detached_weapon_effects() -> void:
	if not is_inside_tree():
		return
	for effect in get_tree().get_nodes_in_group("player_weapon_effects"):
		if effect != null and is_instance_valid(effect):
			effect.remove_from_group("player_weapon_effects")
			effect.queue_free()


func _weapon_socket() -> Node2D:
	var socket := get_node_or_null("VisualRoot/WeaponSocket") as Node2D
	if socket != null:
		return socket
	socket = get_node_or_null("WeaponSocket") as Node2D
	if socket != null:
		return socket
	var visual_root := _visual_root()
	if visual_root == null:
		visual_root = Node2D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	socket = Node2D.new()
	socket.name = "WeaponSocket"
	visual_root.add_child(socket)
	return socket


func _physics_process(_delta: float) -> void:
	_damage_invulnerability_left = max(_damage_invulnerability_left - _delta, 0.0)
	var direction := Vector2.ZERO

	if Input.is_action_pressed("move_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("move_right"):
		direction.x += 1.0
	if Input.is_action_pressed("move_up"):
		direction.y -= 1.0
	if Input.is_action_pressed("move_down"):
		direction.y += 1.0

	velocity = direction.normalized() * speed
	move_and_slide()
	_update_movement_animation(_delta)
	_update_low_hp_state()
	_apply_regeneration(_delta)


func play_action_animation(action_id: String, direction := Vector2.ZERO) -> void:
	if direction.length_squared() > 0.0:
		_facing_direction = direction.normalized()
		_update_sprite_facing(_facing_direction)
	var rig := _cutout_rig()
	if rig != null and rig.has_method("play_action"):
		var animation_variant: String = weapon_id if action_id == "attack" else character_id
		rig.play_action(action_id, _facing_direction, animation_variant)

	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()

	var impact_offset := Vector2.ZERO
	var impact_rotation := 0.0
	var impact_scale := Vector2.ONE
	var windup_time := 0.06
	var recover_time := 0.13
	var direction_sign := 1.0 if _facing_direction.x >= 0.0 else -1.0

	match action_id:
		"attack":
			impact_offset = _facing_direction * 13.0
			impact_rotation = direction_sign * 0.22
			impact_scale = Vector2(1.08, 0.94)
			windup_time = 0.05
			recover_time = 0.14
		"shoot":
			impact_offset = -_facing_direction * 8.0
			impact_rotation = -direction_sign * 0.11
			impact_scale = Vector2(0.96, 1.04)
			windup_time = 0.04
			recover_time = 0.12
		"cast":
			impact_offset = Vector2(0.0, -10.0)
			impact_rotation = direction_sign * 0.08
			impact_scale = Vector2(1.05, 1.08)
			windup_time = 0.08
			recover_time = 0.18
		_:
			impact_offset = _facing_direction * 6.0

	_action_offset = impact_offset
	_action_rotation = impact_rotation
	_action_scale = impact_scale
	_apply_sprite_transform()

	_action_tween = create_tween()
	_action_tween.set_parallel(true)
	_action_tween.tween_property(self, "_action_offset", Vector2.ZERO, recover_time).set_delay(windup_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "_action_rotation", 0.0, recover_time).set_delay(windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(self, "_action_scale", Vector2.ONE, recover_time).set_delay(windup_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_callback(_apply_sprite_transform)


func take_damage(amount: float, _source := "") -> bool:
	if _damage_invulnerability_left > 0.0:
		return false

	if randf() < clampf(float(derived_parameters.get("dodge", 0.0)), 0.0, 0.8):
		_show_dodge_popup()
		_play_sfx("dodge")
		_trigger_dodge_rush()
		return false

	var defense := clampf(float(derived_parameters.get("defense", 0.0)), 0.0, 0.95)
	# Поглощение: плоско срезает часть удара до защиты, но не ниже 20% урона.
	var absorb := float(derived_parameters.get("absorb", 0.0))
	var absorbed_amount: float = maxf(amount - absorb, amount * 0.2)
	var final_damage := absorbed_amount * (1.0 - defense)
	health = max(health - final_damage, 0.0)
	_damage_invulnerability_left = damage_invulnerability_time
	_play_hit_feedback()
	_play_sfx("player_hit")
	damaged.emit(amount)
	_trigger_thorn_reflect(final_damage)

	if health <= 0.0:
		var rig := _cutout_rig()
		if rig != null and rig.has_method("spawn_death_ghost"):
			rig.spawn_death_ghost()
		died.emit()
		queue_free()
	return true


func _trigger_thorn_reflect(received_damage: float) -> void:
	var reflect := float(run_modifiers.get("thorn_reflect_multiplier", 0.0))
	if reflect <= 0.0 or received_damage <= 0.0 or not is_inside_tree():
		return
	var reflected := received_damage * reflect
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if global_position.distance_squared_to(enemy_node.global_position) <= 200.0 * 200.0 and enemy_node.has_method("take_damage"):
			enemy_node.take_damage(reflected)


func _trigger_dodge_rush() -> void:
	if float(run_modifiers.get("dodge_rush_bonus", 0.0)) <= 0.0:
		return
	run_modifiers["dodge_rush_active"] = 1.0
	_apply_stat_scaling(false, max_health)
	if _dodge_rush_tween != null and _dodge_rush_tween.is_valid():
		_dodge_rush_tween.kill()
	_dodge_rush_tween = create_tween()
	_dodge_rush_tween.tween_interval(2.0)
	_dodge_rush_tween.tween_callback(func() -> void:
		run_modifiers["dodge_rush_active"] = 0.0
		_apply_stat_scaling(false, max_health)
	)


func _update_low_hp_state() -> void:
	if float(run_modifiers.get("low_hp_damage_bonus", 0.0)) <= 0.0:
		return
	var active := health < max_health * 0.3
	if active == _low_hp_active:
		return
	_low_hp_active = active
	run_modifiers["low_hp_active"] = 1.0 if active else 0.0
	_apply_stat_scaling(false, max_health)


func apply_reward(reward: Dictionary) -> void:
	var old_max_health := max_health

	if reward.has("stats"):
		for stat_id in reward["stats"].keys():
			stats[stat_id] = float(stats.get(stat_id, 0.0)) + float(reward["stats"][stat_id])

	if reward.has("mods"):
		_apply_reward_mods(reward["mods"])
	# Классовая часть артефакта применяется только совпадающему классу (честный расчет).
	if reward.has("affinity_mods"):
		var affinity: Array = reward.get("class_affinity", [])
		if affinity.is_empty() or affinity.has(character_id):
			_apply_reward_mods(reward["affinity_mods"])

	if reward.get("kind", "") == "artifact":
		# Храним id и title: id нужен для иконок HUD/паузы, title — для текстов.
		artifacts.append({"id": str(reward.get("id", "")), "title": str(reward.get("title", ""))})

	_apply_stat_scaling(false, old_max_health)

	if reward.has("heal_percent"):
		heal_percent(float(reward["heal_percent"]))

	for weapon in _equipped_weapons():
		_apply_weapon_scaling(weapon)


func _apply_reward_mods(mods: Dictionary) -> void:
	for modifier_id in mods.keys():
		if modifier_id.ends_with("_multiplier"):
			run_modifiers[modifier_id] = float(run_modifiers.get(modifier_id, 1.0)) * float(mods[modifier_id])
		else:
			run_modifiers[modifier_id] = float(run_modifiers.get(modifier_id, 0.0)) + float(mods[modifier_id])


func _apply_regeneration(delta: float) -> void:
	var regeneration := float(derived_parameters.get("regeneration", 0.0))
	if regeneration <= 0.0 or health >= max_health or health <= 0.0:
		return
	health = minf(health + regeneration * delta, max_health)


func on_weapon_hit(enemy: Node2D, dealt_damage := 0.0) -> void:
	# Вампиризм: с шансом vampiric_chance лечит vampiric_amount + половину урона.
	var vampiric_chance := float(derived_parameters.get("vampiric_chance", 0.0))
	if vampiric_chance > 0.0 and dealt_damage > 0.0 and randf() < vampiric_chance:
		var vampiric_heal := float(derived_parameters.get("vampiric_amount", 0.0)) + dealt_damage * 0.5
		health = minf(health + vampiric_heal, max_health)
	_on_weapon_hit_echo(enemy)


func _on_weapon_hit_echo(enemy: Node2D) -> void:
	# «Эхо Разлома» (tier 3): каждый N-й удар — взрыв по области вокруг цели.
	var every := int(run_modifiers.get("echo_blast_every", 0.0))
	if every <= 0 or enemy == null or not is_instance_valid(enemy):
		return
	_echo_hit_counter += 1
	if _echo_hit_counter < every:
		return
	_echo_hit_counter = 0
	var blast_position := enemy.global_position
	var blast_damage := float(derived_parameters.get("damage", 10.0)) * 0.8
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	AttackVfx.orb_burst(scene, blast_position, 140.0, Color(1.0, 0.82, 0.30, 0.5))
	for other in get_tree().get_nodes_in_group("enemies"):
		var other_node := other as Node2D
		if other_node == null or not is_instance_valid(other_node):
			continue
		if other_node.global_position.distance_squared_to(blast_position) <= 140.0 * 140.0 and other_node.has_method("take_damage"):
			other_node.take_damage(blast_damage)


func gain_xp(amount: int) -> void:
	xp += maxi(1, int(round(float(amount) * float(run_modifiers.get("xp_gain_multiplier", 1.0)))))
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(ceil(float(xp_to_next) * 1.35 + 2.0))
		leveled_up.emit()


func gain_money(amount: int) -> void:
	money += maxi(1, int(round(float(amount) * float(run_modifiers.get("money_gain_multiplier", 1.0)))))


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	return true


func heal_percent(percent: float) -> void:
	health = min(max_health, health + max_health * percent * float(run_modifiers.get("healing_multiplier", 1.0)))


func _apply_stat_scaling(full_heal := false, old_max_health := 0.0) -> void:
	derived_parameters = PROGRESSION_DATA.derived_parameters(stats, run_modifiers, weapon_config)
	speed = float(derived_parameters.get("move_speed", 235.0))
	max_health = float(derived_parameters.get("health_point", 88.0))
	pickup_radius = float(derived_parameters.get("pickup_radius", 115.0))

	if full_heal or health <= 0.0:
		health = max_health
	else:
		health = min(max_health, health + max(max_health - old_max_health, 0.0))


func _apply_weapon_scaling(weapon: Node) -> void:
	_capture_weapon_base_values(weapon)

	if weapon.get("damage") != null:
		var damage_parameter := "damage"
		if weapon.get("damage_parameter") != null:
			damage_parameter = str(weapon.get("damage_parameter"))
		weapon.set("damage", float(derived_parameters.get(damage_parameter, weapon.get_meta("base_damage"))))

	if weapon.get("fire_interval") != null:
		var attack_speed := float(derived_parameters.get("attack_speed", 1.0))
		var base_fire_interval := float(weapon.get_meta("base_fire_interval", 1.0))
		weapon.set("fire_interval", max(0.18, base_fire_interval / max(attack_speed, 0.1)))

	if weapon.get("attack_range") != null:
		var base_attack_range := float(weapon.get_meta("base_attack_range"))
		var scaled_attack_range := float(derived_parameters.get("attack_range", base_attack_range))
		weapon.set("attack_range", scaled_attack_range)
		var width_scale: float = scaled_attack_range / max(base_attack_range, 1.0)
		if weapon.get("inner_width") != null:
			weapon.set("inner_width", float(weapon.get_meta("base_inner_width")) * min(width_scale, 1.35))
		if weapon.get("outer_width") != null:
			weapon.set("outer_width", float(weapon.get_meta("base_outer_width")) * width_scale)

	if weapon.get("aoe_radius") != null:
		weapon.set("aoe_radius", float(derived_parameters.get("aoe_radius", weapon.get_meta("base_aoe_radius", 200.0))))

	if weapon.get("projectile_speed") != null:
		weapon.set("projectile_speed", float(derived_parameters.get("projectile_speed", weapon.get_meta("base_projectile_speed", 520.0))))

	if weapon.get("knockback") != null:
		weapon.set("knockback", float(derived_parameters.get("knockback_power", weapon.get_meta("base_knockback", 80.0))))

	if weapon.get("beam_width") != null and weapon.has_meta("base_beam_width"):
		weapon.set("beam_width", float(weapon.get_meta("base_beam_width")) * max(float(derived_parameters.get("aoe_radius", 1.0)) / max(float(weapon.get_meta("base_aoe_radius", 1.0)), 1.0), 0.75))

	if weapon.get("wave_width") != null and weapon.has_meta("base_wave_width"):
		weapon.set("wave_width", float(weapon.get_meta("base_wave_width")) * max(float(derived_parameters.get("aoe_radius", 1.0)) / max(float(weapon.get_meta("base_aoe_radius", 1.0)), 1.0), 0.75))

	if weapon.get("max_summons") != null:
		var base_max_summons := int(weapon.get_meta("base_max_summons"))
		weapon.set("max_summons", base_max_summons + int(floor(float(stats.get("leadership", 0.0)) / 4.0)) + int(run_modifiers.get("summon_bonus", 0.0)))


func _equipped_weapons() -> Array:
	var weapons := []
	var socket := _weapon_socket()
	if socket != null:
		for child in socket.get_children():
			if child.is_in_group("player_weapons"):
				weapons.append(child)
	for child in get_children():
		if child.is_in_group("player_weapons"):
			weapons.append(child)
	return weapons


func _capture_weapon_base_values(weapon: Node) -> void:
	if weapon.get("damage") != null and not weapon.has_meta("base_damage"):
		weapon.set_meta("base_damage", weapon.get("damage"))
	if weapon.get("fire_interval") != null and not weapon.has_meta("base_fire_interval"):
		weapon.set_meta("base_fire_interval", weapon.get("fire_interval"))
	if weapon.get("attack_range") != null and not weapon.has_meta("base_attack_range"):
		weapon.set_meta("base_attack_range", weapon.get("attack_range"))
	if weapon.get("aoe_radius") != null and not weapon.has_meta("base_aoe_radius"):
		weapon.set_meta("base_aoe_radius", weapon.get("aoe_radius"))
	if weapon.get("inner_width") != null and not weapon.has_meta("base_inner_width"):
		weapon.set_meta("base_inner_width", weapon.get("inner_width"))
	if weapon.get("outer_width") != null and not weapon.has_meta("base_outer_width"):
		weapon.set_meta("base_outer_width", weapon.get("outer_width"))
	if weapon.get("max_summons") != null and not weapon.has_meta("base_max_summons"):
		weapon.set_meta("base_max_summons", weapon.get("max_summons"))
	if weapon.get("projectile_speed") != null and not weapon.has_meta("base_projectile_speed"):
		weapon.set_meta("base_projectile_speed", weapon.get("projectile_speed"))
	if weapon.get("beam_width") != null and not weapon.has_meta("base_beam_width"):
		weapon.set_meta("base_beam_width", weapon.get("beam_width"))
	if weapon.get("wave_width") != null and not weapon.has_meta("base_wave_width"):
		weapon.set_meta("base_wave_width", weapon.get("wave_width"))
	if weapon.get("knockback") != null and not weapon.has_meta("base_knockback"):
		weapon.set_meta("base_knockback", weapon.get("knockback"))


func _ensure_default_input_actions() -> void:
	_ensure_key_action("move_up", [KEY_W, KEY_UP])
	_ensure_key_action("move_down", [KEY_S, KEY_DOWN])
	_ensure_key_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_key_action("move_right", [KEY_D, KEY_RIGHT])


func _ensure_key_action(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if not InputMap.action_get_events(action_name).is_empty():
		return

	for keycode in keycodes:
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action_name, event)


func _update_movement_animation(delta: float) -> void:
	var body := _animated_sprite()
	if body == null:
		return

	if velocity.length_squared() > 0.0:
		_animation_time += delta * 10.0
		_facing_direction = velocity.normalized()
		_movement_offset = Vector2(0.0, sin(_animation_time) * 3.0)
		_movement_rotation = clamp(velocity.x / max(speed, 1.0), -1.0, 1.0) * 0.12
		_movement_scale_delta = Vector2(sin(_animation_time) * 0.025, -sin(_animation_time) * 0.018)
		if body.animation != "walk":
			body.play("walk")
		_update_sprite_facing(_facing_direction)
	else:
		_movement_offset = _movement_offset.lerp(Vector2.ZERO, 10.0 * delta)
		_movement_rotation = lerpf(_movement_rotation, 0.0, 10.0 * delta)
		_movement_scale_delta = _movement_scale_delta.lerp(Vector2.ZERO, 10.0 * delta)
		if body.animation != "idle":
			body.play("idle")

	var rig := _cutout_rig()
	if rig != null and rig.has_method("update_animation"):
		rig.update_animation(delta, velocity, _facing_direction)
	_apply_sprite_transform()


func _update_sprite_facing(direction: Vector2) -> void:
	var body := _animated_sprite()
	if body == null:
		return
	if abs(direction.x) > 0.05:
		body.flip_h = direction.x < 0.0


func _apply_sprite_transform() -> void:
	var visual_root := _visual_root()
	if visual_root == null:
		return

	visual_root.position = Vector2.ZERO
	visual_root.rotation = 0.0
	visual_root.scale = Vector2.ONE

	var weapon_socket := _weapon_socket()
	if weapon_socket != null:
		var rig := _cutout_rig()
		if rig != null and rig.has_method("weapon_socket_position"):
			weapon_socket.position = rig.weapon_socket_position()
			weapon_socket.rotation = rig.weapon_socket_rotation()
		else:
			weapon_socket.position = Vector2.ZERO
			weapon_socket.rotation = 0.0
		weapon_socket.scale = Vector2.ONE


func _play_hit_feedback() -> void:
	var body := _animated_sprite()
	if body == null:
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	body.modulate = Color(1.0, 0.35, 0.35, 1.0)
	var rig := _cutout_rig()
	if rig != null and rig.has_method("play_hit"):
		rig.play_hit()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(body, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _show_dodge_popup() -> void:
	if not is_inside_tree():
		return
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	var popup := Label.new()
	popup.text = "Промах!"
	popup.z_index = 40
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0, 1.0))
	popup.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.16, 1.0))
	popup.add_theme_constant_override("outline_size", 5)
	parent.add_child(popup)
	popup.global_position = global_position + Vector2(-32.0, -64.0)
	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "global_position", popup.global_position + Vector2(0.0, -34.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(popup.queue_free)


var _cached_audio: Node = null


func _play_sfx(sfx_id: String) -> void:
	if not is_inside_tree():
		return
	if _cached_audio == null or not is_instance_valid(_cached_audio):
		_cached_audio = get_node_or_null("/root/AudioManager")
	if _cached_audio != null and _cached_audio.has_method("play_sfx"):
		_cached_audio.play_sfx(sfx_id)


func _visual_root() -> Node2D:
	return get_node_or_null("VisualRoot") as Node2D


func _animated_sprite() -> AnimatedSprite2D:
	return get_node_or_null("VisualRoot/Body") as AnimatedSprite2D


func _cutout_rig() -> Node2D:
	return get_node_or_null("VisualRoot/RigRoot") as Node2D


func _configure_player_rig(config: Dictionary) -> void:
	var visual_root := _visual_root()
	if visual_root == null:
		return
	var rig := _cutout_rig()
	if rig == null:
		rig = Node2D.new()
		rig.name = "RigRoot"
		rig.set_script(CUTOUT_RIG_SCRIPT)
		visual_root.add_child(rig)
	var texture := config.get("sprite", BERSERK_SPRITE) as Texture2D
	if rig.has_method("configure"):
		rig.configure(texture, BASE_SPRITE_SCALE, character_id, {"is_player": true})


func _character_sprite_frames(config: Dictionary) -> SpriteFrames:
	if character_id == "berserk":
		return _berserk_sprite_frames()
	return _single_texture_sprite_frames(config["sprite"])


func _berserk_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 3.0)
	for frame_index in range(2):
		frames.add_frame("idle", _atlas_frame(BERSERK_ANIMATED_SPRITE, frame_index, 0, BERSERK_ANIMATION_FRAME_SIZE))

	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 10.0)
	for frame_index in range(6):
		frames.add_frame("walk", _atlas_frame(BERSERK_ANIMATED_SPRITE, frame_index, 1, BERSERK_ANIMATION_FRAME_SIZE))
	return frames


func _single_texture_sprite_frames(texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation_name in ["idle", "walk"]:
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, true)
		frames.set_animation_speed(animation_name, 1.0)
		frames.add_frame(animation_name, texture)
	return frames


func _atlas_frame(texture: Texture2D, column: int, row: int, frame_size: Vector2i) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(Vector2(column * frame_size.x, row * frame_size.y), frame_size)
	return frame
