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
		_widget.call("apply_state", {})
		return
	var class_id := str(_player.get("character_id"))
	var weapon_id := str(_player.get("weapon_id"))
	var registry = PlayerHost.shared_registry()
	var profile: Dictionary = registry.catalog_profile_for(class_id, weapon_id)
	if profile.is_empty():
		_widget.call("apply_state", {})
		return
	var maximum := maxf(float(_player.get("ultimate_max_charge")), 1.0)
	var state := ViewModel.build({
		"profile": profile,
		"resolution_source": registry.resolution_source(class_id, weapon_id, false),
		"weapon_config": ProgressionData.weapon(class_id, weapon_id),
		"ultimate_text": ProgressionData.ultimate_config(class_id),
		"charge": {
			"fraction": clampf(float(_player.get("ultimate_charge")) / maximum, 0.0, 1.0),
			"active": bool(_player.get("_ultimate_active")),
		},
		"input": _input_state(),
		"aim": {
			"mode": _player.call("attack_aim_mode") if _player.has_method("attack_aim_mode") else "nearest",
			"aiming": _player.has_method("attack_aim_mode") and str(_player.call("attack_aim_mode")) == "cursor",
		},
	})
	_widget.call("apply_state", state)


func _input_state() -> Dictionary:
	var device := "keyboard"
	var manager := get_tree().root.get_node_or_null("InputDeviceManager") if get_tree() != null else null
	if manager != null and manager.has_method("active_kind"):
		device = str(manager.call("active_kind"))
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
