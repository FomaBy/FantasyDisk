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
const GRAVITY_WELL_TEXTURE := preload("res://assets/sprites/effects/boss_gravity_well_zone.png")
const VAMPIRIC_BITE_TEXTURE := preload("res://assets/sprites/effects/boss_vampiric_bite_zone.png")
const RIFT_ZONE_TEXTURE := preload("res://assets/sprites/effects/boss_rift_zone.png")
const BROOD_WEB_TEXTURE := preload("res://assets/sprites/effects/boss_brood_web_zone.png")
const ASH_EMBER_TEXTURE := preload("res://assets/sprites/effects/boss_ash_ember_zone.png")
const MOLTEN_PULSE_TEXTURE := preload("res://assets/sprites/effects/boss_molten_armor_pulse.png")
const BONE_PRISON_TEXTURE := preload("res://assets/sprites/effects/boss_bone_prison_zone.png")
const SUMMON_PORTAL_TEXTURE := preload("res://assets/sprites/effects/enemy_summon_portal.png")
const SHIELD_BLOCK_TEXTURE := preload("res://assets/sprites/effects/enemy_shield_block_front.png")
const REFLECT_THORNS_TEXTURE := preload("res://assets/sprites/effects/enemy_reflect_thorns_aura.png")
const COMMAND_AURA_TEXTURE := preload("res://assets/sprites/effects/enemy_command_aura_pulse.png")

# hazard_zone.png danger-ring radius in texture pixels.
const ZONE_RADIUS := 118.0
# impact_ring.png rim radius in texture pixels.
const RING_RADIUS := 104.0


static func _texture_radius(texture: Texture2D) -> float:
	return maxf(float(maxi(texture.get_width(), texture.get_height())) * 0.5, 1.0)


static func _zone_texture(parent: Node2D) -> Texture2D:
	if parent == null:
		return ZONE_TEXTURE
	match parent.name:
		"BossGravityWell":
			return GRAVITY_WELL_TEXTURE
		"BossVampiricBite":
			return VAMPIRIC_BITE_TEXTURE
		"BossRiftZone":
			if str(parent.get_meta("boss_behavior", "")).contains("bone"):
				return BONE_PRISON_TEXTURE
			return RIFT_ZONE_TEXTURE
		"BroodWebZone":
			return BROOD_WEB_TEXTURE
		"AshEmberZone":
			return ASH_EMBER_TEXTURE
		"BossMoltenArmorPulse":
			return MOLTEN_PULSE_TEXTURE
		_:
			return ZONE_TEXTURE


static func _residue_texture(parent: Node2D, kind: String) -> Texture2D:
	if kind == "poison":
		return POISON_POOL_TEXTURE
	if parent == null:
		return null
	match parent.name:
		"BossRiftZone":
			if str(parent.get_meta("boss_behavior", "")).contains("bone"):
				return BONE_PRISON_TEXTURE
			return RIFT_ZONE_TEXTURE
		"BroodWebZone":
			return BROOD_WEB_TEXTURE
		"AshEmberZone":
			return ASH_EMBER_TEXTURE
		_:
			return null


static func _aura_texture(parent: Node2D) -> Texture2D:
	var mechanics: Array = parent.get_meta("unique_mechanics", []) as Array if parent != null else []
	if mechanics.has("reflect_thorns"):
		return REFLECT_THORNS_TEXTURE
	var elite_behavior := str(parent.get("elite_behavior")) if parent != null and parent.get("elite_behavior") != null else ""
	if elite_behavior.contains("commander") or elite_behavior.contains("marshal"):
		return COMMAND_AURA_TEXTURE
	return RING_TEXTURE


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
static func telegraph(parent: Node2D, radius: float, color: Color, windup: float, texture: Texture2D = null) -> Node2D:
	# SCRUM-790: опциональный `texture` — доставленный telegraph-PNG поверх процедурного
	# круга. null (по умолчанию) = прежнее поведение (регресс-безопасно для всех зон).
	# Передавать ТОЛЬКО радиальные/симметричные PNG (ring/rupture): zone — круговая
	# (radius + distance_to), так что направленные формы (cone/beam) исказили бы
	# геометрию урона. Текстура центрируется и масштабируется по radius как круг.
	var holder := Node2D.new()
	holder.name = "HazardTelegraph"
	holder.z_index = -1
	parent.add_child(holder)

	var zone := Sprite2D.new()
	zone.texture = texture if texture != null else _zone_texture(parent)
	zone.modulate = Color(color.r, color.g, color.b, 0.0)
	var target_scale: float = radius / _texture_radius(zone.texture)
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


## SCRUM-791: directional telegraph for cone-sector / beam-lane damage zones.
## The texture's canonical orientation is +X (apex/mouth at the `anchor` texture-
## pixel, shape extends toward +X). The sprite is pivoted so `anchor` sits at the
## parent origin and the holder is rotated by `angle`, so the art points along the
## real attack direction. FAIRNESS CONTRACT: the caller MUST pass the SAME `angle`
## (and a damage length/half-extent derived from the SAME `scale_factor`) it uses
## for the damage test — orientation of the PNG then equals the geometry of the
## damage zone. Added as a child of `parent`; freed when the hazard frees itself.
static func directional_telegraph(parent: Node2D, texture: Texture2D, anchor: Vector2, scale_factor: float, angle: float, color: Color, windup: float) -> Node2D:
	var holder := Node2D.new()
	holder.name = "HazardDirTelegraph"
	holder.z_index = -1
	holder.rotation = angle
	parent.add_child(holder)

	var zone := Sprite2D.new()
	zone.name = "DirZone"
	zone.texture = texture
	zone.centered = false
	zone.offset = -anchor  # anchor pixel sits at the holder origin (rotation pivot)
	zone.scale = Vector2.ONE * scale_factor
	zone.modulate = Color(color.r, color.g, color.b, 0.0)
	holder.add_child(zone)

	# fade in over the first part of the windup, then pulse for urgency
	var grow := holder.create_tween()
	grow.tween_property(zone, "modulate:a", 0.5, minf(windup * 0.4, 0.25))
	var pulse := holder.create_tween()
	pulse.set_loops()
	pulse.tween_property(zone, "modulate:a", 0.82, 0.30).set_delay(minf(windup * 0.4, 0.25)).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(zone, "modulate:a", 0.42, 0.30).set_trans(Tween.TRANS_SINE)
	return holder


## SCRUM-791: damage-moment flash for a directional telegraph (built by
## directional_telegraph). Brightens the zone sprite then fades it out.
static func directional_detonate(holder: Node2D, color: Color) -> void:
	if not is_instance_valid(holder) or not holder.is_inside_tree():
		return
	var zone := holder.get_node_or_null("DirZone") as Sprite2D
	if zone == null:
		return
	var tween := zone.create_tween()
	tween.tween_property(zone, "modulate", Color(color.r, color.g, color.b, 0.95), 0.06)
	tween.tween_property(zone, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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

	var residue_texture := _residue_texture(parent, kind)
	if residue_texture != null:
		var pool := Sprite2D.new()
		pool.texture = residue_texture
		pool.modulate = Color(1.0, 1.0, 1.0, 0.0)
		pool.scale = Vector2.ONE * (radius / _texture_radius(residue_texture))
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


## Small DoT/burn tick marker on an enemy: a tiny coloured spark rising off the
## target, distinct from the normal red hit flash so damage-over-time reads.
static func dot_tick(target: Node2D, color: Color) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var spark := _additive(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.85))
	spark.scale = Vector2.ONE * 0.16
	spark.z_index = 16
	spark.position = Vector2(randf_range(-7.0, 7.0), -14.0)
	target.add_child(spark)
	var tween := spark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "position", spark.position + Vector2(0.0, -16.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(spark, "scale", Vector2.ONE * 0.26, 0.4)
	tween.tween_property(spark, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(spark.queue_free)


## Friendly buff wave (e.g. commander aura): a ring + soft flash expanding once
## from the source out to `radius`. Attach to the caster so it follows/pauses.
static func aura_pulse(parent: Node2D, radius: float, color: Color) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var holder := Node2D.new()
	holder.name = "AuraPulseVfx"
	holder.z_index = -1
	parent.add_child(holder)

	var aura_texture := _aura_texture(parent)
	var glow := _additive(aura_texture, Color(color.r, color.g, color.b, 0.7))
	glow.scale = Vector2.ONE * (radius / _texture_radius(aura_texture))
	holder.add_child(glow)

	var ring := _additive(RING_TEXTURE, Color(color.r, color.g, color.b, 0.85))
	ring.scale = Vector2.ONE * (radius * 0.2 / RING_RADIUS)
	holder.add_child(ring)

	var ring2 := _additive(RING_TEXTURE, Color(color.r, color.g, color.b, 0.5))
	ring2.scale = Vector2.ONE * (radius * 0.2 / RING_RADIUS)
	holder.add_child(ring2)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * (radius / RING_RADIUS), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.45).set_delay(0.1)
	tween.tween_property(ring2, "scale", Vector2.ONE * (radius * 0.7 / RING_RADIUS), 0.42).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring2, "modulate:a", 0.0, 0.4).set_delay(0.12)
	tween.tween_property(glow, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(holder.queue_free)


## Short-lived defensive front plate used for elite/boss shield activation.
static func shield_block(parent: Node2D, color: Color) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var holder := Node2D.new()
	holder.name = "ShieldBlockVfx"
	holder.z_index = 13
	parent.add_child(holder)

	var shield := _additive(SHIELD_BLOCK_TEXTURE, Color(color.r, color.g, color.b, 0.78))
	shield.position = Vector2(0.0, -12.0)
	shield.scale = Vector2.ONE * 0.34
	holder.add_child(shield)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(shield, "scale", Vector2.ONE * 0.54, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(shield, "modulate:a", 0.0, 0.55).set_delay(0.18)
	tween.chain().tween_callback(holder.queue_free)


static func summon_portal(parent: Node2D, radius: float, color: Color) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var portal := _additive(SUMMON_PORTAL_TEXTURE, Color(color.r, color.g, color.b, 0.82))
	portal.name = "SummonPortalVfx"
	portal.z_index = 8
	portal.scale = Vector2.ONE * (radius / _texture_radius(SUMMON_PORTAL_TEXTURE))
	parent.add_child(portal)
	var tween := portal.create_tween()
	tween.set_parallel(true)
	tween.tween_property(portal, "rotation", TAU * 0.12, 0.55).set_trans(Tween.TRANS_SINE)
	tween.tween_property(portal, "modulate:a", 0.0, 0.45).set_delay(0.25)
	tween.chain().tween_callback(portal.queue_free)
