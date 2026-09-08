extends SceneTree

# FAN-3926 (agent-ready-refactor FD19): характеризация оружия Солдата после
# выноса исполнителей в scripts/classes/executors/ за явный контекст.
#
# 1) Поведение через фасад (детерминированные фикстуры, seed): аркебуза —
#    центр/falloff/вне зоны; граната — урон только после фитиля, множитель
#    взрыва; штык — геометрия конуса без мёртвой зоны, авто-выстрел по цели за
#    конусом; порядок RNG (ровно два ролла за взмах штыка: урон, затем шанс
#    выстрела); реестр эффектов и путь `_effects_shutdown` (снаряды гаснут, урона
#    нет). Трасса урона/RNG пишется в файл из FSD_SOLDIER_TRACE_OUT — сравнение
#    до/после выноса делается по этому файлу в отчёте карточки.
# 2) Шов: контекст/исполнитель существуют; каждый член REQUIRED_* есть на
#    фасаде; исполнитель зовёт на контексте только объявленные методы и не
#    трогает фасад/цепочку/TARGET_QUERY напрямую; у исполнителя и контекста по
#    одному полю; фасад не содержит логики выбора целей и роллов.
# 3) Представительная локальная правка: подкласс исполнителя меняет правило
#    конуса и подставляется в слот фасада — ни siblings, ни shared API не
#    трогаются, соседний класс (Снайпер) стреляет как прежде.
#
# Секции 1 и 3 не ссылаются на новые скрипты статически (load() в рантайме),
# поэтому файл запускается и на базе до выноса: поведение сравнивается один в
# один, а секция шва там честно сообщает об отсутствии исполнителя.

const ClassWeapon := preload("res://scripts/class_weapon.gd")
const PD := preload("res://scripts/progression_data.gd")

const CONTEXT_PATH := "res://scripts/classes/executors/soldier_context.gd"
const EXECUTOR_PATH := "res://scripts/classes/executors/soldier_executor.gd"
const FACADE_PATH := "res://scripts/classes/soldier_weapon.gd"
const EXECUTOR_SLOT := "_soldier_executor_instance"
const EPS := 0.001
const TRACE_SEED := 20260908

# Методы фасада, которые обязаны остаться (реестр режимов, отложенные шаги,
# внешние suites: soldier_kit_test, constellation_schema6_live_runtime_test,
# fan1893_capability_contract_test, projectile_chain_pierce_identity_test).
const FACADE_METHODS: Array[StringName] = [
	&"_exec_arquebus_shot",
	&"_exec_grenade_fuse",
	&"_exec_bayonet_cone",
	&"_fire_arquebus_shot",
	&"_launch_arquebus_bullet",
	&"_explode_arquebus_bullet",
	&"_fire_grenade_fuse",
	&"_arm_grenade_fuse",
	&"_explode_grenade_fuse",
	&"_constellation_grenade_second_wave",
	&"_fire_bayonet_cone",
	&"_resolve_bayonet_brace_countershot",
	&"_fire_bayonet_countershot_line",
	&"_is_enemy_inside_bayonet_cone",
	&"_fire_bayonet_auto_shot",
	&"_find_bayonet_shot_target",
]


class MockOwner extends CharacterBody2D:
	var derived_parameters := {
		"damage": 100.0,
		"magic_damage": 100.0,
		"crit_chance": 0.0,
		"crit_damage_multiplier": 1.0,
		"dot_damage": 4.0,
		"dot_speed": 4.0,
	}
	var run_modifiers := {}
	var stats := {}
	var trait_overrides := {}

	func class_trait_value(key: String, default_value := 0.0) -> float:
		return float(trait_overrides.get(key, default_value))


class MockEnemy extends Node2D:
	var total_damage := 0.0
	var hit_count := 0
	var hits: Array[float] = []

	func take_damage(amount: float) -> void:
		total_damage += amount
		hit_count += 1
		hits.append(amount)


var errors := PackedStringArray()
var trace := {}


func _initialize() -> void:
	# Прогрев: в headless-запуске первый кадр приносит дельту в сотни мс, и
	# tween первого же снаряда разрешает свой callback дважды в одном кадре —
	# и на базе, и на кандидате. Дальше по прогону такого нет; сцены теста
	# начинаются после стабилизации кадров.
	await create_timer(0.3).timeout
	await process_frame
	await _check_arquebus_behavior()
	await _check_grenade_behavior()
	await _check_bayonet_behavior()
	await _check_rng_order()
	await _check_effect_shutdown()
	await _record_trace()
	_write_trace()
	await _check_seam_contract()
	await _check_local_edit_seam()

	if not errors.is_empty():
		for error in errors:
			push_error("FAN-3926 soldier composition: %s" % error)
		quit(1)
		return
	print("FAN-3926 soldier executor composition test passed.")
	quit(0)


# --- helpers ------------------------------------------------------------------


func _fail(message: String) -> void:
	errors.append(message)


func _new_scene(name: String) -> Node2D:
	var holder := Node2D.new()
	holder.name = name
	root.add_child(holder)
	current_scene = holder
	return holder


func _cleanup(holder: Node2D) -> void:
	holder.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _new_owner(holder: Node2D, position := Vector2(900, 700), crit_chance := 0.0) -> MockOwner:
	var owner := MockOwner.new()
	holder.add_child(owner)
	owner.global_position = position
	owner.trait_overrides = PD.class_trait("soldier")
	owner.trait_overrides["action_echo_chance"] = 0.0  # детерминизм: без копий действия
	owner.derived_parameters["crit_chance"] = crit_chance
	owner.derived_parameters["crit_damage_multiplier"] = 1.5
	return owner


func _new_weapon(owner: MockOwner, class_id: String, weapon_id: String) -> ClassWeapon:
	var weapon := ClassWeapon.new()
	owner.add_child(weapon)
	weapon.configure_weapon(PD.weapon(class_id, weapon_id))
	weapon.set_process(false)
	return weapon


func _new_enemy(holder: Node2D, name: String, position: Vector2) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.name = name
	enemy.add_to_group("enemies")
	holder.add_child(enemy)
	enemy.global_position = position
	return enemy


# Пуши выключены: mock-враг без apply_knockback сдвигается фоллбеком и менял бы
# геометрию между уколами (как в soldier_kit_test).
func _disable_push(weapon: ClassWeapon) -> void:
	weapon.set("knockback", 0.0)
	weapon.set("melee_stagger_knockback_multiplier", 0.0)


func _close_bonus_applies(weapon: ClassWeapon, distance: float) -> bool:
	return float(weapon.melee_close_bonus_radius) > 0.0 and float(weapon.melee_close_damage_multiplier) > 1.0 and distance <= float(weapon.melee_close_bonus_radius)


func _expected_stab_hits(weapon: ClassWeapon, distance: float) -> int:
	return 2 if _close_bonus_applies(weapon, distance) else 1


func _expected_stab_total(weapon: ClassWeapon, distance: float) -> float:
	return 100.0 * (float(weapon.melee_close_damage_multiplier) if _close_bonus_applies(weapon, distance) else 1.0)


# --- 1) поведение через фасад -------------------------------------------------


func _check_arquebus_behavior() -> void:
	var holder := _new_scene("SoldierCompositionArquebus")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "soldier", "soldier_rifle")
	var radius := float(weapon.aoe_radius)
	var primary := _new_enemy(holder, "Primary", owner.global_position + Vector2(220, 0))
	var neighbor := _new_enemy(holder, "Neighbor", owner.global_position + Vector2(220 + radius * 0.7, 0))
	var outside := _new_enemy(holder, "Outside", owner.global_position + Vector2(220 + radius * 2.5, 0))
	await process_frame
	weapon.call("_fire_arquebus_shot", owner, primary, Vector2.RIGHT)
	var in_flight: Array = weapon.call("_alive_effects")
	if in_flight.size() != 2:
		_fail("Arquebus: after the shot the registry must hold muzzle flash + bullet (2), got %d." % in_flight.size())
		await _cleanup(holder)
		return
	var bullet := in_flight[1] as Node
	await create_timer(0.7).timeout
	if primary.hit_count != 1 or absf(primary.total_damage - 100.0) > EPS:
		_fail("Arquebus: primary target expects exactly one 100.0 hit, got %d hits / %.2f." % [primary.hit_count, primary.total_damage])
	# Сосед: радиальный falloff по дистанции × крауд-фактор ранга 1 (FAN-1031).
	var expected_neighbor := 100.0 * lerpf(1.0, float(weapon.damage_falloff), 0.7) * float(weapon.call("_falloff_fanout_factor", 1))
	if neighbor.hit_count != 1 or absf(neighbor.total_damage - expected_neighbor) > 0.01:
		_fail("Arquebus: neighbour falloff expects %.2f, got %.2f (%d hits)." % [expected_neighbor, neighbor.total_damage, neighbor.hit_count])
	if outside.hit_count != 0:
		_fail("Arquebus: target outside the blast radius must not be hit.")
	if is_instance_valid(bullet) and not bullet.is_queued_for_deletion():
		_fail("Arquebus: the bullet must be released from the effect registry after the explosion.")
	await _cleanup(holder)


func _check_grenade_behavior() -> void:
	var holder := _new_scene("SoldierCompositionGrenade")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "soldier", "soldier_grenade")
	var enemy := _new_enemy(holder, "Center", owner.global_position + Vector2(220, 0))
	await process_frame
	var travel := (220.0 - 26.0) / clampf(float(weapon.projectile_speed), 60.0, 460.0)
	var fuse := maxf(float(weapon.grenade_delay), 0.20)
	weapon.call("_fire_grenade_fuse", owner, enemy, Vector2.RIGHT)
	var in_flight: Array = weapon.call("_alive_effects")
	if in_flight.size() != 2:
		_fail("Grenade: in flight the registry must hold telegraph + grenade (2), got %d." % in_flight.size())
		await _cleanup(holder)
		return
	var telegraph := in_flight[0] as Node
	var grenade := in_flight[1] as Node
	await create_timer(travel + fuse * 0.35).timeout
	if enemy.hit_count != 0:
		_fail("Grenade: no damage may land before the fuse ends.")
	await create_timer(fuse * 0.65 + 0.25).timeout
	if enemy.hit_count != 1 or absf(enemy.total_damage - 100.0) > EPS:
		_fail("Grenade: centre target expects one 100.0 hit after the fuse, got %d hits / %.2f." % [enemy.hit_count, enemy.total_damage])
	for released in [telegraph, grenade]:
		if is_instance_valid(released) and not (released as Node).is_queued_for_deletion():
			_fail("Grenade: telegraph and grenade must be released after the explosion.")
	# Множитель взрыва применяется к роллу урона (артефакт «Длинный фитиль»).
	enemy.hits.clear()
	weapon.call("_explode_grenade_fuse", 0, 0, owner.get_instance_id(), enemy.global_position, 120.0, 2.0, Vector2.RIGHT)
	if enemy.hits.size() != 1 or absf(enemy.hits[0] - 200.0) > EPS:
		_fail("Grenade: blast_damage_mult 2.0 expects a single 200.0 hit, got %s." % str(enemy.hits))
	await _cleanup(holder)


func _check_bayonet_behavior() -> void:
	var holder := _new_scene("SoldierCompositionBayonet")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "soldier", "soldier_bayonet")
	_disable_push(weapon)
	weapon.set("bayonet_auto_shot_chance", 0.0)
	var contact := _new_enemy(holder, "Contact", owner.global_position + Vector2(10, 0))
	var close := _new_enemy(holder, "Close", owner.global_position + Vector2(70, 6))
	var mid := _new_enemy(holder, "Mid", owner.global_position + Vector2(160, -30))
	var side := _new_enemy(holder, "Side", owner.global_position + Vector2(100, 0).rotated(deg_to_rad(80)))
	var behind := _new_enemy(holder, "Behind", owner.global_position + Vector2(-110, 0))
	var far := _new_enemy(holder, "Far", owner.global_position + Vector2(float(weapon.attack_range) + 90.0, 0))
	var beyond := _new_enemy(holder, "Beyond", owner.global_position + Vector2(420, 190))
	await process_frame
	weapon.call("_fire_bayonet_cone", owner, Vector2.RIGHT)
	await process_frame
	# Укол = один take_damage плюс близкий бонус (melee_close_bonus_radius) —
	# сумма 100 × melee_close_damage_multiplier вплотную, ровно 100 дальше.
	for hit_enemy in [contact, close, mid]:
		var stab := hit_enemy as MockEnemy
		var distance := owner.global_position.distance_to(stab.global_position)
		var expected_hits := _expected_stab_hits(weapon, distance)
		var expected_total := _expected_stab_total(weapon, distance)
		if stab.hit_count != expected_hits or absf(stab.total_damage - expected_total) > EPS:
			_fail("Bayonet: %s expects %d hit(s) totalling %.2f, got %d / %.2f." % [stab.name, expected_hits, expected_total, stab.hit_count, stab.total_damage])
	for miss_enemy in [side, behind, far, beyond]:
		if (miss_enemy as MockEnemy).hit_count != 0:
			_fail("Bayonet: %s is outside the cone and must not be hit." % (miss_enemy as MockEnemy).name)
	await _cleanup(holder)

	# chance = 1: выстрел гарантирован, доворачивает на ближайшую цель ЗА конусом
	# (в стороне от направления укола), урон = bayonet_shot_damage_multiplier от
	# укола первому врагу на траектории; цель в конусе получает только укол.
	holder = _new_scene("SoldierCompositionBayonetShot")
	owner = _new_owner(holder)
	weapon = _new_weapon(owner, "soldier", "soldier_bayonet")
	_disable_push(weapon)
	weapon.set("bayonet_auto_shot_chance", 1.0)
	var cone_enemy := _new_enemy(holder, "Cone", owner.global_position + Vector2(180, 0))
	var beyond_near := _new_enemy(holder, "BeyondNear", owner.global_position + Vector2(420, 190))
	var beyond_far := _new_enemy(holder, "BeyondFar", owner.global_position + Vector2(300, 400))
	await process_frame
	weapon.call("_fire_bayonet_cone", owner, Vector2.RIGHT)
	await process_frame
	var expected_shot := 100.0 * float(weapon.bayonet_shot_damage_multiplier)
	if beyond_near.hit_count != 1 or absf(beyond_near.total_damage - expected_shot) > EPS:
		_fail("Bayonet: auto shot expects one %.2f hit on the nearest target beyond the cone, got %d hits / %.2f." % [expected_shot, beyond_near.hit_count, beyond_near.total_damage])
	if beyond_far.hit_count != 0:
		_fail("Bayonet: the auto shot must pick the nearest target beyond the cone only.")
	if cone_enemy.hit_count != _expected_stab_hits(weapon, 180.0) or absf(cone_enemy.total_damage - _expected_stab_total(weapon, 180.0)) > EPS:
		_fail("Bayonet: the cone target must take only the stab (%d hits / %.2f)." % [cone_enemy.hit_count, cone_enemy.total_damage])
	await _cleanup(holder)


# Порядок RNG: пустая сцена ⇒ взмах штыка делает ровно два ролла — урон
# (_rolled_damage), затем шанс авто-выстрела — и ничего больше.
func _check_rng_order() -> void:
	var holder := _new_scene("SoldierCompositionRng")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "soldier", "soldier_bayonet")
	weapon.set("bayonet_auto_shot_chance", 0.0)
	await process_frame
	seed(TRACE_SEED)
	randf()
	randf()
	var expected_third := randf()
	seed(TRACE_SEED)
	weapon.call("_fire_bayonet_cone", owner, Vector2.RIGHT)
	var after_swing := randf()
	if absf(after_swing - expected_third) > 0.0:
		_fail("RNG: a bayonet swing without targets must consume exactly two rolls (damage, shot chance).")
	await _cleanup(holder)


# Путь _effects_shutdown: отложенные шаги гасят снаряды и не наносят урона.
func _check_effect_shutdown() -> void:
	var holder := _new_scene("SoldierCompositionShutdown")
	var owner := _new_owner(holder)
	var rifle := _new_weapon(owner, "soldier", "soldier_rifle")
	var enemy := _new_enemy(holder, "Center", owner.global_position + Vector2(200, 0))
	await process_frame
	rifle.call("_launch_arquebus_bullet", owner, enemy, Vector2.RIGHT)
	var bullet: Node = null
	for effect in (rifle.call("_alive_effects") as Array):
		bullet = effect as Node
	rifle.set("_effects_shutdown", true)
	rifle.call("_explode_arquebus_bullet", bullet.get_instance_id(), owner.get_instance_id(), enemy.global_position, Vector2.RIGHT)
	if enemy.hit_count != 0:
		_fail("Shutdown: an arquebus bullet resolving after shutdown must deal no damage.")
	if bullet == null or not bullet.is_queued_for_deletion():
		_fail("Shutdown: the arquebus bullet must be freed when resolving after shutdown.")

	var grenade_weapon := _new_weapon(owner, "soldier", "soldier_grenade")
	var grenade := Node2D.new()
	var telegraph := Node2D.new()
	holder.add_child(grenade)
	holder.add_child(telegraph)
	grenade_weapon.set("_effects_shutdown", true)
	grenade_weapon.call("_explode_grenade_fuse", grenade.get_instance_id(), telegraph.get_instance_id(), owner.get_instance_id(), enemy.global_position, 120.0, 1.0, Vector2.RIGHT)
	if enemy.hit_count != 0:
		_fail("Shutdown: a grenade resolving after shutdown must deal no damage.")
	if not grenade.is_queued_for_deletion() or not telegraph.is_queued_for_deletion():
		_fail("Shutdown: grenade and telegraph must be freed when resolving after shutdown.")
	await _cleanup(holder)


# Трасса: seed + крит-шанс делают порядок роллов наблюдаемым в суммах урона.
func _record_trace() -> void:
	var layouts := {
		"soldier_rifle": [Vector2(220, 0), Vector2(260, 40), Vector2(300, -30), Vector2(700, 0)],
		"soldier_grenade": [Vector2(220, 0), Vector2(260, 40), Vector2(300, -30), Vector2(700, 0)],
		"soldier_bayonet": [Vector2(10, 0), Vector2(70, 6), Vector2(160, -30), Vector2(420, 190)],
	}
	var waits := {"soldier_rifle": 0.7, "soldier_grenade": 2.4, "soldier_bayonet": 0.3}
	for weapon_id in ["soldier_rifle", "soldier_grenade", "soldier_bayonet"]:
		var holder := _new_scene("SoldierCompositionTrace_%s" % weapon_id)
		var owner := _new_owner(holder, Vector2(900, 700), 0.35)
		var weapon := _new_weapon(owner, "soldier", str(weapon_id))
		_disable_push(weapon)
		if weapon_id == "soldier_bayonet":
			weapon.set("bayonet_auto_shot_chance", 0.5)
		var enemies: Array[MockEnemy] = []
		var index := 0
		for offset in (layouts[weapon_id] as Array):
			enemies.append(_new_enemy(holder, "E%d" % index, owner.global_position + (offset as Vector2)))
			index += 1
		await process_frame
		seed(TRACE_SEED)
		var swings := 3 if weapon_id == "soldier_bayonet" else 1
		for swing in range(swings):
			weapon.call("_attack")
		await create_timer(float(waits[weapon_id])).timeout
		var hits := {}
		for enemy in enemies:
			var rounded: Array[String] = []
			for amount in enemy.hits:
				rounded.append("%.4f" % amount)
			hits[enemy.name] = rounded
		trace[weapon_id] = {
			"hits": hits,
			"rng_after": "%.9f" % randf(),
			"alive_effects": (weapon.call("_alive_effects") as Array).size(),
		}
		await _cleanup(holder)


func _write_trace() -> void:
	var out_path := OS.get_environment("FSD_SOLDIER_TRACE_OUT")
	if out_path.is_empty():
		return
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		_fail("Trace: cannot write %s." % out_path)
		return
	file.store_string(JSON.stringify(trace, "  ", true))
	file.close()
	print("FAN-3926 soldier trace written to %s" % out_path)


# --- 2) шов контекст/исполнитель ---------------------------------------------


func _check_seam_contract() -> void:
	if not ResourceLoader.exists(CONTEXT_PATH) or not ResourceLoader.exists(EXECUTOR_PATH):
		_fail("Seam: %s / %s are absent (pre-extraction base?)." % [CONTEXT_PATH, EXECUTOR_PATH])
		return
	var context_script := load(CONTEXT_PATH) as GDScript
	var executor_script := load(EXECUTOR_PATH) as GDScript
	var holder := _new_scene("SoldierCompositionSeam")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "soldier", "soldier_bayonet")
	await process_frame

	# Каждый член поверхности контекста существует на фасаде.
	var missing: Array = context_script.new(weapon).call("missing_weapon_members", weapon)
	if not missing.is_empty():
		_fail("Seam: facade lacks context members: %s." % ", ".join(missing))
	# Прежние методы фасада сохранены.
	for method_name in FACADE_METHODS:
		if not weapon.has_method(method_name):
			_fail("Seam: facade method %s must remain on soldier_weapon.gd." % method_name)

	# Исполнитель зовёт на контексте только объявленные методы и не трогает
	# фасад/цепочку/TARGET_QUERY напрямую.
	var context_methods := {}
	for method in context_script.get_script_method_list():
		context_methods[str(method.get("name", ""))] = true
	var executor_source := FileAccess.get_file_as_string(EXECUTOR_PATH)
	var context_call_re := RegEx.new()
	context_call_re.compile("(?<![A-Za-z0-9_])_context\\.([A-Za-z_][A-Za-z0-9_]*)")
	var used_context_methods := {}
	for match in context_call_re.search_all(executor_source):
		var name := match.get_string(1)
		used_context_methods[name] = true
		if not context_methods.has(name):
			_fail("Seam: executor calls undeclared context member %s." % name)
	var forbidden_re := RegEx.new()
	forbidden_re.compile("(?<![A-Za-z0-9_])(_weapon|TARGET_QUERY|get_tree\\(|get_parent\\(|self\\.)")
	var forbidden_match := forbidden_re.search(executor_source)
	if forbidden_match != null:
		_fail("Seam: executor must not reach the facade/chain directly (found '%s')." % forbidden_match.get_string(1))
	# Отложенные шаги — только через объявленные точки входа фасада.
	var deferred_re := RegEx.new()
	deferred_re.compile("deferred\\(&\"([A-Za-z_][A-Za-z0-9_]*)\"\\)")
	var declared_deferred := {}
	for name in (context_script.get_script_constant_map().get("DEFERRED_FACADE_METHODS", []) as Array):
		declared_deferred[str(name)] = true
	for match in deferred_re.search_all(executor_source):
		var name := match.get_string(1)
		if not declared_deferred.has(name):
			_fail("Seam: deferred step %s is not declared in DEFERRED_FACADE_METHODS." % name)
		if not weapon.has_method(name):
			_fail("Seam: deferred step %s is missing on the facade." % name)

	# Ни исполнитель, ни контекст не хранят копий состояния.
	var executor_fields := _script_field_names(executor_script)
	if executor_fields != ["_context"]:
		_fail("Seam: executor must keep a single field _context, got %s." % str(executor_fields))
	var context_fields := _script_field_names(context_script)
	if context_fields != ["_weapon"]:
		_fail("Seam: context must keep a single field _weapon, got %s." % str(context_fields))

	# Фасад больше не содержит выбора целей и роллов.
	var facade_source := FileAccess.get_file_as_string(FACADE_PATH)
	for logic_marker in ["randf(", "TARGET_QUERY", "AttackVfx", "create_tween("]:
		if facade_source.find(logic_marker) >= 0:
			_fail("Seam: facade still carries executor logic ('%s')." % logic_marker)

	# Измеренная поверхность зависимостей — в лог как evidence карточки.
	var declared_methods: int = (context_script.get_script_constant_map().get("REQUIRED_WEAPON_METHODS", []) as Array).size()
	var declared_properties: int = (context_script.get_script_constant_map().get("REQUIRED_WEAPON_PROPERTIES", []) as Array).size()
	print("FAN-3926 seam surface: %d context methods used by the executor; facade members forwarded: %d methods + %d properties + %d deferred entry points." % [used_context_methods.size(), declared_methods, declared_properties, declared_deferred.size()])
	await _cleanup(holder)


func _script_field_names(script: GDScript) -> Array[String]:
	var names: Array[String] = []
	for property in script.get_script_property_list():
		var usage := int(property.get("usage", 0))
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(str(property.get("name", "")))
	names.sort()
	return names


# --- 3) представительная локальная правка ------------------------------------


# Будущая правка Солдата (например, правило конуса) живёт в подклассе/файле
# исполнителя и подставляется в слот фасада: siblings и shared API не меняются.
# Подкласс собирается в рантайме, чтобы файл теста не зависел от новых скриптов
# статически (см. заголовок).
func _check_local_edit_seam() -> void:
	if not ResourceLoader.exists(EXECUTOR_PATH):
		return  # уже отмечено в секции шва
	var context_script := load(CONTEXT_PATH) as GDScript
	var local_edit := GDScript.new()
	local_edit.source_code = "extends \"%s\"\n\n# Локальная правка: удар назад в пределах 200 px тоже считается контактом.\nfunc is_enemy_inside_bayonet_cone(origin: Vector2, enemy_position: Vector2, direction: Vector2) -> bool:\n\tif origin.distance_to(enemy_position) <= 200.0:\n\t\treturn true\n\treturn super(origin, enemy_position, direction)\n" % EXECUTOR_PATH
	if local_edit.reload() != OK:
		_fail("Local edit: runtime subclass of the executor failed to compile.")
		return

	var holder := _new_scene("SoldierCompositionLocalEdit")
	var owner := _new_owner(holder)
	var weapon := _new_weapon(owner, "soldier", "soldier_bayonet")
	_disable_push(weapon)
	weapon.set("bayonet_auto_shot_chance", 0.0)
	var behind := _new_enemy(holder, "Behind", owner.global_position + Vector2(-110, 0))
	var front := _new_enemy(holder, "Front", owner.global_position + Vector2(160, 0))
	await process_frame
	var front_hits := _expected_stab_hits(weapon, 160.0)
	var behind_hits := _expected_stab_hits(weapon, 110.0)
	weapon.call("_fire_bayonet_cone", owner, Vector2.RIGHT)
	if behind.hit_count != 0 or front.hit_count != front_hits:
		_fail("Local edit: stock rule must hit only the front target (behind %d, front %d)." % [behind.hit_count, front.hit_count])
	weapon.set(EXECUTOR_SLOT, local_edit.new(context_script.new(weapon)))
	weapon.call("_fire_bayonet_cone", owner, Vector2.RIGHT)
	if behind.hit_count != behind_hits or front.hit_count != front_hits * 2:
		_fail("Local edit: the injected executor must now also stab the target behind (behind %d, front %d)." % [behind.hit_count, front.hit_count])

	# Сосед по цепочке (Снайпер) не зависит от слота Солдата.
	var sniper := _new_weapon(owner, "sniper", "sniper_deadeye_rifle")
	var far_target := _new_enemy(holder, "SniperTarget", owner.global_position + Vector2(minf(400.0, float(sniper.attack_range) - 40.0), 0))
	await process_frame
	sniper.call("_attack")
	await create_timer(maxf(float(sniper.grenade_delay), 0.08) + 0.3).timeout
	if far_target.hit_count == 0:
		_fail("Local edit: sibling Sniper lockshot must keep hitting its target.")
	await _cleanup(holder)
