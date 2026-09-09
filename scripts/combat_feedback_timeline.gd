class_name CombatFeedbackTimeline
extends Node

## FAN-3934 full-density feedback allocation repair.
##
## One pause-aware node owns every transient combat-feedback item (damage
## numbers, crit markers, hit ticks, body-flash restores). Items are pooled and
## animated per-frame from here, replicating the exact curves, timings, colors
## and lifetimes the previous per-item node+tween trees produced:
##   damage number — position rise 0.62 s cubic-ease-out, alpha fade 0.42 s
##                   starting at 0.20 s, gone at 0.62 s;
##   crit marker   — position rise 0.48 s back-ease-out, alpha fade 0.28 s
##                   starting at 0.20 s, gone at 0.48 s;
##   hit tick      — alpha 0.40 → 0 over 0.16 s quad-ease-out, gone at 0.16 s;
##   body flash    — instant tint blend, restore over 0.16 s quad-ease-out.
## Density is unchanged: every event still spawns an item, the existing
## group-count caps see exactly the same membership, and the pool grows on
## demand — it only stops re-allocating nodes, tweens and tweeners per hit.

const HIT_FLASH_TEXTURE := preload("res://assets/sprites/effects/impact_flash.png")

const NUMBER_LIFETIME := 0.62
const NUMBER_RISE := 44.0
const NUMBER_FADE_DELAY := 0.20
const NUMBER_FADE_TIME := 0.42
const CRIT_LIFETIME := 0.48
const CRIT_RISE := 28.0
const CRIT_FADE_DELAY := 0.20
const CRIT_FADE_TIME := 0.28
const TICK_LIFETIME := 0.16
const TICK_BASE_ALPHA := 0.40
const BODY_RESTORE_TIME := 0.16

var _numbers: Array[Label] = []
var _ticks: Array[Sprite2D] = []
var _active_numbers: Array[Dictionary] = []
var _active_ticks: Array[Dictionary] = []
var _active_bodies: Array[Dictionary] = []


static func for_scene(scene: Node) -> Node:
	if scene == null or not scene.is_inside_tree():
		return null
	var existing := scene.get_node_or_null("CombatFeedbackTimeline") as CombatFeedbackTimeline
	if existing != null:
		return existing
	var timeline := CombatFeedbackTimeline.new()
	timeline.name = "CombatFeedbackTimeline"
	timeline.process_mode = Node.PROCESS_MODE_PAUSABLE
	scene.add_child(timeline)
	return timeline


func _process(delta: float) -> void:
	_step_numbers(delta)
	_step_ticks(delta)
	_step_bodies(delta)


## Damage number (and crit variant): `label_setup` receives the pooled Label so
## the caller keeps ownership of text, typography, colors and z-ordering.
func spawn_number(label_setup: Callable, start_global: Vector2, rise: float,
		lifetime: float, fade_delay: float, fade_time: float, back_ease: bool) -> void:
	var label := _acquire_number()
	if label == null:
		return
	label_setup.call(label)
	label.add_to_group("combat_feedback_labels")
	label.global_position = start_global
	label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	label.visible = true
	_active_numbers.append({
		"label": label,
		"start": start_global,
		"rise": rise,
		"lifetime": lifetime,
		"fade_delay": fade_delay,
		"fade_time": fade_time,
		"back_ease": back_ease,
		"elapsed": 0.0,
		"group": "combat_feedback_labels",
	})


## Hit tick: additive impact-flash sprite fading out in place.
func spawn_tick(start_global: Vector2, scale: Vector2, modulate: Color, group: String) -> void:
	var tick := _acquire_tick()
	if tick == null:
		return
	tick.texture = HIT_FLASH_TEXTURE
	tick.material = HazardVfx.additive_material()
	tick.modulate = modulate
	tick.scale = scale
	tick.global_position = start_global
	tick.visible = true
	tick.add_to_group(group)
	_active_ticks.append({
		"tick": tick,
		"elapsed": 0.0,
		"base_alpha": modulate.a,
		"group": group,
	})


## Body flash: the caller blends the tint immediately; the timeline restores
## the original modulate over 0.16 s (quad ease-out), matching the old tween.
func flash_body(body: CanvasItem, original_modulate: Color) -> void:
	if body == null or not is_instance_valid(body):
		return
	for record in _active_bodies:
		if (record["body"] as CanvasItem) == body:
			record["from"] = body.modulate
			record["restore"] = original_modulate
			record["elapsed"] = 0.0
			return
	_active_bodies.append({
		"body": body,
		"from": body.modulate,
		"restore": original_modulate,
		"elapsed": 0.0,
	})


func _acquire_number() -> Label:
	for label in _numbers:
		if not label.visible:
			return label
	var label := Label.new()
	label.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(label)
	_numbers.append(label)
	return label


func _acquire_tick() -> Sprite2D:
	for tick in _ticks:
		if not tick.visible:
			return tick
	var tick := Sprite2D.new()
	tick.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(tick)
	_ticks.append(tick)
	return tick


func _step_numbers(delta: float) -> void:
	var index := 0
	while index < _active_numbers.size():
		var record: Dictionary = _active_numbers[index]
		record["elapsed"] = float(record["elapsed"]) + delta
		var elapsed := float(record["elapsed"])
		var lifetime := float(record["lifetime"])
		var label := record["label"] as Label
		if label == null or not is_instance_valid(label):
			_active_numbers.remove_at(index)
			continue
		if elapsed >= lifetime:
			_release_number(label, str(record["group"]))
			_active_numbers.remove_at(index)
			continue
		var progress: float = _ease_out_back(elapsed / lifetime) if bool(record["back_ease"]) else _ease_out_cubic(elapsed / lifetime)
		label.global_position = (record["start"] as Vector2) + Vector2(0.0, -float(record["rise"]) * progress)
		var fade_elapsed := elapsed - float(record["fade_delay"])
		if fade_elapsed <= 0.0:
			label.modulate.a = 1.0
		else:
			label.modulate.a = maxf(1.0 - fade_elapsed / float(record["fade_time"]), 0.0)
		index += 1


func _step_ticks(delta: float) -> void:
	var index := 0
	while index < _active_ticks.size():
		var record: Dictionary = _active_ticks[index]
		record["elapsed"] = float(record["elapsed"]) + delta
		var elapsed := float(record["elapsed"])
		var tick := record["tick"] as Sprite2D
		if tick == null or not is_instance_valid(tick):
			_active_ticks.remove_at(index)
			continue
		if elapsed >= TICK_LIFETIME:
			_release_tick(tick, str(record["group"]))
			_active_ticks.remove_at(index)
			continue
		tick.modulate.a = float(record["base_alpha"]) * (1.0 - _ease_out_quad(elapsed / TICK_LIFETIME))
		index += 1


func _step_bodies(delta: float) -> void:
	var index := 0
	while index < _active_bodies.size():
		var record: Dictionary = _active_bodies[index]
		record["elapsed"] = float(record["elapsed"]) + delta
		var elapsed := float(record["elapsed"])
		var body := record["body"] as CanvasItem
		if body == null or not is_instance_valid(body) or elapsed >= BODY_RESTORE_TIME:
			_active_bodies.remove_at(index)
			continue
		var restore: Color = record["restore"]
		var from: Color = record["from"]
		var blend: float = _ease_out_quad(elapsed / BODY_RESTORE_TIME)
		body.modulate = from.lerp(restore, blend)
		index += 1


func _release_number(label: Label, group: String) -> void:
	label.visible = false
	label.remove_from_group(group)


func _release_tick(tick: Sprite2D, group: String) -> void:
	tick.visible = false
	tick.remove_from_group(group)


static func _ease_out_cubic(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)


static func _ease_out_quad(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - clamped) * (1.0 - clamped)


static func _ease_out_back(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var shifted := clamped - 1.0
	return 1.0 + c3 * shifted * shifted * shifted + c1 * shifted * shifted
