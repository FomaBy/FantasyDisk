class_name StatusEffects
extends RefCounted

const META_KEY := "status_effects"
const MARKER_META_KEY := "status_marker_color"


static func apply_status(target: Node, status_id: String, config: Dictionary) -> void:
	if target == null or not is_instance_valid(target) or status_id.strip_edges() == "":
		return
	var statuses := _statuses(target)
	var existing: Dictionary = statuses.get(status_id, {})
	var max_stacks := maxi(int(config.get("max_stacks", existing.get("max_stacks", 1))), 1)
	var stack_mode := str(config.get("stack_mode", "refresh"))
	var current_stacks := int(existing.get("stacks", 0))
	var stacks := 1
	match stack_mode:
		"add":
			stacks = mini(current_stacks + 1, max_stacks)
		"extend":
			stacks = maxi(current_stacks, 1)
		_:
			stacks = maxi(current_stacks, 1)
	var duration := maxf(float(config.get("duration", existing.get("duration", 0.0))), 0.0)
	var remaining := duration
	if stack_mode == "extend" and not existing.is_empty():
		remaining = maxf(float(existing.get("remaining", 0.0)), 0.0) + duration
	var status := config.duplicate(true)
	status["id"] = status_id
	status["duration"] = duration
	status["remaining"] = remaining
	status["stacks"] = stacks
	status["max_stacks"] = max_stacks
	status["tick_left"] = minf(float(existing.get("tick_left", config.get("dot_interval", 1.0))), maxf(float(config.get("dot_interval", 1.0)), 0.1))
	statuses[status_id] = status
	_set_statuses(target, statuses)
	if config.has("marker_color"):
		target.set_meta(MARKER_META_KEY, config["marker_color"])


# SCRUM-942: применение ПЕРИОДИЧЕСКОГО статуса с учётом trait'а источника.
# Тики статуса бегут на цели и не видят владельца, поэтому классовый множитель
# периодики («Катализатор» Химика: ×1.5) запекается в dot_damage на моменте
# применения. Источник опт-инится утиным методом periodic_damage_multiplier()
# (player читает его из ProgressionData.CLASS_TRAITS — data-driven, без утечки
# другим классам). Статусы без dot_damage проходят без изменений.
static func apply_status_from(source: Node, target: Node, status_id: String, config: Dictionary) -> void:
	var scaled_config := config
	var multiplier := source_periodic_multiplier(source)
	if not is_equal_approx(multiplier, 1.0) and float(config.get("dot_damage", 0.0)) > 0.0:
		scaled_config = config.duplicate(true)
		scaled_config["dot_damage"] = float(config.get("dot_damage", 0.0)) * multiplier
	apply_status(target, status_id, scaled_config)


# SCRUM-942: периодический множитель источника урона (1.0 — без trait'а).
static func source_periodic_multiplier(source: Node) -> float:
	if source == null or not is_instance_valid(source):
		return 1.0
	if source.has_method("periodic_damage_multiplier"):
		return maxf(float(source.call("periodic_damage_multiplier")), 0.0)
	return 1.0


# SCRUM-944: число активных статусов с данным префиксом id (кап перманентных
# кислотных зарядов: один заряд = один статус "acid_charge_p<pool_id>").
static func count_status_prefix(target: Node, prefix: String) -> int:
	var count := 0
	for status_id in _statuses(target).keys():
		if str(status_id).begins_with(prefix):
			count += 1
	return count


static func tick(target: Node, delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.has_meta(META_KEY):
		return
	var statuses := _statuses(target)
	var changed := false
	var expired: Array[String] = []
	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]
		status["remaining"] = float(status.get("remaining", 0.0)) - delta
		if float(status.get("dot_damage", 0.0)) > 0.0 and target.has_method("take_damage"):
			var interval := maxf(float(status.get("dot_interval", 1.0)), 0.1)
			status["tick_left"] = float(status.get("tick_left", interval)) - delta
			var feedback_capable := _take_damage_accepts_feedback(target)
			while float(status["tick_left"]) <= 0.0 and float(status.get("remaining", 0.0)) > 0.0:
				status["tick_left"] = float(status["tick_left"]) + interval
				var tick_total := float(status.get("dot_damage", 0.0)) * float(status.get("stacks", 1))
				# SCRUM-523: тик статуса — периодический урон → красим цифру как "dot".
				# Только если цель принимает 2-арг take_damage(amount, feedback) (враг/босс);
				# у игрока 2-й аргумент — строка-источник, ему feedback не шлём.
				if feedback_capable:
					# SCRUM-1007: статус может нести tick_feedback (атрибуция
					# источника тика, напр. player_owned у проклятия черепа) —
					# дефолтный damage_type "dot" сохраняется, ключи домешиваются.
					var tick_feedback := {"damage_type": "dot"}
					var extra_feedback_raw = status.get("tick_feedback", null)
					if extra_feedback_raw is Dictionary:
						tick_feedback.merge(extra_feedback_raw as Dictionary, true)
					target.call("take_damage", tick_total, tick_feedback)
				else:
					target.call("take_damage", tick_total)
		if float(status.get("remaining", 0.0)) <= 0.0:
			expired.append(str(status_id))
		else:
			statuses[status_id] = status
		changed = true
	for status_id in expired:
		statuses.erase(status_id)
	if changed:
		_set_statuses(target, statuses)


# SCRUM-523: принимает ли take_damage второй аргумент (feedback-словарь).
# Та же проверка арности, что в class_weapon._take_damage_accepts_feedback.
static func _take_damage_accepts_feedback(target: Node) -> bool:
	for method in target.get_method_list():
		if str(method.get("name", "")) == "take_damage":
			return int((method.get("args", []) as Array).size()) >= 2
	return false


static func has_status(target: Node, status_id: String) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return _statuses(target).has(status_id)


# SCRUM-1005 «Разбор образцов»: есть ли на цели ЖИВОЙ периодический эффект с
# атрибуцией конкретного владельца. Владелец тегируется в конфиге статуса ключом
# source_id (instance id узла-автора, см. ClassWeapon._apply_bio_infection).
# Чужие статусы (другой владелец/без тега) и истёкшие (remaining<=0, ещё не
# собранные tick'ом) бонусов не дают.
static func has_dot_from_source(target: Node, source_id: int) -> bool:
	if source_id == 0:
		return false
	for status in _statuses(target).values():
		var status_config: Dictionary = status
		if float(status_config.get("dot_damage", 0.0)) <= 0.0:
			continue
		if float(status_config.get("remaining", 0.0)) <= 0.0:
			continue
		if int(status_config.get("source_id", 0)) == source_id:
			return true
	return false


static func snapshot(target: Node) -> Dictionary:
	return _statuses(target).duplicate(true)


static func damage_multiplier(target: Node) -> float:
	var multiplier := 1.0
	for status in _statuses(target).values():
		multiplier *= _stacked_multiplier(status, "damage_multiplier")
	return multiplier


static func damage_taken_multiplier(target: Node) -> float:
	var multiplier := 1.0
	for status in _statuses(target).values():
		multiplier *= _stacked_multiplier(status, "damage_taken_multiplier")
	return multiplier


static func speed_multiplier(target: Node) -> float:
	var multiplier := 1.0
	for status in _statuses(target).values():
		multiplier *= _stacked_multiplier(status, "speed_multiplier")
	return clampf(multiplier, 0.25, 1.75)


# SCRUM-913: жёсткий контроль (паралич капкана Рейнджера) — статус с
# movement_locked=true ПОЛНОСТЬЮ останавливает перемещение жертвы
# (enemy._physics_process гейтит velocity в ноль; внешние импульсы
# apply_knockback продолжают действовать), в отличие от speed_multiplier,
# который клампится снизу на 0.25. Конечность гарантирована штатным
# истечением статуса в tick(); длительность у боссов/элит режется
# контроль-резистом источника (ClassWeapon._control_resist_factor).
static func is_movement_locked(target: Node) -> bool:
	for status in _statuses(target).values():
		if bool((status as Dictionary).get("movement_locked", false)):
			return true
	return false


static func _stacked_multiplier(status: Dictionary, key: String) -> float:
	if not status.has(key):
		return 1.0
	var value := float(status.get(key, 1.0))
	var stacks := maxi(int(status.get("stacks", 1)), 1)
	if is_equal_approx(value, 1.0) or stacks <= 1:
		return value
	return maxf(0.0, 1.0 + (value - 1.0) * float(stacks))


static func _statuses(target: Node) -> Dictionary:
	if target == null or not is_instance_valid(target) or not target.has_meta(META_KEY):
		return {}
	var raw = target.get_meta(META_KEY)
	return raw if raw is Dictionary else {}


static func _set_statuses(target: Node, statuses: Dictionary) -> void:
	if statuses.is_empty():
		target.remove_meta(META_KEY)
		if target.has_meta(MARKER_META_KEY):
			target.remove_meta(MARKER_META_KEY)
		return
	target.set_meta(META_KEY, statuses)
