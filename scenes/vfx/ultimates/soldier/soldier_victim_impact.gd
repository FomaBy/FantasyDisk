extends Node2D

## Shared driver of the three Soldier ultimate scenes.
##
## Every beat that names victims plays the weapon's victim-impact flipbook
## through the shared UltimateVictimImpactPlayer. FAN-3941 adds the grenade
## payoff: the executor detonates its seven grenades at 4.7-6.5 s and burns
## the crater to 8.4 s, after the authored 3.5 s timeline has ended, and until
## this card no beat drew that. The `.detonate` and `.crater` beats now carry
## the real blast/crater position and radius, and this script draws them with
## the scene's existing ChainBlast ring, FireColumn and seeded grenade props:
## no node is allocated, every tween is tracked, and finish/exit reset the
## nodes so pause, cancel, death and node end leave nothing behind. Scenes
## without those nodes (rifle, bayonet) ignore the payoff beats.

const ImpactPlayer := preload("res://scripts/ultimates/presentation/victim_impact_player.gd")

const DETONATE_SUFFIX := ".detonate"
const CRATER_SUFFIX := ".crater"
const BLAST_NODE := "ChainBlast"
const CRATER_NODE := "FireColumn"
## The seeded props, consumed in detonation order as the outside-in chain runs.
const GRENADE_NODES: Array[String] = [
	"GrenadeOne", "GrenadeTwo", "GrenadeThree", "GrenadeFour", "GrenadeFive", "GrenadeSix", "GrenadeSeven",
]
## Authored radius of the ChainBlast ring polygon, so a beat radius scales it.
const BLAST_RING_RADIUS := 218.0
## One blast ring pulse fits inside the executor's 0.3 s chain interval, so
## consecutive blasts never overlap on the single ring node.
const BLAST_SECONDS := 0.28
const BLAST_START_SCALE := 0.35
const CRATER_RISE_SECONDS := 0.25
const CRATER_PULSE_SECONDS := 0.2
const CRATER_FADE_SECONDS := 0.5
const CRATER_RING_ALPHA := 0.45
const CRATER_PULSE_ALPHA := 0.6

@export var victim_frames: SpriteFrames

var _impacts: Node2D = null
var _impacts_started := false
var _payoff_tweens: Array[Tween] = []
var _detonations := 0


func present(event_id: String, payload: Dictionary) -> void:
	# Payoff first: an explosion over an empty patch of arena is still an
	# explosion, so it must not depend on the victim list below.
	_present_payoff(event_id, payload)
	var raw_victims: Variant = payload.get("victims")
	if not raw_victims is Array or (raw_victims as Array).is_empty() or victim_frames == null:
		return
	if _impacts == null or not is_instance_valid(_impacts):
		_impacts = ImpactPlayer.new()
		add_child(_impacts)
		_impacts_started = false
	if _impacts_started:
		_impacts.enqueue(raw_victims as Array, global_position)
	else:
		_impacts.play(victim_frames, raw_victims as Array, global_position)
		_impacts_started = true


func finish(_reason: String) -> void:
	if _impacts != null and is_instance_valid(_impacts):
		_impacts.finish()
	_reset_payoff()


func _exit_tree() -> void:
	_impacts = null
	_impacts_started = false
	_reset_payoff()


## Live payoff state, so a gate can read what the scene is drawing.
func payoff_snapshot() -> Dictionary:
	var ring := get_node_or_null(BLAST_NODE) as CanvasItem
	var column := get_node_or_null(CRATER_NODE) as CanvasItem
	return {
		"detonations": _detonations,
		"blast_alpha": ring.modulate.a if ring != null else 0.0,
		"blast_position": to_global((ring as Node2D).position) if ring != null else Vector2.ZERO,
		"crater_alpha": column.modulate.a if column != null else 0.0,
		"crater_position": to_global((column as Node2D).position) if column != null else Vector2.ZERO,
		"live_tweens": _live_tween_count(),
	}


func _present_payoff(event_id: String, payload: Dictionary) -> void:
	if event_id.ends_with(DETONATE_SUFFIX):
		_present_blast(payload)
	elif event_id.ends_with(CRATER_SUFFIX):
		_present_crater(payload)


## One blast ring at the executor's real blast position, scaled to its real
## radius, plus the next seeded prop burning away.
func _present_blast(payload: Dictionary) -> void:
	var ring := get_node_or_null(BLAST_NODE) as Node2D
	if ring == null:
		return
	var center: Variant = payload.get("position")
	var radius := float(payload.get("radius", BLAST_RING_RADIUS))
	ring.position = to_local(center as Vector2) if center is Vector2 else Vector2.ZERO
	var target_scale := Vector2.ONE * maxf(radius, 1.0) / BLAST_RING_RADIUS
	ring.scale = target_scale * BLAST_START_SCALE
	ring.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween := _payoff_tween()
	if tween == null:
		return
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", target_scale, BLAST_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, BLAST_SECONDS * 0.65).set_delay(BLAST_SECONDS * 0.35)
	if _detonations < GRENADE_NODES.size():
		var prop := get_node_or_null(GRENADE_NODES[_detonations]) as CanvasItem
		if prop != null:
			tween.tween_property(prop, "modulate:a", 0.0, BLAST_SECONDS)
	_detonations += 1


## The burning crater: the fire column rises at the crater centre on the first
## tick, pulses on each tick and burns out after the last one; the ring marks
## the crater radius while it burns.
func _present_crater(payload: Dictionary) -> void:
	var column := get_node_or_null(CRATER_NODE) as Node2D
	var ring := get_node_or_null(BLAST_NODE) as Node2D
	if column == null:
		return
	var center: Variant = payload.get("position")
	var local := to_local(center as Vector2) if center is Vector2 else Vector2.ZERO
	var tick := int(payload.get("tick", 0))
	var ticks := maxi(int(payload.get("ticks", 1)), 1)
	var tween := _payoff_tween()
	if tween == null:
		return
	tween.set_parallel(true)
	if tick == 0:
		column.position = local
		column.scale = Vector2.ONE * 0.1
		column.modulate = Color(1.0, 1.0, 1.0, 0.0)
		tween.tween_property(column, "scale", Vector2.ONE, CRATER_RISE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(column, "modulate:a", 1.0, CRATER_RISE_SECONDS)
		if ring != null:
			ring.position = local
			ring.scale = Vector2.ONE * maxf(float(payload.get("radius", BLAST_RING_RADIUS)), 1.0) / BLAST_RING_RADIUS
			ring.modulate = Color(1.0, 1.0, 1.0, 0.0)
			tween.tween_property(ring, "modulate:a", CRATER_RING_ALPHA, CRATER_RISE_SECONDS)
	else:
		tween.tween_property(column, "modulate:a", CRATER_PULSE_ALPHA, CRATER_PULSE_SECONDS * 0.5)
		tween.chain().tween_property(column, "modulate:a", 1.0, CRATER_PULSE_SECONDS * 0.5)
	if tick >= ticks - 1:
		var fade := _payoff_tween()
		if fade == null:
			return
		fade.set_parallel(true)
		fade.tween_property(column, "scale", Vector2.ONE * 1.15, CRATER_FADE_SECONDS).set_delay(CRATER_PULSE_SECONDS)
		fade.tween_property(column, "modulate:a", 0.0, CRATER_FADE_SECONDS).set_delay(CRATER_PULSE_SECONDS)
		if ring != null:
			fade.tween_property(ring, "modulate:a", 0.0, CRATER_FADE_SECONDS).set_delay(CRATER_PULSE_SECONDS)


func _payoff_tween() -> Tween:
	if not is_inside_tree():
		return null
	var tween := create_tween()
	_payoff_tweens.append(tween)
	return tween


func _live_tween_count() -> int:
	var live := 0
	for tween in _payoff_tweens:
		if tween != null and tween.is_valid() and tween.is_running():
			live += 1
	return live


## Kill every payoff tween and put the nodes back to their authored idle state,
## so nothing animates or calls back after finish, cancel, death or exit.
func _reset_payoff() -> void:
	for tween in _payoff_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_payoff_tweens.clear()
	_detonations = 0
	for node_name in [BLAST_NODE, CRATER_NODE]:
		var node := get_node_or_null(node_name) as CanvasItem
		if node != null:
			node.modulate = Color(1.0, 1.0, 1.0, 0.0)
