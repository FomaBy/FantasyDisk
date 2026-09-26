extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса dark_mage.
# Домен владения: class/dark_mage (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_dark_mage_weapon_configs()
	await _check_dark_mage_chain_cast()
	_finish("[balance/dark_mage] PASSED")


func _check_dark_mage_weapon_configs() -> void:
	# SCRUM-939: палочка — цепной снаряд: до 3 целей + бурст на каждом попадании.
	var wand_config: Dictionary = ProgressionData.weapon("dark_mage", "dark_wand")
	if str(wand_config.get("attack_mode", "")) != "dark_chain_burst" or int(wand_config.get("chain_targets", 0)) != 3:
		_fail("Expected dark wand to be a chain projectile with 3 total targets.")
		return
	if float(wand_config.get("chain_burst_ratio", 0.0)) <= 0.0:
		_fail("Expected dark wand chain hits to carry an AoE burst ratio.")
		return
	# SCRUM-941: книга — одна пара зеркальных взрывов за каст (не мультиснаряд).
	var book_config: Dictionary = ProgressionData.weapon("dark_mage", "dark_book")
	if str(book_config.get("attack_mode", "")) != "dark_mirror_blast" or int(book_config.get("projectile_count", 0)) != 1:
		_fail("Expected dark book to fire one mirrored AoE pair per cast.")
		return
	if absf(float(book_config.get("mirror_damage_ratio", 0.0)) - 1.0) > 0.001:
		_fail("Expected dark book mirror blast to deal full symmetric damage.")
		return
	# SCRUM-940: череп — curse-only (прямого урона нет, только dot-ось).
	var skull_config: Dictionary = ProgressionData.weapon("dark_mage", "cursed_skull")
	if str(skull_config.get("attack_mode", "")) != "skull_curse_burn" or not bool(skull_config.get("curse_only", false)):
		_fail("Expected cursed skull to be a curse-only burn zone.")
		return
	if int(skull_config.get("dot_ticks", 0)) <= 0 or float(skull_config.get("curse_tick_rate", 0.0)) <= 1.0:
		_fail("Expected cursed skull to tick frequently through the dot pipeline.")
		return


func _check_dark_mage_chain_cast() -> void:
	var holder := Node2D.new()
	holder.name = "DarkMageWeaponReworkScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	# SCRUM-939: живой каст палочки — видимый цепной снаряд долетает и наносит
	# урон реальному врагу (fallback одной цели: цепь обрывается без повторов).
	var mage := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	holder.add_child(mage)
	mage.global_position = Vector2(700, 700)
	await process_frame
	mage.call("configure_character", "dark_mage", "dark_wand")
	var wand: Node = mage.get("equipped_weapon")
	wand.set_process(false)
	var chain_enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate()
	holder.add_child(chain_enemy)
	chain_enemy.set("max_health", 100000.0)
	chain_enemy.set("health", 100000.0)
	chain_enemy.set("move_speed", 0.0)
	chain_enemy.global_position = mage.global_position + Vector2(300, 0)
	await process_frame
	var effects_before := get_nodes_in_group("player_weapon_effects").size()
	wand.call("_attack")
	var chain_effects_spawned := get_nodes_in_group("player_weapon_effects").size() - effects_before
	if chain_effects_spawned < 1:
		_fail("Expected dark wand attack to spawn a visible chain projectile, got %d effect(s)." % chain_effects_spawned)
		return
	await create_timer(0.9).timeout
	if float(chain_enemy.get("health")) >= 100000.0:
		_fail("Expected dark wand chain projectile to damage the target on arrival.")
		return
	mage.queue_free()
	chain_enemy.queue_free()
	await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame
