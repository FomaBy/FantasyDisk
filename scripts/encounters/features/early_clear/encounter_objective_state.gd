extends RefCounted
## Objective state for the isolated normal-battle early-clear pack.

var _minimum_elapsed := 0.0
var _quota_kills := 0
var _captain_required := false
var _elapsed := 0.0
var _kills := 0
var _captain_complete := false


func configure(minimum_elapsed: float, quota_kills: int, captain_required: bool) -> void:
	_minimum_elapsed = maxf(minimum_elapsed, 0.0)
	_quota_kills = maxi(quota_kills, 0)
	_captain_required = captain_required


func advance(elapsed: float) -> void:
	_elapsed = maxf(elapsed, 0.0)


func record_kills(kills: int) -> void:
	_kills = maxi(kills, 0)


func mark_captain_complete() -> void:
	_captain_complete = true


func is_ready() -> bool:
	return _elapsed >= _minimum_elapsed and _kills >= _quota_kills and mandatory_objective_complete()


func mandatory_objective_complete() -> bool:
	return not _captain_required or _captain_complete


func snapshot() -> Dictionary:
	return {
		"elapsed": _elapsed,
		"kills": _kills,
		"minimum_elapsed": _minimum_elapsed,
		"quota_kills": _quota_kills,
		"captain_complete": _captain_complete,
		"mandatory_objective_complete": mandatory_objective_complete(),
	}
