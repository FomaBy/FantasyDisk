extends SceneTree

# SCRUM-505 deterministic measurement (SIGABRT-safe; the full 51-row
# character_balance_csv.gd crashes under recursive teardown in this environment —
# see Jira SCRUM-505 / memory csv-balance-gen-sigabrt-flaky).
#
# Prints the live 20-target throughput (lvl1 out-of-box AND lvl20-ideal build) for the
# three previously-dead mobile summon weapons, via the SAME real combat path the
# balance harness uses (live Player + ally minions / sentry turret vs a fixed enemy
# ring). Runs ONLY 3 weapons → well under the teardown count that trips the harness
# SIGABRT → completes cleanly.
#
# Usage: compare git HEAD (pre-SCRUM-505) vs working tree to confirm the buff lifts
# lvl20 crowd-clear strongly while keeping lvl1 ~flat. Also self-gates that each weapon
# is materially above an absolute dead-slot floor at lvl20 (regression guard).

const ProgressionData := preload("res://scripts/progression_data.gd")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const WINDOW_SECONDS := 8.0
const FRAMES := 480
const TARGET_LEVEL := 20
const BASE_SEED := 20260620
const OFFER_SIZE := 3
const RARE_SLOT_CHANCE := 0.05

# Per weapon: minimum lvl20-ideal 20t throughput on THIS probe's scale that proves the
# weapon is revived off its dead slot, and the max lvl1 (out-of-box) 20t allowed so the
# starting balance is not inflated. Probe under-measures vs the CSV (~5x); thresholds
# are calibrated to the probe scale (measured post-SCRUM-505: amulet ~430/35,
# homunculus ~95/14, sentry ~48/23 for lvl20/lvl1). Generous margins absorb the live
# sim's run-to-run variance while still catching a regression back to the dead floor
# (pre-505 probe lvl20: amulet 147, homunculus 29, sentry 35).
const WEAPONS := [
	{"cid": "druid", "wid": "summon_amulet", "min_lvl20": 300.0, "max_lvl1": 90.0},
	{"cid": "chemist", "wid": "homunculus_vial", "min_lvl20": 60.0, "max_lvl1": 30.0},
	{"cid": "engineer", "wid": "engineer_sentry_wrench", "min_lvl20": 42.0, "max_lvl1": 38.0},
]

var _holder: Node2D


func _initialize() -> void:
	await process_frame
	_holder = Node2D.new()
	_holder.name = "SummonFloorHolder"
	root.add_child(_holder)
	current_scene = _holder
	await process_frame

	var errors: Array = []
	for pair in WEAPONS:
		var cid := str(pair["cid"])
		var wid := str(pair["wid"])
		var min_l20 := float(pair["min_lvl20"])
		var max_l1 := float(pair["max_lvl1"])
		var l1 := await _measure_20t(cid, wid, true)
		var l20 := await _measure_20t(cid, wid, false)
		print("  SCRUM-505 PROBE: %s/%s 20t lvl1=%.1f lvl20_ideal=%.1f (gate: lvl20>=%.0f, lvl1<=%.0f)" % [
			cid, wid, l1, l20, min_l20, max_l1])
		if l20 < min_l20:
			errors.append("%s/%s lvl20_ideal 20t=%.1f below revival floor %.1f on probe scale — still a dead slot." % [
				cid, wid, l20, min_l20])
		if l1 > max_l1:
			errors.append("%s/%s lvl1 20t=%.1f above %.1f on probe scale — starting balance inflated." % [
				cid, wid, l1, max_l1])

	if not errors.is_empty():
		for e in errors:
			push_error("Summon crowd floor: %s" % e)
		push_error("Summon crowd floor test FAILED: %d errors." % errors.size())
		quit(1)
		return
	print("Summon weapon crowd floor test passed.")
	quit(0)


func _measure_20t(cid: String, wid: String, lvl1: bool) -> float:
	var archetype: String = ProgressionData.weapon_archetype(ProgressionData.weapon(cid, wid))
	var build: Array = []
	if not lvl1:
		var rng := RandomNumberGenerator.new()
		rng.seed = BASE_SEED
		build = _build_levelups(cid, archetype, rng) + _build_artifacts(rng)
	return await _measure_dps(cid, wid, 20, build)


func _measure_dps(character_id: String, weapon_id: String, target_count: int, rewards: Array) -> float:
	_teardown()
	await process_frame
	await process_frame
	var player := PLAYER_SCENE.instantiate() as Node2D
	_holder.add_child(player)
	player.add_to_group("player")
	player.global_position = Vector2(1280, 720)
	if player.has_method("configure_character"):
		player.configure_character(character_id, weapon_id)
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	for reward in rewards:
		if player.has_method("apply_reward"):
			player.apply_reward(reward)
	if not rewards.is_empty():
		player.set("level", TARGET_LEVEL)
	await process_frame
	var dummies := _spawn_dummies(player.global_position, target_count)
	var anchors: Array = []
	for e in dummies:
		anchors.append((e as Node2D).global_position)
	await process_frame
	var hp_before := 0.0
	for e in dummies:
		hp_before += float(e.get("health"))
	for _f in range(FRAMES):
		await process_frame
		for i in range(dummies.size()):
			var e := dummies[i] as Node2D
			if is_instance_valid(e):
				e.global_position = anchors[i]
	var hp_after := 0.0
	for e in dummies:
		if is_instance_valid(e):
			hp_after += float(e.get("health"))
	return maxf(hp_before - hp_after, 0.0) / WINDOW_SECONDS


func _teardown() -> void:
	for ally in get_nodes_in_group("allies"):
		if is_instance_valid(ally):
			ally.remove_from_group("allies")
			var n := ally as Node
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	for child in _holder.get_children():
		if is_instance_valid(child):
			_holder.remove_child(child)
			child.free()


func _spawn_dummies(player_pos: Vector2, target_count: int) -> Array:
	var dummies: Array = []
	for i in range(target_count):
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		_holder.add_child(enemy)
		var ang := TAU * float(i) / float(target_count)
		var rad := 120.0 + 90.0 * float(i % 3)
		var pos := player_pos + Vector2(cos(ang), sin(ang)) * rad
		enemy.global_position = pos
		enemy.set("max_health", 1.0e9)
		enemy.set("health", 1.0e9)
		dummies.append(enemy)
	return dummies


func _build_levelups(cid: String, archetype: String, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for _lvl in range(19):
		var offer: Array = []
		for _o in range(OFFER_SIZE):
			offer.append(_random_levelup(cid, rng))
		out.append(_pick_best(offer, archetype))
	return out


func _random_levelup(cid: String, rng: RandomNumberGenerator):
	var pool: Array = ProgressionData.LEVEL_UP_REWARDS.duplicate()
	if rng.randf() < RARE_SLOT_CHANCE:
		return {"type": "main_stat", "stat": ProgressionData.damage_parameter_for(cid)}
	return pool[rng.randi() % pool.size()]


func _pick_best(offer: Array, archetype: String):
	var best = offer[0]
	var best_score := -1.0e9
	for r in offer:
		var s := _score(r, archetype)
		if s > best_score:
			best_score = s
			best = r
	return best


func _score(reward, archetype: String) -> float:
	var score := 0.0
	if reward is Dictionary:
		var t := str(reward.get("type", ""))
		var v := float(reward.get("value", reward.get("amount", 1.0)))
		match t:
			"damage_multiplier", "main_stat":
				score += 10.0 * v
			"attack_speed":
				score += 8.0 * v
			"summon_bonus":
				score += (30.0 if archetype == "summon" else 3.0) * v
			_:
				score += 1.0 * v
	return score


func _build_artifacts(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var pool: Array = ProgressionData.ARTIFACTS.duplicate() if "ARTIFACTS" in ProgressionData else []
	for _i in range(6):
		if pool.is_empty():
			break
		out.append(pool[rng.randi() % pool.size()])
	return out
