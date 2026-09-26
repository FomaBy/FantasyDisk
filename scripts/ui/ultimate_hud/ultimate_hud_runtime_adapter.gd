class_name UltimateHudRuntimeAdapter
extends Node

## Narrow live bridge: it only translates current Player/registry state into
## the already-versioned widget contract and routes the widget's request back
## through Player.activate_ultimate().

const WidgetScene := preload("res://scenes/ui/ultimate_hud/ultimate_hud_widget.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const ViewModel := preload("res://scripts/ui/ultimate_hud/ultimate_hud_view_model.gd")

var _player: Node2D = null
var _widget: Control = null
var _game: Node = null
var _input_manager: Node = null
var _cached_input := {}
var _cached_class_id := ""
var _cached_weapon_id := ""
var _cached_profile := {}
var _cached_resolution_source := ""
var _cached_weapon_config := {}
var _cached_ultimate_text := {}
var _last_observation := {}
var _has_observation := false


## The combat director creates the HUD before it creates the Player. Keep this
## small bridge inside the adapter, so the monolithic UI owner only attaches it.
static func attach(parent: Control, game: Node) -> Node:
	var adapter := new()
	adapter._game = game
	adapter.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(adapter)
	adapter.set_process(true)
	return adapter


func _process(_delta: float) -> void:
	_sync_input_manager()
	if _widget != null and is_instance_valid(_widget):
		refresh()
		return
	if _game == null or not is_instance_valid(_game) or get_parent() is not Control:
		return
	var player: Node2D = _game.get("current_player") as Node2D
	if player != null and is_instance_valid(player):
		mount(get_parent() as Control, player)


func mount(parent: Control, player: Node2D) -> bool:
	if parent == null or player == null or not is_instance_valid(player):
		return false
	_player = player
	_reset_cache()
	_widget = WidgetScene.instantiate() as Control
	if _widget == null:
		return false
	_widget.name = "UltimateHudWidget"
	_widget.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_widget.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_widget.position = Vector2(-24.0, 88.0)
	_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_widget)
	if _widget.has_signal("activation_requested"):
		_widget.connect("activation_requested", Callable(self, "_on_activation_requested"))
	refresh()
	return true


func refresh() -> void:
	if _widget == null or not is_instance_valid(_widget):
		return
	if _player == null or not is_instance_valid(_player):
		_apply_empty_state()
		return
	var class_id := str(_player.get("character_id"))
	var weapon_id := str(_player.get("weapon_id"))
	if class_id != _cached_class_id or weapon_id != _cached_weapon_id:
		_cache_selection(class_id, weapon_id)
	if _cached_profile.is_empty():
		_apply_empty_state()
		return
	var maximum := maxf(float(_player.get("ultimate_max_charge")), 1.0)
	var aim_mode: String = str(_player.call("attack_aim_mode")) if _player.has_method("attack_aim_mode") else "nearest"
	var observation := {
		"available": true,
		"charge_fraction": clampf(float(_player.get("ultimate_charge")) / maximum, 0.0, 1.0),
		"charge_active": bool(_player.get("_ultimate_active")),
		"input": _cached_input,
		"aim_mode": aim_mode,
		"aiming": str(aim_mode) == "cursor",
	}
	if _has_observation and observation == _last_observation:
		return
	_last_observation = observation
	_has_observation = true
	_widget.call("apply_state", _build_state({
		"profile": _cached_profile,
		"resolution_source": _cached_resolution_source,
		"weapon_config": _cached_weapon_config,
		"ultimate_text": _cached_ultimate_text,
		"charge": {
			"fraction": observation["charge_fraction"],
			"active": observation["charge_active"],
		},
		"input": _cached_input,
		"aim": {
			"mode": aim_mode,
			"aiming": observation["aiming"],
		},
	}))


func invalidate_input() -> void:
	_refresh_input_state(_active_input_kind())
	_has_observation = false
	refresh()


func _build_state(snapshot: Dictionary) -> Dictionary:
	return ViewModel.build(snapshot)


func _reset_cache() -> void:
	_cached_class_id = ""
	_cached_weapon_id = ""
	_cached_profile = {}
	_cached_resolution_source = ""
	_cached_weapon_config = {}
	_cached_ultimate_text = {}
	_last_observation = {}
	_has_observation = false
	_refresh_input_state(_active_input_kind())


func _cache_selection(class_id: String, weapon_id: String) -> void:
	_cached_class_id = class_id
	_cached_weapon_id = weapon_id
	var registry = PlayerHost.shared_registry()
	_cached_profile = registry.catalog_profile_for(class_id, weapon_id)
	_cached_resolution_source = registry.resolution_source(class_id, weapon_id, false)
	_cached_weapon_config = ProgressionData.weapon(class_id, weapon_id)
	# FAN-2515: текст ульты — канонический weapon-ultimate выбранного оружия,
	# а не legacy-ульта класса.
	_cached_ultimate_text = registry.ultimate_text(class_id, weapon_id)
	_has_observation = false


func _apply_empty_state() -> void:
	var observation := {"available": false}
	if _has_observation and observation == _last_observation:
		return
	_last_observation = observation
	_has_observation = true
	_widget.call("apply_state", {})


func _sync_input_manager() -> void:
	var manager := get_tree().root.get_node_or_null("InputDeviceManager") if get_tree() != null else null
	if manager == _input_manager:
		return
	if _input_manager != null and is_instance_valid(_input_manager) \
			and _input_manager.has_signal("device_changed") \
			and _input_manager.device_changed.is_connected(_on_input_device_changed):
		_input_manager.device_changed.disconnect(_on_input_device_changed)
	_input_manager = manager
	if _input_manager != null and _input_manager.has_signal("device_changed"):
		_input_manager.device_changed.connect(_on_input_device_changed)
	_refresh_input_state(_active_input_kind())
	_has_observation = false


func _active_input_kind() -> String:
	if _input_manager != null and is_instance_valid(_input_manager) and _input_manager.has_method("active_kind"):
		return str(_input_manager.call("active_kind"))
	return "keyboard"


func _on_input_device_changed(kind: String) -> void:
	_refresh_input_state(kind)
	_has_observation = false
	refresh()


func _refresh_input_state(device: String) -> void:
	_cached_input = _input_state(device)


func _input_state(device: String) -> Dictionary:
	var joy_button := JOY_BUTTON_Y
	var key_label := "R"
	for event in InputMap.action_get_events("ultimate"):
		if event is InputEventJoypadButton:
			joy_button = int(event.button_index)
		elif event is InputEventKey:
			var code := int(event.keycode if event.keycode != 0 else event.physical_keycode)
			if code != 0:
				key_label = OS.get_keycode_string(code)
	return {"device": device, "joy_button": joy_button, "key_label": key_label, "key_glyph": "generic"}


func _on_activation_requested(profile_id: String) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.has_method("activate_ultimate"):
		return
	var profile: Dictionary = PlayerHost.shared_registry().catalog_profile_for(
		str(_player.get("character_id")), str(_player.get("weapon_id"))
	)
	var identity = profile.get("identity", {})
	if identity is Dictionary and str((identity as Dictionary).get("profile_id", "")) == profile_id:
		_player.call("activate_ultimate")
