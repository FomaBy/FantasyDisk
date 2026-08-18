class_name WeaponUltimatePresentationTimeline
extends RefCounted

## Testable lifecycle for presentation handles.
##
## This is not a shared pool implementation. It records the contract that the
## integration adapter must honor when it owns real animation, VFX, and audio
## handles, while allowing fixture tests to prove pause and teardown behavior.

const HEADLESS_STATE := "headless_no_op"
const READY_STATE := "ready"
const ACTIVE_STATE := "active"
const FINISHED_STATE := "finished"

var _manifest: Dictionary = {}
var _headless := false
var _paused := false
var _elapsed := 0.0
var _state := READY_STATE
var _handles := {}
var _emitted_phases := {}
var _beats: Array[Dictionary] = []


## Pass 1 for deterministic headless behavior, 0 for a fixture timeline, and
## -1 to use the runtime display-server mode.
func _init(manifest: Dictionary, headless_mode := -1) -> void:
	_manifest = manifest.duplicate(true)
	_headless = DisplayServer.get_name() == "headless" if headless_mode < 0 else headless_mode == 1


func begin(handles: Dictionary) -> Dictionary:
	if _headless:
		_state = HEADLESS_STATE
		return snapshot()
	_handles = handles.duplicate()
	_state = ACTIVE_STATE
	return snapshot()


func set_paused(value: bool) -> void:
	if _state == ACTIVE_STATE:
		_paused = value


func advance(delta_seconds: float) -> Array[Dictionary]:
	var emitted: Array[Dictionary] = []
	if _headless or _paused or _state != ACTIVE_STATE:
		return emitted
	_elapsed += maxf(delta_seconds, 0.0)
	var timing: Dictionary = _manifest.get("timing", {})
	var phases = _manifest.get("phases", [])
	if not phases is Array:
		return emitted
	for raw_phase in phases as Array:
		if not raw_phase is Dictionary:
			continue
		var phase := raw_phase as Dictionary
		var name := str(phase.get("name", ""))
		if _emitted_phases.has(name):
			continue
		if _elapsed >= float(timing.get(name, INF)):
			_emitted_phases[name] = true
			emitted.append(phase.duplicate(true))
	return emitted


func finish(reason: String) -> Dictionary:
	if _headless:
		_state = HEADLESS_STATE
		return snapshot()
	for handle in _handles.values():
		if handle != null and handle.has_method("release"):
			handle.call("release")
	_handles.clear()
	_paused = false
	_state = FINISHED_STATE
	return snapshot(reason)


## One executor beat routed into this presentation. The headless no-op timeline
## records it too: the beat reaching the presentation is the contract, drawing
## it is the authored scene's business.
func record_beat(event_id: String, payload: Dictionary) -> void:
	if _state == FINISHED_STATE or event_id.is_empty():
		return
	_beats.append({"event_id": event_id, "payload": payload.duplicate(true)})


func beats() -> Array[Dictionary]:
	return _beats.duplicate(true)


func active_handle_count() -> int:
	return _handles.size()


func elapsed_seconds() -> float:
	return _elapsed


func snapshot(reason := "") -> Dictionary:
	return {
		"state": _state,
		"headless": _headless,
		"paused": _paused,
		"elapsed_seconds": _elapsed,
		"active_handle_count": active_handle_count(),
		"reason": reason,
		"events": beats(),
	}
