extends SceneTree

# FAN-3977 (0.3.2 release blocker, FAN-3964 Windows QA FAILED): the game froze
# to 1 FPS in fights because full-frame packs (mini-elites, night_stalker,
# bosses) were loaded synchronously on the main thread when the actor
# spawned. This suite pins the residency contract on the REAL combat start:
#
# 1. ROSTER: the encounter roster covers every pack an encounter can spawn —
#    every enemy, every mini-elite kind that can roll, every ally, the node
#    elite of an elite fight (each of the four elite scenes), the act boss of
#    a boss fight (every registered boss) and the secret boss (metadata pack).
# 2. GATE: `_start_combat` never finalizes (no spawns, no waves) before the
#    roster is resident; the Player/HUD are still created synchronously; the
#    finalize is re-entered from the prefetch tick and raises the combat guard.
# 3. ZERO SYNC LOADS: with the guard up, spawning every regular enemy scene,
#    every mini-elite kind, every elite scene, every boss (incl. secret) and
#    every ally visual leaves `synchronous_combat_load_count()` at 0 and gives
#    each actor a live FullFrameBody served from the resident set.
# 4. MISS FALLBACK: a pack deliberately made non-resident during a fight is
#    NOT loaded on the main thread — the actor keeps its static body, the
#    counter records the miss, one warning is logged, the pack is queued and
#    the actor swaps to its FullFrameBody when the background load lands.
# 5. BOUND: an elite/boss fight drops the packs it cannot spawn (mini-elites)
#    and the roster's RGBA bytes (from the trim manifests) stay under the
#    acceptance ceiling; `_end_combat` lowers the guard.
#
# Запуск: Godot --headless --path . --script res://tests/full_frame_combat_residency_test.gd

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const FullFrameAnimationRegistry := preload("res://scripts/full_frame_animation_registry.gd")
const FullFrameEncounterRoster := preload("res://scripts/full_frame_encounter_roster.gd")
const CombatStartSupport := preload("res://tests/support/combat_start_support.gd")
const AllyMinionScene := preload("res://scenes/AllyMinion.tscn")

const ENEMY_SCENES := [
	"res://scenes/Enemy.tscn", "res://scenes/EnemyRunner.tscn", "res://scenes/EnemyBiter.tscn",
	"res://scenes/EnemyBruiser.tscn", "res://scenes/EnemyShield.tscn", "res://scenes/EnemyFlyingRunner.tscn",
	"res://scenes/EnemySummoner.tscn", "res://scenes/EnemyShooter.tscn", "res://scenes/EnemyMage.tscn",
	"res://scenes/EnemySpitter.tscn", "res://scenes/EnemyBoneShaman.tscn",
]
const ELITE_SCENE_KEYS := ["armored", "stalker", "poisoned", "commander"]
const SECRET_BOSS_ID := "secret_ascension_boss"
const SECRET_BOSS_FRAMES := "res://assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres"
# RGBA bytes of resident trim pages any encounter roster may hold. The
# RENDER_TEXTURE_MEM_USED monitor reports 4/3 of these bytes (mip-chain
# accounting for every texture) on top of the ~0.2 GiB of UI/backgrounds/hero
# sheets, so 1000 MiB here keeps the fight under the 1.5 GiB acceptance line.
const ROSTER_RGBA_BUDGET_BYTES := 1000 * 1024 * 1024
const MAX_SEED_SEARCH := 4096

var _errors: Array = []
var _main: Node = null


func _initialize() -> void:
	await _run()
	if not _errors.is_empty():
		for error in _errors:
			push_error("Full-frame combat residency: %s" % error)
		push_error("Full-frame combat residency test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Full-frame combat residency test passed (roster covers every spawnable pack, combat start waits for residency, 0 synchronous loads across every enemy/mini-elite/elite/boss/ally spawn, miss falls back to the static body and swaps later, elite/boss fights drop the mini-elites).")
	quit(0)


func _fail(message: String) -> void:
	_errors.append(message)


func _run() -> void:
	_main = MAIN_SCENE.instantiate()
	root.add_child(_main)
	await process_frame
	# The regular-fight phase runs as the Druid: the class with the most
	# summon visuals (its ultimate spawns default-visual allies and its summon
	# weapon rolls the five ghost packs), so the per-class ally roster and the
	# ally spawns are exercised for real.
	_main.set("selected_character_id", "druid")
	_main.set("selected_weapon_id", "summon_amulet")
	FullFrameAnimationRegistry.release_prefetched()
	FullFrameAnimationRegistry.reset_synchronous_combat_load_count()

	_check_roster_composition()
	await _check_object_budget()
	await _check_gate_and_regular_spawns()
	await _check_miss_fallback()
	await _check_elite_fights()
	await _check_boss_fights()
	_check_roster_budgets()

	_end_combat_if_active()
	FullFrameAnimationRegistry.release_prefetched()
	_main.queue_free()
	await process_frame


# --- 0. object budget (FAN-3981) ------------------------------------------------

# The core roster resident (the route-map state every regular fight starts
# from) may cost at most RESIDENT_OBJECT_BUDGET engine objects per pack;
# with the FAN-3977 AtlasTexture-per-frame packs the same roster cost
# ~230 per pack (route map 7,606 objects, P2 8,643-8,719 on the fixed
# 0.3.1 Windows review; checklist P2 target 5,000, red > 6,250).
func _check_object_budget() -> void:
	var progression = _main.get("PROGRESSION_DATA")
	var roster: Array = FullFrameEncounterRoster.core_paths(progression, "druid")
	FullFrameAnimationRegistry.release_prefetched()
	await process_frame
	await process_frame
	var objects_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for frames_path in roster:
		FullFrameAnimationRegistry.queue_prefetch_path(str(frames_path))
	for _frame in range(3000):
		if FullFrameAnimationRegistry.all_resident(roster):
			break
		await process_frame
	if not FullFrameAnimationRegistry.all_resident(roster):
		_fail("object budget: the core roster did not become resident.")
		return
	await process_frame
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objects_before
	var budget := roster.size() * FullFrameTrimAtlas.RESIDENT_OBJECT_BUDGET
	print("object budget: core roster of %d packs resident adds %d engine objects (budget %d)." % [roster.size(), objects, budget])
	if objects > budget:
		_fail("object budget: the resident core roster (%d packs) added %d engine objects, over the %d budget." % [roster.size(), objects, budget])
	FullFrameAnimationRegistry.release_prefetched()
	await process_frame
	await process_frame
	var released := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objects_before
	if released > roster.size():
		_fail("object budget: %d engine objects remain after release_prefetched (expected the packs to be freed)." % released)


# --- 1. roster composition -----------------------------------------------------

func _check_roster_composition() -> void:
	var progression = _main.get("PROGRESSION_DATA")
	var core: Array = FullFrameEncounterRoster.core_paths(progression, "druid")
	for entity_id in FullFrameAnimationRegistry.kind_entity_ids("enemy"):
		var frames_path := FullFrameAnimationRegistry.frames_path_for("enemy", str(entity_id))
		if not core.has(frames_path):
			_fail("core roster misses enemy/%s (%s)." % [entity_id, frames_path])
	_check_class_ally_rosters(progression)
	var kinds: Array = _main.get("PROGRESSION_DATA").mini_elite_kinds()
	if kinds.size() < 10:
		_fail("expected at least 10 mini-elite kinds, found %d." % kinds.size())
	for kind in kinds:
		var frames_path := FullFrameAnimationRegistry.frames_path_for("elite", str(kind.get("id", "")))
		if frames_path == "":
			_fail("mini-elite kind %s has no registered pack." % kind.get("id", ""))
		elif not core.has(frames_path):
			_fail("core roster misses mini-elite %s." % kind.get("id", ""))
	var elite_id := FullFrameAnimationRegistry.frames_path_for("elite", "night_stalker")
	if core.has(elite_id):
		_fail("core roster must not carry node elites (night_stalker) — they are loaded per elite fight.")


# Per class: the ally roster must name every registered ally id that appears
# anywhere in the class's weapon data (independent textual scan), the
# summon defaults for classes with a summon weapon or the Druid, and nothing
# for classes without summons; an unknown class keeps every ally pack.
func _check_class_ally_rosters(progression) -> void:
	var ally_ids: Array = FullFrameAnimationRegistry.kind_entity_ids("ally")
	var classes_with_allies := 0
	for character_id_variant in progression.character_ids():
		var character_id := str(character_id_variant)
		var roster: Array = FullFrameEncounterRoster.ally_paths_for_class(progression, character_id)
		var config_text := ""
		var has_summon_weapon := false
		for weapon_id in progression.weapon_ids(character_id):
			var config: Dictionary = progression.weapon(character_id, str(weapon_id))
			config_text += JSON.stringify(config)
			for key in config.keys():
				if str(key).begins_with("summon_"):
					has_summon_weapon = true
		var expected := {}
		for ally_id in ally_ids:
			if config_text.contains("\"%s\"" % ally_id):
				expected[str(ally_id)] = true
		if has_summon_weapon or character_id == "druid" or not expected.is_empty():
			expected["druid_beast"] = true
			expected["druid_pack_spirit"] = true
		for ally_id in expected.keys():
			if not roster.has(FullFrameAnimationRegistry.frames_path_for("ally", str(ally_id))):
				_fail("class %s: ally roster misses %s named by its weapon data." % [character_id, ally_id])
		if roster.size() != expected.size():
			_fail("class %s: ally roster has %d packs, expected %d (%s)." % [character_id, roster.size(), expected.size(), expected.keys()])
		if not expected.is_empty():
			classes_with_allies += 1
	if classes_with_allies < 2:
		_fail("expected at least two classes with summon visuals (Druid, Chemist), found %d." % classes_with_allies)
	if FullFrameEncounterRoster.ally_paths_for_class(progression, "").size() != ally_ids.size():
		_fail("an unknown class must keep every ally pack (fail-safe).")


# --- 2/3. gate + regular spawns --------------------------------------------------

func _start_fight(is_boss: bool, combat_type: String) -> void:
	_end_combat_if_active()
	_main.set("current_node_type", combat_type)
	_main.combat._start_combat(is_boss, combat_type)


func _end_combat_if_active() -> void:
	if bool(_main.get("combat_active")):
		_main.combat._end_combat(false)


func _check_gate_and_regular_spawns() -> void:
	_start_fight(false, "battle")
	if not bool(_main.get("combat_active")) or _main.get("current_player") == null:
		_fail("regular fight: combat_active/Player must be set synchronously by _start_combat.")
		return
	if bool(_main.combat.get("_combat_start_finalized")):
		_fail("regular fight: combat start finalized before the core roster was resident (no packs were resident).")
	if FullFrameAnimationRegistry.is_combat_guard_active():
		_fail("regular fight: the combat guard must not be up before the roster is resident.")
	if FullFrameAnimationRegistry.residency_waiter_count() != 1:
		_fail("regular fight: expected one residency waiter, found %d." % FullFrameAnimationRegistry.residency_waiter_count())
	if not await CombatStartSupport.await_finalized(_main):
		_fail("regular fight: combat start did not finalize after the roster loaded.")
		return
	var roster: Array = FullFrameEncounterRoster.encounter_paths(_main, Callable(_main.combat, "_boss_scene_for_id"))
	if not FullFrameAnimationRegistry.all_resident(roster):
		_fail("regular fight: roster not fully resident at finalize.")
	if not FullFrameAnimationRegistry.is_combat_guard_active():
		_fail("regular fight: the combat guard must be up once combat finalized.")
	if FullFrameAnimationRegistry.synchronous_combat_load_count() != 0:
		_fail("regular fight: %d synchronous loads during the gated start." % FullFrameAnimationRegistry.synchronous_combat_load_count())
	# Every regular enemy scene, every mini-elite kind and every ally visual.
	for scene_path in ENEMY_SCENES:
		var enemy := _spawn_scene(scene_path)
		if enemy != null:
			_assert_live_body(enemy, scene_path)
			enemy.queue_free()
	var kinds: Array = _main.get("PROGRESSION_DATA").mini_elite_kinds()
	for kind in kinds:
		var elite_scene: PackedScene = _main.combat._elite_scene_by_key(str(kind.get("scene", "")))
		if elite_scene == null:
			_fail("mini-elite kind %s has no elite scene." % kind.get("id", ""))
			continue
		var elite := elite_scene.instantiate() as Node2D
		elite.add_to_group("elite_enemies")
		_main.combat._apply_mini_elite_kind(elite, kind)
		_main.add_child(elite)
		var body := _assert_live_body(elite, "mini-elite %s" % kind.get("id", ""))
		if body != null and str(body.get_meta("entity_id", "")) != str(kind.get("id", "")):
			_fail("mini-elite %s plays pack %s instead of its own." % [kind.get("id", ""), body.get_meta("entity_id", "")])
		elite.queue_free()
	# The REAL wave spawner (`_maybe_spawn_mini_elite`, forced chance 1.0) must
	# pick the kind's own pack at _ready time — FAN-3977 found it requested
	# the base elite pack first (meta set after add_child): a roster miss and
	# a ~70 MiB pack loaded for nothing on every mini-elite roll.
	var seen_kinds := {}
	for _roll in range(80):
		var before := get_nodes_in_group("elite_enemies").size()
		_main.combat._maybe_spawn_mini_elite({"mini_elite_chance": 1.0}, 8)
		var elites := get_nodes_in_group("elite_enemies")
		if elites.size() <= before:
			continue
		var rolled := elites[elites.size() - 1] as Node2D
		var kind_id := str(rolled.get_meta("mini_elite_kind", ""))
		seen_kinds[kind_id] = true
		var body := _assert_live_body(rolled, "wave mini-elite %s" % kind_id)
		if body != null and str(body.get_meta("entity_id", "")) != kind_id:
			_fail("wave mini-elite %s plays pack %s instead of its own." % [kind_id, body.get_meta("entity_id", "")])
		for enemy in get_nodes_in_group("enemies"):
			(enemy as Node).queue_free()
		await process_frame
	if seen_kinds.size() < kinds.size():
		_fail("wave spawner rolled only %d of %d mini-elite kinds in 80 forced rolls." % [seen_kinds.size(), kinds.size()])
	if FullFrameAnimationRegistry.synchronous_combat_load_count() != 0:
		_fail("wave mini-elite rolls caused %d combat-guard misses (base elite pack requested before the kind meta)." % FullFrameAnimationRegistry.synchronous_combat_load_count())
	var druid_allies: Array = FullFrameEncounterRoster.ally_paths_for_class(_main.get("PROGRESSION_DATA"), "druid")
	if druid_allies.size() < 7:
		_fail("druid ally roster has %d packs, expected the beast, pack spirit and five ghosts." % druid_allies.size())
	for ally_id in FullFrameAnimationRegistry.kind_entity_ids("ally"):
		if not druid_allies.has(FullFrameAnimationRegistry.frames_path_for("ally", str(ally_id))):
			continue
		var ally := AllyMinionScene.instantiate() as Node2D
		ally.set("ally_visual_id", str(ally_id))
		_main.add_child(ally)
		var animated_body := ally.get_node_or_null("AnimatedBody") as AnimatedSprite2D
		if animated_body == null or animated_body.sprite_frames == null or not animated_body.visible:
			_fail("ally %s has no live AnimatedBody under the guard." % ally_id)
		ally.queue_free()
	await process_frame
	if FullFrameAnimationRegistry.synchronous_combat_load_count() != 0:
		_fail("regular fight: %d synchronous pack loads while spawning enemies/mini-elites/allies." % FullFrameAnimationRegistry.synchronous_combat_load_count())


func _spawn_scene(scene_path: String) -> Node2D:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		_fail("%s does not load." % scene_path)
		return null
	var node := scene.instantiate() as Node2D
	_main.add_child(node)
	return node


func _assert_live_body(actor: Node2D, label: String) -> AnimatedSprite2D:
	var body := actor.get_node_or_null("FullFrameBody") as AnimatedSprite2D
	if body == null or body.sprite_frames == null or not body.visible:
		_fail("%s spawned without a live FullFrameBody (static fallback) under the combat guard." % label)
		return null
	var frames_path := body.sprite_frames.resource_path
	if not FullFrameAnimationRegistry.is_resident(frames_path):
		_fail("%s plays %s which is not in the resident set." % [label, frames_path])
	return body


# --- 4. miss fallback ---------------------------------------------------------------

func _check_miss_fallback() -> void:
	var kind: Dictionary = _main.get("PROGRESSION_DATA").mini_elite_kinds()[0]
	var kind_id := str(kind.get("id", ""))
	var frames_path := FullFrameAnimationRegistry.frames_path_for("elite", kind_id)
	# Drop just this pack from the resident set while the fight is running.
	var keep: Array = FullFrameAnimationRegistry._prefetched_frames.keys()
	keep.erase(frames_path)
	FullFrameAnimationRegistry.retain_only(keep)
	if FullFrameAnimationRegistry.is_resident(frames_path):
		_fail("miss fixture: %s still resident after retain_only." % frames_path)
		return
	var count_before := FullFrameAnimationRegistry.synchronous_combat_load_count()
	var elite_scene: PackedScene = _main.combat._elite_scene_by_key(str(kind.get("scene", "")))
	var elite := elite_scene.instantiate() as Node2D
	elite.add_to_group("elite_enemies")
	_main.combat._apply_mini_elite_kind(elite, kind)
	_main.add_child(elite)
	var body := elite.get_node_or_null("FullFrameBody") as AnimatedSprite2D
	if body != null and body.visible and body.sprite_frames != null and body.sprite_frames.resource_path == frames_path:
		_fail("miss: the pack was loaded synchronously for %s during the fight." % kind_id)
	if FullFrameAnimationRegistry.synchronous_combat_load_count() <= count_before:
		_fail("miss: the synchronous-load counter did not record the miss.")
	if not (FullFrameAnimationRegistry._prefetch_queue.has(frames_path) or FullFrameAnimationRegistry._prefetch_in_flight.has(frames_path)):
		_fail("miss: the missing pack was not queued for a background load.")
	if FullFrameAnimationRegistry.deferred_owner_count() == 0:
		_fail("miss: the actor was not registered for a deferred swap.")
	# The safe fallback is the pre-full-frame visual: the static Body sprite or
	# the cutout rig enemy.gd builds from it (RigRoot) — never an empty actor.
	var static_visible := false
	for candidate_name in ["Body", "Sprite2D", "RigRoot"]:
		var static_body := elite.get_node_or_null(candidate_name) as CanvasItem
		if static_body != null and static_body.visible:
			static_visible = true
	if not static_visible:
		_fail("miss: the actor must keep a visible static body/rig while its pack loads.")
	var waited := 0
	while not FullFrameAnimationRegistry.is_resident(frames_path) and waited < 3000:
		await process_frame
		waited += 1
	if not FullFrameAnimationRegistry.is_resident(frames_path):
		_fail("miss: the queued pack never became resident.")
	else:
		body = elite.get_node_or_null("FullFrameBody") as AnimatedSprite2D
		if body == null or body.sprite_frames == null or not body.visible or body.sprite_frames.resource_path != frames_path:
			_fail("miss: the actor did not swap to its FullFrameBody after the background load landed.")
		elif str(body.get_meta("entity_id", "")) != kind_id:
			_fail("miss: the swapped body plays %s instead of %s." % [body.get_meta("entity_id", ""), kind_id])
	elite.queue_free()
	await process_frame
	FullFrameAnimationRegistry.reset_synchronous_combat_load_count()


# --- elite fights -------------------------------------------------------------------

func _seed_for_elite_scene(target: PackedScene) -> int:
	for node_seed in range(MAX_SEED_SEARCH):
		if _main.node_elite_scene(node_seed) == target:
			return node_seed
	return -1


func _check_elite_fights() -> void:
	var mini_path := FullFrameAnimationRegistry.frames_path_for("elite", str(_main.get("PROGRESSION_DATA").mini_elite_kinds()[0].get("id", "")))
	for key in ELITE_SCENE_KEYS:
		var elite_scene: PackedScene = _main.combat._elite_scene_by_key(key)
		if elite_scene == null:
			_fail("elite scene %s missing." % key)
			continue
		var node_seed := _seed_for_elite_scene(elite_scene)
		if node_seed < 0:
			_fail("no node seed resolves elite scene %s." % key)
			continue
		var elite_id := FullFrameAnimationRegistry.scene_root_string_property(elite_scene, "elite_behavior")
		var elite_path := FullFrameAnimationRegistry.frames_path_for("elite", elite_id)
		if elite_path == "":
			_fail("elite scene %s declares unregistered elite '%s'." % [key, elite_id])
			continue
		_end_combat_if_active()
		_main.set("current_node_seed", node_seed)
		_main.set("current_node_type", "elite_battle")
		_main.combat._start_combat(false, "elite")
		if not await CombatStartSupport.await_finalized(_main):
			_fail("elite fight (%s): combat start did not finalize." % elite_id)
			continue
		if not FullFrameAnimationRegistry.is_resident(elite_path):
			_fail("elite fight (%s): the node elite pack is not resident at finalize." % elite_id)
		if FullFrameAnimationRegistry.is_resident(mini_path):
			_fail("elite fight (%s): mini-elite packs must be released (they cannot roll in elite combat)." % elite_id)
		var elite := get_first_node_in_group("elite_enemies") as Node2D
		if elite == null:
			_fail("elite fight (%s): no elite spawned by _finalize_combat_start." % elite_id)
		else:
			var body := _assert_live_body(elite, "node elite %s" % elite_id)
			if body != null and str(body.get_meta("entity_id", "")) != elite_id:
				_fail("elite fight: body plays %s, expected %s." % [body.get_meta("entity_id", ""), elite_id])
		if FullFrameAnimationRegistry.synchronous_combat_load_count() != 0:
			_fail("elite fight (%s): %d synchronous loads." % [elite_id, FullFrameAnimationRegistry.synchronous_combat_load_count()])
		await process_frame


# --- boss fights -------------------------------------------------------------------

func _check_boss_fights() -> void:
	var boss_ids: Array = FullFrameAnimationRegistry.kind_entity_ids("boss")
	boss_ids.append(SECRET_BOSS_ID)
	var mini_path := FullFrameAnimationRegistry.frames_path_for("elite", str(_main.get("PROGRESSION_DATA").mini_elite_kinds()[0].get("id", "")))
	for boss_id_variant in boss_ids:
		var boss_id := str(boss_id_variant)
		var boss_path := FullFrameAnimationRegistry.frames_path_for("boss", boss_id)
		if boss_id == SECRET_BOSS_ID:
			boss_path = SECRET_BOSS_FRAMES
		_end_combat_if_active()
		_main.set("current_boss_id", boss_id)
		_main.set("current_node_type", "boss")
		_main.set("secret_boss_active", boss_id == SECRET_BOSS_ID)
		_main.combat._start_combat(true, "boss")
		if not await CombatStartSupport.await_finalized(_main):
			_fail("boss fight (%s): combat start did not finalize." % boss_id)
			continue
		if not FullFrameAnimationRegistry.is_resident(boss_path):
			_fail("boss fight (%s): boss pack %s not resident at finalize." % [boss_id, boss_path])
		if FullFrameAnimationRegistry.is_resident(mini_path):
			_fail("boss fight (%s): mini-elite packs must be released." % boss_id)
		var boss := get_first_node_in_group("bosses") as Node2D
		if boss == null:
			_fail("boss fight (%s): no boss spawned by _finalize_combat_start." % boss_id)
		else:
			var body := boss.get_node_or_null("FullFrameBody") as AnimatedSprite2D
			if body == null or body.sprite_frames == null or not body.visible:
				_fail("boss fight (%s): boss spawned without a live FullFrameBody." % boss_id)
			elif body.sprite_frames.resource_path != boss_path:
				_fail("boss fight (%s): boss plays %s, expected %s." % [boss_id, body.sprite_frames.resource_path, boss_path])
		if FullFrameAnimationRegistry.synchronous_combat_load_count() != 0:
			_fail("boss fight (%s): %d synchronous loads." % [boss_id, FullFrameAnimationRegistry.synchronous_combat_load_count()])
		await process_frame
	_main.set("secret_boss_active", false)
	_end_combat_if_active()
	if FullFrameAnimationRegistry.is_combat_guard_active():
		_fail("_end_combat must lower the combat guard.")


# --- 5. budgets ----------------------------------------------------------------------

func _roster_rgba_bytes(paths: Array) -> int:
	var total := 0
	for frames_path in paths:
		var manifest_path := str(frames_path).get_base_dir().path_join(_manifest_stem(str(frames_path)) + "_trim_manifest.json")
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if not (parsed is Dictionary):
			_fail("budget: manifest %s missing/malformed." % manifest_path)
			continue
		total += int((parsed as Dictionary).get("page_rgba_bytes", 0))
	return total


static func _manifest_stem(frames_path: String) -> String:
	var stem := frames_path.get_file().trim_suffix(".tres").trim_suffix("_spriteframes")
	return stem.trim_prefix("ally_") if frames_path.contains("/allies/") else stem


func _check_roster_budgets() -> void:
	var progression = _main.get("PROGRESSION_DATA")
	var core_bytes := _roster_rgba_bytes(FullFrameEncounterRoster.core_paths(progression, "druid"))
	if core_bytes > ROSTER_RGBA_BUDGET_BYTES:
		_fail("core roster is %.0f MiB of RGBA pages, over the %.0f MiB budget." % [core_bytes / 1048576.0, ROSTER_RGBA_BUDGET_BYTES / 1048576.0])
	var base: Array = FullFrameEncounterRoster.enemy_paths()
	base.append_array(FullFrameEncounterRoster.ally_paths_for_class(progression, "druid"))
	var base_bytes := _roster_rgba_bytes(base)
	var worst_extra := 0
	for entity_kind in ["elite", "boss"]:
		for entity_id in FullFrameAnimationRegistry.kind_entity_ids(entity_kind):
			worst_extra = maxi(worst_extra, _roster_rgba_bytes([FullFrameAnimationRegistry.frames_path_for(entity_kind, str(entity_id))]))
	worst_extra = maxi(worst_extra, _roster_rgba_bytes([SECRET_BOSS_FRAMES]))
	if base_bytes + worst_extra > ROSTER_RGBA_BUDGET_BYTES:
		_fail("worst elite/boss roster is %.0f MiB of RGBA pages, over the budget." % ((base_bytes + worst_extra) / 1048576.0))
	print("roster RGBA bytes: core %.0f MiB, enemies+allies %.0f MiB, largest single elite/boss pack %.0f MiB." % [core_bytes / 1048576.0, base_bytes / 1048576.0, worst_extra / 1048576.0])
