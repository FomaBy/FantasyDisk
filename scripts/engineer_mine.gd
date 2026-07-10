extends Node2D

# SCRUM-907: персистентная нажимная мина инженера («Минная Сетка»).
# Ставится парой в случайные точки кольца вокруг игрока
# (class_weapon._fire_engineer_pressure_mines); лежит БЕЗ таймера жизни до
# срабатывания или lifecycle-чистки (конец боя, смена оружия, смерть игрока —
# через weapon._register_effect). Триггеры:
#   - враг в радиусе mine_trigger_radius — подрыв СРАЗУ (и в первые 3 секунды);
#   - сам игрок — только после mine_self_arm_delay (3с) с постановки; до того
#     наступание НЕ тратит и НЕ подрывает мину (AC SCRUM-907).
# Подрыв — weapon._detonate_engineer_mine (урон по области с falloff + VFX +
# «Ядро утилизации»). Проверки замедлены (SCAN_INTERVAL) — без every-frame
# нагрузки. Без лямбд в твинах (SCRUM-551): вся логика — в _physics_process.

const SCAN_INTERVAL := 0.10
const PLAYER_TRIGGER_RADIUS := 46.0
# SCRUM-908 «Сеть мастерской»: мины кормят сеть с ПОНИЖЕННЫМ весом
# (предохранитель от мин-спама из тикета).
const NETWORK_WEIGHT := 0.5

var _weapon_instance_id := 0
var _owner_instance_id := 0
var _mine_index := 0
var _age := 0.0
var _scan_cooldown := 0.0
var _triggered := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("engineer_devices")
	set_meta("persistent_mine", true)
	set_meta("persistent_hazard", true)  # контракт SCRUM-854: наземный хазард
	set_meta("network_weight", NETWORK_WEIGHT)  # SCRUM-908
	z_index = 6


func setup(weapon: Node, owner_node: Node2D, mine_index: int) -> void:
	_weapon_instance_id = weapon.get_instance_id() if weapon != null else 0
	_owner_instance_id = owner_node.get_instance_id() if owner_node != null else 0
	_mine_index = mine_index


func age() -> float:
	return _age


func is_self_armed(weapon: Node) -> bool:
	var arm_delay := 3.0
	if weapon != null and is_instance_valid(weapon) and weapon.get("mine_self_arm_delay") != null:
		arm_delay = maxf(float(weapon.get("mine_self_arm_delay")), 0.0)
	return _age >= arm_delay


func debug_force_age(new_age: float) -> void:
	# Для focused-тестов: детерминированно открыть окно самоподрыва.
	_age = new_age


func _physics_process(delta: float) -> void:
	if _triggered:
		return
	_age += delta
	var weapon := instance_from_id(_weapon_instance_id) as Node
	if weapon == null or not is_instance_valid(weapon):
		# Оружие исчезло (смена/чистка) — мина не должна жить без хозяина.
		queue_free()
		return
	_scan_cooldown -= delta
	if _scan_cooldown > 0.0:
		return
	_scan_cooldown = SCAN_INTERVAL
	var trigger_radius := 84.0
	if weapon.get("mine_trigger_radius") != null:
		trigger_radius = maxf(float(weapon.get("mine_trigger_radius")), 16.0)
	# Враг подрывает мину сразу, включая первые секунды (AC SCRUM-907).
	if bool(weapon.call("_has_enemy_in_circle", global_position, trigger_radius)):
		_detonate(weapon)
		return
	# Игрок подрывает СВОЮ мину только после окна самоподрыва.
	if is_self_armed(weapon):
		var owner_node := instance_from_id(_owner_instance_id) as Node2D
		if owner_node != null and is_instance_valid(owner_node) \
				and owner_node.global_position.distance_to(global_position) <= PLAYER_TRIGGER_RADIUS:
			_detonate(weapon)


func _detonate(weapon: Node) -> void:
	if _triggered:
		return
	_triggered = true
	weapon.call("_detonate_engineer_mine", get_instance_id(), _owner_instance_id, _mine_index)
