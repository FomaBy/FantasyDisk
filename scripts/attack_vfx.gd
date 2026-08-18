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
# FAN-3010: единственное правило поиска анимированного пака, соглашение
# Combat VFX Art Standard v1.2 (docs/design/systems/weapon_ultimate_presentation.md):
# assets/sprites/effects/<class>/<weapon>/<effect>/<effect>_spriteframes.tres.
const EFFECT_PACK_PATH := "res://assets/sprites/effects/%s/%s/%s/%s_spriteframes.tres"
const WEAPON_SIGNATURE_EFFECT := "weapon_signature"
# Девять общих семейств обычных атак; имя семейства — это же <effect> в пути пака.
const EFFECT_FAMILIES: Array[String] = [
	"slash",
	"hammer_slam",
	"orb_projectile",
	"projectile_trace",
	"orb_burst",
	"beam",
	"sound_wave_blast",
	"ring_pulse",
	"curse_skull",
]
# Стандарт v1.2: повторяющиеся удары могут стартовать с разного кадра. Выключено
# там, где фиксированный первый кадр несёт читаемость — летящий снаряд, луч и
# череп должны появляться одинаково, иначе теряется момент вылета.
const START_FRAME_VARIATION := {
	"weapon_signature": true,
	"slash": true,
	"hammer_slam": true,
	"orb_burst": true,
	"ring_pulse": true,
	"sound_wave_blast": true,
	"orb_projectile": false,
	"projectile_trace": false,
	"beam": false,
	"curse_skull": false,
}
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


static func _combat_holder(name: String, layer: int) -> Node2D:
	var holder := Node2D.new()
	holder.name = name
	holder.z_index = layer
	holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	return holder


## Пак есть — играем flipbook, пака нет — временно та же статичная текстура.
## Возвращает SpriteFrames или null; сам путь строится ровно по соглашению v1.2.
static func effect_pack(class_id: String, weapon_id: String, effect: String) -> SpriteFrames:
	if class_id.is_empty() or weapon_id.is_empty() or effect.is_empty():
		return null
	var path := EFFECT_PACK_PATH % [class_id, weapon_id, effect, effect]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as SpriteFrames


## Класс героя, от которого идёт удар — первый сегмент пути пака.
## Пусто (нет владельца или свойства) — значит остаёмся на статичном фолбэке.
static func owner_class_id(owner_node: Node) -> String:
	if owner_node == null:
		return ""
	var raw = owner_node.get("character_id")
	return str(raw) if raw != null else ""


static func _additive_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


# FAN-3010: одна фигура на обе ветки. Без пака это в точности прежний Sprite2D.
# С паком — AnimatedSprite2D внутри Node2D-обёртки, отмасштабированный под след
# статичной текстуры: вся геометрия, тайминги, твины и blend-режимы вызывающего
# кода продолжают работать с теми же числами.
static func _figure(texture: Texture2D, color: Color, additive: bool, pack: SpriteFrames, start_frame: int) -> Node2D:
	var tint := _calmed_color(color) if additive else color
	if pack == null:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.modulate = tint
		if additive:
			sprite.material = _additive_material()
		return sprite

	var animation := _pack_animation(pack)
	var flipbook := AnimatedSprite2D.new()
	flipbook.sprite_frames = pack
	flipbook.scale = _pack_fit_scale(pack, texture)
	if additive:
		flipbook.material = _additive_material()
	flipbook.play(animation)
	flipbook.frame = start_frame
	var holder := Node2D.new()
	holder.modulate = tint
	holder.add_child(flipbook)
	return holder


static func _additive_sprite(texture: Texture2D, color: Color, pack: SpriteFrames = null, start_frame := 0) -> Node2D:
	return _figure(texture, color, true, pack, start_frame)


static func _normal_sprite(texture: Texture2D, color: Color, pack: SpriteFrames = null, start_frame := 0) -> Node2D:
	return _figure(texture, color, false, pack, start_frame)


static func _pack_animation(pack: SpriteFrames) -> StringName:
	var names := pack.get_animation_names()
	if names.is_empty() or names.has("default"):
		return &"default"
	return StringName(names[0])


static func _pack_frame_size(pack: SpriteFrames) -> Vector2:
	var animation := _pack_animation(pack)
	if pack.get_frame_count(animation) <= 0:
		return Vector2.ONE
	var frame := pack.get_frame_texture(animation, 0)
	return frame.get_size() if frame != null else Vector2.ONE


static func _pack_fit_scale(pack: SpriteFrames, texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var frame_size := _pack_frame_size(pack)
	var target := texture.get_size()
	return Vector2(target.x / maxf(frame_size.x, 1.0), target.y / maxf(frame_size.y, 1.0))


# Один стартовый кадр на весь эффект: слои одной фигуры обязаны идти синхронно.
static func _start_frame(pack: SpriteFrames, effect: String) -> int:
	if pack == null or not bool(START_FRAME_VARIATION.get(effect, false)):
		return 0
	return randi() % maxi(pack.get_frame_count(_pack_animation(pack)), 1)


# Шлейф снаряда снимает кадр с самой фигуры — иначе призраки анимированного
# снаряда застыли бы на первом кадре, чего статичный шлейф никогда не делал.
static func _figure_frame(figure: Node2D) -> int:
	if figure.get_child_count() == 0:
		return 0
	var flipbook := figure.get_child(0) as AnimatedSprite2D
	return flipbook.frame if flipbook != null else 0


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
	weapon_offset := Vector2.ZERO,
	class_id := ""
) -> Node2D:
	var pack := effect_pack(class_id, weapon_id, WEAPON_SIGNATURE_EFFECT)
	var texture: Texture2D = null
	if pack == null:
		var texture_path := WEAPON_SIGNATURE_PATH % weapon_id
		if not ResourceLoader.exists(texture_path):
			return null
		texture = load(texture_path) as Texture2D
		if texture == null:
			return null
	var start_frame := _start_frame(pack, WEAPON_SIGNATURE_EFFECT)

	var holder := _combat_holder("WeaponSignatureVfx_%s" % weapon_id, 9)
	scene.add_child(holder)
	var direction := Vector2.RIGHT.rotated(rotation)
	holder.global_position = global_pos
	holder.rotation = rotation - 0.12
	holder.set_meta("release_motion", true)
	holder.set_meta("release_travel_px", WEAPON_RELEASE_TRAVEL_PX)
	holder.set_meta("damage_zone_overlay", false)

	var shadow := _normal_sprite(texture, Color(0.02, 0.015, 0.012, WEAPON_SIGNATURE_SHADOW_ALPHA), pack, start_frame)
	shadow.name = "WeaponSignatureShadow"
	shadow.scale = Vector2.ONE * 0.90
	shadow.z_index = -1
	holder.add_child(shadow)

	var sprite := _normal_sprite(texture, Color(color.r, color.g, color.b, WEAPON_SIGNATURE_BODY_ALPHA), pack, start_frame)
	sprite.name = "WeaponSignatureBody"
	holder.add_child(sprite)

	var rim := _additive_sprite(texture, Color(0.92, 0.78, 0.54, WEAPON_SIGNATURE_RIM_ALPHA), pack, start_frame)
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
	var footprint := texture.get_size() if texture != null else _pack_frame_size(pack)
	var texture_diameter := maxf(footprint.x, footprint.y)
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


static func slash(owner_node: Node2D, direction: Vector2, reach: float, color: Color, sprite_rotation := 0.0, lateral_scale := 1.0, visual_sweep_degrees := 0.0, pack: SpriteFrames = null) -> Node2D:
	var holder := _combat_holder("SlashVfx", 11)
	holder.set_meta("visual_lateral_scale", lateral_scale)
	holder.set_meta("visual_sweep_degrees", visual_sweep_degrees)
	owner_node.add_child(holder)
	var start_frame := _start_frame(pack, "slash")

	# Непрозрачный подслой дает дуге контраст на светлом фоне.
	var body := _normal_sprite(
		SLASH_TEXTURE,
		_calmed_color(Color(color.r * 0.45, color.g * 0.45, color.b * 0.65, 0.44)),
		pack,
		start_frame
	)
	body.position = Vector2(SLASH_TEXTURE.get_width() * 0.5 - SLASH_ORIGIN_X, 0.0)
	body.rotation = sprite_rotation
	body.z_index = -1
	holder.add_child(body)

	var tint := Color(color.r, color.g, color.b, 0.9)
	var sprite := _additive_sprite(SLASH_TEXTURE, tint, pack, start_frame)
	sprite.position = body.position
	sprite.rotation = sprite_rotation
	holder.add_child(sprite)

	var ghost := _additive_sprite(SLASH_TEXTURE, Color(color.r, color.g, color.b, 0.28), pack, start_frame)
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


static func hammer_slam(scene: Node, global_pos: Vector2, radius: float, color: Color, pack: SpriteFrames = null) -> Node2D:
	var holder := _combat_holder("HammerSlamVfx", 10)
	scene.add_child(holder)
	holder.global_position = global_pos

	# Пак рисует сам удар; кольцо-ударная волна, пыль и блики остаются общими.
	var flash := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.95), pack, _start_frame(pack, "hammer_slam"))
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


static func orb_projectile(scene: Node, start: Vector2, color: Color, profile := {}, travel_direction := Vector2.RIGHT, pack: SpriteFrames = null) -> Node2D:
	var visual_id := str(profile.get("visual_id", "")) if profile is Dictionary else ""
	var holder := _combat_holder("PlayerProjectile_%s" % (visual_id if not visual_id.is_empty() else "DevFallback"), 11)
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

	var asset_path := str(profile.get("asset_path", "")) if profile is Dictionary else ""
	var profile_texture := load(asset_path) as Texture2D if not asset_path.is_empty() else null
	var orb_texture: Texture2D = profile_texture if profile_texture != null else ORB_TEXTURE
	var orb := _normal_sprite(orb_texture, Color(1.0, 1.0, 1.0, 1.0), pack, _start_frame(pack, "orb_projectile"))
	var display_size: Vector2 = profile.get("display_size", Vector2(46.0, 46.0)) if profile is Dictionary else Vector2(46.0, 46.0)
	var texture_size := orb_texture.get_size() if orb_texture != null else Vector2.ONE
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
		var ghost := _normal_sprite(
			orb_texture,
			_calmed_color(Color(trail_color.r, trail_color.g, trail_color.b, 0.34)),
			pack,
			_figure_frame(orb)
		)
		ghost.process_mode = Node.PROCESS_MODE_PAUSABLE
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


static func projectile_trace(scene: Node, start: Vector2, finish: Vector2, color: Color, profile: Dictionary, duration := 0.14, pack: SpriteFrames = null) -> Node2D:
	var direction := finish - start
	var holder := orb_projectile(scene, start, color, profile, direction, pack)
	var move := holder.create_tween()
	move.tween_property(holder, "global_position", finish, maxf(duration, 0.04)).set_trans(Tween.TRANS_LINEAR)
	move.tween_callback(holder.queue_free)
	return holder


static func orb_burst(scene: Node, global_pos: Vector2, radius: float, color: Color, pack: SpriteFrames = null) -> Node2D:
	var holder := _combat_holder("VoidBurstVfx", 11)
	scene.add_child(holder)
	holder.global_position = global_pos

	# Пак рисует сам взрыв; расходящееся кольцо и клочья остаются общими.
	var flash := _additive_sprite(FLASH_TEXTURE, Color(color.r, color.g, color.b, 0.82), pack, _start_frame(pack, "orb_burst"))
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


static func beam(scene: Node, start: Vector2, finish: Vector2, width: float, color: Color, pack: SpriteFrames = null) -> Node2D:
	var holder := _combat_holder("BeamVfx", 12)
	scene.add_child(holder)
	holder.global_position = start
	var delta := finish - start
	holder.rotation = delta.angle()

	var length: float = max(delta.length(), 8.0)
	# Пак рисует сам луч; дульная вспышка и вспышка попадания остаются общими.
	var sprite := _additive_sprite(BEAM_TEXTURE, Color(color.r, color.g, color.b, 0.78), pack, _start_frame(pack, "beam"))
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


static func sound_wave_blast(scene: Node, start: Vector2, direction: Vector2, reach: float, color: Color, pack: SpriteFrames = null) -> Node2D:
	var holder := _combat_holder("SoundWaveVfx", 10)
	scene.add_child(holder)
	holder.global_position = start
	holder.rotation = direction.angle()

	# Пак рисует саму волну; вылетающие ноты остаются общими.
	var sprite := _additive_sprite(WAVE_TEXTURE, Color(color.r, color.g, color.b, 0.74), pack, _start_frame(pack, "sound_wave_blast"))
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


static func ring_pulse(scene: Node, global_pos: Vector2, radius: float, color: Color, with_notes := false, pack: SpriteFrames = null) -> Node2D:
	var holder := _combat_holder("RingPulseVfx", 10)
	scene.add_child(holder)
	holder.global_position = global_pos

	# Пак рисует само кольцо; центральная вспышка и ноты остаются общими.
	var ring := _additive_sprite(RING_TEXTURE, Color(color.r, color.g, color.b, 0.85), pack, _start_frame(pack, "ring_pulse"))
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


static func curse_skull(scene: Node, start: Vector2, target: Vector2, color: Color, travel_time: float, on_hit: Callable, profile := {}, pack: SpriteFrames = null) -> Node2D:
	var holder := _combat_holder("CurseSkullVfx", 11)
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

	var asset_path := str(profile.get("asset_path", "")) if profile is Dictionary else ""
	var profile_texture := load(asset_path) as Texture2D if not asset_path.is_empty() else null
	var skull_texture: Texture2D = profile_texture if profile_texture != null else SKULL_TEXTURE
	# Пак рисует сам череп; ореол остаётся общим.
	var skull := _normal_sprite(skull_texture, Color(1.0, 1.0, 1.0, 1.0), pack, _start_frame(pack, "curse_skull"))
	var display_size: Vector2 = profile.get("display_size", Vector2(34.0, 34.0)) if profile is Dictionary else Vector2(34.0, 34.0)
	var texture_size := skull_texture.get_size() if skull_texture != null else Vector2.ONE
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
		var ghost := _normal_sprite(
			skull_texture,
			_calmed_color(Color(trail_color.r, trail_color.g, trail_color.b, 0.30)),
			pack,
			_figure_frame(skull)
		)
		ghost.process_mode = Node.PROCESS_MODE_PAUSABLE
		ghost.scale = skull_scale * 0.85
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
