extends SceneTree

# Integrity-тест данных врагов/энкаунтеров (progression_data_enemies.gd) — был
# непокрыт (content_registry проверяет сцены/спрайты, но НЕ внутренние кросс-ссылки
# этих таблиц). Висячая ссылка тихо ломает бой/кодекс: progression_data.gd берёт
# elite_attack_config по `behavior`, а энкаунтеры ссылаются на `mechanics`. Этот
# тест ловит опечатку в id механики/поведения/атаки при добавлении контента.
# Изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/enemy_content_integrity_test.gd

const EnemyData := preload("res://scripts/progression_data_enemies.gd")

const VALID_KINDS := ["elite", "boss"]
const EXPECTED_SIZE_PROFILES := ["ordinary", "mini_elite", "elite", "boss"]


func _initialize() -> void:
	var errors: Array = []
	_check_size_profiles(errors)
	_check_mechanic_catalog(errors)
	_check_elite_attack_configs(errors)
	_check_mini_elites(errors)
	_check_encounter_patterns(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Enemy content integrity: %s" % e)
		push_error("Enemy content integrity test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Enemy content integrity test passed (%d мини-элиток, %d энкаунтеров)." % [
		EnemyData.MINI_ELITE_KINDS.size(),
		EnemyData.UNIQUE_ENCOUNTER_PATTERNS.size(),
	])
	quit(0)


func _text_ok(text: String) -> bool:
	var t := text.strip_edges()
	return t != "" and not t.to_lower().begins_with("res://")


func _check_size_profiles(errors: Array) -> void:
	var profiles: Dictionary = EnemyData.ENEMY_SIZE_PROFILES
	for key in EXPECTED_SIZE_PROFILES:
		if not profiles.has(key):
			errors.append("ENEMY_SIZE_PROFILES без ожидаемого профиля '%s'" % key)
			continue
		var p: Dictionary = profiles[key]
		if float(p.get("scale", 0.0)) <= 0.0:
			errors.append("профиль '%s': scale <= 0" % key)
		if not _text_ok(str(p.get("label", ""))):
			errors.append("профиль '%s': пустой label" % key)


func _check_mechanic_catalog(errors: Array) -> void:
	var catalog: Dictionary = EnemyData.ENEMY_MECHANIC_CATALOG
	if catalog.is_empty():
		errors.append("ENEMY_MECHANIC_CATALOG пуст")
	for mech_id in catalog:
		var m: Dictionary = catalog[mech_id]
		if not _text_ok(str(m.get("title", ""))):
			errors.append("механика '%s': пустой title" % mech_id)
		if not (m.get("telegraph") is bool):
			errors.append("механика '%s': telegraph не bool" % mech_id)
		if not _text_ok(str(m.get("desc", ""))):
			errors.append("механика '%s': пустой desc" % mech_id)


func _check_elite_attack_configs(errors: Array) -> void:
	var configs: Dictionary = EnemyData.ELITE_ATTACK_CONFIGS
	for behavior in configs:
		var c: Dictionary = configs[behavior]
		var where := "ELITE_ATTACK_CONFIGS['%s']" % behavior
		if not _text_ok(str(c.get("attack_id", ""))):
			errors.append("%s: пустой attack_id" % where)
		for k in ["cooldown", "windup", "strike", "recover", "trigger_range", "damage_factor"]:
			if float(c.get(k, 0.0)) <= 0.0:
				errors.append("%s: %s <= 0" % [where, k])
		# Радиус может быть 0 (снарядная атака) — допускаем >= 0.
		if float(c.get("radius", 0.0)) < 0.0:
			errors.append("%s: radius < 0" % where)
		# Фазы атаки должны умещаться в кулдаун — иначе атака перекрывает сама себя.
		var phase := float(c.get("windup", 0.0)) + float(c.get("strike", 0.0)) + float(c.get("recover", 0.0))
		if phase > float(c.get("cooldown", 0.0)):
			errors.append("%s: windup+strike+recover (%.2f) > cooldown (%.2f)" % [where, phase, float(c.get("cooldown", 0.0))])


func _check_mini_elites(errors: Array) -> void:
	var kinds: Array = EnemyData.MINI_ELITE_KINDS
	var configs: Dictionary = EnemyData.ELITE_ATTACK_CONFIGS
	if kinds.is_empty():
		errors.append("MINI_ELITE_KINDS пуст")
	var seen := {}
	for entry in kinds:
		var k: Dictionary = entry
		var kid := str(k.get("id", ""))
		if kid == "" or seen.has(kid):
			errors.append("мини-элитка с пустым/дублирующимся id '%s'" % kid)
			continue
		seen[kid] = true
		if not _text_ok(str(k.get("title", ""))):
			errors.append("мини-элитка '%s': пустой title" % kid)
		if not _text_ok(str(k.get("desc", ""))):
			errors.append("мини-элитка '%s': пустой desc" % kid)
		if not _text_ok(str(k.get("scene", ""))):
			errors.append("мини-элитка '%s': пустой scene" % kid)
		for mult in ["hp_mult", "speed_mult", "damage_mult"]:
			if float(k.get(mult, 0.0)) <= 0.0:
				errors.append("мини-элитка '%s': %s <= 0" % [kid, mult])
		# tint — три компоненты в [0,1].
		var tint = k.get("tint", [])
		if not (tint is Array) or (tint as Array).size() != 3:
			errors.append("мини-элитка '%s': tint не [r,g,b]" % kid)
		else:
			for comp in tint:
				if float(comp) < 0.0 or float(comp) > 1.0:
					errors.append("мини-элитка '%s': компонента tint вне [0,1] (%.2f)" % [kid, float(comp)])
		# Кросс-ссылка: behavior обязан иметь elite-attack-config (иначе нет атаки).
		var behavior := str(k.get("behavior", ""))
		if not configs.has(behavior):
			errors.append("мини-элитка '%s': behavior '%s' без ELITE_ATTACK_CONFIGS" % [kid, behavior])


func _check_encounter_patterns(errors: Array) -> void:
	var patterns: Dictionary = EnemyData.UNIQUE_ENCOUNTER_PATTERNS
	var catalog: Dictionary = EnemyData.ENEMY_MECHANIC_CATALOG
	var configs: Dictionary = EnemyData.ELITE_ATTACK_CONFIGS
	if patterns.is_empty():
		errors.append("UNIQUE_ENCOUNTER_PATTERNS пуст")
	for pid in patterns:
		var p: Dictionary = patterns[pid]
		var where := "энкаунтер '%s'" % pid
		if not _text_ok(str(p.get("title", ""))):
			errors.append("%s: пустой title" % where)
		if not _text_ok(str(p.get("summary", ""))):
			errors.append("%s: пустой summary" % where)
		var kind := str(p.get("kind", ""))
		if not VALID_KINDS.has(kind):
			errors.append("%s: kind '%s' вне %s" % [where, kind, str(VALID_KINDS)])
		# Кросс-ссылка: каждая механика обязана быть в каталоге.
		var mechanics: Array = p.get("mechanics", [])
		if mechanics.is_empty():
			errors.append("%s: пустой список mechanics" % where)
		for mech in mechanics:
			if not catalog.has(str(mech)):
				errors.append("%s: механика '%s' вне ENEMY_MECHANIC_CATALOG" % [where, str(mech)])
		# Для элиток attack_id обязателен и согласован с ELITE_ATTACK_CONFIGS[pid].
		if kind == "elite":
			var attack_id := str(p.get("attack_id", ""))
			if attack_id == "":
				errors.append("%s: elite без attack_id" % where)
			elif configs.has(pid) and str(configs[pid].get("attack_id", "")) != attack_id:
				errors.append("%s: attack_id '%s' != ELITE_ATTACK_CONFIGS['%s'].attack_id '%s'" % [
					where, attack_id, pid, str(configs[pid].get("attack_id", "")),
				])
