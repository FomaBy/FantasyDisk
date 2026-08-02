extends "res://scripts/encounters/encounter_feature.gd"
## Commander/Hunter captain-tier roles for normal waves (FAN-1451).
## The pack never changes elite groups, reward fields, or shared composition.

const CATALOG := preload("res://scripts/encounters/features/captains/captain_catalog.gd")
const SemanticTypography := preload("res://scripts/ui/semantic_typography.gd")
const CAPTAIN_GROUP := "captain_enemies"
const OWNER_META := "captain_aura_owner"
const ROUND_TAIL_MARGIN := 2.0

var _role_id := ""
var _role := ""
var _settings: Dictionary = {}
var _active_time := 0.0
var _resolved := false
var _status := ""
var _reason := ""

var _captain: Node2D = null
var _retinue: Array = []
var _captain_was_physics_processing := false
var _phase := ""
var _phase_time := 0.0
var _locked_target := Vector2.ZERO
var _hunter_target: Node2D = null
var _hunter_hit := false
var _hunter_disengaged := false

var _marker: Node2D = null
var _target_marker: Node2D = null
var _hud_label: Label = null


func id() -> String:
	return _role_id if _role_id != "" else "captain"


func is_eligible(context) -> bool:
	return CATALOG.is_enabled() and context.is_normal_battle()


func plan(context, beat_def: Dictionary) -> Dictionary:
	_load_settings(beat_def)
	if _settings.is_empty() or not context.is_normal_battle():
		return {}
	var window_def: Dictionary = _settings.get("trigger_window", {})
	var min_seconds := float(window_def.get("min_seconds", 12.0))
	var max_seconds := float(window_def.get("max_seconds", 24.0))
	var latest := float(context.round_duration) - ROUND_TAIL_MARGIN
	if latest < min_seconds:
		return {}
	var rng: RandomNumberGenerator = context.aspect_rng(int(_settings.get("seed_salt", 0)))
	return {
		"trigger_at": minf(rng.randf_range(min_seconds, max_seconds), latest),
		"window": maxf(latest - min_seconds, 0.0),
	}


func on_trigger(context, beat_def: Dictionary) -> bool:
	_load_settings(beat_def)
	if _settings.is_empty() or not context.is_normal_battle() or _captain_exists(context):
		return false
	var candidates: Array = context.alive_normal_enemies()
	if candidates.is_empty():
		return false
	candidates.sort_custom(func(a, b):
		var da: float = context.player_position().distance_squared_to(a.global_position)
		var db: float = context.player_position().distance_squared_to(b.global_position)
		return da < db if da != db else a.get_instance_id() < b.get_instance_id()
	)
	_captain = candidates[0] as Node2D
	if _captain == null:
		return false
	_mark_captain()
	_build_presentation(context)
	if _role == "commander":
		_bind_commander_retinue(candidates)
	elif _role == "hunter":
		_begin_hunter(context)
		if _resolved:
			_cleanup_runtime()
			return false
	else:
		_cleanup_runtime()
		return false
	return true


func on_tick(context, delta: float) -> void:
	if _resolved:
		return
	_active_time += delta
	if not _is_live(_captain):
		_finish(STATUS_FAILED, "captain_lost")
		return
	if _is_live(_marker):
		_marker.global_position = _captain.global_position
	if _role == "hunter":
		_tick_hunter(delta)
	_update_hud()


func is_resolved() -> bool:
	return _resolved


func resolve(_context, reason: String) -> Dictionary:
	if not _resolved:
		_status = STATUS_ABORTED if reason == "no_target" else STATUS_FAILED
		_reason = reason
		_resolved = true
	_cleanup_runtime()
	return make_outcome(id(), _status, {
		"duration": _active_time,
		"reason": _reason,
		"captain_role": _role,
		"reward_contract": str(_settings.get("reward_contract", "normal_enemy_unchanged")),
		"hunter_hit": _hunter_hit,
		"hunter_disengaged": _hunter_disengaged,
	})


func _load_settings(beat_def: Dictionary) -> void:
	if not beat_def.is_empty():
		_role_id = str(beat_def.get("id", beat_def.get("role_id", _role_id)))
		_settings = beat_def.duplicate(true)
	if _settings.is_empty() and _role_id != "":
		_settings = CATALOG.role(_role_id)
	_role = str(_settings.get("role", ""))


func _captain_exists(context) -> bool:
	if context.game == null or context.game.get_tree() == null:
		return false
	for node in context.game.get_tree().get_nodes_in_group(CAPTAIN_GROUP):
		if _is_live(node):
			return true
	return false


func _mark_captain() -> void:
	_captain.add_to_group(CAPTAIN_GROUP)
	_captain.set_meta("captain_id", _role_id)
	_captain.set_meta("captain_role", _role)
	_captain.set_meta("captain_lifecycle", "normal_wave_captain")
	_captain.set_meta("captain_reward_contract", str(_settings.get("reward_contract", "normal_enemy_unchanged")))
	if _captain.has_signal("died") and not _captain.died.is_connected(_on_captain_died):
		_captain.died.connect(_on_captain_died)


func _bind_commander_retinue(candidates: Array) -> void:
	var payload: Dictionary = _settings.get("payload", {})
	var radius := float(payload.get("retinue_radius", 300.0))
	var limit := maxi(int(payload.get("retinue_max", 4)), 0)
	var eligible: Array = []
	for candidate in candidates:
		if candidate != _captain and _is_live(candidate) \
				and candidate.global_position.distance_to(_captain.global_position) <= radius:
			eligible.append(candidate)
	eligible.sort_custom(func(a, b):
		var da: float = a.global_position.distance_squared_to(_captain.global_position)
		var db: float = b.global_position.distance_squared_to(_captain.global_position)
		return da < db if da != db else a.get_instance_id() < b.get_instance_id()
	)
	for enemy in eligible.slice(0, limit):
		_apply_retinue_aura(enemy as Node2D, payload)


func _apply_retinue_aura(enemy: Node2D, payload: Dictionary) -> void:
	var deltas := {}
	for property in ["move_speed", "contact_damage", "projectile_damage"]:
		var current = enemy.get(property)
		if current == null:
			continue
		var multiplier := float(payload.get(
			"move_speed_multiplier" if property == "move_speed" else "attack_damage_multiplier", 1.0))
		var delta := float(current) * (multiplier - 1.0)
		enemy.set(property, float(current) + delta)
		deltas[property] = delta
	enemy.set_meta(OWNER_META, _captain.get_instance_id())
	enemy.set_meta("captain_aura_deltas", deltas)
	if enemy.has_signal("died") and not enemy.died.is_connected(_on_retinue_died):
		enemy.died.connect(_on_retinue_died)
	_retinue.append(enemy)


func _remove_retinue_aura(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or int(enemy.get_meta(OWNER_META, 0)) != _captain_instance_id():
		return
	var deltas: Dictionary = enemy.get_meta("captain_aura_deltas", {})
	for property in deltas:
		var current = enemy.get(property)
		if current != null:
			enemy.set(property, float(current) - float(deltas[property]))
	enemy.remove_meta(OWNER_META)
	enemy.remove_meta("captain_aura_deltas")
	if enemy.has_signal("died") and enemy.died.is_connected(_on_retinue_died):
		enemy.died.disconnect(_on_retinue_died)


func _remove_commander_aura() -> void:
	for enemy in _retinue:
		if is_instance_valid(enemy):
			_remove_retinue_aura(enemy)
	_retinue.clear()


func _begin_hunter(context) -> void:
	_hunter_target = context.player() as Node2D
	_captain_was_physics_processing = _captain.is_physics_processing()
	if _hunter_target == null:
		_finish(STATUS_ABORTED, "no_player")
		return
	_captain.set_physics_process(false)
	_phase = "lock"
	_phase_time = 0.0
	_locked_target = _hunter_target.global_position


func _tick_hunter(delta: float) -> void:
	if not _is_live(_hunter_target):
		_finish(STATUS_FAILED, "target_lost")
		return
	var payload: Dictionary = _settings.get("payload", {})
	_phase_time += delta
	match _phase:
		"lock":
			_locked_target = _hunter_target.global_position
			_move_target_marker(_locked_target)
			if _phase_time >= float(payload.get("lock_seconds", 0.65)):
				_change_phase("windup")
		"windup":
			if _phase_time >= float(payload.get("windup_seconds", 0.8)):
				_change_phase("pursuit")
		"pursuit":
			var distance_to_player := _captain.global_position.distance_to(_hunter_target.global_position)
			if distance_to_player > float(payload.get("disengage_distance", 720.0)):
				_hunter_disengaged = true
				_change_phase("recovery")
				return
			var to_locked := _locked_target - _captain.global_position
			var speed := float(payload.get("pursuit_speed", 420.0)) * _target_resist_factor(payload)
			_captain.global_position += to_locked.normalized() * minf(to_locked.length(), speed * delta)
			if not _hunter_hit and _captain.global_position.distance_to(_hunter_target.global_position) \
					<= float(payload.get("hit_radius", 42.0)):
				if _hunter_target.has_method("take_damage"):
					_hunter_target.call("take_damage", float(payload.get("hit_damage", 1.0)), "captain_hunter")
				_hunter_hit = true
				_change_phase("recovery")
			elif to_locked.length() <= 0.01 or _phase_time >= float(payload.get("pursuit_seconds", 1.25)):
				_change_phase("recovery")
		"recovery":
			if _phase_time >= float(payload.get("recovery_seconds", 0.9)):
				_change_phase("lock")


func _target_resist_factor(payload: Dictionary) -> float:
	var meta_name := str(payload.get("target_resist_meta", "captain_pursuit_resist"))
	var resist := clampf(float(_hunter_target.get_meta(meta_name, 0.0)), 0.0,
		float(payload.get("max_target_resist", 0.75)))
	return 1.0 - resist


func _change_phase(next_phase: String) -> void:
	_phase = next_phase
	_phase_time = 0.0


func _on_captain_died(_enemy: Node2D) -> void:
	_remove_commander_aura()
	_finish(STATUS_COMPLETED, "captain_killed")


func _on_retinue_died(enemy: Node2D) -> void:
	_remove_retinue_aura(enemy)
	_retinue.erase(enemy)


func _finish(status: String, reason: String) -> void:
	if _resolved:
		return
	_status = status
	_reason = reason
	_resolved = true


func _build_presentation(context) -> void:
	var payload: Dictionary = _settings.get("payload", {})
	var color_values: Array = payload.get("marker_color", [1.0, 0.78, 0.24])
	var color := Color(float(color_values[0]), float(color_values[1]), float(color_values[2]), 0.95)
	if context.presentation_parent != null:
		_marker = _ring("CaptainRoleMarker", float(payload.get("marker_radius", 52.0)), color)
		context.presentation_parent.add_child(_marker)
		_marker.global_position = _captain.global_position
		if _role == "hunter":
			_target_marker = _ring("CaptainHunterTargetMarker", 36.0, color)
			context.presentation_parent.add_child(_target_marker)
	var hud: Control = context.hud_root()
	if hud != null:
		_hud_label = Label.new()
		_hud_label.name = "CaptainHudLabel"
		_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hud_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_hud_label.position = Vector2(-220.0, 122.0)
		_hud_label.custom_minimum_size = Vector2(440.0, 30.0)
		_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_label.process_mode = Node.PROCESS_MODE_PAUSABLE
		_hud_label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(SemanticTypography.ROLE_HUD, 20))
		_hud_label.add_theme_color_override("font_color", color)
		_hud_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 1.0))
		_hud_label.add_theme_constant_override("outline_size", 4)
		hud.add_child(_hud_label)
		_update_hud()


func _ring(node_name: String, radius: float, color: Color) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.z_index = 60
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = color
	line.closed = true
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		line.add_point(Vector2(cos(angle), sin(angle)) * radius)
	root.add_child(line)
	return root


func _move_target_marker(position: Vector2) -> void:
	if _is_live(_target_marker):
		_target_marker.global_position = position


func _update_hud() -> void:
	if not _is_live(_hud_label):
		return
	if _role == "commander":
		_hud_label.text = "КАПИТАН-КОМАНДИР — уничтожьте его, чтобы снять ауру"
	else:
		var labels := {"lock": "НАВОДКА", "windup": "ПРИГОТОВЬТЕСЬ", "pursuit": "ПОГОНЯ", "recovery": "ПЕРЕДЫШКА"}
		_hud_label.text = "КАПИТАН-ОХОТНИК — %s" % str(labels.get(_phase, ""))


func _cleanup_runtime() -> void:
	_remove_commander_aura()
	if is_instance_valid(_captain):
		if _role == "hunter":
			_captain.set_physics_process(_captain_was_physics_processing)
		if _captain.has_signal("died") and _captain.died.is_connected(_on_captain_died):
			_captain.died.disconnect(_on_captain_died)
		_captain.remove_from_group(CAPTAIN_GROUP)
		for meta_name in ["captain_id", "captain_role", "captain_lifecycle", "captain_reward_contract"]:
			if _captain.has_meta(meta_name):
				_captain.remove_meta(meta_name)
	_free_presentation(_marker)
	_free_presentation(_target_marker)
	_free_presentation(_hud_label)
	_marker = null
	_target_marker = null
	_hud_label = null


func _free_presentation(node: Node) -> void:
	if is_instance_valid(node) and not node.is_queued_for_deletion():
		node.queue_free()


func _captain_instance_id() -> int:
	return _captain.get_instance_id() if is_instance_valid(_captain) else 0


func _is_live(node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()


# Focused test/QA accessors.
func debug_captain() -> Node2D: return _captain
func debug_retinue() -> Array: return _retinue.duplicate()
func debug_phase() -> String: return _phase
func debug_locked_target() -> Vector2: return _locked_target
func debug_active_time() -> float: return _active_time
func debug_disengaged() -> bool: return _hunter_disengaged
func debug_marker() -> Node2D: return _marker
func debug_hud_label() -> Label: return _hud_label
