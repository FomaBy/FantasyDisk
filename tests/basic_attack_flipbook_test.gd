extends SceneTree

## FAN-3010: flipbook-плумбинг обычных атак (Combat VFX Art Standard v1.2).
##
## Каждое из девяти общих семейств и путь сигнатуры оружия обязаны играть
## SpriteFrames, когда пак есть, и оставаться на прежней статичной текстуре,
## когда пака нет. Резолвинг пака идёт ровно по соглашению
## <class>/<weapon>/<effect>/<effect>_spriteframes.tres.

const AttackVfxScript := preload("res://scripts/attack_vfx.gd")

# Временный пак для проверки живого пути сигнатуры: соглашение прибито к
# res://, подменить путь нечем, поэтому фикстура создаётся и удаляется здесь же.
const FIXTURE_DIR := "res://assets/sprites/effects/berserk/sword/weapon_signature"
const FIXTURE_PACK := "res://assets/sprites/effects/berserk/sword/weapon_signature/weapon_signature_spriteframes.tres"
const PACK_FRAMES := 8
const VARIATION_SAMPLES := 32

var _errors: Array[String] = []
var _host: Node2D


func _initialize() -> void:
	await process_frame
	_host = Node2D.new()
	root.add_child(_host)
	var pack := _build_pack()

	_check_convention_resolution()
	for family in AttackVfxScript.EFFECT_FAMILIES:
		_check_family(str(family), null)
		_check_family(str(family), pack)
	_check_start_frame_variation(pack)
	_check_weapon_signature(pack)

	_host.queue_free()
	if _errors.is_empty():
		print("Basic-attack flipbook plumbing passed: %d families + weapon signature play SpriteFrames when a pack exists and stay on the static stand-in when it does not." % AttackVfxScript.EFFECT_FAMILIES.size())
		quit(0)
	else:
		for error in _errors:
			push_error("Basic-attack flipbook: %s" % error)
		quit(1)


# Соглашение проверяется на настоящем содержимом репозитория, а не на фикстуре.
func _check_convention_resolution() -> void:
	if AttackVfxScript.effect_pack("berserk", "sword", "whirlwind") == null:
		_errors.append("effect_pack must resolve the existing convention pack berserk/sword/whirlwind.")
	if AttackVfxScript.effect_pack("berserk", "sword", "no_such_effect") != null:
		_errors.append("effect_pack must return null for a missing pack instead of guessing a path.")
	if AttackVfxScript.effect_pack("", "sword", "whirlwind") != null \
			or AttackVfxScript.effect_pack("berserk", "", "whirlwind") != null \
			or AttackVfxScript.effect_pack("berserk", "sword", "") != null:
		_errors.append("effect_pack must return null when any path segment is empty.")


func _check_family(family: String, pack: SpriteFrames) -> void:
	var effect := _spawn_family(family, pack)
	if effect == null:
		_errors.append("family %s did not spawn." % family)
		return
	var flipbooks := _flipbooks(effect)
	var textured := _textured_sprites(effect)
	if pack == null:
		if not flipbooks.is_empty():
			_errors.append("family %s built a flipbook without a pack; the fallback must stay a static sprite." % family)
		if textured == 0:
			_errors.append("family %s lost its static stand-in sprite." % family)
	else:
		if flipbooks.is_empty():
			_errors.append("family %s ignored its pack and stayed on the static stand-in." % family)
		for flipbook in flipbooks:
			if flipbook.sprite_frames != pack or not flipbook.is_playing():
				_errors.append("family %s must play the supplied SpriteFrames." % family)
				break
	effect.queue_free()


func _check_start_frame_variation(pack: SpriteFrames) -> void:
	for family in AttackVfxScript.EFFECT_FAMILIES:
		var name := str(family)
		var frames := {}
		for index in VARIATION_SAMPLES:
			var effect := _spawn_family(name, pack)
			if effect == null:
				continue
			for flipbook in _flipbooks(effect):
				frames[flipbook.frame] = true
			effect.queue_free()
		var varies := bool(AttackVfxScript.START_FRAME_VARIATION.get(name, false))
		if varies and frames.size() < 2:
			_errors.append("family %s declares start-frame variation but always opened on the same frame." % name)
		if not varies and frames.keys() != [0]:
			_errors.append("family %s has start-frame variation switched off but opened on %s." % [name, frames.keys()])


func _check_weapon_signature(pack: SpriteFrames) -> void:
	var fallback := AttackVfxScript.weapon_signature(_host, Vector2.ZERO, "sword", 120.0, Color(0.8, 0.7, 1.0, 0.45))
	if fallback == null or not _flipbooks(fallback).is_empty() or _textured_sprites(fallback) == 0:
		_errors.append("weapon signature without a pack must stay on the static vfx_weapon_*.png stand-in.")
	if fallback != null:
		fallback.queue_free()

	if DirAccess.make_dir_recursive_absolute(FIXTURE_DIR) != OK or ResourceSaver.save(pack, FIXTURE_PACK) != OK:
		_errors.append("could not stage the temporary weapon-signature pack at %s." % FIXTURE_PACK)
		return
	var drawn := AttackVfxScript.weapon_signature(_host, Vector2.ZERO, "sword", 120.0, Color(0.8, 0.7, 1.0, 0.45), 0.0, null, 0.0, 0.58, Vector2.ZERO, "berserk")
	if drawn == null or _flipbooks(drawn).is_empty():
		_errors.append("weapon signature must play the convention pack for berserk/sword once it exists.")
	elif float(drawn.get_meta("release_diameter_px", 0.0)) <= 0.0:
		_errors.append("weapon signature lost its compact release geometry on the flipbook route.")
	if drawn != null:
		drawn.queue_free()

	if DirAccess.remove_absolute(FIXTURE_PACK) != OK or DirAccess.remove_absolute(FIXTURE_DIR) != OK:
		_errors.append("could not remove the temporary weapon-signature pack at %s; delete it before committing." % FIXTURE_PACK)


func _spawn_family(family: String, pack: SpriteFrames) -> Node2D:
	var color := Color(0.8, 0.7, 1.0, 0.45)
	match family:
		"slash":
			return AttackVfxScript.slash(_host, Vector2.RIGHT, 120.0, color, 0.0, 1.0, 0.0, pack)
		"hammer_slam":
			return AttackVfxScript.hammer_slam(_host, Vector2.ZERO, 120.0, color, pack)
		"orb_projectile":
			return AttackVfxScript.orb_projectile(_host, Vector2.ZERO, color, {}, Vector2.RIGHT, pack)
		"projectile_trace":
			return AttackVfxScript.projectile_trace(_host, Vector2.ZERO, Vector2(80.0, 0.0), color, {}, 0.14, pack)
		"orb_burst":
			return AttackVfxScript.orb_burst(_host, Vector2.ZERO, 120.0, color, pack)
		"beam":
			return AttackVfxScript.beam(_host, Vector2.ZERO, Vector2(80.0, 0.0), 24.0, color, pack)
		"sound_wave_blast":
			return AttackVfxScript.sound_wave_blast(_host, Vector2.ZERO, Vector2.RIGHT, 150.0, color, pack)
		"ring_pulse":
			return AttackVfxScript.ring_pulse(_host, Vector2.ZERO, 120.0, color, false, pack)
		"curse_skull":
			return AttackVfxScript.curse_skull(_host, Vector2.ZERO, Vector2(80.0, 0.0), color, 5.0, Callable(), {}, pack)
	_errors.append("family %s has no spawn case in this test." % family)
	return null


func _build_pack() -> SpriteFrames:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var pack := SpriteFrames.new()
	for index in PACK_FRAMES:
		pack.add_frame(&"default", texture)
	return pack


func _flipbooks(node: Node) -> Array[AnimatedSprite2D]:
	var found: Array[AnimatedSprite2D] = []
	if node is AnimatedSprite2D:
		found.append(node as AnimatedSprite2D)
	for child in node.get_children():
		found.append_array(_flipbooks(child))
	return found


func _textured_sprites(node: Node) -> int:
	var count := 0
	if node is Sprite2D and (node as Sprite2D).texture != null:
		count += 1
	for child in node.get_children():
		count += _textured_sprites(child)
	return count
