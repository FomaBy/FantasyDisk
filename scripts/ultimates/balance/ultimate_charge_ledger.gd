class_name UltimateChargeLedger
extends RefCounted

## FAN-1460: the stateful side of the charge economy — one ledger per player.
##
## The ledger owns everything that decides WHEN an ultimate is available:
## the accumulated charge, the per-encounter budget, the single activation gate
## and the transient active-effect flag. Charge is a run resource and survives
## battle -> map -> battle, act transitions and Continue; the transient state
## never crosses an encounter boundary.
##
## It is fed HP that was actually removed (UltimateDamageResult.applied), never
## damage attempted, so overkill and damage-taken reductions cannot inflate it.

const Budget := preload("res://scripts/ultimates/balance/ultimate_charge_budget.gd")

const SNAPSHOT_KEY := "ultimate_charge"

var charge := 0.0

var _row: Dictionary = {}
var _build_multiplier := 1.0
var _encounter_kind := Budget.ENCOUNTER_NORMAL
var _encounter_charge := 0.0
var _encounter_taken_charge := 0.0
var _encounter_activations := 0
var _ultimate_active := false


func _init(row: Dictionary = {}) -> void:
	_row = row.duplicate(true)


func fixture_row() -> Dictionary:
	return _row.duplicate(true)


## Energy is the amount invested above the class base; a neutral build is 1.0.
func set_build(invested_energy: float, ult_charge_multiplier := 1.0) -> void:
	_build_multiplier = Budget.build_multiplier(invested_energy, ult_charge_multiplier)


func build_multiplier() -> float:
	return _build_multiplier


## Start of a battle. Charge survives; the per-encounter budget, the activation
## gate and any active effect do not.
func begin_encounter(kind := Budget.ENCOUNTER_NORMAL) -> void:
	_encounter_kind = kind
	_reset_encounter_state()


func encounter_kind() -> String:
	return _encounter_kind


func encounter_charge() -> float:
	return _encounter_charge


func encounter_taken_charge() -> float:
	return _encounter_taken_charge


func encounter_activations() -> int:
	return _encounter_activations


func is_ultimate_active() -> bool:
	return _ultimate_active


func set_ultimate_active(active: bool) -> void:
	_ultimate_active = active


## Damage channel. `removed_health` is the HP the target actually lost.
## Returns the charge that was credited after every cap.
func add_removed_health(removed_health: float) -> float:
	var rate := float(_row.get("charge_per_removed_hp", 0.0))
	return _credit(maxf(removed_health, 0.0) * rate, false)


## Taken-damage channel. `removed_health` is the HP the PLAYER actually lost;
## `max_health` normalizes it so a big health pool is not a charge battery.
func add_taken_health(removed_health: float, max_health: float) -> float:
	if max_health <= 0.0:
		return 0.0
	var bars := maxf(removed_health, 0.0) / max_health
	var rate := float(_row.get("taken_charge_rate", 1.0))
	return _credit(bars * Budget.TAKEN_CHARGE_PER_HEALTH_BAR * rate, true)


func is_ready() -> bool:
	return charge >= Budget.MAX_CHARGE


func can_activate() -> bool:
	return (
		is_ready()
		and not _ultimate_active
		and _encounter_activations < Budget.MAX_ACTIVATIONS_PER_ENCOUNTER
	)


## The ONLY path that spends charge. A refused activation spends nothing.
func try_activate() -> bool:
	if not can_activate():
		return false
	_encounter_activations += 1
	charge = 0.0
	return true


## Guild Atlas `ult_start_charge`, applied once at run start. It pre-fills the
## bar, it does not raise the ceiling or bypass the per-encounter caps that
## govern every later activation.
func apply_start_charge(ratio: float) -> void:
	charge = clampf(Budget.MAX_CHARGE * clampf(ratio, 0.0, 1.0), 0.0, Budget.MAX_CHARGE)


## New run, or a class/weapon change before the run starts.
func reset_for_new_run() -> void:
	charge = 0.0
	_build_multiplier = 1.0
	_encounter_kind = Budget.ENCOUNTER_NORMAL
	_reset_encounter_state()


## Only the accumulated charge is a run resource. The active-effect flag and the
## activation gate are runtime state of one battle and are deliberately absent.
func to_snapshot() -> Dictionary:
	return {SNAPSHOT_KEY: charge}


## Restore onto the fresh player node of the next battle. A pre-FAN-1460 save
## has no key and yields 0.
func apply_snapshot(snapshot: Dictionary) -> void:
	charge = clampf(float(snapshot.get(SNAPSHOT_KEY, 0.0)), 0.0, Budget.MAX_CHARGE)
	_reset_encounter_state()


func _reset_encounter_state() -> void:
	_encounter_charge = 0.0
	_encounter_taken_charge = 0.0
	_encounter_activations = 0
	_ultimate_active = false


func _credit(amount: float, taken_channel: bool) -> float:
	# An active ultimate earns nothing: the payoff window cannot pay for itself.
	if amount <= 0.0 or _ultimate_active:
		return 0.0
	var scaled := amount * _build_multiplier
	var room := minf(
		Budget.encounter_cap(_encounter_kind) - _encounter_charge,
		Budget.MAX_CHARGE - charge
	)
	if taken_channel:
		room = minf(room, Budget.taken_channel_cap(_encounter_kind) - _encounter_taken_charge)
	var credited := clampf(scaled, 0.0, maxf(room, 0.0))
	if credited <= 0.0:
		return 0.0
	charge += credited
	_encounter_charge += credited
	if taken_channel:
		_encounter_taken_charge += credited
	return credited
