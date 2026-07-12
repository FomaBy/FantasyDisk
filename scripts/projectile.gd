extends Area2D

const ProjectileVisuals := preload("res://scripts/projectile_visual_registry.gd")

@export var speed := 600.0
@export var lifetime := 2.0
@export var projectile_visual_weapon_id := "soldier_rifle"

const ARENA_SIZE := Vector2(4096, 2304)  # SCRUM-518: синхронно с main.gd (×1.6)
const CLEANUP_MARGIN := 180.0

const TRAIL_POINTS := 9
const DEFAULT_TRAIL_COLOR := Color(0.62, 0.86, 1.0, 0.7)

var damage := 1.0
var direction := Vector2.RIGHT
var _trail: Line2D = null
var _trail_color := DEFAULT_TRAIL_COLOR


func setup(start_position: Vector2, target_position: Vector2, projectile_damage: float, visual_weapon_id := "") -> void:
	global_position = start_position
	damage = projectile_damage
	if not visual_weapon_id.is_empty():
		projectile_visual_weapon_id = visual_weapon_id
		if is_inside_tree():
			_apply_visual_profile()

	var target_direction := target_position - start_position
	if target_direction.length_squared() > 0.0:
		direction = target_direction.normalized()

	rotation = direction.angle()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)
	_apply_visual_profile()
	_build_trail()


func _apply_visual_profile() -> void:
	var profile := ProjectileVisuals.profile_for_weapon(projectile_visual_weapon_id)
	if profile.is_empty():
		_clear_visual_profile()
		push_warning("Legacy Projectile missing canonical visual profile: %s" % projectile_visual_weapon_id)
		return
	var visual := get_node_or_null("Shape") as Sprite2D
	if visual == null:
		return
	var texture := load(str(profile.get("asset_path", ""))) as Texture2D
	if texture == null:
		_clear_visual_profile()
		return
	visual.texture = texture
	var display_size: Vector2 = profile.get("display_size", Vector2(40.0, 40.0))
	var texture_size := texture.get_size()
	visual.scale = Vector2(display_size.x / maxf(texture_size.x, 1.0), display_size.y / maxf(texture_size.y, 1.0))
	visual.rotation = deg_to_rad(float(profile.get("rotation_offset_degrees", 0.0)))
	set_meta("projectile_visual_id", str(profile.get("visual_id", "")))
	set_meta("projectile_asset_path", str(profile.get("asset_path", "")))
	var palette = profile.get("trail_palette", [])
	if palette is Array and not palette.is_empty():
		var c: Color = palette[0]
		_trail_color = Color(c.r, c.g, c.b, 0.70)
	else:
		_trail_color = DEFAULT_TRAIL_COLOR
	if _trail != null:
		_trail.default_color = _trail_color


func _clear_visual_profile() -> void:
	remove_meta("projectile_visual_id")
	remove_meta("projectile_asset_path")
	var visual := get_node_or_null("Shape") as Sprite2D
	if visual != null:
		visual.texture = null
		visual.scale = Vector2.ONE
		visual.rotation = 0.0
	_trail_color = DEFAULT_TRAIL_COLOR
	if _trail != null:
		_trail.default_color = _trail_color


func _build_trail() -> void:
	# Дешёвый трейл-полоса в мировом пространстве (одна нода, без аллокаций нод
	# в кадре): тянется за снарядом и сужается к хвосту.
	_trail = Line2D.new()
	_trail.top_level = true            # игнорировать трансформ снаряда -> мировые координаты
	_trail.z_index = -1
	_trail.width = 9.0
	_trail.width_curve = _trail_taper()
	_trail.default_color = _trail_color
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail)
	_trail.add_point(global_position)


func _trail_taper() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.05))   # хвост тонкий
	curve.add_point(Vector2(1.0, 1.0))    # голова широкая
	return curve


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	_update_trail()

	if lifetime <= 0.0 or _is_outside_arena():
		queue_free()


func _update_trail() -> void:
	if _trail == null:
		return
	_trail.add_point(global_position)
	while _trail.get_point_count() > TRAIL_POINTS:
		_trail.remove_point(0)


func _is_outside_arena() -> bool:
	return (
		global_position.x < -CLEANUP_MARGIN
		or global_position.x > ARENA_SIZE.x + CLEANUP_MARGIN
		or global_position.y < -CLEANUP_MARGIN
		or global_position.y > ARENA_SIZE.y + CLEANUP_MARGIN
	)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
