extends "res://scripts/classes/guitarist_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса priest.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


func _exec_priest_sanctify(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_priest_sanctify(owner_node, target, direction)


func _exec_priest_ward(owner_node: Node2D, _target: Node2D, _direction: Vector2) -> void:
	_fire_priest_ward(owner_node)


func _exec_priest_dual_toll(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_priest_dual_toll(owner_node, target, direction)


# SCRUM-927: Реликварий — быстрый дальний бурст «тик-тик-тик» БЕЗ лечения
func _fire_priest_sanctify(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.08), direction, {"delayed": true})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 480.0)
	var target_id := 0
	if target != null:
		center = target.global_position
		target_id = target.get_instance_id()
	var mark := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(mark)
	# SCRUM-961 «Реликварный залп»: вспышки сильнее (+20%); темп — в
	# _fire_interval_artifact_factor (лечения у реликвария больше нет, SCRUM-927).
	var barrage_blast_mult := 1.2 if _owner_mod("reliquary_barrage_mode") > 0.0 else 1.0
	var tick_damage: float = _rolled_damage(owner_node) * clampf(sanctify_tick_ratio, 0.05, 1.0) * barrage_blast_mult
	var pulse_count: int = maxi(storm_ticks, 1)
	if target != null and is_instance_valid(target):
		target.set_meta(_constellation_mark_key("reliquary"), true)
		target.set_meta(_constellation_mark_key("reliquary_base"), tick_damage * float(pulse_count))
	for tick_index in range(pulse_count):
		var burst_tween := create_tween()
		burst_tween.tween_interval(maxf(grenade_delay, 0.08) + float(tick_index) * maxf(burst_interval, 0.06))
		# SCRUM-551: bound-метод вместо лямбды (анти use-after-free в tween).
		burst_tween.tween_callback(Callable(self, "_sanctify_burst_tick").bind(owner_node.get_instance_id(), target_id, center, direction, tick_index, pulse_count, tick_damage))
	# Снятие знака после последнего тика (mark по id — анти use-after-free).
	var release_tween := create_tween()
	var expiry_delay := maxf(grenade_delay, 0.08) + float(pulse_count) * maxf(burst_interval, 0.06) + 0.18
	release_tween.tween_interval(expiry_delay)
	release_tween.tween_callback(Callable(self, "_constellation_reliquary_expire_by_id").bind(owner_node.get_instance_id(), target_id, center, tick_damage * float(pulse_count)))
	release_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(mark.get_instance_id()))


# Один тик бурста реликвария: вспышка малого радиуса по живой позиции цели.
func _sanctify_burst_tick(owner_id: int, target_id: int, stored_center: Vector2, direction: Vector2, tick_index: int, tick_count: int, tick_damage: float) -> void:
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	var impact_center := stored_center
	var current_target := instance_from_id(target_id) as Node2D
	if current_target != null and is_instance_valid(current_target):
		impact_center = current_target.global_position
	if tick_index == 0:
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	else:
		_emit_weapon_animation_event(current_owner, "pulse", maxf(burst_interval, 0.06), direction, {"index": tick_index, "count": tick_count})
	AttackVfx.orb_burst(_projectile_parent(), impact_center, aoe_radius * 0.72, visual_color)
	_damage_enemies_in_circle_falloff(impact_center, aoe_radius, tick_damage, damage_falloff)


# SCRUM-928: Кадило — большой БЛИЗКИЙ AoE с долгим кулдауном. Редкие тяжёлые
func _fire_priest_ward(owner_node: Node2D) -> void:
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var pulse_count: int = maxi(storm_ticks, 1)
	# SCRUM-961 «Обет кадила»: пульс реже (fire_interval-фактор), но шире (+45%
	# радиуса) и больнее (+35%) — DPS ≈ паритет, пейсинг-переработка.
	var vow_mode := _owner_mod("censer_vow_mode") > 0.0
	var vow_radius_mult := 1.45 if vow_mode else 1.0
	var vow_damage_mult := 1.35 if vow_mode else 1.0
	_emit_weapon_animation_event(owner_node, "burst", maxf(burst_interval, 0.06) * float(maxi(pulse_count - 1, 1)), Vector2.RIGHT, {"count": pulse_count})
	var ward_duration := maxf(burst_interval, 0.06) * float(pulse_count) + 0.35
	if owner_node.has_method("meta_apply_priest_ward"):
		owner_node.call("meta_apply_priest_ward", ward_duration)
	var censer_profile := _constellation_profile("censer_absorb_retaliation")
	if not censer_profile.is_empty() and owner_node.has_method("constellation_set_single_hit_ward"):
		var censer_params: Dictionary = censer_profile.get("params", {})
		owner_node.call("constellation_set_single_hit_ward", "censer_%d" % get_instance_id(), clampf(float(censer_params.get("absorb_ratio", 0.18)), 0.0, 0.80), ward_duration)
	var damage_value: float = _rolled_damage(owner_node) * vow_damage_mult
	# FAN-1031 v8-микротрим: крауд-добор Жреца перенесён с каденции реликвария (смягчена выше)
	var ward_full := aoe_full_targets if aoe_full_targets >= 0 else 9999
	var ward_diminish := aoe_target_diminish if aoe_target_diminish >= 0.0 else 0.0
	for pulse_index in range(pulse_count):
		var ward_tween := create_tween()
		ward_tween.tween_interval(float(pulse_index) * maxf(burst_interval, 0.06))
		ward_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_owner := instance_from_id(owner_id) as Node2D
			if current_weapon == null or current_owner == null:
				return
			current_weapon.call("_emit_weapon_animation_event", current_owner, "pulse", maxf(float(current_weapon.get("burst_interval")), 0.06), Vector2.RIGHT, {"index": pulse_index, "count": pulse_count})
			# SCRUM-928: волны раскрываются от 0.80 до ПОЛНОГО aoe_radius —
			# «большой близкий AoE», заявленный радиус реально достигается.
			var pulse_progress := 1.0 if pulse_count <= 1 else float(pulse_index) / float(pulse_count - 1)
			var radius: float = float(current_weapon.get("aoe_radius")) * lerpf(0.80, 1.0, pulse_progress) * vow_radius_mult
			AttackVfx.ring_pulse(current_weapon.call("_projectile_parent"), current_owner.global_position, radius, current_weapon.get("visual_color"), false)
			current_weapon.call("_damage_enemies_in_circle_capped", current_owner.global_position, radius, damage_value, ward_full, ward_diminish)
		)


# SCRUM-929: Колокол Молитвы — dual toll. Каждый удар создаёт РОВНО два центра
func _fire_priest_dual_toll(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var bell_target: Node2D = target
	if bell_target == null:
		bell_target = _find_closest_enemy(owner_node, INF)
	var target_center: Vector2 = owner_node.global_position + direction * minf(attack_range, 480.0)
	if bell_target != null and is_instance_valid(bell_target):
		target_center = bell_target.global_position
	_emit_weapon_animation_event(owner_node, "release", 0.14, direction, {"dual": true})
	var damage_value: float = _rolled_damage(owner_node)
	# Резонанс-линия между центрами — читаемость связи двух взрывов (AC SCRUM-929).
	AttackVfx.beam(_projectile_parent(), owner_node.global_position, target_center, beam_width * 0.5, Color(visual_color.r, visual_color.g, visual_color.b, 0.26))
	var toll_hit := {}
	_fire_bell_toll_blast(target_center, damage_value, toll_hit)
	_fire_bell_toll_blast(owner_node.global_position, damage_value, toll_hit)
	if toll_hit.size() >= 3:
		var return_result := _constellation_event("return", null, 0.0, {"unique_targets": toll_hit.size()})
		if bool(return_result.get("triggered", false)) and owner_node.has_method("constellation_set_timed_absorb"):
			var mechanic = owner_node.call("constellation_weapon_mechanic", weapon_id, "chime_owner_return_shield") if owner_node.has_method("constellation_weapon_mechanic") else {}
			var params: Dictionary = (mechanic as Dictionary).get("params", {}) if mechanic is Dictionary else {}
			var shield := minf(float(owner_node.get("max_health")) * clampf(float(params.get("return_shield_ratio", 0.12)), 0.0, 1.0), maxf(float(params.get("shield_cap", 18.0)), 0.0))
			owner_node.call("constellation_set_timed_absorb", "chime_%d" % get_instance_id(), shield, 4.0)
	# SCRUM-961 «Двойной колокол» (rework под dual-toll базу SCRUM-929): эхо-звон —
	# оба взрыва повторяются через 0.45с на 45% урона (свой дедуп на эхо-волну).
	if _owner_mod("chime_twin_toll") > 0.0:
		var echo_tween := create_tween()
		echo_tween.tween_interval(0.45)
		# SCRUM-551: bound-метод вместо лямбды (анти use-after-free в tween).
		echo_tween.tween_callback(Callable(self, "_fire_bell_echo_toll").bind(owner_node.get_instance_id(), target_center, damage_value * 0.45))


# Эхо-волна «Двойного колокола»: повторный dual toll со своим дедупом.
func _fire_bell_echo_toll(owner_id: int, target_center: Vector2, amount: float) -> void:
	if _effects_shutdown:
		return
	var echo_hit := {}
	_fire_bell_toll_blast(target_center, amount, echo_hit)
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner != null and is_instance_valid(current_owner):
		_fire_bell_toll_blast(current_owner.global_position, amount, echo_hit)


# Одиночный взрыв колокола с общим дедупом волны: враг в перекрытии двух
# центров ловит урон ровно один раз (per-enemy max-hit, SCRUM-929).
func _fire_bell_toll_blast(center: Vector2, amount: float, toll_hit: Dictionary) -> void:
	AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, false)
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius * 0.55, visual_color)
	for enemy in TARGET_QUERY.in_radius(self, center, aoe_radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var enemy_id := enemy_node.get_instance_id()
		if toll_hit.has(enemy_id):
			continue
		toll_hit[enemy_id] = true
		_damage_enemy(enemy_node, amount)


func _constellation_reliquary_expire_by_id(owner_id: int, target_id: int, fallback_center: Vector2, burst_base: float) -> void:
	if _effects_shutdown:
		return
	var owner_node := instance_from_id(owner_id) as Node2D
	var target := instance_from_id(target_id) as Node2D
	if target == null or not is_instance_valid(target):
		return
	_constellation_reliquary_expire(owner_node, target, target.global_position if is_instance_valid(target) else fallback_center, burst_base)


func _constellation_reliquary_expire(owner_node: Node2D, target: Node2D, center: Vector2, burst_base: float) -> Dictionary:
	if owner_node == null or target == null or not is_instance_valid(target):
		return {"valid": true, "triggered": false}
	var mark_key := _constellation_mark_key("reliquary")
	if not bool(target.get_meta(mark_key, false)):
		return {"valid": true, "triggered": false}
	target.remove_meta(mark_key)
	var stored_base := float(target.get_meta(_constellation_mark_key("reliquary_base"), burst_base))
	target.remove_meta(_constellation_mark_key("reliquary_base"))
	var expiry := _constellation_event("expiry", target, 0.0, {"constellation_consumer_event": true})
	if not bool(expiry.get("triggered", false)):
		return expiry
	var wave_damage := maxf(stored_base, 0.0) * _constellation_result_param(expiry, "damage_ratio", 0.40)
	_damage_enemies_in_circle(center, aoe_radius, wave_damage)
	var now_msec := Time.get_ticks_msec()
	var window_start := int(_constellation_local_state.get("reliquary_heal_window_msec", 0))
	if now_msec - window_start >= 1000:
		window_start = now_msec
		_constellation_local_state["reliquary_healed"] = 0.0
	_constellation_local_state["reliquary_heal_window_msec"] = window_start
	var cap := _constellation_result_param(expiry, "heal_per_second_cap", 1.6)
	var already := float(_constellation_local_state.get("reliquary_healed", 0.0))
	var heal_amount := minf(wave_damage * _constellation_result_param(expiry, "heal_ratio", 0.08), maxf(cap - already, 0.0))
	if heal_amount > 0.0:
		var previous_health := float(owner_node.get("health"))
		var maximum := float(owner_node.get("max_health"))
		var actual := minf(heal_amount, maxf(maximum - previous_health, 0.0))
		owner_node.set("health", previous_health + actual)
		_constellation_local_state["reliquary_healed"] = already + actual
	return expiry
