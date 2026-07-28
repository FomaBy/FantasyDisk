class_name UltimateController
extends RefCounted

## Generic ultimate runtime: one activation path for every class and weapon.
##
## The controller reads the frozen registry contract, picks the executor family
## the declaration names, and owns the cast lifetime. It never branches on a
## class or a weapon, and it never repairs a declaration.
##
## Migration bridge: a profile that is still `declared` resolves to the legacy
## class fallback, so activate() returns false and the caller keeps running its
## existing class ultimate unchanged.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const Library := preload("res://scripts/ultimates/executors/ultimate_executor_library.gd")
const Resolver := preload("res://scripts/ultimates/registry/weapon_ultimate_resolver.gd")

var _host: Node = null
var _registry = null
var _activation: Activation = null


func _init(host: Node, registry) -> void:
	_host = host
	_registry = registry


func is_active() -> bool:
	return _activation != null


## True when the cast was taken over by the generic runtime. False means the
## declaration is not executable yet and the caller owns the activation.
func activate(class_id: String, weapon_id: String) -> bool:
	if is_active() or not Activation.host_supports(_host) or not _host.is_inside_tree():
		return false
	if _registry == null or not _registry.has_method("resolution_source"):
		return false
	if str(_registry.resolution_source(class_id, weapon_id)) != Resolver.SOURCE_WEAPON_PROFILE:
		return false
	var profile: Dictionary = _registry.catalog_profile_for(class_id, weapon_id)
	var executor = profile.get("executor")
	if not executor is Dictionary:
		return false
	var strategy_id := str((executor as Dictionary).get("strategy_id", ""))
	if not Library.has_strategy(strategy_id):
		return false
	var params = (executor as Dictionary).get("params", {})
	_activation = Activation.new(
		_host,
		params if params is Dictionary else {},
		float(profile.get("total_boss_cap", 0.0))
	)
	_host.call("ultimate_host_set_active", true)
	var duration := Library.execute(strategy_id, _activation)
	# A family that scheduled its own tween owns the cast length: chaining the
	# completion onto that tween keeps teardown strictly after its last step,
	# instead of racing it with a parallel timer of nominally equal length.
	var scheduled := _activation.last_tween()
	if scheduled != null:
		scheduled.tween_callback(_complete)
		return true
	if duration <= 0.0:
		_complete()
		return true
	var lifetime := _activation.track_tween()
	if lifetime == null:
		_complete()
		return true
	lifetime.tween_interval(duration)
	lifetime.tween_callback(_complete)
	return true


func active_activation() -> Activation:
	return _activation


## Death, node end or a new run: drop the cast and everything it is still
## holding, presentation included.
func cancel() -> void:
	_shutdown(true)


func _complete() -> void:
	_shutdown(false)


func _shutdown(free_presentation: bool) -> void:
	if _activation == null:
		return
	var activation := _activation
	_activation = null
	activation.shutdown(free_presentation)
	if _host != null and is_instance_valid(_host) and _host.has_method("ultimate_host_set_active"):
		_host.call("ultimate_host_set_active", false)
