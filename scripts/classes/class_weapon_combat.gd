extends "res://scripts/classes/class_weapon_core.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — общий боевой слой: цели/урон/статусы/лужи/капы ширины и диспетчеризация событий созвездий.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


const TAKE_DAMAGE_CONTRACT := preload("res://scripts/take_damage_contract.gd")


# SCRUM-533: тик ЛУЖИ (DoT-облако) с диминишингом по числу целей. Раньше каждый
const POOL_FULL_TARGETS := 1


const POOL_TARGET_DIMINISH := 1.5


const AOE_PROJECTILE_FULL_TARGETS := 5


const AOE_PROJECTILE_TARGET_DIMINISH := 2.0


const POOL_PROJECTILE_FULL_TARGETS := 1


const POOL_PROJECTILE_TARGET_DIMINISH := 3.0


const POOL_PROJECTILE_DAMAGE_MULTIPLIER := 0.55


# FAN-1031 3c(b): дефолт STATUS fan-out — БЕЗ диминиша (diminish 0 → factor==1 для
# всех рангов), чтобы оружия без override не меняли поведение (нулевой A/B-контроль).
# Оффендеры опт-инятся полями status_full_targets/status_target_diminish в конфиге.
const STATUS_FANOUT_FULL_TARGETS := 4


const STATUS_FANOUT_TARGET_DIMINISH := 0.0


# FAN-1031 3c(b2): дефолт FALLOFF/ORBIT fan-out — БЕЗ диминиша (diminish 0 → factor==1
# для всех рангов), чтобы оружия без override не меняли поведение (нулевой A/B-контроль).
# Оффендер опт-инится полями falloff_*/orbit_* в конфиге.
const FALLOFF_FANOUT_FULL_TARGETS := 4


const FALLOFF_FANOUT_TARGET_DIMINISH := 0.0


# SCRUM-944: базовый префикс id вечных кислотных зарядов (+ instance id лужи).
const ACID_CHARGE_STATUS_PREFIX := "acid_charge"


# SCRUM-944: «вечность» заряда — живёт до смерти носителя (раунды много короче).
const ACID_CHARGE_PERSIST_SECONDS := 999999.0


# SCRUM-961 «Кислотный катализатор»: артефакт поднимает кап зарядов на цель.
const ACID_CHARGE_ARTIFACT_CAP_BONUS := 3


func _extra_projectiles() -> int:
	var owner_node := _owner_node()
	if owner_node == null:
		return 0
	# FAN-1893: generic-ось «+1 снаряд» потребляется ТОЛЬКО оружием с явной
	# capability real_projectile_count > 0 — тогда каждый пункт добавляет ровно
	# один реальный снаряд боевого пути. У обычного оружия это его выстрел;
	# engineer_sentry_link читает шов из try_fire каждой активной турели, поэтому
	# один пункт добавляет по снаряду к каждому её залпу, но не меняет парк,
	# cadence, damage или summon scaling. Для остальных оружий generic-ключ
	# инертен (перегруженные интерпретации «лишняя ловушка/тик/звено/ширина»
	# удалены); семантические мета-ключи (trap_extra_count и т.п.) остаются.
	# FAN-2247: player-facing source отсутствует; direct probes и injected/future
	# values проверяют runtime seam, но не означают доступную игроку награду.
	var generic_extra := 0
	if real_projectile_count > 0:
		var mods = owner_node.get("run_modifiers")
		if mods is Dictionary:
			generic_extra = maxi(int((mods as Dictionary).get("extra_projectile", 0.0)), 0)
	var semantic_extra := 0
	if owner_node.has_method("meta_extra_projectiles"):
		semantic_extra = int(owner_node.call("meta_extra_projectiles", _meta_context()))
	return generic_extra + semantic_extra


func _effective_pierce_count() -> int:
	var owner_node := _owner_node()
	var extra := 0
	if owner_node != null and owner_node.has_method("meta_extra_pierce"):
		extra = int(owner_node.call("meta_extra_pierce", _meta_context({"charge_seconds": charge_seconds})))
	return maxi(pierce_count + extra, 1)


func _meta_context(extra := {}) -> Dictionary:
	var owner_node := _owner_node()
	var payload: Dictionary = extra.duplicate(true) if extra is Dictionary else {}
	payload["pool_element"] = pool_element
	payload["leaves_pool"] = leaves_pool
	payload["summon_role"] = summon_role
	payload["charge_seconds"] = charge_seconds
	if owner_node != null and owner_node.has_method("meta_context_for_weapon"):
		return owner_node.call("meta_context_for_weapon", self, payload)
	payload["weapon_id"] = weapon_id
	payload["attack_mode"] = attack_mode
	payload["damage_parameter"] = damage_parameter
	payload["damage_type"] = str(payload.get("damage_type", _weapon_damage_type()))
	return payload


func _constellation_event(event: String, enemy: Node2D = null, base_damage := 0.0, extra := {}) -> Dictionary:
	var owner_node := _owner_node()
	if owner_node == null or not owner_node.has_method("constellation_weapon_event"):
		return {"valid": true, "triggered": false}
	var context := _meta_context(extra)
	var resolution: Dictionary = owner_node.call("constellation_weapon_event", weapon_id, event, context, enemy)
	if not bool(resolution.get("valid", false)) or not bool(resolution.get("triggered", false)):
		return resolution
	var bonus_ratio := maxf(float(resolution.get("damage_multiplier", 1.0)) - 1.0, 0.0)
	if enemy != null and is_instance_valid(enemy) and base_damage > 0.0 and bonus_ratio > 0.0:
		_call_take_damage(enemy, base_damage * bonus_ratio, {"damage_type": _weapon_damage_type()})
	return resolution


func _constellation_result_param(result: Dictionary, key: String, fallback: float) -> float:
	var params = result.get("params", {})
	return float((params as Dictionary).get(key, fallback)) if params is Dictionary else fallback


func _constellation_profile(mechanic_id: String) -> Dictionary:
	var owner_node := _owner_node()
	if owner_node == null or not owner_node.has_method("constellation_weapon_mechanic"):
		return {}
	var raw = owner_node.call("constellation_weapon_mechanic", weapon_id, mechanic_id)
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func _constellation_mark_key(label: String) -> String:
	var owner_node := _owner_node()
	var owner_id := owner_node.get_instance_id() if owner_node != null else 0
	return "constellation_%s_%d" % [label, owner_id]


func _arm_constellation_target_mark(enemy: Node, label: String, duration: float, bonus: float, threshold := 1.0) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	enemy.set_meta(_constellation_mark_key(label), {
		"until_msec": Time.get_ticks_msec() + int(maxf(duration, 0.0) * 1000.0),
		"bonus": clampf(bonus, 0.0, 0.55),
		"threshold": clampf(threshold, 0.0, 1.0),
	})


func _consume_constellation_target_mark(enemy: Node, label: String, fallback_multiplier := 1.0) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return fallback_multiplier
	var key := _constellation_mark_key(label)
	var raw = enemy.get_meta(key, {})
	if not raw is Dictionary or (raw as Dictionary).is_empty():
		return fallback_multiplier
	var mark: Dictionary = raw
	if Time.get_ticks_msec() > int(mark.get("until_msec", 0)):
		enemy.remove_meta(key)
		return fallback_multiplier
	var max_hp_value = enemy.get("max_health")
	var hp_value = enemy.get("health")
	var threshold := float(mark.get("threshold", 1.0))
	if max_hp_value != null and hp_value != null and float(max_hp_value) > 0.0 and float(hp_value) / float(max_hp_value) > threshold:
		return fallback_multiplier
	enemy.remove_meta(key)
	return fallback_multiplier + clampf(float(mark.get("bonus", 0.0)), 0.0, 0.55)


func _advance_constellation_target_stack(enemy: Node, label: String, cap: int, duration: float) -> int:
	if enemy == null or not is_instance_valid(enemy):
		return 0
	var key := _constellation_mark_key(label)
	var raw = enemy.get_meta(key, {})
	var entry: Dictionary = raw if raw is Dictionary else {}
	var now_msec := Time.get_ticks_msec()
	var count := int(entry.get("count", 0)) if now_msec <= int(entry.get("until_msec", 0)) else 0
	count = mini(count + 1, maxi(cap, 1))
	enemy.set_meta(key, {"count": count, "until_msec": now_msec + int(maxf(duration, 0.0) * 1000.0)})
	return count


func constellation_owner_event(event: String, context := {}, enemy: Node2D = null) -> Dictionary:
	var payload: Dictionary = context if context is Dictionary else {}
	var base_damage := float(payload.get("dealt_damage", damage))
	var owner_node := _owner_node()
	if event == "dodge" and weapon_id == "thief_smoke_bomb" and bool(payload.get("smoke_zone", false)) and owner_node != null:
		var cloud_id := int(payload.get("smoke_cloud_id", 0))
		if cloud_id <= 0 or not owner_node.has_method("consume_smoke_cloud_constellation_burst") or not bool(owner_node.call("consume_smoke_cloud_constellation_burst", cloud_id)):
			return {"valid": true, "triggered": false}
		var center: Vector2 = payload.get("smoke_center", owner_node.global_position)
		var target := TARGET_QUERY.nearest(self, center, aoe_radius)
		var smoke_result := _constellation_event("dodge", target, 0.0, payload)
		if bool(smoke_result.get("triggered", false)):
			var burst_damage := _rolled_damage(owner_node) * _constellation_result_param(smoke_result, "burst_damage_ratio", 0.40)
			_damage_enemies_in_circle(center, aoe_radius, burst_damage)
			for affected in TARGET_QUERY.in_radius(self, center, aoe_radius):
				StatusEffects.apply_status(affected, "constellation_smoke_slow", {"duration": _constellation_result_param(smoke_result, "slow_seconds", 1.4), "speed_multiplier": 0.60})
		return smoke_result
	if event == "damage_absorbed" and weapon_id == "priest_censer" and owner_node != null:
		if str(payload.get("constellation_ward_source", "")) != ("censer_%d" % get_instance_id()):
			return {"valid": true, "triggered": false}
		var now_msec := Time.get_ticks_msec()
		if now_msec < int(_constellation_local_state.get("censer_ready_msec", 0)):
			return {"valid": true, "triggered": false}
		var target := TARGET_QUERY.nearest(self, owner_node.global_position, aoe_radius)
		if target == null:
			return {"valid": true, "triggered": false}
		var retaliation := _constellation_event("damage_absorbed", target, 0.0, payload)
		if bool(retaliation.get("triggered", false)):
			_constellation_local_state["censer_ready_msec"] = now_msec + int(_constellation_result_param(retaliation, "cooldown_seconds", 1.5) * 1000.0)
			_damage_enemies_in_circle(target.global_position, aoe_radius, _rolled_damage(owner_node) * _constellation_result_param(retaliation, "retaliation_damage_ratio", 0.45))
		return retaliation
	if event == "execute" and weapon_id == "shadow_daggers" and owner_node != null and enemy != null and not TARGET_QUERY.is_epic_displacement_immune(enemy):
		var now_msec := Time.get_ticks_msec()
		if now_msec < int(_constellation_local_state.get("shadow_window_ready_msec", 0)):
			return {"valid": true, "triggered": false}
		var window := _constellation_event("execute", enemy, 0.0, payload)
		if bool(window.get("triggered", false)) and owner_node.has_method("constellation_set_timed_dodge"):
			owner_node.call("constellation_set_timed_dodge", "shadow_window_%d" % get_instance_id(), _constellation_result_param(window, "dodge_bonus", 0.18), _constellation_result_param(window, "window_seconds", 0.75))
			_constellation_local_state["shadow_window_ready_msec"] = now_msec + int(_constellation_result_param(window, "cooldown_seconds", 3.0) * 1000.0)
		return window
	if event == "kill" and weapon_id == "cursed_skull" and enemy != null:
		return _constellation_transfer_skull_curse(enemy, payload)
	if event == "kill" and weapon_id == "biologist_symbiote_seed" and enemy != null and owner_node != null:
		var transferred := _constellation_transfer_symbiote_host(enemy, owner_node)
		return {"valid": true, "triggered": transferred}
	if event == "expiry" and weapon_id == "priest_reliquary":
		if enemy != null and bool(enemy.get_meta(_constellation_mark_key("reliquary"), false)):
			return _constellation_reliquary_expire(owner_node, enemy, enemy.global_position, base_damage)
		return {"valid": true, "triggered": false}
	match event:
		"block": return _constellation_event("block", enemy, base_damage, payload)
		"dodge": return _constellation_event("dodge", enemy, base_damage, payload)
		"damage_absorbed": return _constellation_event("damage_absorbed", enemy, base_damage, payload)
		"kill": return _constellation_event("kill", enemy, base_damage, payload)
		"execute": return _constellation_event("execute", enemy, base_damage, payload)
		"expiry": return _constellation_event("expiry", enemy, base_damage, payload)
	return {"valid": true, "triggered": false}


func _find_closest_enemy(owner_node: Node2D, range_limit := -1.0) -> Node2D:
	var max_distance := attack_range if range_limit < 0.0 else range_limit
	return TARGET_QUERY.nearest(self, owner_node.global_position, max_distance)


func _owner_uses_cursor_aim(owner_node: Node) -> bool:
	return owner_node != null and owner_node.has_method("attack_aim_mode") and str(owner_node.call("attack_aim_mode")) == "cursor"


func _enemies_in_corridor(origin: Vector2, direction: Vector2, width: float, range_limit: float) -> Array:
	return TARGET_QUERY.in_corridor(self, origin, direction, width, range_limit, _line_back_allowance(origin))


func _line_back_allowance(origin: Vector2) -> float:
	var owner_node := _owner_node()
	if owner_node == null:
		return 0.0
	if origin.distance_squared_to(owner_node.global_position) <= CONTACT_STUCK_HIT_BACK_ALLOWANCE * CONTACT_STUCK_HIT_BACK_ALLOWANCE:
		return CONTACT_STUCK_HIT_BACK_ALLOWANCE
	return 0.0


func _find_nearest_enemy_from(origin: Vector2, range_limit: float, excluded_ids: Dictionary) -> Node2D:
	return TARGET_QUERY.nearest(self, origin, range_limit, excluded_ids)


func _is_enemy_inside_wave(origin: Vector2, enemy_position: Vector2, direction: Vector2) -> bool:
	var perpendicular := Vector2(-direction.y, direction.x)
	var to_enemy := enemy_position - origin
	var forward := to_enemy.dot(direction)
	if forward < -CONTACT_STUCK_HIT_BACK_ALLOWANCE or forward > attack_range:
		return false
	var width_ratio: float = clamp(forward / max(attack_range, 1.0), 0.0, 1.0)
	# SCRUM-961 «Зубья костяной пилы»: веер пилы шире (+saw_arc_width_mult).
	var effective_wave_width := wave_width
	if attack_mode == "stab_flurry":
		effective_wave_width *= 1.0 + _owner_mod("saw_arc_width_mult")
	var half_width := lerpf(58.0, effective_wave_width * 0.5, width_ratio)
	return abs(to_enemy.dot(perpendicular)) <= half_width


# SCRUM-523: КАНАЛ урона оружия → строковый тип для палитры боевых цифр.
func _weapon_damage_type() -> String:
	match damage_parameter:
		"magic_damage":
			return "magic"
		_:
			return "physical"


func _damage_enemy(enemy: Node, amount: float, apply_unique_melee_effects := true, damage_type := "", notify_owner_hit := true) -> void:
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("take_damage"):
		var hit_type := damage_type if damage_type != "" else _weapon_damage_type()
		var owner_node := _owner_node()
		var hit_context := _meta_context({"damage_type": hit_type})
		if owner_node != null and owner_node.has_method("telemetry_context_for_hit"):
			hit_context = owner_node.call("telemetry_context_for_hit", hit_context)
		var is_critical := _last_attack_crit and apply_unique_melee_effects
		hit_context["critical"] = is_critical
		var final_amount := amount
		if owner_node != null and owner_node.has_method("meta_damage_multiplier"):
			final_amount *= float(owner_node.call("meta_damage_multiplier", hit_context, enemy))
		if hit_type != "dot":
			match weapon_id:
				"thief_shadow_cloak": final_amount *= _consume_constellation_target_mark(enemy, "backstab")
				"robot_magnetic_anchor": final_amount *= _consume_constellation_target_mark(enemy, "anchor")
				"moon_crossbow": final_amount *= _consume_constellation_target_mark(enemy, "moon")
		# SCRUM-1005 «Разбор образцов»: ПРЯМЫЕ хиты владельца по цели под ЕГО
		if hit_type != "dot" and owner_node != null and owner_node.has_method("class_trait_value"):
			var infected_multiplier := maxf(float(owner_node.call("class_trait_value", "infected_direct_hit_multiplier", 1.0)), 1.0)
			if infected_multiplier > 1.0 and StatusEffects.has_dot_from_source(enemy, owner_node.get_instance_id()):
				final_amount *= infected_multiplier
			# SCRUM-930 «Дальний расчёт»: урон оружия Снайпера растёт с дистанцией
			final_amount *= _class_distance_trait_multiplier(owner_node, enemy as Node2D)
		var hit_feedback := {"critical": is_critical, "damage_type": hit_type}
		if owner_node != null and owner_node.has_method("telemetry_feedback_for_hit"):
			hit_feedback = owner_node.call("telemetry_feedback_for_hit", hit_context, hit_feedback)
		_call_take_damage(enemy, final_amount, hit_feedback)
		_apply_constellation_symbiote_share(enemy, owner_node, final_amount, hit_type)
		_apply_constellation_prey_distribution(enemy, owner_node, final_amount, hit_type)
		# SCRUM-961: он-хит статусы и дубль-выстрел солдата (только прямые хиты).
		if apply_unique_melee_effects:
			_apply_class_on_hit_statuses(enemy)
			_apply_ranger_bow_knockback(enemy)  # SCRUM-909 «Сторожевой лук»
			_maybe_duplicate_hit(enemy, final_amount, hit_type)
		if notify_owner_hit and owner_node != null and owner_node.has_method("on_weapon_hit"):
			owner_node.on_weapon_hit(enemy, final_amount, _last_attack_crit, hit_context)  # SCRUM-500/SCRUM-835: крит + semantic hit context
		_heal_owner_from_damage(owner_node, final_amount)
		if _last_attack_crit and crit_shadow_burst_radius > 0.0 and owner_node != null and owner_node.has_method("trigger_assassin_crit_shadow"):
			owner_node.trigger_assassin_crit_shadow(enemy, crit_shadow_burst_radius)
		if apply_unique_melee_effects and owner_node != null:
			_apply_unique_melee_hit_effects(owner_node, enemy, final_amount)


# SCRUM-930 «Дальний расчёт»: множитель дистанции для прямого хита владельца.
func _class_distance_trait_multiplier(owner_node: Node2D, enemy_node: Node2D) -> float:
	if owner_node == null or enemy_node == null or not is_instance_valid(enemy_node):
		return 1.0
	var per_100 := float(owner_node.call("class_trait_value", "distance_damage_per_100px", 0.0))
	if per_100 <= 0.0:
		return 1.0
	var cap_bonus := float(owner_node.call("class_trait_value", "distance_damage_cap_bonus", 0.0))
	var free_range := float(owner_node.call("class_trait_value", "distance_damage_free_range", 0.0))
	var distance := owner_node.global_position.distance_to(enemy_node.global_position)
	return ProgressionData.distance_trait_multiplier(per_100, cap_bonus, free_range, distance)


func _apply_unique_melee_hit_effects(owner_node: Node2D, enemy: Node, amount: float) -> void:
	var enemy_node := enemy as Node2D
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	var direction := enemy_node.global_position - owner_node.global_position
	var distance := direction.length()
	# SCRUM-523: добивания/осколки красим тем же каналом, что основное попадание.
	var hit_type := _weapon_damage_type()
	if melee_close_bonus_radius > 0.0 and melee_close_damage_multiplier > 1.0 and distance <= melee_close_bonus_radius:
		_call_take_damage(enemy_node, amount * (melee_close_damage_multiplier - 1.0), {"damage_type": hit_type})
	if melee_execute_threshold > 0.0 and melee_execute_multiplier > 1.0:
		var max_hp := float(enemy_node.get("max_health")) if enemy_node.get("max_health") != null else 0.0
		var health := float(enemy_node.get("health")) if enemy_node.get("health") != null else max_hp
		if max_hp > 0.0 and health / max_hp <= melee_execute_threshold:
			_call_take_damage(enemy_node, amount * (melee_execute_multiplier - 1.0), {"damage_type": hit_type})
	if melee_stagger_knockback_multiplier > 0.0 and direction.length_squared() > 0.001:
		_push_enemy_scaled(enemy_node, direction.normalized(), melee_stagger_knockback_multiplier)
	if melee_arc_followup_radius > 0.0 and melee_arc_followup_multiplier > 0.0:
		var splash_damage := amount * melee_arc_followup_multiplier
		for nearby in TARGET_QUERY.in_radius(self, enemy_node.global_position, melee_arc_followup_radius):
			if nearby == enemy_node:
				continue
			if nearby.has_method("take_damage"):
				_call_take_damage(nearby, splash_damage, {"damage_type": hit_type})
	# SCRUM-603: мили лечение-при-ударе тоже через per-second бюджет (capped).
	if melee_heal_percent_on_hit > 0.0 and owner_node.has_method("heal_percent_capped"):
		owner_node.heal_percent_capped(melee_heal_percent_on_hit)
	elif melee_heal_percent_on_hit > 0.0 and owner_node.has_method("heal_percent"):
		owner_node.heal_percent(melee_heal_percent_on_hit)


func _damage_enemy_with_dot(enemy: Node, direct_damage: float, owner_node: Node2D) -> void:
	var wire_damage := direct_damage
	if not _constellation_profile("wire_poison_ramp_snap").is_empty():
		var wire_stacks := _advance_constellation_target_stack(enemy, "wire_poison", 5, 3.0)
		var wire_event := _constellation_event("hit", enemy as Node2D, 0.0, {"wire_stacks": wire_stacks, "constellation_consumer_event": true})
		wire_damage *= 1.0 + 0.06 * float(wire_stacks)
		if bool(wire_event.get("triggered", false)):
			_call_take_damage(enemy, direct_damage * _constellation_result_param(wire_event, "snap_damage_ratio", 0.55), {"damage_type": _weapon_damage_type(), "constellation_final": "wire_poison_ramp_snap"})
	_damage_enemy(enemy, wire_damage)
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var tick_damage := float(parameters.get("dot_damage", max(1.0, direct_damage * 0.22)))
	# SCRUM-894: крит-снапшот яда (dot_crit_snapshot_ratio > 0, Ядовитая струна) —
	# критовый прямой удар усиливает тики долей крит-множителя, зафиксированного
	# на момент каста (_last_attack_crit из _rolled_damage). Выше raw 2.75
	# множитель использует убывающий sqrt-tail без верхнего потолка.
	if dot_crit_snapshot_ratio > 0.0 and _last_attack_crit:
		tick_damage *= 1.0 + maxf(float(parameters.get("crit_damage_multiplier", 1.0)) - 1.0, 0.0) * clampf(dot_crit_snapshot_ratio, 0.0, 1.0)
	var tick_speed: float = max(float(parameters.get("dot_speed", 1.0)), 0.2)
	if dot_ticks <= 0:
		return
	# SCRUM-961: классовые артефакты продлевают DoT-идентичность конкретных линий
	# («Ядовитая катушка» — Ядовитая струна). SCRUM-896: биологические оружия
	# сюда больше не ходят — их периодика живёт статусом bio_infection
	# (_apply_bio_infection, symbiote_dot_extra_ticks учитывается там).
	var extra_ticks := 0
	if attack_mode == "dot_beam":
		extra_ticks = int(_owner_mod("venom_dot_extra_ticks"))
	# Tween на оружии замораживается паузой, в отличие от SceneTreeTimer.
	var dot_color := Color(visual_color.r, visual_color.g, visual_color.b, 1.0)
	var dot_tween := create_tween()
	for tick_index in range(dot_ticks + extra_ticks):
		dot_tween.tween_interval(1.0 / tick_speed)
		# SCRUM-551: bound-метод вместо лямбды с захватом локала `enemy` (Node). Захват
		# узла в lambda-callable интермиттентно «освобождался» под быстрым create/free
		# оружия и врагов в balance-CSV (ERROR: Lambda capture at index 1 was freed,
		# gdscript_lambda_callable.cpp:110) и валил прогон. Callable.bind держит self
		# (живёт пока жив tween) + value-args; гвард is_instance_valid внутри метода.
		dot_tween.tween_callback(Callable(self, "_apply_weapon_dot_tick").bind(enemy, tick_damage, dot_color))


func _apply_weapon_dot_tick(enemy: Node, tick_damage: float, dot_color: Color) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	_damage_enemy(enemy, tick_damage, false, "dot", false)
	if enemy is Node2D:
		HazardVfx.dot_tick(enemy, dot_color)


func _damage_enemies_in_circle(origin: Vector2, radius: float, amount: float) -> void:
	for enemy_node in TARGET_QUERY.in_radius(self, origin, radius):
		_damage_enemy(enemy_node, amount)


func _damage_aoe_projectile_explosion(origin: Vector2, radius: float, amount: float) -> void:
	# FAN-1031 S1: per-weapon override прямого AoE-капа (сентинел <0 → общий default).
	var full_targets := aoe_full_targets if aoe_full_targets >= 0 else AOE_PROJECTILE_FULL_TARGETS
	var target_diminish := aoe_target_diminish if aoe_target_diminish >= 0.0 else AOE_PROJECTILE_TARGET_DIMINISH
	# SCRUM-961 «Летучая пыль»: без облака взрыв прямой (+25%, каппинг обычного AoE).
	if _volatile_powder_active():
		_damage_enemies_in_circle_capped(origin, radius, amount * 1.25, full_targets, target_diminish)
		return
	if leaves_pool:
		# FAN-1031 3c(a): прямая leaves_pool-ветка тоже уважает per-weapon override
		# (сентинел <0 → общий POOL_PROJECTILE_* default).
		var pool_full := pool_full_targets if pool_full_targets >= 0 else POOL_PROJECTILE_FULL_TARGETS
		var pool_diminish := pool_target_diminish if pool_target_diminish >= 0.0 else POOL_PROJECTILE_TARGET_DIMINISH
		_damage_enemies_in_circle_capped(origin, radius, amount * POOL_PROJECTILE_DAMAGE_MULTIPLIER * pool_direct_damage_multiplier, pool_full, pool_diminish)
		return
	_damage_enemies_in_circle_capped(origin, radius, amount, full_targets, target_diminish)


# FAN-1031 3c: диминиш-факторы крауд-fan-out каналов (STATUS/FALLOFF/ORBIT) — обёртки над
# WeaponCrowdCaps.fanout_factor с per-weapon полями + сентинел-дефолтами. Канон и профиль
# каждого канала: docs/design/systems/progression_balance.md. Ранг = дистанция от центра.
func _status_fanout_factor(rank: int) -> float:
	return WEAPON_CROWD_CAPS.fanout_factor(rank, status_full_targets, status_target_diminish, status_max_targets, STATUS_FANOUT_FULL_TARGETS, STATUS_FANOUT_TARGET_DIMINISH)


func _falloff_fanout_factor(rank: int) -> float:
	return WEAPON_CROWD_CAPS.fanout_factor(rank, falloff_full_targets, falloff_target_diminish, -1, FALLOFF_FANOUT_FULL_TARGETS, FALLOFF_FANOUT_TARGET_DIMINISH)


# FAN-1031 3c(b): дистанционно-отсортированный список врагов в радиусе — ранг
# определяет диминиш крауд-DoT (_status_fanout_factor). Дубликат исходной выборки,
# чтобы не тревожить порядок вызывающего (constellation-логика читает свой порядок).
func _status_fanout_order(origin: Vector2, enemies: Array) -> Array:
	var ordered := enemies.duplicate()
	ordered.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return ordered


func _retire_excess_damage_pools(new_pool: Node2D) -> void:
	var active_pools: Array[Node2D] = []
	for cloud_node in get_tree().get_nodes_in_group("chemist_clouds"):
		if not (cloud_node is Node2D):
			continue
		if int(cloud_node.get_meta("pool_weapon_owner", 0)) != get_instance_id():
			continue
		active_pools.append(cloud_node as Node2D)
	active_pools.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		if a == new_pool:
			return false
		if b == new_pool:
			return true
		return int(a.get_instance_id()) < int(b.get_instance_id())
	)
	while active_pools.size() > MAX_ACTIVE_DAMAGE_POOLS:
		var stale_pool := active_pools.pop_front() as Node2D
		if stale_pool == new_pool:
			active_pools.append(stale_pool)
			continue
		stale_pool.remove_from_group("chemist_clouds")
		_release_effect(stale_pool)
		stale_pool.queue_free()


func _damage_enemies_in_pool(origin: Vector2, radius: float, amount: float, source_pool: Node2D = null) -> void:
	var enemies: Array = TARGET_QUERY.in_radius(self, origin, radius)
	_apply_pool_contact_statuses(enemies, source_pool)
	# FAN-1031 3c(a): per-weapon override пул-тика (сентинел <0 → общий default).
	var full_targets := pool_full_targets if pool_full_targets >= 0 else POOL_FULL_TARGETS
	var target_diminish := pool_target_diminish if pool_target_diminish >= 0.0 else POOL_TARGET_DIMINISH
	# FAN-1031 3c-final fix (peer review MINOR): fast-path берём только когда жёсткий кап ШИРИНЫ
	# не режет глубже full_targets — иначе малый пак (size ≤ full, но > pool_max) обходил бы кап
	# (немонотонность; pool_max=0 не мог «выключить» канал). effective_cap = min(full, max).
	var fast_cap := full_targets if pool_max_targets < 0 else mini(full_targets, pool_max_targets)
	if enemies.size() <= fast_cap:
		for enemy_node in enemies:
			# SCRUM-942: тик лужи — периодический канал и на одиночной цели тоже:
			# тип "dot" (единая покраска цифр + trait-множитель периодики), без
			# он-хит статусов/дублей — зеркально ветке толпы ниже.
			_damage_enemy(enemy_node, amount, false, "dot", false)
		return
	# Сортировка по близости к центру лужи — полный урон достаётся «ядру» пака.
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		# FAN-1031 3c(final): жёсткий кап ШИРИНЫ тика лужи — дальше pool_max_targets НОЛЬ.
		if pool_max_targets >= 0 and index >= pool_max_targets:
			break
		var factor := 1.0
		if index >= full_targets:
			factor = 1.0 / (1.0 + float(index - full_targets + 1) * target_diminish)
		_damage_enemy(enemies[index] as Node2D, amount * factor, false, "dot", false)


# Existing acid charges outlive their pools, so weapon cadence changes must
# retime their stored intervals in place instead of re-applying/resetting them.
func refresh_persistent_status_cadence() -> void:
	if not pool_contact_charges or not is_inside_tree():
		return
	var owner_node := _owner_node()
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var owner_id := owner_node.get_instance_id()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node and is_instance_valid(enemy):
			StatusEffects.retime_dot_statuses(enemy as Node, ACID_CHARGE_STATUS_PREFIX, owner_id, pool_charge_tick_interval)


# SCRUM-944: контактные статусы луж. Кислотная колба (pool_contact_charges):
func _apply_pool_contact_statuses(enemies: Array, source_pool: Node2D = null) -> void:
	var acid_charges := pool_contact_charges and source_pool != null and is_instance_valid(source_pool)
	if not acid_charges:
		return
	var owner_node := _owner_node()
	var charge_cap := pool_charge_cap
	var charge_status_id := "%s_p%d" % [ACID_CHARGE_STATUS_PREFIX, source_pool.get_instance_id()]
	if _owner_mod("acid_charge_stacks") > 0.0:
		charge_cap += ACID_CHARGE_ARTIFACT_CAP_BONUS
	var parameters_raw = owner_node.get("derived_parameters") if owner_node != null else null
	var dot_damage := 2.0
	if parameters_raw is Dictionary:
		dot_damage = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)), 1.0)
	var charge_tick := maxf(dot_damage * pool_charge_tick_multiplier, 0.30)
	# FAN-1031 3c(b): крауд-заряды ранжируются по дистанции к центру лужи — ближние
	var charge_order := _status_fanout_order(source_pool.global_position, enemies)
	for rank in range(charge_order.size()):
		var enemy_node := charge_order[rank] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var per_target_tick := charge_tick * _status_fanout_factor(rank)
		# FAN-1031 3c-final fix (peer review MINOR): жёсткий кап ШИРИНЫ = skip. За status_max_targets
		# (factor==0) НЕ вешаем вечный acid_charge с dot_damage 0 (занимал бы слот charge_cap и
		# считался в 5-стаковой детонации нулём). order отсортирован по дистанции → break. Без
		# override status_max factor>0 всегда → break не срабатывает (нулевое изменение поведения).
		if per_target_tick <= 0.0:
			break
		var owner_id := owner_node.get_instance_id() if owner_node != null else 0
		var previous_stack_count := StatusEffects.count_status_prefix(enemy_node, ACID_CHARGE_STATUS_PREFIX)
		if previous_stack_count < 5 and int(enemy_node.get_meta("constellation_acid_detonated_owner", 0)) == owner_id:
			enemy_node.remove_meta("constellation_acid_detonated_owner")
		if not StatusEffects.has_status(enemy_node, charge_status_id) \
				and previous_stack_count < charge_cap:
			StatusEffects.apply_status_from(owner_node, enemy_node, charge_status_id, {
				"source_id": owner_id,
				"duration": ACID_CHARGE_PERSIST_SECONDS,
				"dot_damage": per_target_tick,
				"dot_interval": pool_charge_tick_interval,
				"max_stacks": 1,
				"marker_color": Color(0.62, 0.95, 0.25, 1.0),
			})
		var acid_stack_count := StatusEffects.count_status_prefix(enemy_node, ACID_CHARGE_STATUS_PREFIX)
		if acid_stack_count >= 5 \
				and int(enemy_node.get_meta("constellation_acid_detonated_owner", 0)) != owner_id:
			var detonation := _constellation_event("pool_stack", enemy_node, 0.0, {"stacks": acid_stack_count})
			if bool(detonation.get("triggered", false)):
				enemy_node.set_meta("constellation_acid_detonated_owner", owner_id)
				var detonation_radius := maxf(aoe_radius * 0.60, 48.0)
				AttackVfx.orb_burst(_projectile_parent(), enemy_node.global_position, detonation_radius, visual_color)
				_damage_enemies_in_circle_capped(enemy_node.global_position, detonation_radius, per_target_tick * 5.0 * _constellation_result_param(detonation, "detonation_damage_ratio", 0.46), 2, 0.65)


func _damage_enemies_in_circle_capped(origin: Vector2, radius: float, amount: float, full_targets: int, diminish: float) -> void:
	var enemies: Array = TARGET_QUERY.in_radius(self, origin, radius)
	# FAN-1031 3c-final fix (peer review MINOR): fast-path берём только когда жёсткий кап ШИРИНЫ
	# (aoe_max_targets) не режет глубже full_targets — иначе малый пак обходил бы кап
	# (немонотонность; aoe_max=0 не мог «выключить» канал). effective_cap = min(full, max).
	var fast_cap := full_targets if aoe_max_targets < 0 else mini(full_targets, aoe_max_targets)
	if enemies.size() <= fast_cap:
		for enemy_node in enemies:
			_damage_enemy(enemy_node, amount)
		return
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		# FAN-1031 3c(final): жёсткий кап ШИРИНЫ прямого AoE — дальше aoe_max_targets НОЛЬ.
		if aoe_max_targets >= 0 and index >= aoe_max_targets:
			break
		var factor := 1.0
		if index >= full_targets:
			factor = 1.0 / (1.0 + float(index - full_targets + 1) * diminish)
		_damage_enemy(enemies[index] as Node2D, amount * factor, index < full_targets)


func _damage_enemies_in_circle_falloff(origin: Vector2, radius: float, amount: float, minimum_factor: float) -> void:
	# FAN-1031 3c(b2): к радиальному спаду (per-target, по дистанции) добавлен крауд-кап
	# ХВОСТА по ЧИСЛУ целей (_falloff_fanout_factor). Ранг = дистанция от центра; сентинел
	# (без override) → factor 1.0 для всех рангов → урон побайтово прежний (A/B-контроль).
	var ordered := _status_fanout_order(origin, TARGET_QUERY.in_radius(self, origin, radius))
	for rank in range(ordered.size()):
		var enemy_node := ordered[rank] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var distance := origin.distance_to(enemy_node.global_position)
		var factor := lerpf(1.0, clampf(minimum_factor, 0.0, 1.0), distance / maxf(radius, 1.0))
		_damage_enemy(enemy_node, amount * factor * _falloff_fanout_factor(rank))


func _call_take_damage(enemy: Node, amount: float, feedback := {}) -> void:
	if _take_damage_accepts_feedback(enemy):
		var tagged: Dictionary = feedback if feedback is Dictionary else {}
		var owner_node := _owner_node()
		if str(tagged.get("telemetry_provenance_id", "")) == "" and owner_node != null and owner_node.has_method("telemetry_context_for_hit") and owner_node.has_method("telemetry_feedback_for_hit"):
			var telemetry_context: Dictionary = owner_node.call("telemetry_context_for_hit", {"weapon_id": weapon_id, "attack_mode": attack_mode, "damage_type": str(tagged.get("damage_type", _weapon_damage_type()))})
			tagged = owner_node.call("telemetry_feedback_for_hit", telemetry_context, tagged)
		# SCRUM-1007: весь урон классового оружия — урон ИГРОКА. Метка едет в
		# feedback убившего хита (enemy._record_kill_attribution) и служит
		# атрибуцией он-килл trait'ов; лишний ключ для остальных читателей шумом
		# не является (enemy читает только известные поля).
		tagged["player_owned"] = true
		enemy.call("take_damage", amount, tagged)
	else:
		enemy.call("take_damage", amount)


func _take_damage_accepts_feedback(enemy: Node) -> bool:
	# FAN-3061: арность take_damage кэшируется по скрипту — без get_method_list()
	# (~2.7 мс) на каждом попадании; групповая ветка остаётся пер-инстансной.
	if not TAKE_DAMAGE_CONTRACT.accepts_two_arguments(enemy):
		return false
	var script: Script = enemy.get_script()
	if script != null and str(script.resource_path) in ["res://scripts/enemy.gd", "res://scripts/boss.gd"]:
		return true
	return enemy.is_in_group("enemies") and enemy.has_method("_show_combat_feedback")


func _push_enemy(enemy: Node2D, direction: Vector2) -> void:
	_push_enemy_scaled(enemy, direction, 1.0)


func _push_enemy_scaled(enemy: Node2D, direction: Vector2, multiplier: float) -> void:
	if direction.length_squared() <= 0.001:
		return
	var push_strength := knockback * maxf(multiplier, 0.0)
	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(direction.normalized() * push_strength * 3.6)
	else:
		enemy.global_position += direction.normalized() * push_strength * 0.12


func _rolled_damage(owner_node: Node2D) -> float:
	var raw_parameters = owner_node.get("derived_parameters")
	if not (raw_parameters is Dictionary):
		return damage

	var parameters: Dictionary = raw_parameters
	var result := float(parameters.get(damage_parameter, damage))
	_last_attack_crit = false
	if randf() < float(parameters.get("crit_chance", 0.0)):
		result *= float(parameters.get("crit_damage_multiplier", 1.0))
		_last_attack_crit = true
	if charge_seconds > 0.0:
		result *= _current_charge_multiplier
	if not summon_role.is_empty():
		result *= _summon_role_damage_factor(parameters)
	# SCRUM-908 «Сеть мастерской»: живые устройства инженера усиливают урон
	# устройств (data-driven через CLASS_TRAITS; для прочих классов фактор 1.0).
	result *= _workshop_network_factor(owner_node)
	# SCRUM-961 «Счетчик ритма»: ослабленный повтор каста (эхо активно только
	# внутри _maybe_fire_rhythm_echo, обычные касты не задевает).
	result *= _rhythm_echo_scale
	return result


func _summon_role_damage_factor(parameters: Dictionary) -> float:
	# SCRUM-546: deploy/sentry-саммоны (turret/totem/drone) масштабируются от
	# Лидерства так же, как pure-саммоны (summoner_weapon._summon_profile) и
	# бюджетная модель (progression_data._budget_summon_role_damage_factor).
	var summon_amount := float(parameters.get("summon_amount", 0.0))
	var leadership := float(parameters.get("leadership", 0.0))
	return summon_role_damage_multiplier * (1.0 + minf(leadership * 0.060 + summon_amount * 0.016, 1.15))


# SCRUM-899: Лидерство = uptime деплой-ампа — продлевает жизнь усилителя на
# amp_leadership_lifetime_per_point за очко (кап amp_leadership_lifetime_cap).
# Opt-in через конфиг оружия (sound_amp); у неподписанных амп-оружий
# per_point = 0 → бонус нулевой.
func _amp_leadership_lifetime_bonus(owner_node: Node2D) -> float:
	if amp_leadership_lifetime_per_point <= 0.0 or owner_node == null:
		return 0.0
	var owner_stats = owner_node.get("stats")
	if not (owner_stats is Dictionary):
		return 0.0
	var leadership := float((owner_stats as Dictionary).get("leadership", 0.0))
	return minf(leadership * amp_leadership_lifetime_per_point, maxf(amp_leadership_lifetime_cap, 0.0))


# SCRUM-899: «сила» ампа от summon_amount — учащение пульса по КАНОНУ
# саммон-хейста (summoner_weapon._summon_profile: min(summon_amount*0.014 +
# leadership*0.006, 0.30)). Урон отдельного пульса остаётся чистой magic_damage
# осью — никакой «лидерской» оси урона (политика SCRUM-899).
func _amp_summon_haste_value(owner_node: Node2D) -> float:
	if owner_node == null:
		return 0.0
	var raw_parameters = owner_node.get("derived_parameters")
	if not (raw_parameters is Dictionary):
		return 0.0
	var parameters: Dictionary = raw_parameters
	var summon_amount := float(parameters.get("summon_amount", 0.0))
	var leadership := float(parameters.get("leadership", 0.0))
	return minf(summon_amount * 0.014 + leadership * 0.006, 0.30)


func _update_charge(delta: float) -> void:
	if charge_seconds <= 0.0:
		return
	var owner_node := _owner_node()
	if owner_node == null:
		return
	var energy := 0.0
	var owner_stats = owner_node.get("stats")
	if owner_stats is Dictionary:
		energy = float((owner_stats as Dictionary).get("energy", 0.0))
	var effective_charge_seconds := maxf(charge_seconds / (1.0 + energy * 0.025), 0.25)
	var owner_velocity := Vector2.ZERO
	var raw_velocity = owner_node.get("velocity")
	if raw_velocity is Vector2:
		owner_velocity = raw_velocity
	if owner_velocity.length_squared() <= 4.0:
		_charge_time = minf(_charge_time + delta, effective_charge_seconds)
	else:
		_charge_time = maxf(_charge_time - delta * 2.5, 0.0)


func _charge_multiplier() -> float:
	if charge_seconds <= 0.0:
		return 1.0
	var owner_node := _owner_node()
	var energy := 0.0
	if owner_node != null:
		var owner_stats = owner_node.get("stats")
		if owner_stats is Dictionary:
			energy = float((owner_stats as Dictionary).get("energy", 0.0))
	var effective_charge_seconds := maxf(charge_seconds / (1.0 + energy * 0.025), 0.25)
	var charge_ratio := clampf(_charge_time / maxf(effective_charge_seconds, 0.01), 0.0, 1.0)
	return lerpf(1.0, maxf(charge_max_multiplier, 1.0), charge_ratio)


func _owner_node() -> CharacterBody2D:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node is CharacterBody2D:
			return parent_node
		parent_node = parent_node.get_parent()
	return null


func _emit_weapon_animation_event(owner_node: Node2D, phase: String, duration: float, direction: Vector2, metadata := {}) -> void:
	if owner_node == null or not is_instance_valid(owner_node) or not owner_node.has_method("play_action_animation"):
		return
	var event_metadata: Dictionary = metadata if metadata is Dictionary else {}
	var payload := event_metadata.duplicate(true)
	payload["attack_mode"] = attack_mode
	payload["weapon_id"] = weapon_id
	payload["display_name"] = display_name
	payload["phase_source"] = "class_weapon"
	var action_id := _event_action_animation_for_mode()
	owner_node.call("play_action_animation", action_id, direction, phase, maxf(duration, 0.0), payload)


func _estimated_windup_duration() -> float:
	match attack_mode:
		"grenade_fuse", "smoke_bomb", "prism_rift", "meteor_shards", "priest_sanctify", "robot_magnetic_anchor", "robot_compression_line", "sniper_lockshot", "sniper_kill_zone":
			return maxf(grenade_delay, 0.08)
		"priest_ward", "bio_spore_bloom", "bio_sample_dart":
			return maxf(burst_interval, 0.06)
		"amp", "trap", "engineer_sentry_link", "engineer_orbit_drone", "engineer_pressure_mines":
			return 0.10
		"beam", "dot_beam", "drain_link", "priest_dual_toll", "bio_symbiote_web", "moon_split_shot", "storm_pierce_cone":
			return 0.12
		# SCRUM-939..941: касты кита Тёмного мага — короткий читаемый замах.
		"dark_chain_burst", "skull_curse_burn", "dark_mirror_blast":
			return 0.12
	return 0.08


func _projectile_parent() -> Node:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	return parent


func _projectile_visual_profile() -> Dictionary:
	return PROJECTILE_VISUALS.profile_for_weapon(weapon_id)


func _spawn_projectile_visual(start: Vector2, travel_direction := Vector2.RIGHT) -> Node2D:
	return AttackVfx.orb_projectile(_projectile_parent(), start, visual_color, _projectile_visual_profile(), travel_direction)


func _projectile_impact_color() -> Color:
	var profile := _projectile_visual_profile()
	var palette = profile.get("impact_palette", [])
	return palette[0] if palette is Array and not palette.is_empty() else visual_color


func _weapon_visual_texture() -> Texture2D:
	var visual := get_node_or_null("WeaponVisual") as Sprite2D
	if visual != null and visual.texture != null:
		return visual.texture
	return SOUND_AMP_TEXTURE


func _deploy_visual_texture() -> Texture2D:
	if not deploy_texture_path.is_empty():
		var texture := load(deploy_texture_path) as Texture2D
		if texture != null:
			return texture
	return _weapon_visual_texture()


func _register_effect(effect: Node) -> void:
	if effect == null:
		return
	effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	_effects_shutdown = false
	effect.set_meta("weapon_owner_id", get_instance_id())
	effect.add_to_group("player_weapon_effects")
	_spawned_effects = _alive_effects()
	_spawned_effects.append(effect)


func _alive_effects() -> Array[Node]:
	var alive: Array[Node] = []
	for tracked in _spawned_effects:
		if tracked != null and is_instance_valid(tracked):
			alive.append(tracked)
	return alive


func _release_effect(effect: Node) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	effect.remove_from_group("player_weapon_effects")
	_spawned_effects.erase(effect)
	effect.queue_free()


func _capture_base_values() -> void:
	if not has_meta("base_damage"):
		set_meta("base_damage", damage)
	if not has_meta("base_fire_interval"):
		set_meta("base_fire_interval", fire_interval)
	if not has_meta("base_attack_range"):
		set_meta("base_attack_range", attack_range)
	if not has_meta("base_aoe_radius"):
		set_meta("base_aoe_radius", aoe_radius)
	if not has_meta("base_projectile_speed"):
		set_meta("base_projectile_speed", projectile_speed)
	if not has_meta("base_beam_width"):
		set_meta("base_beam_width", beam_width)
	if not has_meta("base_wave_width"):
		set_meta("base_wave_width", wave_width)
	if not has_meta("base_suppression_width"):
		set_meta("base_suppression_width", suppression_width)
	if not has_meta("base_knockback"):
		set_meta("base_knockback", knockback)
