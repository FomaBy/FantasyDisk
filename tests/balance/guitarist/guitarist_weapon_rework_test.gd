extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса guitarist.
# Домен владения: class/guitarist (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_guitarist_weapon_configs()
	await _check_guitarist_amp_limit()
	_finish("[balance/guitarist] PASSED")


func _check_guitarist_weapon_configs() -> void:
	var bass_config: Dictionary = ProgressionData.weapon("guitarist", "bass_guitar")
	# FAN-1031 3d-final: identity-кап баса поднят задокументированным продуктовым
	# решением (координатор, DoD FAN-1028): порог 0.35 → 0.50 зеркалит guitarist
	# kit-тест (bass ≤ 0.50, bass < electric). Контроль-идентичность (частый пульс,
	# жёсткий отброс) остаётся запинена.
	if float(bass_config.get("damage_multiplier", 1.0)) > 0.50 or float(bass_config.get("fire_interval", 9.9)) > 0.9 or float(bass_config.get("knockback", 0.0)) < 150.0:
		_fail("Expected bass guitar to be a fast low-damage control pulse.")
		return
	var amp_config: Dictionary = ProgressionData.weapon("guitarist", "sound_amp")
	if float(amp_config.get("amp_lifetime", 0.0)) < 6.0 or float(amp_config.get("amp_lifetime", 0.0)) > 8.0 or int(amp_config.get("max_summons", 0)) != 1:
		_fail("Expected sound amp to live 6-8s with base limit 1.")
		return


func _check_guitarist_amp_limit() -> void:
	var holder := Node2D.new()
	holder.name = "GuitaristWeaponReworkScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	# Лимит ампов: гитарист с Лидерством 7 держит 1 + floor(7/4) = 2 усилителя.
	var guitarist := (load("res://scenes/Player.tscn") as PackedScene).instantiate()
	holder.add_child(guitarist)
	guitarist.global_position = Vector2(700, 700)
	await process_frame
	guitarist.call("configure_character", "guitarist", "sound_amp")
	var amp_weapon: Node = guitarist.get("equipped_weapon")
	amp_weapon.set_process(false)
	if int(amp_weapon.get("max_summons")) != 2:
		_fail("Expected guitarist (leadership 7) amp limit to be 2, got %d." % int(amp_weapon.get("max_summons")))
		return
	for deploy_index in range(3):
		amp_weapon.call("_attack")
		await process_frame
	var active_amps := get_nodes_in_group("deployed_sound_amps").size()
	if active_amps != 2:
		_fail("Expected oldest amp to despawn at the limit, got %d active." % active_amps)
		return
	var amp_nodes := get_nodes_in_group("deployed_sound_amps")
	if amp_nodes.is_empty() or _node_sprite_texture_path(amp_nodes[0], "") != "res://assets/sprites/allies/deploy_sound_amp_field.png":
		_fail("Expected sound amp deployables to use the source-specific field sprite.")
		return

	guitarist.queue_free()
	holder.queue_free()
	current_scene = null
	await process_frame
