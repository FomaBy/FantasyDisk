extends SceneTree
## FAN-4007: real route, level-up pick/defer, pause, HUD lifetime and wave scaling.
## Run through godot_gate with an isolated profile and --fixed-fps 60.

const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const FEATURE := preload("res://scripts/encounters/features/contracts/next_phase_contract_feature.gd")
const ENEMY := preload("res://scenes/Enemy.tscn")

var errors: Array[String] = []
var completed := 0


func _initialize() -> void:
	var scratch := OS.get_environment("PROBE_SCRATCH")
	if scratch.is_empty() or not OS.get_user_data_dir().begins_with(scratch + "/"):
		push_error("contract-lifetime: isolated PROBE_SCRATCH profile required")
		quit(1)
		return
	print("contract-lifetime user data: ", OS.get_user_data_dir())
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		push_error("contract-lifetime timeout after %d completed checks" % completed)
		quit(2)
	)
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(3)
	main.force_skip_lore_intro = true
	main.ui._show_character_select()
	main.selected_character_id = "berserk"
	main.selected_weapon_id = str(main.PROGRESSION_DATA.weapon_ids("berserk")[0])
	main.begin_new_run_session()
	var position := CONFIG.slice_route_position(main.route_nodes, main.current_act)
	_expect(not position.is_empty(), "generated route must contain the special battle")
	if not position.is_empty():
		var row := int(position["row"])
		var branch := int(position["branch"])
		main.route_stage = row
		main.route_selected_indices = []
		for index in range(row):
			main.route_selected_indices.append(0)
		main.route._activate_route_node(row, branch, main.route_nodes[row][branch])
		var deadline := Time.get_ticks_msec() + 120000
		while not main.combat._combat_start_finalized and Time.get_ticks_msec() < deadline:
			await process_frame
		_expect(main.combat._combat_start_finalized, "real route combat must finish loading")
		if main.combat._combat_start_finalized:
			await _check_live_chain(main)
	main._clear_all_game_pauses()
	main.queue_free()
	await _frames(3)
	_expect(completed == 5, "all five lifetime checks must finish (%d/5)" % completed)
	for error in errors:
		push_error("contract-lifetime: " + error)
	if errors.is_empty():
		print("FAN-4007 contract offer lifetime and real-wave scaling passed.")
	quit(0 if errors.is_empty() else 1)


func _check_live_chain(main: Node) -> void:
	# Keep production feature/UI flows, with combat inputs and time controlled.
	main.set_process(false)
	main.current_player.debug_godmode = true
	main.current_player.process_mode = Node.PROCESS_MODE_DISABLED
	main.combat._encounters.shutdown(false)
	main.combat._encounters.begin(main, main.combat)
	var director: Node = main.combat._encounters.debug_director()
	_expect(director != null, "special battle must create its production director")
	if director == null:
		return
	director.set_process(false)
	for index in range(4):
		main.combat._spawn_random_enemy(ENEMY, main.ARENA_CENTER + Vector2(500 + index * 40, 0), true)
	for enemy in get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	print("contract-lifetime initial phase: ", director.planned_beat_id(), "/", director.state(), " enemies=", get_nodes_in_group("enemies").size())
	_trigger_planned(director)
	print("contract-lifetime triggered phase: ", director.planned_beat_id(), "/", director.state())
	var marked = director.debug_feature()
	var marked_label: Label = marked.debug_hud_label()
	await _level_up(main, false)
	_expect(is_instance_valid(marked_label) and marked_label.is_visible_in_tree() \
		and main.hud_layer.is_ancestor_of(marked_label), "marked-target label must survive level-up pick")
	await _capture("marked_after_pick")
	marked.debug_target().take_damage(999999.0)
	director._process(0.01)
	_trigger_planned(director)
	var captain = director.debug_feature()
	var captain_label: Label = captain.debug_hud_label()
	await _level_up(main, true)
	_expect(is_instance_valid(captain_label) and captain_label.is_visible_in_tree() \
		and main.hud_layer.is_ancestor_of(captain_label), "captain label must survive level-up defer")
	await _capture("captain_after_defer")
	captain.debug_captain().take_damage(999999.0)
	director._process(0.01)
	_trigger_planned(director)
	completed += 1

	var feature = director.debug_feature()
	var offer: Control = feature.debug_offer()
	_expect(is_instance_valid(offer), "contract offer must follow the captain phase")
	if not is_instance_valid(offer):
		return
	var remaining: float = offer.debug_remaining()
	main.push_pause("contract_test")
	# Headless runs exercise all 840 frames. Visual capture avoids repeating the
	# long wait in a window which macOS can throttle when it is not foreground.
	if OS.get_environment("FSD_CONTRACT_CAPTURE") == "1":
		offer._process(14.0)
		await _frames(2)
	else:
		await _frames(840)
	_expect(is_instance_valid(offer) and not feature.is_resolved(), "14 paused seconds must not decline the offer")
	if is_instance_valid(offer):
		_expect(is_equal_approx(remaining, offer.debug_remaining()), "paused countdown must stay exactly unchanged")
	main.pop_pause("contract_test")
	completed += 1

	for defer_choice in [true, false]:
		if not is_instance_valid(offer):
			_expect(false, "offer must survive both level-up exits")
			break
		remaining = offer.debug_remaining()
		var offer_rect := offer.get_global_rect()
		await _level_up(main, defer_choice)
		_expect(is_instance_valid(offer) and not offer.is_queued_for_deletion(), "level-up must retain the same offer instance")
		if is_instance_valid(offer):
			_expect(main.hud_layer.is_ancestor_of(offer) and offer.is_visible_in_tree(), "offer must be on the rebuilt HUD")
			_expect(absf(remaining - offer.debug_remaining()) < 0.1, "level-up must preserve remaining offer time")
			_expect(offer.get_global_rect().is_equal_approx(offer_rect), "HUD transfer must preserve offer placement")
			_expect((offer.get_node("DeclineButton") as Button).has_focus(), "HUD transfer must restore safe keyboard focus")
	await _capture("offer_after_pick_and_defer")
	if is_instance_valid(offer):
		# Verify the existing buttons still decide while paused; only time freezes.
		main.push_pause("contract_test")
		(offer.get_node("DeclineButton") as Button).pressed.emit()
		main.pop_pause("contract_test")
	director._process(0.01)
	_trigger_planned(director)
	_expect(director.planned_beat_id() == "reward_carrier" and director.state() == "active",
		"contract decision after level-up must allow the carrier phase to run")
	var carrier = director.debug_feature().debug_carrier()
	if is_instance_valid(carrier):
		carrier.emit_signal("died", carrier)
	director._process(0.01)
	_trigger_planned(director)
	_expect(director.planned_beat_id() == "normal_early_clear" and director.state() == "active",
		"early clear must still follow the carrier")
	director.shutdown(false)
	completed += 1
	await _check_scaling(main)
	await _check_lost_offer(main)


func _level_up(main: Node, defer_choice: bool) -> void:
	main.pending_level_ups = 1
	main.level_up_offer = []
	main.ui._open_pending_level_up()
	await _frames(2)
	_expect(paused, "real level-up screen must pause gameplay")
	await _frames(2 if OS.get_environment("FSD_CONTRACT_CAPTURE") == "1" else 180)
	var button: Button = main.find_child("LevelUpLaterButton" if defer_choice else "LevelUpRewardButton0", true, false)
	_expect(button != null, "real level-up exit button must exist")
	if button != null:
		button.pressed.emit()
	await _frames(2)
	_expect(not paused, "level-up exit must resume gameplay")


func _check_scaling(main: Node) -> void:
	var original_stage: int = main.route_stage
	var original_ascension: int = main.selected_ascension_level
	var original_wave: int = main.spawn_wave_index
	var original_state: Dictionary = main.encounter_feature_state.duplicate(true)
	var count := 0
	for stage in [0, 1, 4, 8, 16]:
		for ascension in range(6):
			for wave in [0, 8]:
				main.route_stage = stage
				main.selected_ascension_level = ascension
				main.spawn_wave_index = wave
				main.encounter_feature_state = CONFIG.empty_act_state(main.current_act)
				var context := CONTEXT.new()
				context.game = main
				context.combat = main.combat
				context.route_scaling_stage = main.route_scaling_stage()
				var ordinary: Node2D = main.combat._spawn_random_enemy(ENEMY, main.ARENA_CENTER + Vector2(600, 0), true)
				var feature := FEATURE.new()
				feature.on_trigger(context, _definition())
				feature.debug_offer().debug_accept()
				var enemies := feature.debug_risk_enemies()
				_expect(enemies.size() >= 2, "scaling case must produce risk enemies")
				for enemy in enemies:
					_expect(is_equal_approx(enemy.max_health, ordinary.max_health * 1.35) \
						and is_equal_approx(enemy.health, enemy.max_health) \
						and is_equal_approx(enemy.contact_damage, ordinary.contact_damage * 1.35),
						"risk strength must match ordinary * 1.35 at stage %d ascension %d wave %d" % [stage, ascension, wave])
					_expect(enemy.reward_xp == 0 and enemy.reward_money == 0, "scaled risk must keep zero drops")
				feature.resolve(context, "test_cleanup")
				ordinary.queue_free()
				await _frames(1)
				count += 1
	main.route_stage = original_stage
	main.selected_ascension_level = original_ascension
	main.spawn_wave_index = original_wave
	main.encounter_feature_state = original_state
	_expect(count == 60, "all 60 real-scaler cases must finish")
	print("contract-lifetime scaling cases: ", count)
	completed += 1


func _check_lost_offer(main: Node) -> void:
	for detach in [false, true]:
		main.encounter_feature_state = CONFIG.empty_act_state(main.current_act)
		var context := CONTEXT.new()
		context.game = main
		context.combat = main.combat
		var feature := FEATURE.new()
		feature.on_trigger(context, _definition())
		var offer := feature.debug_offer()
		if detach:
			offer.get_parent().remove_child(offer)
		else:
			offer.queue_free()
		await _frames(2)
		feature.on_tick(context, 0.01)
		var outcome := feature.resolve(context, "test_cleanup")
		_expect(feature.is_resolved() and str(outcome.get("reason", "")) == "offer_lost" \
			and context.act_feature_state("next_phase_contract").get("decision") == "declined",
			"freed or detached offer must explicitly decline and unblock the feature")
		await _frames(1)
	main.encounter_feature_state = CONFIG.empty_act_state(main.current_act)
	completed += 1


func _definition() -> Dictionary:
	for entry in CONFIG.all_features():
		if str(entry.get("id", "")) == "next_phase_contract":
			return entry
	return {}


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _trigger_planned(director: Node) -> void:
	# Route seeds vary phase trigger times; advance to this phase's actual plan.
	director._process(maxf(director.planned_trigger_at() - director.elapsed_seconds(), 0.0) + 0.01)


func _capture(label: String) -> void:
	if OS.get_environment("FSD_CONTRACT_CAPTURE") != "1" or DisplayServer.get_name() == "headless":
		return
	# A paused or occluded window may not schedule another draw by itself.
	RenderingServer.force_draw()
	var directory := OS.get_environment("FSD_CONTRACT_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	_expect(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK,
		"windowed capture must be saved")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
