extends SceneTree

const Meta := preload("res://scripts/meta_progression.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BerserkWeaponScript := preload("res://scripts/berserk_weapon.gd")
const HolyFlailScript := preload("res://scripts/holy_flail_weapon.gd")
const SummonerWeaponScript := preload("res://scripts/summoner_weapon.gd")

class DummyEnemy extends Node2D:
	var health := 10000.0
	var max_health := 10000.0
	func take_damage(amount: float, _feedback := {}) -> void:
		health -= amount

var errors := PackedStringArray()


func _initialize() -> void:
	_test_berserk_live_hit()
	_test_holy_flail_live_hit()
	_test_summoner_profile()
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("SCRUM-1068 live consumer paths passed Berserk/HolyFlail hit ownership and Summoner flat/geometry propagation.")
	quit(0)


func _test_berserk_live_hit() -> void:
	var state := Meta.default_state()
	state["skill_nodes"] = ["berserk_sword_b1", "berserk_sword_b2", "berserk_sword_b3", "berserk_sword_b4", "berserk_sword_b5", "berserk_h0"]
	var player = PlayerScript.new()
	root.add_child(player)
	player.configure_character("berserk")
	player.apply_constellation_weapon_profiles(Meta.skill_profiles_for_class(state, "berserk"))
	var sword = BerserkWeaponScript.new()
	sword.weapon_id = "sword"
	root.add_child(sword)
	player._apply_weapon_scaling(sword)
	# FAN-1720: живой хит роллит крит глобальным randf() (berserk_weapon.gd:824),
	# а глобальный поток сидится заново в каждом процессе. Проки (~7.5%) множили
	# dealt на crit_damage_multiplier=1.575 и ломали точное равенство профилей.
	# Крит — ортогональный контракту слой; выключаем его, как в
	# constellation_schema6_lifecycle_runtime_test / special_finals_test.
	player.derived_parameters["crit_chance"] = 0.0
	var enemy := DummyEnemy.new()
	root.add_child(enemy)
	var before := enemy.health
	sword._damage_target(player, enemy, Vector2.RIGHT)
	var expected := float(sword.damage) * 1.12 * 1.08 * 1.08
	_check(is_equal_approx(before - enemy.health, expected), "live Berserk hit bypassed exact sword identity/solo/hidden profile (got %.6f expected %.6f)" % [before - enemy.health, expected])
	enemy.queue_free()
	sword.queue_free()
	player.queue_free()


func _test_holy_flail_live_hit() -> void:
	var state := Meta.default_state()
	state["skill_nodes"] = ["knight_holy_flail_b1", "knight_holy_flail_b2", "knight_holy_flail_b3", "knight_holy_flail_b4", "knight_holy_flail_b5", "knight_h1"]
	var player = PlayerScript.new()
	root.add_child(player)
	player.configure_character("knight")
	player.apply_constellation_weapon_profiles(Meta.skill_profiles_for_class(state, "knight"))
	var flail = HolyFlailScript.new()
	flail.weapon_id = "holy_flail"
	root.add_child(flail)
	player._apply_weapon_scaling(flail)
	# FAN-1720: без выключенного крита прок ×1.575 маскировал бы потерянный
	# префинальный профиль (1.0 × 1.575 > 1.119) — ложно-зелёный односторонней
	# проверки ниже. С critом 0.0 порог различает профиль детерминированно.
	player.derived_parameters["crit_chance"] = 0.0
	var enemy := DummyEnemy.new()
	root.add_child(enemy)
	var before := enemy.health
	flail._damage_target(player, enemy, Vector2.RIGHT)
	_check(before - enemy.health > float(flail.damage) * 1.119, "live HolyFlail hit did not consume its prefinal identity profile")
	enemy.queue_free()
	flail.queue_free()
	player.queue_free()


func _test_summoner_profile() -> void:
	var player = PlayerScript.new()
	root.add_child(player)
	player.configure_character("druid")
	var summoner = SummonerWeaponScript.new()
	summoner.weapon_id = "summon_amulet"
	root.add_child(summoner)
	var neutral: Dictionary = summoner._summon_profile(player, {"family": "physical", "attack_kind": "melee"})
	var state := Meta.default_state()
	state["skill_nodes"] = ["druid_summon_amulet_b1", "druid_summon_amulet_b2", "druid_summon_amulet_b3", "druid_summon_amulet_b4", "druid_summon_amulet_b5", "druid_h0"]
	player.apply_constellation_weapon_profiles(Meta.skill_profiles_for_class(state, "druid"))
	player._apply_weapon_scaling(summoner)
	var boosted: Dictionary = summoner._summon_profile(player, {"family": "physical", "attack_kind": "melee"})
	_check(float(boosted.get("damage", 0.0)) > float(neutral.get("damage", 0.0)) + 0.1, "Summoner flat damage profile is a no-op")
	_check(float(boosted.get("aoe_radius", 0.0)) > float(neutral.get("aoe_radius", 0.0)) * 1.07, "Summoner geometry/hidden crowd profile is a no-op")
	_check(int(boosted.get("constellation_owner_instance_id", 0)) == player.get_instance_id(), "Summoner profile lost owning Player attribution")
	_check(str(boosted.get("constellation_weapon_id", "")) == "summon_amulet", "Summoner profile lost canonical weapon attribution")
	summoner.queue_free()
	player.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
