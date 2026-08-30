extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса chemist.
# Домен владения: class/chemist (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_chemist_identity_modes()
	await _check_chemist_identity()
	await _check_chemist_homunculus_pair()
	_finish("[balance/chemist] PASSED")


func _check_chemist_identity_modes() -> void:
	# SCRUM-943/944: кит Химика — быстрый прямой физический AoE без луж +
	# кислотные лужи с перманентными контактными зарядами.
	var chemist_blast_config: Dictionary = ProgressionData.weapon("chemist", "blast_powder")
	if bool(chemist_blast_config.get("leaves_pool", false)) \
			or str(chemist_blast_config.get("damage_parameter", "")) != "damage" \
			or float(chemist_blast_config.get("fire_interval", 9.0)) > 0.8:
		_fail("Expected Chemist blast powder to be a fast direct physical AoE without pools.")
		return
	if not bool(ProgressionData.weapon("chemist", "acid_flask").get("pool_contact_charges", false)):
		_fail("Expected Chemist acid flask puddles to apply persistent contact charges.")
		return


func _check_chemist_identity() -> void:
	var holder := Node2D.new()
	holder.name = "ChemistIdentityScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var chemist := player_scene.instantiate()
	holder.add_child(chemist)
	chemist.global_position = Vector2(1100, 700)
	await process_frame
	chemist.call("configure_character", "chemist", "blast_powder")
	var chemist_weapon: Node = chemist.get("equipped_weapon")
	chemist_weapon.set_process(false)
	var chemist_enemy := enemy_scene.instantiate()
	holder.add_child(chemist_enemy)
	chemist_enemy.set("max_health", 100000.0)
	chemist_enemy.set("health", 100000.0)
	chemist_enemy.global_position = chemist.global_position + Vector2(40, 0)
	await process_frame
	# SCRUM-943: взрыв пыли — прямой БЕЗ лужи; SCRUM-944: кислотная лужа вешает
	# перманентный контактный заряд с per-pool идентичностью.
	var chemist_hp_before := float(chemist_enemy.get("health"))
	chemist_weapon.call("_damage_aoe_projectile_explosion", chemist_enemy.global_position, 150.0, 10.0)
	await process_frame
	if float(chemist_enemy.get("health")) >= chemist_hp_before:
		_fail("Expected Chemist blast powder direct AoE explosion to damage enemies.")
		return
	if get_nodes_in_group("chemist_clouds").size() > 0:
		_fail("Expected Chemist blast powder explosion to leave no pools.")
		return
	# FAN-2238: продакшен-путь каста пыли (полёт + прилёт) остаётся pool-free и
	# без реагентного следа, пока финал созвездия не куплен.
	var chemist_natural_hp_before := float(chemist_enemy.get("health"))
	chemist_weapon.call("_attack")
	await create_timer(0.6).timeout
	if float(chemist_enemy.get("health")) >= chemist_natural_hp_before:
		_fail("Expected Chemist blast powder natural cast/travel/impact to damage enemies.")
		return
	if get_nodes_in_group("chemist_clouds").size() > 0:
		_fail("Expected Chemist blast powder natural cast to leave no pools.")
		return
	for chemist_effect in get_nodes_in_group("player_weapon_effects"):
		if (chemist_effect as Node).name == "PowderReagentTrace":
			_fail("Expected base Chemist blast powder to leave no reagent trace without its constellation final.")
			return
	var chemist_acid := player_scene.instantiate()
	holder.add_child(chemist_acid)
	chemist_acid.global_position = Vector2(1150, 700)
	await process_frame
	chemist_acid.call("configure_character", "chemist", "acid_flask")
	var acid_weapon: Node = chemist_acid.get("equipped_weapon")
	acid_weapon.set_process(false)
	var acid_enemy := enemy_scene.instantiate()
	holder.add_child(acid_enemy)
	acid_enemy.set("max_health", 100000.0)
	acid_enemy.set("health", 100000.0)
	acid_enemy.global_position = chemist_acid.global_position + Vector2(40, 0)
	await process_frame
	var acid_hp_before := float(acid_enemy.get("health"))
	acid_weapon.call("_spawn_damage_pool", acid_enemy.global_position, 2.0)
	var acid_pools := get_nodes_in_group("chemist_clouds")
	if acid_pools.is_empty():
		_fail("Expected Chemist acid flask to leave a ground puddle.")
		return
	var acid_pool := acid_pools[0] as Node2D
	acid_weapon.call("_damage_enemies_in_pool", acid_pool.global_position, 150.0, 2.0, acid_pool)
	await process_frame
	if float(acid_enemy.get("health")) >= acid_hp_before:
		_fail("Expected Chemist acid puddle tick to damage enemies inside.")
		return
	var acid_charge_found := false
	for status_id in StatusEffects.snapshot(acid_enemy).keys():
		if str(status_id).begins_with("acid_charge"):
			acid_charge_found = true
	if not acid_charge_found:
		_fail("Expected Chemist acid puddle contact to apply a persistent acid charge.")
		return
	acid_pool.remove_from_group("chemist_clouds")
	acid_pool.queue_free()
	await process_frame
	holder.queue_free()
	current_scene = null
	await process_frame


func _check_chemist_homunculus_pair() -> void:
	var holder := Node2D.new()
	holder.name = "ChemistHomunculusScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	# SCRUM-946: пара «танк + кастер» — постоянные юниты на новых PixelLab-спрайтах.
	var chemist_minion_owner := player_scene.instantiate()
	holder.add_child(chemist_minion_owner)
	chemist_minion_owner.global_position = Vector2(1600, 700)
	await process_frame
	chemist_minion_owner.call("configure_character", "chemist", "homunculus_vial")
	var homunculus_weapon: Node = chemist_minion_owner.get("equipped_weapon")
	homunculus_weapon.set_process(false)
	homunculus_weapon.call("_update_homunculus_pair", 0.1)
	await process_frame
	# Направленный статичный арт мог развернуть танк за кадр — принимаем любой
	# из 4 новых PixelLab-кадров танка (prefix-match).
	var homunculus_tank_visual_ok := false
	for ally in get_nodes_in_group("allies"):
		if ally.get("owner_node") == chemist_minion_owner and _node_sprite_texture_path(ally, "Body").begins_with("res://assets/sprites/allies/homunculus_tank_"):
			homunculus_tank_visual_ok = true
	if not homunculus_tank_visual_ok:
		_fail("Expected Chemist homunculus tank to use the new PixelLab tank sprite.")
		return
	var homunculus_caster: Node = homunculus_weapon.get("_pair_caster")
	if homunculus_caster == null or not is_instance_valid(homunculus_caster):
		_fail("Expected Chemist homunculus pair to spawn the invulnerable caster.")
		return
	if (homunculus_caster as Node).is_in_group("allies"):
		_fail("Expected Chemist homunculus caster to stay outside the allies combat group.")
		return
	if not _node_sprite_texture_path(homunculus_caster, "CasterVisual").begins_with("res://assets/sprites/allies/homunculus_caster_"):
		_fail("Expected Chemist homunculus caster to use the new PixelLab caster sprite.")
		return
	holder.queue_free()
	current_scene = null
	await process_frame
