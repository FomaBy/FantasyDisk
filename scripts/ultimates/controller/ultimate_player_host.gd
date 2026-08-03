extends Node

## Narrow Player-side adapter for the generic ultimate runtime.
##
## Everything the controller and the executor families need from the Player goes
## through the ten `ultimate_host_*` methods below — plus the optional repair
## channel this adapter opts into — which is what keeps them free of class and
## weapon branches.
##
## It lives as a child of the Player rather than as methods on `player.gd`:
## the repository's monolith ratchet asks for an integration boundary to be its
## own module, and being a child also means tweens bound here follow the same
## pause rules as the Player and a leaving Player cancels its own cast without
## needing a hook for it. Only a new run — `configure_character`, which replaces
## `run_modifiers` in place — has to call `reset()` explicitly, and it must do so
## before that reset, or the modifier unwind would land on fresh defaults.

const Controller := preload("res://scripts/ultimates/controller/ultimate_controller.gd")
const Registry := preload("res://scripts/ultimates/registry/weapon_ultimate_registry.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const TargetQuery := preload("res://scripts/combat_target_query.gd")

const NODE_NAME := "UltimateHost"
# A script cannot name itself while it is being compiled as a dependency of
# `player.gd`, so the factory instantiates through the resource cache instead.
const SELF_PATH := "res://scripts/ultimates/controller/ultimate_player_host.gd"

static var _shared_registry = null

var player: Node2D = null
var _controller: Controller = null


## Read once per process. The catalog is immutable, so every Player shares it.
static func shared_registry():
	if _shared_registry == null:
		_shared_registry = Registry.new(ProgressionData.WEAPONS_BY_CLASS)
	return _shared_registry


static func for_player(player_node: Node2D) -> Node:
	var existing := player_node.get_node_or_null(NODE_NAME)
	if existing != null:
		return existing
	var host: Node = (load(SELF_PATH) as GDScript).new(player_node)
	player_node.add_child(host)
	return host


## Character change or new run: warm the catalog and drop anything still live so
## no tween, summon, deploy, VFX or transient modifier survives into the run.
static func reset(player_node: Node2D) -> void:
	shared_registry()
	var existing := player_node.get_node_or_null(NODE_NAME)
	if existing != null:
		existing.controller().cancel()


## True when the generic runtime took the cast. False means the equipped weapon
## has no ready declaration yet and the caller keeps its legacy class ultimate.
static func activate(player_node: Node2D) -> bool:
	var host := for_player(player_node)
	return host.controller().activate(
		str(player_node.get("character_id")), str(player_node.get("weapon_id"))
	)


func _init(player_node: Node2D = null) -> void:
	player = player_node
	name = NODE_NAME
	process_mode = Node.PROCESS_MODE_PAUSABLE


func controller() -> Controller:
	if _controller == null:
		_controller = Controller.new(self, shared_registry())
	return _controller


## Death, scene change and node end all remove the Player, and this child with
## it, so one hook covers every case a new run does not.
func _exit_tree() -> void:
	if _controller != null:
		_controller.cancel()


func use_registry(registry) -> void:
	if _controller != null:
		_controller.cancel()
	_controller = Controller.new(self, registry)


# --- host contract -----------------------------------------------------------

func ultimate_host_context() -> Dictionary:
	var damage_parameter := ProgressionData.damage_parameter_for(str(player.get("character_id")))
	var derived: Dictionary = player.get("derived_parameters")
	return {
		"damage": float(derived.get(damage_parameter, derived.get("damage", 10.0))),
		"multiplier": float(derived.get("ultimate_multiplier", 1.0)),
		"damage_type": "magic" if damage_parameter == "magic_damage" else "physical",
	}


func ultimate_host_position() -> Vector2:
	return player.global_position


func ultimate_host_aim(max_range: float) -> Dictionary:
	if not player.has_method("attack_aim_position") or not player.has_method("attack_aim_direction"):
		return {}
	var direction = player.call("attack_aim_direction", Vector2.RIGHT, max_range)
	var point = player.call("attack_aim_position", max_range)
	if not point is Vector2 or not direction is Vector2:
		return {}
	return {"point": point, "direction": direction}


func ultimate_host_targets(center: Vector2, radius: float, limit: int) -> Array:
	if limit > 0:
		return TargetQuery.nearest_many(player, center, radius, limit)
	return TargetQuery.in_radius(player, center, radius)


## Only explicitly player-owned members of the declared group may be borrowed
## by a summon interaction. Duplicate group entries are removed by activation.
func ultimate_host_summons(group_id: String) -> Array:
	if group_id.is_empty() or player == null or not is_instance_valid(player) \
			or player.get_tree() == null:
		return []
	var result: Array = []
	for raw_node in player.get_tree().get_nodes_in_group(group_id):
		var node := raw_node as Node
		if node != null and is_instance_valid(node) and node.get("owner_node") == player:
			result.append(node)
	return result


## Optional repair channel (`UltimateActivation.HOST_REPAIR_METHOD`): only the
## hero itself or a player-owned device — `owner_node` pointing at the Player,
## or at this host for the activation's own temporary deploys — may be
## repaired. Repair never resurrects and never exceeds max_health; the return
## value is the HP actually restored, the same clamped-delta attribution the
## damage path uses. The direct health write mirrors `_apply_regeneration`.
func ultimate_host_repair(target: Node, amount: float) -> float:
	if target == null or not is_instance_valid(target) \
			or not is_finite(amount) or amount <= 0.0 \
			or player == null or not is_instance_valid(player):
		return 0.0
	if target != player:
		var device_owner = target.get("owner_node")
		if device_owner != player and device_owner != self:
			return 0.0
	if target.get("health") == null or target.get("max_health") == null:
		return 0.0
	var before := float(target.get("health"))
	var maximum := float(target.get("max_health"))
	if before <= 0.0 or maximum <= 0.0:
		return 0.0
	var after := minf(before + amount, maximum)
	target.set("health", after)
	return maxf(after - before, 0.0)


## Routed through the Player so generic ultimate damage keeps the same
## take_damage arity contract as every other player-owned damage source.
func ultimate_host_apply_damage(target: Node, amount: float, feedback: Dictionary) -> void:
	player.call("_apply_player_damage", target, amount, feedback)


func ultimate_host_modifier(key: String, value: float, op: String) -> void:
	var multiplicative := op == "mul"
	var run_modifiers: Dictionary = player.get("run_modifiers")
	var current := float(run_modifiers.get(key, 1.0 if multiplicative else 0.0))
	run_modifiers[key] = current * value if multiplicative else current + value
	player.call("_apply_stat_scaling", false, float(player.get("max_health")))


func ultimate_host_effect_parent() -> Node:
	return player.call("_vfx_parent")


func ultimate_host_set_active(active: bool) -> void:
	player.set("_ultimate_active", active)


## Presentation stays primitive on purpose: the weapon-ultimate presentation
## contract is a separate package, so this only maps the geometric shapes the
## executors describe onto the existing AttackVfx primitives.
func ultimate_host_present(_event_id: String, payload: Dictionary) -> Node:
	var parent := ultimate_host_effect_parent()
	if parent == null:
		return null
	var position: Vector2 = payload.get("position", player.global_position)
	var radius := float(payload.get("radius", 240.0))
	match str(payload.get("shape", "ring_pulse")):
		"beam":
			return AttackVfx.beam(
				parent,
				payload.get("from", player.global_position),
				payload.get("to", position),
				34.0,
				Color(0.86, 0.92, 1.0, 0.42)
			)
		"orb_burst":
			return AttackVfx.orb_burst(parent, position, radius, Color(0.62, 0.76, 1.0, 0.44))
		_:
			return AttackVfx.ring_pulse(parent, position, radius, Color(0.86, 0.92, 1.0, 0.40), false)
