class_name HazardVfx
extends Object

## Designed telegraph + detonation visuals for ground hazard zones (boss rift
## zone, boss disk slam, elite poison field) — replaces the bare programmatic
## Polygon2D circles. Kept separate from AttackVfx (player weapon VFX) so the
## two files do not collide. Every helper is pause-aware (node-bound tweens)
## and self-cleaning.

const ZONE_TEXTURE := preload("res://assets/sprites/effects/hazard_zone.png")
const RING_TEXTURE := preload("res://assets/sprites/effects/impact_ring.png")
const FLASH_TEXTURE := preload("res://assets/sprites/effects/impact_flash.png")
const POISON_POOL_TEXTURE := preload("res://assets/sprites/effects/poison_pool.png")

# hazard_zone.png danger-ring radius in texture pixels.
const ZONE_RADIUS := 118.0
# impact_ring.png rim radius in texture pixels.
const RING_RADIUS := 104.0


static func _additive(texture: Texture2D, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = material
	sprite.modulate = color
	return sprite


## Warning circle that grows in and pulses while the attack winds up.
## Added as a child of `parent` (the hazard node), so it inherits position and
## is freed when the hazard frees itself. Returns the telegraph node.
static func telegraph(parent: Node2D, radius: float, color: Color, windup: float) -> Node2D:
	var holder := Node2D.new()
	holder.name = "HazardTelegraph"
	holder.z_index = -1
	parent.add_child(holder)

	var zone := Sprite2D.new()
	zone.texture = ZONE_TEXTURE
	zone.modulate = Color(color.r, color.g, color.b, 0.0)
	var target_scale: float = radius / ZONE_RADIUS
	zone.scale = Vector2.ONE * target_scale * 0.7
	holder.add_child(zone)

	var rim := _additive(RING_TEXTURE, Color(color.r, color.g, color.b, 0.0))
	rim.scale = Vector2.ONE * (radius / RING_RADIUS)
	holder.add_child(rim)

	# grow + fade in over the first part of the windup
	var grow := holder.create_tween()
	grow.set_parallel(true)
	grow.tween_property(zone, "scale", Vector2.ONE * target_scale, minf(windup * 0.5, 0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(zone, "modulate:a", 0.5, minf(windup * 0.4, 0.25))
	grow.tween_property(rim, "modulate:a", 0.9, minf(windup * 0.4, 0.25))
	# urgency pulse for the rest of the windup
	var pulse := holder.create_tween()
	pulse.set_loops()
	pulse.tween_property(zone, "modulate:a", 0.78, 0.32).set_delay(minf(windup * 0.4, 0.25)).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(zone, "modulate:a", 0.42, 0.32).set_trans(Tween.TRANS_SINE)
	return holder


## Detonation burst at the damage moment: expanding shockwave ring + flash, and
## for poison zones a lingering bubbling pool. `kind` in {"", "poison"}.
static func detonate(parent: Node2D, radius: float, color: Color, kind := "") -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	# clear the telegraph so it does not sit under the burst
	var tele := parent.get_node_or_null("HazardTelegraph")
	if tele != null:
		tele.queue_free()

	var burst := Node2D.new()
	burst.name = "HazardBurst"
	parent.add_child(burst)

	if kind == "poison":
		var pool := Sprite2D.new()
		pool.texture = POISON_POOL_TEXTURE
		pool.modulate = Color(1.0, 1.0, 1.0, 0.0)
		pool.scale = Vector2.ONE * (radius / 128.0)
		pool.z_index = -1
		burst.add_child(pool)
		var pool_tween := burst.create_tween()
		pool_tween.tween_property(pool, "modulate:a", 0.92, 0.12)
		pool_tween.tween_interval(0.9)
		pool_tween.tween_property(pool, "modulate:a", 0.0, 0.5)

	var ring := _additive(RING_TEXTURE, Color(color.r, color.g, color.b, 0.95))
	ring.scale = Vector2.ONE * (radius * 0.45 / RING_RADIUS)
	burst.add_child(ring)

	var flash := _additive(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.9))
	flash.scale = Vector2.ONE * (radius / 110.0)
	burst.add_child(flash)

	var tween := burst.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * (radius * 1.05 / RING_RADIUS), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3).set_delay(0.06)
	tween.tween_property(flash, "scale", flash.scale * 1.7, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.18)
