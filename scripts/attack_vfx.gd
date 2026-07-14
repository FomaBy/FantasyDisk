class_name AttackVfx
extends Object

## Painted-style attack visuals shared by all player weapons.
## Every helper spawns a self-cleaning node tree (tweens free the root),
## returns the root so callers may track it in cleanup groups.

const SLASH_TEXTURE := preload("res://assets/sprites/effects/slash_arc.png")
const RING_TEXTURE := preload("res://assets/sprites/effects/impact_ring.png")
const FLASH_TEXTURE := preload("res://assets/sprites/effects/impact_flash.png")
const BEAM_TEXTURE := preload("res://assets/sprites/effects/beam_strip.png")
const WAVE_TEXTURE := preload("res://assets/sprites/effects/sound_wave.png")
const ORB_TEXTURE := preload("res://assets/sprites/effects/void_orb.png")
const NOTE_TEXTURE := preload("res://assets/sprites/effects/music_note.png")
const SKULL_TEXTURE := preload("res://assets/sprites/weapons/cursed_skull.png")
const DUST_TEXTURES := [
	preload("res://assets/sprites/effects/dust_puff_0.png"),
	preload("res://assets/sprites/effects/dust_puff_1.png"),
	preload("res://assets/sprites/effects/dust_puff_2.png"),
]

# slash_arc.png geometry: arc origin at x=40, outer rim reaches x~216.
const SLASH_ORIGIN_X := 40.0
const SLASH_REACH := 176.0
# impact_ring.png rim radius in texture pixels.
const RING_RADIUS := 104.0
# sound_wave.png arc center at x=26.
const WAVE_ORIGIN_X := 26.0
const WEAPON_SIGNATURE_PATH := "res://assets/sprites/effects/vfx_weapon_%s.png"
const INTENSITY_RGB_MULT := 0.88
const INTENSITY_SATURATION := 0.78
const INTENSITY_ALPHA_MULT := 0.62
const MAX_ATTACK_VFX_ALPHA := 0.68
const WEAPON_SIGNATURE_BODY_ALPHA := 0.60
const WEAPON_SIGNATURE_SHADOW_ALPHA := 0.34
const WEAPON_SIGNATURE_RIM_ALPHA := 0.20
const WEAPON_RELEASE_MIN_DIAMETER := 64.0
const WEAPON_RELEASE_MAX_DIAMETER := 100.0
const WEAPON_RELEASE_TRAVEL_PX := 54.0
const BEAM_VISUAL_WIDTH_MULT := 1.15
const PARTICLE_DENSITY_MULT := 0.7


static func _additive_sprite(texture: Texture2D, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = material
	sprite.modulate = _calmed_color(color)
	return sprite


static func _normal_sprite(texture: Texture2D, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.modulate = color
	return sprite


static func _calmed_color(color: Color, alpha_multiplier := 1.0) -> Color:
	var gray := (color.r + color.g + color.b) / 3.0
	return Color(
		lerpf(gray, color.r, INTENSITY_SATURATION) * INTENSITY_RGB_MULT,
		lerpf(gray, color.g, INTENSITY_SATURATION) * INTENSITY_RGB_MULT,
		lerpf(gray, color.b, INTENSITY_SATURATION) * INTENSITY_RGB_MULT,
		minf(color.a * INTENSITY_ALPHA_MULT * alpha_multiplier, MAX_ATTACK_VFX_ALPHA)
	)


static func weapon_signature(
	scene: Node,
	global_pos: Vector2,
	weapon_id: String,
	radius: float,
	color: Color,
	rotation := 0.0,
	weapon_texture: Texture2D = null,
	weapon_rotation := 0.0,
	weapon_scale := 0.58,
	weapon_offset := Vector2.ZERO
) -> Node2D:
	var texture_path := WEAPON_SIGNATURE_PATH % weapon_id
	if not ResourceLoader.exists(texture_path):
		return null
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return null

	var holder := Node2D.new()
	holder.name = "WeaponSignatureVfx_%s" % weapon_id
	holder.z_index = 9
	scene.add_child(holder)
	var direction := Vector2.RIGHT.rotated(rotation)
	holder.global_position = global_pos
	holder.rotation = rotation - 0.12
	holder.set_meta("release_motion", true)
	holder.set_meta("release_travel_px", WEAPON_RELEASE_TRAVEL_PX)
	holder.set_meta("damage_zone_overlay", false)

	var shadow := Sprite2D.new()
	shadow.name = "WeaponSignatureShadow"
	shadow.texture = texture
	shadow.modulate = Color(0.02, 0.015, 0.012, WEAPON_SIGNATURE_SHADOW_ALPHA)
	shadow.scale = Vector2.ONE * 0.90
	shadow.z_index = -1
	holder.add_child(shadow)

	var sprite := _normal_sprite(texture, Color(color.r, color.g, color.b, WEAPON_SIGNATURE_BODY_ALPHA))
	sprite.name = "WeaponSignatureBody"
	holder.add_child(sprite)

	var rim := _additive_sprite(texture, Color(0.92, 0.78, 0.54, WEAPON_SIGNATURE_RIM_ALPHA))
	rim.name = "WeaponSignatureRim"
	rim.scale = Vector2.ONE * 1.02
	rim.z_index = 1
	holder.add_child(rim)

	var actual_weapon: Sprite2D = null
	if weapon_texture != null:
		actual_weapon = Sprite2D.new()
		actual_weapon.name = "WeaponSignatureActualWeapon"
		actual_weapon.texture = weapon_texture
		actual_weapon.modulate = Color(1.0, 0.94, 0.82, 0.82)
		actual_weapon.position = weapon_offset
		actual_weapon.rotation = weapon_rotation
		actual_weapon.scale = Vector2.ONE * weapon_scale
		actual_weapon.z_index = 2
		holder.add_child(actual_weapon)

	# FAN-1079: this is a compact weapon-release cue, never a painted copy of
	# the damage area. Radius only selects a small readability band; gameplay
	# geometry remains in the weapon scripts and is not encoded in this scale.
	var compact_diameter := clampf(radius * 0.45, WEAPON_RELEASE_MIN_DIAMETER, WEAPON_RELEASE_MAX_DIAMETER)
	var texture_diameter := maxf(texture.get_size().x, texture.get_size().y)
	var base_scale := compact_diameter / maxf(texture_diameter, 1.0)
	holder.scale = Vector2.ONE * base_scale * 0.72
	holder.set_meta("release_diameter_px", compact_diameter)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(holder, "global_position", global_pos + direction * WEAPON_RELEASE_TRAVEL_PX, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "rotation", rotation + 0.12, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "scale", Vector2.ONE * base_scale, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.18).set_delay(0.10)
	tween.tween_property(rim, "modulate:a", 0.0, 0.16).set_delay(0.08)
	tween.tween_property(shadow, "modulate:a", 0.0, 0.16).set_delay(0.12)
	if actual_weapon != null:
		tween.tween_property(actual_weapon, "rotation", actual_weapon.rotation + 0.34, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(actual_weapon, "modulate:a", 0.0, 0.18).set_delay(0.12)
	tween.chain().tween_callback(holder.queue_free)
	return holder


static func slash(owner_node: Node2D, direction: Vector2, reach: float, color: Color, sprite_rotation := 0.0, lateral_scale := 1.0, visual_sweep_degrees := 0.0) -> Node2D:
	var holder := Node2D.new()
	holder.name = "SlashVfx"
	holder.z_index = 11
	holder.set_meta("visual_lateral_scale", lateral_scale)
	holder.set_meta("visual_sweep_degrees", visual_sweep_degrees)
	owner_node.add_child(holder)

	# Непрозрачный подслой дает дуге контраст на светлом фоне.
	var body := Sprite2D.new()
	body.texture = SLASH_TEXTURE
	body.position = Vector2(SLASH_TEXTURE.get_width() * 0.5 - SLASH_ORIGIN_X, 0.0)
	body.rotation = sprite_rotation
	body.modulate = _calmed_color(Color(color.r * 0.45, color.g * 0.45, color.b * 0.65, 0.44))
	body.z_index = -1
	holder.add_child(body)

	var tint := Color(color.r, color.g, color.b, 0.9)
	var sprite := _additive_sprite(SLASH_TEXTURE, tint)
	sprite.position = body.position
	sprite.rotation = sprite_rotation
	holder.add_child(sprite)

	var ghost := _additive_sprite(SLASH_TEXTURE, Color(color.r, color.g, color.b, 0.28))
	ghost.position = sprite.position
	ghost.rotation = sprite_rotation
	ghost.scale = Vector2(0.92, 1.06)
	holder.add_child(ghost)

	var base_angle := direction.angle()
	var figure_scale: float = max(reach, 60.0) / SLASH_REACH
	# Дуга вылетает из героя вдоль направления удара и заполняет зону поражения.
	holder.rotation = base_angle - 0.16
	holder.scale = Vector2(figure_scale * 0.45, figure_scale * 0.75 * maxf(lateral_scale, 0.1))

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(holder, "rotation", base_angle + 0.10, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "scale", Vector2(figure_scale, figure_scale * maxf(lateral_scale, 0.1)), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.17).set_delay(0.09)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.13).set_delay(0.12)
	tween.tween_property(body, "modulate:a", 0.0, 0.15).set_delay(0.10)
	tween.chain().tween_callback(holder.queue_free)
	return holder


static func hammer_slam(scene: Node, global_pos: Vector2, radius: float, color: Color) -> Node2D:
	var holder := Node2D.new()
	holder.name = "HammerSlamVfx"
	holder.z_index = 10
	scene.add_child(holder)
	holder.global_position = global_pos

	var flash := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.95))
	flash.scale = Vector2.ONE * (radius / 90.0)
	flash.z_index = 2
	holder.add_child(flash)

	var ring := _additive_sprite(RING_TEXTURE, Color(color.r, color.g, color.b, 0.9))
	ring.scale = Vector2.ONE * (radius * 0.25 / RING_RADIUS)
	ring.z_index = 1
	holder.add_child(ring)

	var rng := RandomNumberGenerator.new()
	var dust_count := maxi(4, int(round(8.0 * PARTICLE_DENSITY_MULT)))
	for index in range(dust_count):
		var dust := Sprite2D.new()
		dust.texture = DUST_TEXTURES[index % DUST_TEXTURES.size()]
		var angle := TAU * float(index) / float(dust_count) + rng.randf_range(-0.25, 0.25)
		var start_offset := Vector2.RIGHT.rotated(angle) * radius * rng.randf_range(0.35, 0.55)
		dust.position = start_offset
		dust.rotation = rng.randf_range(-PI, PI)
		dust.flip_h = rng.randf() < 0.5
		var dust_scale := (radius / 150.0) * rng.randf_range(0.45, 0.65)
		dust.scale = Vector2.ONE * dust_scale
		dust.modulate = Color(0.88, 0.86, 0.82, 0.58)
		holder.add_child(dust)

		var dust_tween := dust.create_tween()
		dust_tween.set_parallel(true)
		var travel := Vector2.RIGHT.rotated(angle) * radius * rng.randf_range(0.35, 0.50)
		var life := rng.randf_range(0.36, 0.50)
		dust_tween.tween_property(dust, "position", start_offset + travel, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dust_tween.tween_property(dust, "scale", Vector2.ONE * dust_scale * 1.22, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dust_tween.tween_property(dust, "modulate:a", 0.0, life * 0.7).set_delay(life * 0.3)
		dust_tween.tween_property(dust, "rotation", dust.rotation + rng.randf_range(-0.6, 0.6), life)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * (radius * 1.05 / RING_RADIUS), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.26).set_delay(0.06)
	tween.tween_property(flash, "scale", flash.scale * 1.8, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.16)
	tween.chain().tween_interval(0.45)
	tween.chain().tween_callback(holder.queue_free)
	return holder


static func orb_projectile(scene: Node, start: Vector2, color: Color, profile := {}, travel_direction := Vector2.RIGHT) -> Node2D:
	var holder := Node2D.new()
	var visual_id := str(profile.get("visual_id", "")) if profile is Dictionary else ""
	holder.name = "PlayerProjectile_%s" % (visual_id if not visual_id.is_empty() else "DevFallback")
	holder.z_index = 11
	scene.add_child(holder)
	holder.global_position = start
	holder.set_meta("projectile_visual_id", visual_id)
	holder.set_meta("projectile_asset_path", str(profile.get("asset_path", "")) if profile is Dictionary else "")
	var direction: Vector2 = travel_direction if travel_direction is Vector2 else Vector2.RIGHT
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var orientation := str(profile.get("forward_orientation", "right")) if profile is Dictionary else "right"
	if orientation != "non_directional":
		holder.rotation = direction.angle() + deg_to_rad(float(profile.get("rotation_offset_degrees", 0.0)))

	var orb := Sprite2D.new()
	var asset_path := str(profile.get("asset_path", "")) if profile is Dictionary else ""
	var profile_texture := load(asset_path) as Texture2D if not asset_path.is_empty() else null
	orb.texture = profile_texture if profile_texture != null else ORB_TEXTURE
	var display_size: Vector2 = profile.get("display_size", Vector2(46.0, 46.0)) if profile is Dictionary else Vector2(46.0, 46.0)
	var texture_size := orb.texture.get_size() if orb.texture != null else Vector2.ONE
	var base_scale := Vector2(display_size.x / maxf(texture_size.x, 1.0), display_size.y / maxf(texture_size.y, 1.0))
	orb.scale = base_scale
	holder.add_child(orb)

	var trail_palette = profile.get("trail_palette", []) if profile is Dictionary else []
	var trail_color: Color = trail_palette[0] if trail_palette is Array and not trail_palette.is_empty() else color
	var glow := _additive_sprite(FLASH_TEXTURE, Color(trail_color.r, trail_color.g, trail_color.b, 0.35))
	glow.scale = Vector2.ONE * 0.8
	glow.z_index = -1
	holder.add_child(glow)

	var pulse := holder.create_tween()
	pulse.set_loops()
	pulse.tween_property(orb, "scale", base_scale * 1.14, 0.12).set_trans(Tween.TRANS_SINE)
	pulse.parallel().tween_property(glow, "rotation", TAU, 0.9)
	pulse.tween_property(orb, "scale", base_scale * 0.92, 0.12).set_trans(Tween.TRANS_SINE)

	var trail := holder.create_tween()
	trail.set_loops()
	trail.tween_interval(0.055)
	var holder_id := holder.get_instance_id()
	trail.tween_callback(func() -> void:
		var current_holder := instance_from_id(holder_id) as Node2D
		if current_holder == null or not current_holder.is_inside_tree() or current_holder.get_parent() == null:
			return
		var ghost := Sprite2D.new()
		ghost.texture = orb.texture
		ghost.modulate = _calmed_color(Color(trail_color.r, trail_color.g, trail_color.b, 0.34))
		ghost.scale = base_scale * 0.72
		ghost.z_index = 10
		current_holder.get_parent().add_child(ghost)
		ghost.global_position = current_holder.global_position
		ghost.rotation = current_holder.rotation
		var ghost_tween := ghost.create_tween()
		ghost_tween.set_parallel(true)
		ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
		ghost_tween.tween_property(ghost, "scale", base_scale * 0.30, 0.22)
		ghost_tween.chain().tween_callback(ghost.queue_free)
	)
	return holder


static func projectile_trace(scene: Node, start: Vector2, finish: Vector2, color: Color, profile: Dictionary, duration := 0.14) -> Node2D:
	var direction := finish - start
	var holder := orb_projectile(scene, start, color, profile, direction)
	var move := holder.create_tween()
	move.tween_property(holder, "global_position", finish, maxf(duration, 0.04)).set_trans(Tween.TRANS_LINEAR)
	move.tween_callback(holder.queue_free)
	return holder


static func orb_burst(scene: Node, global_pos: Vector2, radius: float, color: Color) -> Node2D:
	var holder := Node2D.new()
	holder.name = "VoidBurstVfx"
	holder.z_index = 11
	scene.add_child(holder)
	holder.global_position = global_pos

	var flash := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.82))
	flash.scale = Vector2.ONE * (radius / 110.0)
	holder.add_child(flash)

	var ring := _additive_sprite(RING_TEXTURE, Color(color.r, color.g, color.b, 0.72))
	ring.scale = Vector2.ONE * (radius * 0.3 / RING_RADIUS)
	holder.add_child(ring)

	var rng := RandomNumberGenerator.new()
	for index in range(5):
		var wisp := Sprite2D.new()
		wisp.texture = DUST_TEXTURES[index % DUST_TEXTURES.size()]
		wisp.modulate = _calmed_color(Color(color.r * 0.8, color.g * 0.6, color.b, 0.58))
		var angle := TAU * float(index) / 5.0 + rng.randf_range(-0.4, 0.4)
		wisp.position = Vector2.RIGHT.rotated(angle) * radius * 0.3
		wisp.scale = Vector2.ONE * (radius / 220.0)
		holder.add_child(wisp)
		var wisp_tween := wisp.create_tween()
		wisp_tween.set_parallel(true)
		wisp_tween.tween_property(wisp, "position", wisp.position * 2.4, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		wisp_tween.tween_property(wisp, "modulate:a", 0.0, 0.34)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * (radius / RING_RADIUS), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.24).set_delay(0.05)
	tween.tween_property(flash, "scale", flash.scale * 1.7, 0.15)
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	tween.chain().tween_interval(0.25)
	tween.chain().tween_callback(holder.queue_free)
	return holder


static func beam(scene: Node, start: Vector2, finish: Vector2, width: float, color: Color) -> Node2D:
	var holder := Node2D.new()
	holder.name = "BeamVfx"
	holder.z_index = 12
	scene.add_child(holder)
	holder.global_position = start
	var delta := finish - start
	holder.rotation = delta.angle()

	var length: float = max(delta.length(), 8.0)
	var sprite := _additive_sprite(BEAM_TEXTURE, Color(color.r, color.g, color.b, 0.78))
	sprite.position = Vector2(length * 0.5, 0.0)
	sprite.scale = Vector2(length / 256.0, max(width / 64.0, 0.35) * BEAM_VISUAL_WIDTH_MULT)
	holder.add_child(sprite)

	var muzzle := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.65))
	muzzle.scale = Vector2.ONE * 0.55
	holder.add_child(muzzle)

	var hit_flash := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.65))
	hit_flash.position = Vector2(length, 0.0)
	hit_flash.scale = Vector2.ONE * 0.7
	holder.add_child(hit_flash)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale:y", sprite.scale.y * 0.30, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(holder, "modulate:a", 0.0, 0.18).set_delay(0.05)
	tween.chain().tween_callback(holder.queue_free)
	return holder


static func sound_wave_blast(scene: Node, start: Vector2, direction: Vector2, reach: float, color: Color) -> Node2D:
	var holder := Node2D.new()
	holder.name = "SoundWaveVfx"
	holder.z_index = 10
	scene.add_child(holder)
	holder.global_position = start
	holder.rotation = direction.angle()

	var sprite := _additive_sprite(WAVE_TEXTURE, Color(color.r, color.g, color.b, 0.74))
	sprite.position = Vector2(WAVE_TEXTURE.get_width() * 0.5 - WAVE_ORIGIN_X, 0.0)
	holder.add_child(sprite)
	var wave_scale: float = max(reach, 120.0) / 150.0
	holder.scale = Vector2.ONE * 0.4

	var rng := RandomNumberGenerator.new()
	for index in range(1):
		var note := Sprite2D.new()
		note.texture = NOTE_TEXTURE
		note.modulate = Color(0.88, 0.86, 0.82, 0.62)
		note.scale = Vector2.ONE * rng.randf_range(0.5, 0.7)
		note.position = Vector2(rng.randf_range(40.0, 90.0), rng.randf_range(-36.0, 36.0))
		note.rotation = rng.randf_range(-0.4, 0.4)
		holder.add_child(note)
		var note_tween := note.create_tween()
		note_tween.set_parallel(true)
		note_tween.tween_property(note, "position", note.position + Vector2(70.0, rng.randf_range(-26.0, -8.0)), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		note_tween.tween_property(note, "rotation", note.rotation + rng.randf_range(-0.7, 0.7), 0.34)
		note_tween.tween_property(note, "modulate:a", 0.0, 0.26).set_delay(0.08)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(holder, "scale", Vector2.ONE * wave_scale, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.20).set_delay(0.06)
	tween.chain().tween_interval(0.20)
	tween.chain().tween_callback(holder.queue_free)
	return holder


static func ring_pulse(scene: Node, global_pos: Vector2, radius: float, color: Color, with_notes := false) -> Node2D:
	var holder := Node2D.new()
	holder.name = "RingPulseVfx"
	holder.z_index = 10
	scene.add_child(holder)
	holder.global_position = global_pos

	var ring := _additive_sprite(RING_TEXTURE, Color(color.r, color.g, color.b, 0.85))
	ring.scale = Vector2.ONE * (radius * 0.3 / RING_RADIUS)
	holder.add_child(ring)

	var flash := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.6))
	flash.scale = Vector2.ONE * (radius / 200.0)
	holder.add_child(flash)

	if with_notes:
		var rng := RandomNumberGenerator.new()
		for index in range(2):
			var note := Sprite2D.new()
			note.texture = NOTE_TEXTURE
			note.scale = Vector2.ONE * rng.randf_range(0.45, 0.65)
			note.modulate = Color(0.88, 0.86, 0.82, 0.62)
			var angle := TAU * float(index) / 3.0 + rng.randf_range(-0.5, 0.5)
			note.position = Vector2.RIGHT.rotated(angle) * radius * 0.4
			holder.add_child(note)
			var note_tween := note.create_tween()
			note_tween.set_parallel(true)
			note_tween.tween_property(note, "position", note.position + Vector2(rng.randf_range(-14.0, 14.0), -radius * 0.35), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			note_tween.tween_property(note, "rotation", rng.randf_range(-0.6, 0.6), 0.42)
			note_tween.tween_property(note, "modulate:a", 0.0, 0.32).set_delay(0.10)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * (radius / RING_RADIUS), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.26).set_delay(0.05)
	tween.tween_property(flash, "scale", flash.scale * 1.6, 0.16)
	tween.tween_property(flash, "modulate:a", 0.0, 0.16)
	tween.chain().tween_interval(0.30)
	tween.chain().tween_callback(holder.queue_free)
	return holder


static func curse_skull(scene: Node, start: Vector2, target: Vector2, color: Color, travel_time: float, on_hit: Callable, profile := {}) -> Node2D:
	var holder := Node2D.new()
	holder.name = "CurseSkullVfx"
	holder.z_index = 11
	scene.add_child(holder)
	holder.global_position = start
	var visual_id := str(profile.get("visual_id", "")) if profile is Dictionary else ""
	holder.set_meta("projectile_visual_id", visual_id)
	holder.set_meta("projectile_asset_path", str(profile.get("asset_path", "")) if profile is Dictionary else "")

	var trail_palette = profile.get("trail_palette", []) if profile is Dictionary else []
	var trail_color: Color = trail_palette[0] if trail_palette is Array and not trail_palette.is_empty() else color
	var glow := _additive_sprite(FLASH_TEXTURE, Color(trail_color.r, trail_color.g, trail_color.b, 0.36))
	glow.scale = Vector2.ONE * 0.6
	glow.z_index = -1
	holder.add_child(glow)

	var skull := Sprite2D.new()
	var asset_path := str(profile.get("asset_path", "")) if profile is Dictionary else ""
	var profile_texture := load(asset_path) as Texture2D if not asset_path.is_empty() else null
	skull.texture = profile_texture if profile_texture != null else SKULL_TEXTURE
	var display_size: Vector2 = profile.get("display_size", Vector2(34.0, 34.0)) if profile is Dictionary else Vector2(34.0, 34.0)
	var texture_size := skull.texture.get_size() if skull.texture != null else Vector2.ONE
	skull.scale = Vector2(display_size.x / maxf(texture_size.x, 1.0), display_size.y / maxf(texture_size.y, 1.0))
	holder.add_child(skull)

	var wobble := holder.create_tween()
	wobble.set_loops()
	wobble.tween_property(skull, "rotation", 0.35, 0.08).set_trans(Tween.TRANS_SINE)
	wobble.tween_property(skull, "rotation", -0.35, 0.08).set_trans(Tween.TRANS_SINE)

	var trail := holder.create_tween()
	trail.set_loops()
	trail.tween_interval(0.06)
	var holder_id := holder.get_instance_id()
	var skull_scale := skull.scale
	trail.tween_callback(func() -> void:
		var current_holder := instance_from_id(holder_id) as Node2D
		if current_holder == null or not current_holder.is_inside_tree() or current_holder.get_parent() == null:
			return
		var ghost := Sprite2D.new()
		ghost.texture = skull.texture
		ghost.scale = skull_scale * 0.85
		ghost.modulate = _calmed_color(Color(trail_color.r, trail_color.g, trail_color.b, 0.30))
		ghost.z_index = 10
		current_holder.get_parent().add_child(ghost)
		ghost.global_position = current_holder.global_position
		var ghost_tween := ghost.create_tween()
		ghost_tween.set_parallel(true)
		ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
		ghost_tween.tween_property(ghost, "scale", ghost.scale * 0.4, 0.18)
		ghost_tween.chain().tween_callback(ghost.queue_free)
	)

	var move := holder.create_tween()
	move.tween_property(holder, "global_position", target, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var move_holder_id := holder.get_instance_id()
	move.tween_callback(func() -> void:
		if on_hit.is_valid():
			on_hit.call()
		var current_holder := instance_from_id(move_holder_id) as Node2D
		if current_holder != null:
			current_holder.queue_free()
	)
	return holder
