extends "res://scripts/encounters/encounter_feature.gd"
## marked_target — первый vertical slice бита (FAN-1447).
##
## На 20–40 секунде обычного боя помечает одного живого рядового врага: мир-маркер
## (пульсирующее кольцо, следует за целью) + экранный HUD-отсчёт окна. Успех —
## цель убита в окне; провал — окно вышло/цель потеряна. Idempotent outcome:
## терминал считается один раз, все узлы/твины/колбэки снимаются в resolve().
##
## Детерминизм: и момент триггера, и выбор цели берутся из независимого
## node-seeded RNG (context.aspect_rng), глобальный game.rng не расходуется.

# Соль выбора цели: микшируется с seed_salt бита, чтобы момент и цель не
# коррелировали через один поток чисел.
const TARGET_PICK_SALT := 0x51ED2701
# Запас до конца раунда, чтобы окно успело закрыться внутри боя.
const ROUND_TAIL_MARGIN := 2.0

var _window := 10.0
var _active_time := 0.0
var _start_hp := 0.0
var _damage_to_target := 0.0
var _killed := false
var _resolved := false
var _status := ""
var _reason := ""

var _target: Node2D = null
var _marker: Node2D = null
var _marker_tween: Tween = null
var _hud_label: Label = null


func id() -> String:
	return "marked_target"


func is_eligible(context) -> bool:
	return context.is_normal_battle()


func plan(context, beat_def: Dictionary) -> Dictionary:
	var window_def: Dictionary = beat_def.get("trigger_window", {})
	var min_s := float(window_def.get("min_seconds", 20.0))
	var max_s := float(window_def.get("max_seconds", 40.0))
	var window := float(beat_def.get("duration_seconds", 10.0))

	# Окно должно закрыться до конца раунда. Слишком короткий бой — отказ.
	var latest: float = float(context.round_duration) - window - ROUND_TAIL_MARGIN
	if latest < min_s:
		return {}
	var rng: RandomNumberGenerator = context.aspect_rng(int(beat_def.get("seed_salt", 0)))
	var trigger: float = rng.randf_range(min_s, max_s)
	trigger = minf(trigger, latest)
	return {"trigger_at": trigger, "window": window}


func on_trigger(context, beat_def: Dictionary) -> bool:
	_window = float(beat_def.get("duration_seconds", 10.0))
	var candidates: Array = context.alive_normal_enemies()
	if candidates.is_empty():
		return false

	var player_pos: Vector2 = context.player_position()
	candidates.sort_custom(func(a, b):
		var da: float = player_pos.distance_squared_to(a.global_position)
		var db: float = player_pos.distance_squared_to(b.global_position)
		if da != db:
			return da < db
		if a.global_position.x != b.global_position.x:
			return a.global_position.x < b.global_position.x
		if a.global_position.y != b.global_position.y:
			return a.global_position.y < b.global_position.y
		return a.get_instance_id() < b.get_instance_id()
	)
	var pick_rng: RandomNumberGenerator = context.aspect_rng(int(beat_def.get("seed_salt", 0)) ^ TARGET_PICK_SALT)
	_target = candidates[pick_rng.randi_range(0, candidates.size() - 1)] as Node2D
	if _target == null or not is_instance_valid(_target):
		return false

	_start_hp = float(_target.get("health"))
	if _target.has_signal("died") and not _target.died.is_connected(_on_target_died):
		_target.died.connect(_on_target_died)

	_build_marker(context, beat_def)
	_build_hud(context)
	return true


func on_tick(context, delta: float) -> void:
	if _resolved:
		return
	_active_time += delta

	var target_live := is_instance_valid(_target) and not _target.is_queued_for_deletion()
	if target_live:
		if _marker != null and is_instance_valid(_marker):
			_marker.global_position = _target.global_position
		_damage_to_target = maxf(_damage_to_target, _start_hp - float(_target.get("health")))
	_update_hud_text()

	if _killed:
		_finish(STATUS_COMPLETED, "target_killed")
	elif not target_live:
		_finish(STATUS_FAILED, "target_lost")
	elif _active_time >= _window:
		_finish(STATUS_FAILED, "window_expired")


func is_resolved() -> bool:
	return _resolved


func resolve(context, reason: String) -> Dictionary:
	_cleanup_nodes()
	if not _resolved:
		if reason == "no_target":
			_status = STATUS_ABORTED
			_reason = "no_target"
		else:
			# Принудительный конец (combat_end) с ещё активным битом = провал.
			_status = _status if _status != "" else STATUS_FAILED
			_reason = _reason if _reason != "" else reason
		_resolved = true
	return make_outcome(id(), _status, {
		"duration": _active_time,
		"damage_to_target": _damage_to_target,
		"player_died": false,
		"reason": _reason,
	})


func _finish(status: String, reason: String) -> void:
	if _resolved:
		return
	_status = status
	_reason = reason
	_resolved = true


func _on_target_died(_enemy: Node2D) -> void:
	_killed = true
	_damage_to_target = _start_hp


func _build_marker(context, beat_def: Dictionary) -> void:
	var payload: Dictionary = beat_def.get("payload", {})
	var color_arr: Array = payload.get("marker_color", [1.0, 0.36, 0.32])
	var color := Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]), 0.95)
	var radius := float(payload.get("marker_radius", 46.0))

	var marker := Node2D.new()
	marker.name = "MarkedTargetMarker"
	marker.z_index = 60
	marker.process_mode = Node.PROCESS_MODE_PAUSABLE

	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = color
	ring.closed = true
	var points := PackedVector2Array()
	var segments := 28
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	ring.points = points
	marker.add_child(ring)

	context.presentation_parent.add_child(marker)
	if is_instance_valid(_target):
		marker.global_position = _target.global_position

	var tween := marker.create_tween()
	tween.set_loops()
	tween.tween_property(ring, "scale", Vector2(1.16, 1.16), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	_marker = marker
	_marker_tween = tween


func _build_hud(context) -> void:
	var root: Control = context.hud_root()
	if root == null:
		return
	var label := Label.new()
	label.name = "MarkedTargetHudLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-140.0, 92.0)
	label.custom_minimum_size = Vector2(280.0, 28.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", SemanticTypography.resolve_fixed(SemanticTypography.ROLE_HUD, 22))
	label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.42, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	root.add_child(label)
	_hud_label = label
	_update_hud_text()


func _update_hud_text() -> void:
	if _hud_label == null or not is_instance_valid(_hud_label):
		return
	var remaining := maxf(_window - _active_time, 0.0)
	_hud_label.text = "Отмеченная цель — %dс" % int(ceil(remaining))


func _cleanup_nodes() -> void:
	if _marker_tween != null and _marker_tween.is_valid():
		_marker_tween.kill()
	_marker_tween = null
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
	if _hud_label != null and is_instance_valid(_hud_label):
		_hud_label.queue_free()
	_hud_label = null
	if _target != null and is_instance_valid(_target) and _target.has_signal("died") \
			and _target.died.is_connected(_on_target_died):
		_target.died.disconnect(_on_target_died)


# --- Доступ для тестов ---

func debug_target() -> Node2D:
	return _target


func debug_marker() -> Node2D:
	return _marker


func debug_hud_label() -> Label:
	return _hud_label


# Ссылку берут ДО resolve: _cleanup_nodes() обнуляет поле сразу после kill().
func debug_tween() -> Tween:
	return _marker_tween


func debug_status() -> String:
	return _status


func debug_damage() -> float:
	return _damage_to_target
