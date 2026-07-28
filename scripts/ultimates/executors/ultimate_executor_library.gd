class_name UltimateExecutorLibrary
extends RefCounted

## Strategy lookup for the executor families.
##
## The declaration's `executor.strategy_id` selects the family; nothing here or
## below it may branch on a class or a weapon.

const Activation := preload("res://scripts/ultimates/controller/ultimate_activation.gd")
const BurstExecutor := preload("res://scripts/ultimates/executors/ultimate_burst_executor.gd")
const AimedSequenceExecutor := preload(
	"res://scripts/ultimates/executors/ultimate_aimed_sequence_executor.gd"
)
const TimedModifierExecutor := preload(
	"res://scripts/ultimates/executors/ultimate_timed_modifier_executor.gd"
)
const StatusZoneExecutor := preload(
	"res://scripts/ultimates/executors/ultimate_status_zone_executor.gd"
)
const ControlExecutor := preload("res://scripts/ultimates/executors/ultimate_control_executor.gd")
const DeploySummonExecutor := preload(
	"res://scripts/ultimates/executors/ultimate_deploy_summon_executor.gd"
)
const ChainedProjectileExecutor := preload(
	"res://scripts/ultimates/executors/ultimate_chained_projectile_executor.gd"
)

const EXECUTORS := {
	BurstExecutor.STRATEGY_ID: BurstExecutor,
	AimedSequenceExecutor.STRATEGY_ID: AimedSequenceExecutor,
	TimedModifierExecutor.STRATEGY_ID: TimedModifierExecutor,
	StatusZoneExecutor.STRATEGY_ID: StatusZoneExecutor,
	ControlExecutor.STRATEGY_ID: ControlExecutor,
	DeploySummonExecutor.STRATEGY_ID: DeploySummonExecutor,
	ChainedProjectileExecutor.STRATEGY_ID: ChainedProjectileExecutor,
}


static func has_strategy(strategy_id: String) -> bool:
	return EXECUTORS.has(strategy_id)


static func strategy_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in EXECUTORS.keys():
		ids.append(str(raw_id))
	ids.sort()
	return ids


## Returns how long the activation stays live, which the controller only uses
## for families that schedule nothing themselves; 0.0 means it finished
## instantly. A family that creates its own tween expresses the whole cast
## length in that tween, and the controller completes the cast right after it.
static func execute(strategy_id: String, activation: Activation) -> float:
	if not EXECUTORS.has(strategy_id):
		return 0.0
	return float(EXECUTORS[strategy_id].execute(activation))
