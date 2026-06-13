extends CharacterBody2D

const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")

const ALLY_VISUAL_PATHS := {
	"druid_beast": "res://assets/sprites/allies/ally_druid_beast.png",
	"druid_pack_spirit": "res://assets/sprites/allies/ally_druid_pack_spirit.png",
	"homunculus": "res://assets/sprites/allies/ally_homunculus.png",
	"leadership_echo": "res://assets/sprites/allies/ally_leadership_echo.png",
}
const FALLBACK_ALLY_VISUAL_ID := "druid_beast"

@export var move_speed := 230.0
@export var damage := 1.5
@export var attack_range := 24.0
@export var attack_interval := 0.45
@export var lifetime := 12.0
@export var command_mode := "attack_target"
@export var ally_visual_id := FALLBACK_ALLY_VISUAL_ID

var _attack_cooldown := 0.0
var owner_node: Node2D = null
var command_target: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("allies")
	_apply_visual()


func set_visual_id(visual_id: String) -> void:
	ally_visual_id = visual_id
	_apply_visual()


func _apply_visual() -> void:
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		return
	var path := str(ALLY_VISUAL_PATHS.get(ally_visual_id, ALLY_VISUAL_PATHS[FALLBACK_ALLY_VISUAL_ID]))
	var texture := load(path) as Texture2D
	if texture != null:
		body.texture = texture


func _physics_process(delta: float) -> void:
	lifetime -= delta
	_attack_cooldown -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	var target := _commanded_target()
	if target == null:
		_follow_guard_position()
		move_and_slide()
		return

	var to_target := target.global_position - global_position
	if to_target.length() <= attack_range:
		velocity = Vector2.ZERO
		_try_attack(target)
	else:
		velocity = to_target.normalized() * move_speed

	move_and_slide()


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
		target.take_damage(damage)

	_attack_cooldown = attack_interval
