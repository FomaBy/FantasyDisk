extends SceneTree

## Host-primitive evidence for FAN-2044: bounded repair and safe temporary
## deploy on the shared weapon-ultimate runtime.
##
## Repair runs against the real Player adapter, so the ownership boundary that
## is being proven is the shipped one, not a fixture copy. Deploys use the real
## SentryTurret scene for the lifecycle proof and an in-memory packed fixture
## where a controllable mid-batch failure is required.
##
## Run:
## python3 tools/godot_gate.py --headless --path . \
##   --script res://tests/ultimates/controller_host_primitives_test.gd

const PlayerScene := preload("res://scenes/Player.tscn")
const SentryScene := preload("res://scenes/SentryTurret.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")
const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")

const PLAYER_CLASS := "berserk"
const PLAYER_WEAPON := "sword"
const DEPLOY_GROUP := "fixture_temporary_deploys"


## A ten-method host without the optional repair channel: the pre-FAN-2044
## contract, which must keep failing closed instead of gaining side effects.
class LegacyHost extends Node2D:
	func ultimate_host_context() -> Dictionary: return {}
	func ultimate_host_position() -> Vector2: return Vector2.ZERO
	func ultimate_host_aim(_max_range: float) -> Dictionary: return {}
	func ultimate_host_targets(_center: Vector2, _radius: float, _limit: int) -> Array: return []
	func ultimate_host_summons(_group_id: String) -> Array: return []
	func ultimate_host_apply_damage(_target: Node, _amount: float, _feedback: Dictionary) -> void: pass
	func ultimate_host_modifier(_key: String, _value: float, _op: String) -> void: pass
	func ultimate_host_effect_parent() -> Node: return self
	func ultimate_host_set_active(_active: bool) -> void: pass
	func ultimate_host_present(_event_id: String, _payload: Dictionary) -> Node: return null


## A repairable device: whoever `owner_node` points at decides foreign or owned.
class DeviceFixture extends Node2D:
	var health := 10.0
	var max_health := 30.0
	var owner_node: Node = null


## Deploy fixture whose setup consumes charges from a shared budget node, so a
## batch can be made to fail exactly at the N-th instance.
class FlakyDeploy extends Node2D:
	var owner_node: Node = null
	var tag := ""
	var ultimate_damage_sink: Callable = Callable()

	func _ready() -> void:
		add_to_group(DEPLOY_GROUP)

	func arm(budget: Node) -> bool:
		if int(budget.get("charges")) <= 0:
			return false
		budget.set("charges", int(budget.get("charges")) - 1)
		return true


class DeployBudget extends Node:
	var charges := 0


## Carries only the one declared property SentryTurret.setup() reads from its
## weapon; no weapon or class id is involved anywhere in the deploy call.
class SentryWeaponRig extends Node2D:
	var sentry_shot_magazine := 7


var _errors: Array[String] = []
var _holder: Node2D = null
var _player: Node2D = null
var _flaky_scene: PackedScene = null


func _initialize() -> void:
	_holder = Node2D.new()
	root.add_child(_holder)
	current_scene = _holder
	root.set_meta("combat_feedback", false)
	await process_frame

	_player = PlayerScene.instantiate() as Node2D
	_holder.add_child(_player)
	await process_frame
	_player.call("configure_character", PLAYER_CLASS, PLAYER_WEAPON)
	await process_frame
	_player.set_process(false)
	_player.set_physics_process(false)

	var template := Node2D.new()
	template.set_script(FlakyDeploy)
	_flaky_scene = PackedScene.new()
	_flaky_scene.pack(template)
	template.free()

	_test_repair_requires_declared_cap()
	_test_repair_hero_actual_hp_overheal_and_cap()
	_test_repair_event_idempotent()
	_test_repair_rejects_foreign_invalid_and_dead()
	_test_repair_owned_devices()
	await _test_repair_fails_closed_without_host_channel()
	await _test_deploy_supports_sentry_lifecycle()
	_test_deploy_rejects_invalid_init()
	_test_deploy_partial_failure_rolls_back()
	await _test_deploy_batch_success_and_ownership()
	_test_deploy_respects_summon_contract_cap()
	await _test_cleanup_removes_deploys_and_state_idempotently()

	_player.queue_free()
	_holder.queue_free()
	await process_frame
	_report()


# --- repair --------------------------------------------------------------------

func _test_repair_requires_declared_cap() -> void:
	var activation := _activation()
	var max_health := float(_player.get("max_health"))
	_player.set("health", max_health - 5.0)
	_check(activation.repair(_player, 5.0)["applied"] == 0.0,
		"repair without a declared cap must fail closed")
	_check(is_equal_approx(float(_player.get("health")), max_health - 5.0),
		"a refused repair must not touch hero health")
	_check(not activation.configure_repair(0.0), "a zero cap must be refused")
	_check(not activation.configure_repair(-4.0), "a negative cap must be refused")
	_check(not activation.configure_repair(NAN), "a non-finite cap must be refused")
	_check(not activation.configure_repair(INF), "an infinite cap must be refused")
	_check(activation.configure_repair(30.0), "a positive cap must be accepted")
	_check(activation.configure_repair(30.0), "re-declaring the same cap must agree")
	_check(not activation.configure_repair(50.0), "a conflicting cap must be refused")
	activation.shutdown(true)


func _test_repair_hero_actual_hp_overheal_and_cap() -> void:
	var activation := _activation()
	var max_health := float(_player.get("max_health"))
	_check(activation.configure_repair(10.0), "the repair cap must open")

	_player.set("health", max_health - 4.0)
	var overheal: Dictionary = activation.repair(_player, 6.0)
	_check(is_equal_approx(float(overheal["requested"]), 6.0),
		"repair must report the requested amount")
	_check(is_equal_approx(float(overheal["applied"]), 4.0),
		"overheal must clamp applied to the HP actually missing, got %f"
		% float(overheal["applied"]))
	_check(is_equal_approx(float(_player.get("health")), max_health),
		"repair must never push the hero past max_health")

	_player.set("health", max_health - 20.0)
	var capped: Dictionary = activation.repair(_player, 100.0)
	_check(is_equal_approx(float(capped["requested"]), 100.0)
			and is_equal_approx(float(capped["applied"]), 6.0),
		"the per-activation cap must bound repair by budget actually spent, got %f"
		% float(capped["applied"]))
	_check(activation.repair(_player, 5.0)["applied"] == 0.0,
		"an exhausted repair budget must refuse further repair")
	activation.shutdown(true)


func _test_repair_event_idempotent() -> void:
	var activation := _activation()
	var max_health := float(_player.get("max_health"))
	_check(activation.configure_repair(20.0), "the repair cap must open")
	_player.set("health", max_health - 15.0)
	_check(is_equal_approx(float(activation.repair(_player, 5.0, "pulse_1")["applied"]), 5.0),
		"the first event-qualified repair must apply")
	_check(activation.repair(_player, 5.0, "pulse_1")["applied"] == 0.0,
		"repeating the same repair event must be idempotent")
	_check(is_equal_approx(float(_player.get("health")), max_health - 10.0),
		"an idempotent repeat must not reach the hero twice")
	activation.shutdown(true)


func _test_repair_rejects_foreign_invalid_and_dead() -> void:
	var activation := _activation()
	_check(activation.configure_repair(25.0), "the repair cap must open")

	var unowned := DeviceFixture.new()
	_holder.add_child(unowned)
	_check(activation.repair(unowned, 10.0)["applied"] == 0.0,
		"a device with no owner must be refused")
	_check(is_equal_approx(unowned.health, 10.0), "a refused device must keep its HP")

	var stranger := Node2D.new()
	_holder.add_child(stranger)
	var foreign := DeviceFixture.new()
	foreign.owner_node = stranger
	_holder.add_child(foreign)
	_check(activation.repair(foreign, 10.0)["applied"] == 0.0,
		"a foreign-owned device must be refused")

	# A freed reference cannot even reach the typed `target: Node` parameter —
	# GDScript rejects it at the call site — so the reacquire-by-id idiom the
	# repository uses resolves a dead device to exactly this null case.
	_check(activation.repair(null, 10.0)["applied"] == 0.0,
		"a null (freed, reacquired-by-id) target must be refused")

	var max_health := float(_player.get("max_health"))
	_player.set("health", 0.0)
	_check(activation.repair(_player, 10.0)["applied"] == 0.0,
		"repair must never resurrect a dead hero")
	_player.set("health", max_health - 25.0)
	_check(is_equal_approx(float(activation.repair(_player, 25.0)["applied"]), 25.0),
		"refused targets must not have spent the repair budget")

	_player.set("health", max_health)
	unowned.queue_free()
	foreign.queue_free()
	stranger.queue_free()
	activation.shutdown(true)


func _test_repair_owned_devices() -> void:
	var activation := _activation()
	_check(activation.configure_repair(18.0), "the repair cap must open")

	var player_owned := DeviceFixture.new()
	player_owned.owner_node = _player
	_holder.add_child(player_owned)
	var mostly: Dictionary = activation.repair(player_owned, 15.0)
	_check(is_equal_approx(float(mostly["applied"]), 15.0),
		"a player-owned device must repair the requested HP within budget, got %f"
		% float(mostly["applied"]))
	_check(is_equal_approx(player_owned.health, 25.0),
		"device HP must reflect exactly the applied repair")

	var host_owned := DeviceFixture.new()
	host_owned.owner_node = PlayerHost.for_player(_player)
	_holder.add_child(host_owned)
	_check(is_equal_approx(float(activation.repair(host_owned, 10.0)["applied"]), 3.0),
		"an activation-owned deploy must draw the remaining repair budget")

	player_owned.queue_free()
	host_owned.queue_free()
	activation.shutdown(true)


func _test_repair_fails_closed_without_host_channel() -> void:
	var legacy := LegacyHost.new()
	_holder.add_child(legacy)
	await process_frame
	var activation := Activation.new(legacy, {}, 0.0)
	_check(activation.configure_repair(10.0), "the cap declaration itself is host-agnostic")
	var device := DeviceFixture.new()
	_holder.add_child(device)
	_check(activation.repair(device, 10.0)["applied"] == 0.0,
		"a host without the repair channel must keep repair failing closed")
	_check(is_equal_approx(device.health, 10.0), "a legacy host must produce no side effect")
	activation.shutdown(true)
	device.queue_free()
	legacy.queue_free()


# --- temporary deploy ------------------------------------------------------------

func _test_deploy_supports_sentry_lifecycle() -> void:
	var activation := _activation()
	var rig := SentryWeaponRig.new()
	_holder.add_child(rig)
	var deployed := activation.deploy_temporary(
		SentryScene, {"setup_method": "setup", "setup_args": [rig, _player]}
	)
	_check(deployed.size() == 1, "the sentry deploy must place its instance")
	if deployed.size() == 1:
		var sentry := deployed[0]
		_check(sentry.is_inside_tree(), "the deployed sentry must be live in the tree")
		_check(int(sentry.call("shots_left")) == rig.sentry_shot_magazine,
			"the generic setup call must have configured the sentry magazine, got %d"
			% int(sentry.call("shots_left")))
		_check(activation.spawned_for_tests().has(sentry),
			"the deploy must be registered with the activation")
	activation.shutdown(true)
	await process_frame
	for node in deployed:
		_check(not is_instance_valid(node), "shutdown must free the temporary sentry")
	rig.queue_free()


func _test_deploy_rejects_invalid_init() -> void:
	var activation := _activation()
	var budget := DeployBudget.new()
	_holder.add_child(budget)

	_check(activation.deploy_temporary(null).is_empty(), "a missing scene must fail closed")
	_check(activation.deploy_temporary(_flaky_scene, {}, 0).is_empty(),
		"a non-positive count must fail closed")
	_check(activation.deploy_temporary(_flaky_scene, {"bogus": 1}).is_empty(),
		"an unknown init key must fail closed")
	_check(activation.deploy_temporary(_flaky_scene, {"properties": 5}).is_empty(),
		"a malformed init value must fail closed")
	_check(activation.deploy_temporary(
			_flaky_scene, {"properties": {"no_such_property": 1.0}}
		).is_empty(),
		"an undeclared property must fail the deploy")
	_check(activation.deploy_temporary(_flaky_scene, {"setup_method": "missing"}).is_empty(),
		"a missing setup method must fail the deploy")
	_check(activation.deploy_temporary(
			_flaky_scene, {"setup_method": "arm", "setup_args": [budget]}
		).is_empty(),
		"a setup that reports failure must fail the deploy")
	_check(get_nodes_in_group(DEPLOY_GROUP).is_empty(),
		"no rejected deploy may leave an instance in the world")
	_check(activation.spawned_for_tests().is_empty(),
		"no rejected deploy may be registered with the activation")
	budget.queue_free()
	activation.shutdown(true)


func _test_deploy_partial_failure_rolls_back() -> void:
	var activation := _activation()
	var budget := DeployBudget.new()
	budget.charges = 2
	_holder.add_child(budget)
	var deployed := activation.deploy_temporary(
		_flaky_scene, {"setup_method": "arm", "setup_args": [budget]}, 3
	)
	_check(deployed.is_empty(), "a batch failing on its third instance must return nothing")
	_check(budget.charges == 0,
		"two instances must actually have initialized before the rollback, got %d left"
		% budget.charges)
	_check(get_nodes_in_group(DEPLOY_GROUP).is_empty(),
		"a rolled-back batch must leave no orphan node")
	_check(activation.spawned_for_tests().is_empty(),
		"a rolled-back batch must leave no registration")
	budget.queue_free()
	activation.shutdown(true)


func _test_deploy_batch_success_and_ownership() -> void:
	var activation := _activation()
	var budget := DeployBudget.new()
	budget.charges = 3
	_holder.add_child(budget)
	var deployed := activation.deploy_temporary(_flaky_scene, {
		"properties": {"tag": "crossfire"},
		"setup_method": "arm",
		"setup_args": [budget],
	}, 3)
	_check(deployed.size() == 3, "a fully valid batch must place every instance")
	var adapter := PlayerHost.for_player(_player)
	for node in deployed:
		_check(node.is_inside_tree(), "every deployed instance must be live in the tree")
		_check(node.get("owner_node") == adapter, "every deploy must attribute back to the host")
		_check(str(node.get("tag")) == "crossfire", "declared properties must reach each instance")
		_check((node.get("ultimate_damage_sink") as Callable).is_valid(),
			"every deploy must be bound to the activation damage ledger")
		_check(activation.spawned_for_tests().has(node),
			"every deploy must be registered with the activation")
	activation.shutdown(true)
	await process_frame
	_check(get_nodes_in_group(DEPLOY_GROUP).is_empty(),
		"shutdown must free the whole deployed batch")
	budget.queue_free()


func _test_deploy_respects_summon_contract_cap() -> void:
	var activation := _activation()
	_check(activation.configure_summon_interaction("fixture_devices", 2, [], {}),
		"the summon interaction contract must open")
	_check(activation.deploy_temporary(_flaky_scene, {}, 3).is_empty(),
		"a batch beyond the declared temporary cap must fail closed")
	_check(activation.deploy_temporary(_flaky_scene, {}, 2).size() == 2,
		"a batch within the declared temporary cap must deploy")
	_check(activation.deploy_temporary(_flaky_scene, {}, 1).is_empty(),
		"the cap must count already-live spawns")
	activation.shutdown(true)


func _test_cleanup_removes_deploys_and_state_idempotently() -> void:
	var permanent := DeviceFixture.new()
	permanent.owner_node = _player
	_holder.add_child(permanent)

	var activation := _activation()
	_check(activation.configure_repair(10.0), "the repair cap must open")
	var deployed := activation.deploy_temporary(_flaky_scene, {}, 2)
	_check(deployed.size() == 2, "the cleanup fixture must be holding live deploys")
	var run_modifiers: Dictionary = _player.get("run_modifiers")
	var absorb_before := float(run_modifiers.get("absorb_flat", 0.0))
	activation.apply_modifier("absorb_flat", 7.0)
	_check(is_equal_approx(float(run_modifiers.get("absorb_flat", 0.0)), absorb_before + 7.0),
		"the cleanup fixture must register a non-zero real Player modifier")

	activation.shutdown(true)
	await process_frame
	for node in deployed:
		_check(not is_instance_valid(node), "cleanup must free every temporary deploy")
	_check(is_instance_valid(permanent),
		"cleanup must not touch a permanent player-owned device")
	_check(activation.repair(_player, 5.0)["applied"] == 0.0,
		"repair state must not survive cleanup")
	_check(not activation.configure_repair(10.0),
		"a finished activation must refuse a new repair cap")
	_check(activation.deploy_temporary(_flaky_scene).is_empty(),
		"a finished activation must refuse new deploys")
	var absorb_after_first_shutdown := float(run_modifiers.get("absorb_flat", 0.0))
	_check(is_equal_approx(absorb_after_first_shutdown, absorb_before),
		"cleanup must roll the real Player modifier back to its baseline")
	activation.shutdown(true)
	var absorb_after_second_shutdown := float(run_modifiers.get("absorb_flat", 0.0))
	_check(is_equal_approx(absorb_after_second_shutdown, absorb_after_first_shutdown)
			and is_equal_approx(absorb_after_second_shutdown, absorb_before),
		"cleanup negative control: a second teardown must not roll the real modifier back twice")
	_check(get_nodes_in_group(DEPLOY_GROUP).is_empty(),
		"repeated cleanup must be idempotent and leave no orphan")
	permanent.queue_free()


# --- fixture plumbing --------------------------------------------------------

func _activation() -> Activation:
	return Activation.new(PlayerHost.for_player(_player), {}, 0.0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _report() -> void:
	if _errors.is_empty():
		print("controller_host_primitives_test: PASS")
		quit(0)
		return
	for error in _errors:
		push_error("controller_host_primitives_test: %s" % error)
	print("controller_host_primitives_test: FAIL (%d)" % _errors.size())
	quit(1)
