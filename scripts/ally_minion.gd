extends CharacterBody2D

const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const StatusEffects := preload("res://scripts/status_effects.gd")

const ALLY_VISUAL_PATHS := {
	"druid_beast": "res://assets/sprites/allies/ally_druid_beast.png",
	"druid_pack_spirit": "res://assets/sprites/allies/ally_druid_pack_spirit.png",
	"homunculus": "res://assets/sprites/allies/ally_homunculus.png",
	"leadership_echo": "res://assets/sprites/allies/ally_leadership_echo.png",
}
const ANIMATED_ALLY_VISUALS := {
	"druid_beast": {
		"frames": "res://assets/sprites/allies/ally_druid_wolf_spriteframes.tres",
		"scale": Vector2(0.34, 0.34),
		"position": Vector2(0.0, -31.0),
	},
	"druid_pack_spirit": {
		"frames": "res://assets/sprites/allies/ally_pack_spirit_spriteframes.tres",
		"scale": Vector2(0.34, 0.34),
		"position": Vector2(0.0, -10.0),
	},
	"homunculus": {
		"frames": "res://assets/sprites/allies/ally_homunculus_spriteframes.tres",
		"scale": Vector2(0.34, 0.34),
		"position": Vector2(0.0, -10.0),
	},
	"leadership_echo": {
		"frames": "res://assets/sprites/allies/ally_leadership_echo_spriteframes.tres",
		"scale": Vector2(0.34, 0.34),
		"position": Vector2(0.0, -10.0),
	},
}
const FALLBACK_ALLY_VISUAL_ID := "druid_beast"

@export var move_speed := 230.0
@export var damage := 1.5
@export var attack_range := 24.0
@export var attack_interval := 0.45
@export var lifetime := 12.0
@export var command_mode := "attack_target"
@export var ally_visual_id := FALLBACK_ALLY_VISUAL_ID
@export var max_health := 18.0
@export var summon_role := "pack_damage"
@export var control_knockback := 0.0
@export var support_heal_percent := 0.0

var _attack_cooldown := 0.0
var _attack_anim_time := 0.0
var _last_facing_right := false
var owner_node: Node2D = null
var command_target: Node2D = null
var health := 18.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("allies")
	health = max_health
	_apply_visual()


func set_visual_id(visual_id: String) -> void:
	ally_visual_id = visual_id
	_apply_visual()


func set_combat_profile(profile: Dictionary) -> void:
	damage = maxf(float(profile.get("damage", damage)), 0.1)
	move_speed = maxf(float(profile.get("move_speed", move_speed)), 40.0)
	attack_range = maxf(float(profile.get("attack_range", attack_range)), 8.0)
	attack_interval = maxf(float(profile.get("attack_interval", attack_interval)), 0.12)
	lifetime = maxf(float(profile.get("lifetime", lifetime)), 1.0)
	max_health = maxf(float(profile.get("max_health", max_health)), 1.0)
	health = max_health
	summon_role = str(profile.get("summon_role", summon_role))
	control_knockback = maxf(float(profile.get("control_knockback", control_knockback)), 0.0)
	support_heal_percent = maxf(float(profile.get("support_heal_percent", support_heal_percent)), 0.0)


func take_damage(amount: float) -> void:
	health -= maxf(amount, 0.0)
	if health <= 0.0:
		queue_free()


func _apply_visual() -> void:
	var body := get_node_or_null("Body") as Sprite2D
	var animated_body := get_node_or_null("AnimatedBody") as AnimatedSprite2D
	if body == null:
		return
	var path := str(ALLY_VISUAL_PATHS.get(ally_visual_id, ALLY_VISUAL_PATHS[FALLBACK_ALLY_VISUAL_ID]))
	var texture := load(path) as Texture2D
	if texture != null:
		body.texture = texture
	body.visible = true

	if animated_body == null:
		return
	if not ANIMATED_ALLY_VISUALS.has(ally_visual_id):
		animated_body.visible = false
		animated_body.stop()
		return

	var animated_config: Dictionary = ANIMATED_ALLY_VISUALS[ally_visual_id]
	var frames := load(str(animated_config.get("frames", ""))) as SpriteFrames
	if frames == null or not frames.has_animation("move") or not frames.has_animation("attack"):
		animated_body.visible = false
		animated_body.stop()
		return

	animated_body.sprite_frames = frames
	animated_body.scale = animated_config.get("scale", Vector2(0.34, 0.34))
	animated_body.position = animated_config.get("position", Vector2(0.0, -31.0))
	animated_body.visible = true
	animated_body.flip_h = _last_facing_right
	body.visible = false
	if animated_body.animation != "move":
		animated_body.animation = "move"
	if not animated_body.is_playing():
		animated_body.play("move")


func _physics_process(delta: float) -> void:
	StatusEffects.tick(self, delta)
	lifetime -= delta
	_attack_cooldown -= delta
	_attack_anim_time = maxf(_attack_anim_time - delta, 0.0)
	if lifetime <= 0.0:
		queue_free()
		return

	var target := _commanded_target()
	if target == null:
		_follow_guard_position()
		move_and_slide()
		_update_visual_animation()
		return

	var to_target := target.global_position - global_position
	if to_target.length() <= attack_range:
		velocity = Vector2.ZERO
		_try_attack(target)
	else:
		velocity = to_target.normalized() * move_speed * StatusEffects.speed_multiplier(self)

	move_and_slide()
	_update_visual_animation()


func _find_closest_enemy() -> Node2D:
	return TARGET_QUERY.nearest(self, global_position)


func _commanded_target() -> Node2D:
	if command_mode == "guard_owner" and owner_node != null and is_instance_valid(owner_node):
		var local_target := _find_closest_enemy_near(owner_node.global_position, 320.0)
		if local_target != null:
			return local_target
		return null
	if command_target != null and is_instance_valid(command_target):
		return command_target
	return _find_closest_enemy()


func _find_closest_enemy_near(origin: Vector2, max_distance: float) -> Node2D:
	return TARGET_QUERY.nearest(self, origin, max_distance)


func _follow_guard_position() -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		velocity = Vector2.ZERO
		return
	var guard_offset := Vector2(56.0, 0.0).rotated(float(get_instance_id() % 360) * PI / 180.0)
	var guard_position := owner_node.global_position + guard_offset
	var to_guard := guard_position - global_position
	if to_guard.length() <= 18.0:
		velocity = Vector2.ZERO
	else:
		velocity = to_guard.normalized() * move_speed


func _try_attack(target: Node2D) -> void:
	if _attack_cooldown > 0.0:
		return

	if target.has_method("take_damage"):
		target.take_damage(damage * StatusEffects.damage_multiplier(self))
	if control_knockback > 0.0 and target.has_method("apply_knockback"):
		var push_origin := owner_node.global_position if owner_node != null and is_instance_valid(owner_node) else global_position
		var push_direction := target.global_position - push_origin
		if push_direction.length_squared() > 0.001:
			target.apply_knockback(push_direction.normalized() * control_knockback)
	if support_heal_percent > 0.0 and owner_node != null and is_instance_valid(owner_node) and owner_node.has_method("heal_percent"):
		owner_node.heal_percent(support_heal_percent)

	_attack_cooldown = attack_interval
	_play_attack_animation(target.global_position - global_position)


func _update_visual_animation() -> void:
	var animated_body := get_node_or_null("AnimatedBody") as AnimatedSprite2D
	if animated_body == null or not animated_body.visible:
		return

	if absf(velocity.x) > 1.0:
		_last_facing_right = velocity.x > 0.0
	animated_body.flip_h = _last_facing_right

	if _attack_anim_time > 0.0:
		if animated_body.animation != "attack":
			animated_body.play("attack")
		return

	if animated_body.animation != "move":
		animated_body.play("move")
	elif not animated_body.is_playing():
		animated_body.play("move")


func _play_attack_animation(direction: Vector2 = Vector2.ZERO) -> void:
	var animated_body := get_node_or_null("AnimatedBody") as AnimatedSprite2D
	if animated_body == null or not animated_body.visible:
		return
	if absf(direction.x) > 0.01:
		_last_facing_right = direction.x > 0.0
	animated_body.flip_h = _last_facing_right
	_attack_anim_time = 0.44
	animated_body.play("attack")


func is_using_animated_ally_visual() -> bool:
	var animated_body := get_node_or_null("AnimatedBody") as AnimatedSprite2D
	return animated_body != null and animated_body.visible
