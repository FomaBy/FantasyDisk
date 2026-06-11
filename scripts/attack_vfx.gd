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


static func _additive_sprite(texture: Texture2D, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = material
	sprite.modulate = color
	return sprite


static func slash(owner_node: Node2D, direction: Vector2, reach: float, color: Color) -> Node2D:
	var holder := Node2D.new()
	holder.name = "SlashVfx"
	holder.z_index = 11
	owner_node.add_child(holder)

	# Непрозрачный подслой дает дуге контраст на светлом фоне.
	var body := Sprite2D.new()
	body.texture = SLASH_TEXTURE
	body.position = Vector2(SLASH_TEXTURE.get_width() * 0.5 - SLASH_ORIGIN_X, 0.0)
	body.modulate = Color(color.r * 0.45, color.g * 0.45, color.b * 0.65, 0.5)
	body.z_index = -1
	holder.add_child(body)

	var tint := Color(color.r, color.g, color.b, 0.95)
	var sprite := _additive_sprite(SLASH_TEXTURE, tint)
	sprite.position = body.position
	holder.add_child(sprite)

	var ghost := _additive_sprite(SLASH_TEXTURE, Color(color.r, color.g, color.b, 0.40))
	ghost.position = sprite.position
	ghost.scale = Vector2(0.92, 1.06)
	holder.add_child(ghost)

	var base_angle := direction.angle()
	var figure_scale: float = max(reach, 60.0) / SLASH_REACH
	# Дуга вылетает из героя вдоль направления удара и заполняет зону поражения.
	holder.rotation = base_angle - 0.16
	holder.scale = Vector2(figure_scale * 0.45, figure_scale * 0.75)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(holder, "rotation", base_angle + 0.10, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "scale", Vector2(figure_scale, figure_scale), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.13).set_delay(0.09)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.10).set_delay(0.12)
	tween.tween_property(body, "modulate:a", 0.0, 0.12).set_delay(0.10)
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
	var dust_count := 8
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
		dust.modulate = Color(1.0, 1.0, 1.0, 0.85)
		holder.add_child(dust)

		var dust_tween := dust.create_tween()
		dust_tween.set_parallel(true)
		var travel := Vector2.RIGHT.rotated(angle) * radius * rng.randf_range(0.35, 0.50)
		var life := rng.randf_range(0.36, 0.50)
		dust_tween.tween_property(dust, "position", start_offset + travel, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dust_tween.tween_property(dust, "scale", Vector2.ONE * dust_scale * 1.45, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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


static func orb_projectile(scene: Node, start: Vector2, color: Color) -> Node2D:
	var holder := Node2D.new()
	holder.name = "VoidOrbProjectile"
	holder.z_index = 11
	scene.add_child(holder)
	holder.global_position = start

	var orb := Sprite2D.new()
	orb.texture = ORB_TEXTURE
	holder.add_child(orb)

	var glow := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.35))
	glow.scale = Vector2.ONE * 0.8
	glow.z_index = -1
	holder.add_child(glow)

	var pulse := holder.create_tween()
	pulse.set_loops()
	pulse.tween_property(orb, "scale", Vector2.ONE * 1.14, 0.12).set_trans(Tween.TRANS_SINE)
	pulse.parallel().tween_property(glow, "rotation", TAU, 0.9)
	pulse.tween_property(orb, "scale", Vector2.ONE * 0.92, 0.12).set_trans(Tween.TRANS_SINE)

	var trail := holder.create_tween()
	trail.set_loops()
	trail.tween_interval(0.035)
	trail.tween_callback(func() -> void:
		if not is_instance_valid(holder) or not holder.is_inside_tree():
			return
		var ghost := Sprite2D.new()
		ghost.texture = ORB_TEXTURE
		ghost.modulate = Color(color.r, color.g, color.b, 0.42)
		ghost.scale = Vector2.ONE * 0.72
		ghost.z_index = 10
		holder.get_parent().add_child(ghost)
		ghost.global_position = holder.global_position
		var ghost_tween := ghost.create_tween()
		ghost_tween.set_parallel(true)
		ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
		ghost_tween.tween_property(ghost, "scale", Vector2.ONE * 0.30, 0.22)
		ghost_tween.chain().tween_callback(ghost.queue_free)
	)
	return holder


static func orb_burst(scene: Node, global_pos: Vector2, radius: float, color: Color) -> Node2D:
	var holder := Node2D.new()
	holder.name = "VoidBurstVfx"
	holder.z_index = 11
	scene.add_child(holder)
	holder.global_position = global_pos

	var flash := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 1.0))
	flash.scale = Vector2.ONE * (radius / 110.0)
	holder.add_child(flash)

	var ring := _additive_sprite(RING_TEXTURE, Color(color.r, color.g, color.b, 0.85))
	ring.scale = Vector2.ONE * (radius * 0.3 / RING_RADIUS)
	holder.add_child(ring)

	var rng := RandomNumberGenerator.new()
	for index in range(5):
		var wisp := Sprite2D.new()
		wisp.texture = DUST_TEXTURES[index % DUST_TEXTURES.size()]
		wisp.modulate = Color(color.r * 0.8, color.g * 0.6, color.b, 0.75)
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
	var sprite := _additive_sprite(BEAM_TEXTURE, Color(color.r, color.g, color.b, 0.95))
	sprite.position = Vector2(length * 0.5, 0.0)
	sprite.scale = Vector2(length / 256.0, max(width / 64.0, 0.35) * 1.5)
	holder.add_child(sprite)

	var muzzle := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.9))
	muzzle.scale = Vector2.ONE * 0.55
	holder.add_child(muzzle)

	var hit_flash := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.9))
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

	var sprite := _additive_sprite(WAVE_TEXTURE, Color(color.r, color.g, color.b, 0.95))
	sprite.position = Vector2(WAVE_TEXTURE.get_width() * 0.5 - WAVE_ORIGIN_X, 0.0)
	holder.add_child(sprite)
	var wave_scale: float = max(reach, 120.0) / 150.0
	holder.scale = Vector2.ONE * 0.4

	var rng := RandomNumberGenerator.new()
	for index in range(2):
		var note := Sprite2D.new()
		note.texture = NOTE_TEXTURE
		note.modulate = Color(1.0, 1.0, 1.0, 0.95)
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
		for index in range(3):
			var note := Sprite2D.new()
			note.texture = NOTE_TEXTURE
			note.scale = Vector2.ONE * rng.randf_range(0.45, 0.65)
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


static func curse_skull(scene: Node, start: Vector2, target: Vector2, color: Color, travel_time: float, on_hit: Callable) -> Node2D:
	var holder := Node2D.new()
	holder.name = "CurseSkullVfx"
	holder.z_index = 11
	scene.add_child(holder)
	holder.global_position = start

	var glow := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.5))
	glow.scale = Vector2.ONE * 0.6
	glow.z_index = -1
	holder.add_child(glow)

	var skull := Sprite2D.new()
	skull.texture = SKULL_TEXTURE
	skull.scale = Vector2.ONE * (34.0 / max(float(SKULL_TEXTURE.get_width()), 1.0))
	holder.add_child(skull)

	var wobble := holder.create_tween()
	wobble.set_loops()
	wobble.tween_property(skull, "rotation", 0.35, 0.08).set_trans(Tween.TRANS_SINE)
	wobble.tween_property(skull, "rotation", -0.35, 0.08).set_trans(Tween.TRANS_SINE)

	var trail := holder.create_tween()
	trail.set_loops()
	trail.tween_interval(0.04)
	trail.tween_callback(func() -> void:
		if not is_instance_valid(holder) or not holder.is_inside_tree():
			return
		var ghost := Sprite2D.new()
		ghost.texture = SKULL_TEXTURE
		ghost.scale = skull.scale * 0.85
		ghost.modulate = Color(color.r, color.g, color.b, 0.40)
		ghost.z_index = 10
		holder.get_parent().add_child(ghost)
		ghost.global_position = holder.global_position
		var ghost_tween := ghost.create_tween()
		ghost_tween.set_parallel(true)
		ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
		ghost_tween.tween_property(ghost, "scale", ghost.scale * 0.4, 0.18)
		ghost_tween.chain().tween_callback(ghost.queue_free)
	)

	var move := holder.create_tween()
	move.tween_property(holder, "global_position", target, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	move.tween_callback(func() -> void:
		if on_hit.is_valid():
			on_hit.call()
		if is_instance_valid(holder):
			holder.queue_free()
	)
	return holder
