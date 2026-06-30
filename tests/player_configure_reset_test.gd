extends SceneTree

# SCRUM-709 (refactor wave 0.1.8): focused coverage for Player run-state reset on
# character configuration. Guards the run_modifiers dedup (single _default_run_modifiers
# source used by both the var initializer and configure_character) and the
# cleanup-on-character-swap acceptance: stale modifiers, artifacts, progression and the
# equipped weapon must not leak across configure_character().

const PlayerScript := preload("res://scripts/player.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	if player_scene == null:
		push_error("Player scene did not load.")
		quit(1)
		return

	var ok: bool = await _run_assertions(player_scene)
	if not ok:
		quit(1)
		return

	print("Player configure-reset test passed.")
	quit()


func _run_assertions(player_scene: PackedScene) -> bool:
	var defaults: Dictionary = PlayerScript._default_run_modifiers()

	# The default modifier set must be non-trivial and carry the balance caps from
	# ProgressionData (the only non-literal entries).
	for required_key in ["damage_multiplier", "attack_speed_multiplier", "max_health_multiplier",
			"summon_bonus", "defense_flat", "healing_multiplier",
			"vampiric_heal_per_second_cap", "drain_heal_per_second_cap", "knockback_multiplier"]:
		if not defaults.has(required_key):
			push_error("Expected _default_run_modifiers() to define '%s'." % required_key)
			return false
	if float(defaults["damage_multiplier"]) != 1.0 or float(defaults["summon_bonus"]) != 0.0:
		push_error("Expected sane default modifier values (mult=1.0, flat=0.0).")
		return false
	if float(defaults["vampiric_heal_per_second_cap"]) != float(ProgressionData.VAMPIRIC_HEAL_CAP_DEFAULT):
		push_error("Expected default vampiric cap to track ProgressionData.")
		return false

	# A freshly instantiated player (var-initializer path) must equal the single source.
	var fresh := player_scene.instantiate()
	root.add_child(fresh)
	await process_frame
	if not _modifiers_match(fresh.get("run_modifiers"), defaults, "fresh var-init"):
		fresh.queue_free()
		return false
	fresh.queue_free()
	await process_frame

	# configure_character path: dirty every reset surface, swap class, expect a clean slate.
	var player := player_scene.instantiate()
	root.add_child(player)
	var berserk_weapons: Array = ProgressionData.weapon_ids("berserk")
	if berserk_weapons.is_empty():
		push_error("Expected berserk to expose weapons for the equip/cleanup check.")
		player.queue_free()
		return false
	player.call("configure_character", "berserk", str(berserk_weapons[0]))
	await process_frame

	# Pollute run state: a stray transient modifier key, an artifact, and progression.
	var dirty: Dictionary = player.get("run_modifiers")
	dirty["damage_multiplier"] = 9.0
	dirty["ultimate_berserk_active"] = 1.0  # transient key not present in defaults
	player.set("run_modifiers", dirty)
	player.call("apply_reward", {"kind": "artifact", "id": "test_relic", "title": "Test Relic"})
	player.set("xp", 99)
	player.set("level", 7)
	player.set("money", 250)
	player.set("ultimate_charge", 100.0)
	await process_frame

	if player.get("equipped_weapon") == null:
		push_error("Expected a weapon to be equipped before the swap.")
		player.queue_free()
		return false

	# Swap to a different class with no weapon — full reset path.
	player.call("configure_character", "dark_mage")
	await process_frame

	var reset_mods: Dictionary = player.get("run_modifiers")
	if reset_mods.has("ultimate_berserk_active"):
		push_error("Expected stray transient modifier to be dropped on configure_character.")
		player.queue_free()
		return false
	if not _modifiers_match(reset_mods, defaults, "post-swap"):
		player.queue_free()
		return false
	if not (player.get("artifacts") as Array).is_empty():
		push_error("Expected artifacts to be cleared on character swap.")
		player.queue_free()
		return false
	if int(player.get("level")) != 1 or int(player.get("xp")) != 0 or int(player.get("money")) != 0:
		push_error("Expected level/xp/money to reset on character swap.")
		player.queue_free()
		return false
	if float(player.get("ultimate_charge")) != 0.0:
		push_error("Expected ultimate charge to reset on character swap.")
		player.queue_free()
		return false
	if player.get("equipped_weapon") != null:
		push_error("Expected equipped weapon to be cleared when swapping to a no-weapon config.")
		player.queue_free()
		return false
	if not player.call("_equipped_weapons").is_empty():
		push_error("Expected no lingering player_weapons children after swap.")
		player.queue_free()
		return false

	player.queue_free()
	await process_frame
	return true


func _modifiers_match(actual_value: Variant, defaults: Dictionary, label: String) -> bool:
	if not (actual_value is Dictionary):
		push_error("Expected run_modifiers to be a Dictionary (%s)." % label)
		return false
	var actual: Dictionary = actual_value
	for key in defaults:
		if not actual.has(key):
			push_error("run_modifiers missing default key '%s' (%s)." % [key, label])
			return false
		if typeof(defaults[key]) == TYPE_FLOAT or typeof(defaults[key]) == TYPE_INT:
			if absf(float(actual[key]) - float(defaults[key])) > 0.0001:
				push_error("run_modifiers['%s'] drifted from default (%s)." % [key, label])
				return false
	return true
