extends SceneTree

# SCRUM-899/SCRUM-1006: фокусный гейт редизайна кита Гитариста.
#
#  - SCRUM-899 (magic-caster + деплой-саммонер):
#      * Электрогитара riff_strip — УЗКАЯ передняя полоса постоянной полной
#        ширины wave_width: цель в полосе поражается, сбоку (внутри старой
#        расширяющейся волны!) и сзади — нет; все цели в полосе бьются без
#        pierce-капа (отличие от лучей); частые низко-средние маг. хиты.
#      * Бас — большое кольцо (радиус с первого уровня), частые слабые тики,
#        бьёт ВО ВСЕ стороны (отличие от полосы), сильный knockback под кайт.
#      * Усилитель — деплой-турель: стационарен, пульсирует магией от статов
#        владельца, лимит ампов соблюдается (старейший убирается), смена
#        оружия не оставляет orphan-нод; правила скейлинга: Лидерство =
#        число + uptime ампов, summon_amount = темп пульса (opt-in, Друид
#        с raven_totem НЕ подписан), урон — чистая magic_damage ось.
#  - SCRUM-1006 «Разогрев»: детерминированный no-hit стек магического урона
#    (+2 п.п./сек, 0→+20% ровно за 10с, кап держится); квалифицированный удар
#    сбрасывает в 0; полностью предотвращенные события (godmode, i-frames)
#    НЕ сбрасывают; physical/dot контексты и другие классы не затронуты;
#    деплой-выход ампа усиливается через владельца (ownership сохранён);
#    смена персонажа не переносит stale-стеки.
#
# Запуск: Godot --headless --path . --script res://tests/guitarist_kit_test.gd

const PD := preload("res://scripts/progression_data.gd")

const EPS := 0.001

var _errors: Array = []


func _initialize() -> void:
	seed(20260710)
	await process_frame

	_check_weapon_configs()
	_check_trait_registry()
	await _check_riff_strip_geometry()
	await _check_bass_aura()
	await _check_amp_deploy_loop()
	await _check_amp_scaling_rules()
	await _check_warmup_trait_timing_and_reset()
	await _check_warmup_ownership_and_isolation()

	if not _errors.is_empty():
		for e in _errors:
			push_error("Guitarist kit: %s" % str(e))
		push_error("Guitarist kit test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Guitarist kit test passed (riff strip, kite bass, amp summoner, warm-up trait).")
	quit(0)


# --- SCRUM-899: конфиги — magic-кит без звуковой оси -------------------------------

func _check_weapon_configs() -> void:
	var expected_modes := {"electric_guitar": "riff_strip", "bass_guitar": "pulse", "sound_amp": "amp"}
	for wid in expected_modes:
		var config: Dictionary = PD.weapon("guitarist", str(wid))
		if str(config.get("damage_parameter", "")) != "magic_damage":
			_errors.append("config %s: damage_parameter не magic_damage" % wid)
		if str(config.get("attack_mode", "")) != str(expected_modes[wid]):
			_errors.append("config %s: attack_mode %s вместо %s" % [wid, config.get("attack_mode", ""), expected_modes[wid]])
		for key in config.keys():
			if str(key).contains("sound_wave_damage"):
				_errors.append("config %s: остался ключ звуковой оси '%s'" % [wid, key])

	var riff: Dictionary = PD.weapon("guitarist", "electric_guitar")
	if float(riff.get("wave_width", 999.0)) > 130.0:
		_errors.append("рифф: полоса шириной %.0f — не узкая (ожидается <= 130)" % float(riff.get("wave_width", 0.0)))
	if float(riff.get("fire_interval", 9.0)) > 0.6:
		_errors.append("рифф: fire_interval %.2f — не частый (ожидается <= 0.6)" % float(riff.get("fire_interval", 9.0)))
	if float(riff.get("damage_multiplier", 9.0)) > 0.8:
		_errors.append("рифф: damage_multiplier %.2f — не низко-средний хит (ожидается <= 0.8)" % float(riff.get("damage_multiplier", 9.0)))

	var bass: Dictionary = PD.weapon("guitarist", "bass_guitar")
	if float(bass.get("aoe_radius", 0.0)) < 320.0:
		_errors.append("бас: базовый радиус %.0f мал (ожидается >= 320 с первого уровня)" % float(bass.get("aoe_radius", 0.0)))
	if float(bass.get("fire_interval", 9.0)) > 0.8:
		_errors.append("бас: fire_interval %.2f — тики не частые" % float(bass.get("fire_interval", 9.0)))
	if float(bass.get("damage_multiplier", 9.0)) > 0.30:
		_errors.append("бас: damage_multiplier %.2f — ранняя слабость должна быть в уроне" % float(bass.get("damage_multiplier", 9.0)))
	if float(bass.get("knockback", 0.0)) < 150.0:
		_errors.append("бас: knockback %.0f мал для кайта" % float(bass.get("knockback", 0.0)))
	if float(bass.get("aoe_radius", 0.0)) > float(bass.get("attack_range", 0.0)) + EPS:
		_errors.append("бас: aoe_radius больше attack_range — кольцо не покрывается триггером атаки")

	var amp: Dictionary = PD.weapon("guitarist", "sound_amp")
	if int(amp.get("max_summons", 0)) != 1 or int(amp.get("max_summons_cap", 0)) < 3:
		_errors.append("амп: базовый лимит/кап деплоя нарушен (base %d, cap %d)" % [int(amp.get("max_summons", 0)), int(amp.get("max_summons_cap", 0))])
	if float(amp.get("amp_lifetime", 0.0)) < 6.0 or float(amp.get("amp_lifetime", 0.0)) > 8.0:
		_errors.append("амп: lifetime %.1f вне 6..8" % float(amp.get("amp_lifetime", 0.0)))
	if not bool(amp.get("amp_summon_haste", false)) or float(amp.get("amp_leadership_lifetime_per_point", 0.0)) <= 0.0:
		_errors.append("амп: правила саммонер-скейлинга (haste/uptime) не включены в конфиге")

	# Идентичность класса — магический кастер, без звука-как-стата.
	var character: Dictionary = PD.character_config("guitarist")
	var description := str(character.get("description", ""))
	if not description.contains("агическ"):
		_errors.append("описание класса не упоминает магическую идентичность")


# --- SCRUM-1006: data-driven реестр trait'а ----------------------------------------

func _check_trait_registry() -> void:
	var trait_config: Dictionary = PD.class_trait("guitarist")
	if str(trait_config.get("id", "")) != "warm_up" or str(trait_config.get("title", "")).is_empty():
		_errors.append("trait: у Гитариста нет trait'а warm_up в CLASS_TRAITS")
	if absf(float(trait_config.get("no_hit_magic_bonus_per_second", 0.0)) - 0.02) > EPS:
		_errors.append("trait: ramp %.3f вместо 0.02/сек" % float(trait_config.get("no_hit_magic_bonus_per_second", 0.0)))
	if absf(float(trait_config.get("no_hit_magic_bonus_cap", 0.0)) - 0.20) > EPS:
		_errors.append("trait: кап %.3f вместо 0.20" % float(trait_config.get("no_hit_magic_bonus_cap", 0.0)))
	for other_class in ["berserk", "soldier", "elementalist", "chemist", "dark_mage", "druid"]:
		if PD.class_trait(str(other_class)).has("no_hit_magic_bonus_per_second"):
			_errors.append("trait: no-hit ключи протекли классу %s" % other_class)


# --- SCRUM-899: узкая передняя полоса риффа ----------------------------------------

func _check_riff_strip_geometry() -> void:
	var player := _make_player("guitarist", "electric_guitar")
	await process_frame
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("рифф: оружие не экипировалось")
		player.free()
		return
	weapon.set_process(false)  # авто-атаки не мешают ручному кейсу
	if str(weapon.call("_weapon_damage_type")) != "magic":
		_errors.append("рифф: канал урона не magic")

	var runtime_range := float(weapon.get("attack_range"))
	var half_width := float(weapon.get("wave_width")) * 0.5
	var origin: Vector2 = player.global_position
	# Полоса вправо: ближайший враг задаёт направление (+X).
	var in_near := _make_dummy_enemy(origin + Vector2(200, 0))
	var in_mid := _make_dummy_enemy(origin + Vector2(400, 0))
	var in_far := _make_dummy_enemy(origin + Vector2(480, 0))
	# Сбоку: внутри СТАРОЙ расширяющейся волны (offset 80 < старой полуширины
	# ~91 на этой дистанции), но за пределами новой узкой полосы (half 59).
	var side := _make_dummy_enemy(origin + Vector2(300, half_width + 21.0))
	var behind := _make_dummy_enemy(origin + Vector2(-220, 0))
	var beyond := _make_dummy_enemy(origin + Vector2(runtime_range + 170.0, 0))
	await process_frame

	weapon.call("_attack")
	var hit_amounts := [
		float(in_near.get_meta("damage_taken", 0.0)),
		float(in_mid.get_meta("damage_taken", 0.0)),
		float(in_far.get_meta("damage_taken", 0.0)),
	]
	if hit_amounts.min() <= 0.0:
		_errors.append("рифф: не все цели в полосе поражены (%s) — pierce-кап?" % str(hit_amounts))
	if float(side.get_meta("damage_taken", 0.0)) > 0.0:
		_errors.append("рифф: боковая цель (offset %.0f) поражена — полоса не узкая" % (half_width + 21.0))
	if float(behind.get_meta("damage_taken", 0.0)) > 0.0:
		_errors.append("рифф: цель сзади поражена")
	if float(beyond.get_meta("damage_taken", 0.0)) > 0.0:
		_errors.append("рифф: цель за пределами attack_range поражена")
	var near_hits: Array = in_near.get_meta("hits", [])
	if near_hits.is_empty() or str((near_hits[0] as Dictionary).get("type", "")) != "magic":
		_errors.append("рифф: прямой хит не тегирован magic (%s)" % str(near_hits))

	player.free()
	for enemy in [in_near, in_mid, in_far, side, behind, beyond]:
		enemy.free()
	await process_frame


# --- SCRUM-899: бас — большое кольцо под кайт --------------------------------------

func _check_bass_aura() -> void:
	var player := _make_player("guitarist", "bass_guitar")
	await process_frame
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("бас: оружие не экипировалось")
		player.free()
		return
	weapon.set_process(false)
	var runtime_radius := float(weapon.get("aoe_radius"))
	if runtime_radius < 320.0:
		_errors.append("бас: рантайм-радиус %.0f мал" % runtime_radius)
	var origin: Vector2 = player.global_position
	# Кольцо бьёт во все стороны — в т.ч. ПОЗАДИ героя (отличие от полосы риффа).
	var behind_in := _make_dummy_enemy(origin + Vector2(-runtime_radius * 0.8, 0))
	var side_in := _make_dummy_enemy(origin + Vector2(0, runtime_radius * 0.7))
	var out := _make_dummy_enemy(origin + Vector2(runtime_radius + 320.0, 0))
	await process_frame

	weapon.call("_attack")
	if float(behind_in.get_meta("damage_taken", 0.0)) <= 0.0 or float(side_in.get_meta("damage_taken", 0.0)) <= 0.0:
		_errors.append("бас: цели внутри кольца (сзади/сбоку) не поражены — аура не круговая")
	if float(out.get_meta("damage_taken", 0.0)) > 0.0:
		_errors.append("бас: цель за радиусом поражена")
	var in_hits: Array = side_in.get_meta("hits", [])
	if in_hits.is_empty() or str((in_hits[0] as Dictionary).get("type", "")) != "magic":
		_errors.append("бас: пульс не тегирован magic")

	player.free()
	for enemy in [behind_in, side_in, out]:
		enemy.free()
	await process_frame


# --- SCRUM-899: амп — стационарная деплой-турель -----------------------------------

func _check_amp_deploy_loop() -> void:
	var player := _make_player("guitarist", "sound_amp")
	await process_frame
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("амп: оружие не экипировалось")
		player.free()
		return
	weapon.set_process(false)
	# Авто-атака кадра экипировки могла уже задеплоить амп (fallback-направление
	# без врагов) — зачищаем, кейс стартует с чистой сцены.
	for stale_amp in get_nodes_in_group("deployed_sound_amps"):
		stale_amp.free()
	# Детерминизм прямых хитов: крит выключаем через derived-словарь владельца,
	# физику игрока стопаем (drift _update_warmup_trait между кадрами) и
	# обнуляем уже накопленные за кадры конфигурации доли разогрева.
	player.set_physics_process(false)
	player.set("_warmup_no_hit_seconds", 0.0)
	var derived: Dictionary = player.get("derived_parameters")
	derived["crit_chance"] = 0.0
	var magic_damage := float(derived.get("magic_damage", 0.0))
	if magic_damage <= 0.0:
		_errors.append("амп: у Гитариста нулевая magic_damage — статы не заданы")

	var origin: Vector2 = player.global_position
	var enemy := _make_dummy_enemy(origin + Vector2(200, 0))
	await process_frame
	weapon.call("_attack")  # амп ставится к врагу (~+92 по X), первый пульс сразу

	var amps := get_nodes_in_group("deployed_sound_amps")
	if amps.size() != 1:
		_errors.append("амп: после деплоя в группе %d нод вместо 1" % amps.size())
		player.free()
		enemy.free()
		return
	var amp_node := amps[0] as Node2D
	var deployed_position := amp_node.global_position

	# Первый пульс уже нанёс урон от статов владельца: прямой хит = ровно
	# magic_damage (крит 0, meta-множитель 1.0), сверху — универсальный
	# он-хит enchant (0.10 x magic, легаси-механика вне trait-пайплайна).
	var hits: Array = enemy.get_meta("hits", [])
	if hits.is_empty():
		_errors.append("амп: немедленный пульс не нанёс урона")
	else:
		var direct := float((hits[0] as Dictionary).get("amount", 0.0))
		if absf(direct - magic_damage) > magic_damage * 0.01:
			_errors.append("амп: пульс %.2f не равен magic_damage владельца %.2f" % [direct, magic_damage])
		if str((hits[0] as Dictionary).get("type", "")) != "magic":
			_errors.append("амп: пульс не тегирован magic")

	# Стационарность: владелец убегает — амп остаётся на месте.
	player.global_position += Vector2(400, 0)
	await process_frame
	if is_instance_valid(amp_node) and amp_node.global_position.distance_to(deployed_position) > 1.0:
		_errors.append("амп: турель сместилась вслед за владельцем")

	# Лимит: с Лидерством 7 держится 1 + floor(7/4) = 2 ампов, старейший убирается.
	var amp_limit := int(weapon.get("max_summons"))
	if amp_limit != 2:
		_errors.append("амп: лимит %d вместо 2 (Лидерство 7)" % amp_limit)
	for extra_deploy in range(3):
		weapon.call("_attack")
		await process_frame
	var active := get_nodes_in_group("deployed_sound_amps")
	var alive := 0
	for node in active:
		if is_instance_valid(node):
			alive += 1
	if alive != amp_limit:
		_errors.append("амп: активных турелей %d вместо лимита %d" % [alive, amp_limit])

	# Cleanup: смена оружия не оставляет orphan-ампов.
	player.call("equip_weapon", "bass_guitar")
	await process_frame
	if not get_nodes_in_group("deployed_sound_amps").filter(func(n: Node) -> bool: return is_instance_valid(n)).is_empty():
		_errors.append("амп: после смены оружия остались orphan-турели")

	player.free()
	enemy.free()
	await process_frame


# --- SCRUM-899: правила саммонер-скейлинга ампа ------------------------------------

func _check_amp_scaling_rules() -> void:
	var player := _make_player("guitarist", "sound_amp")
	await process_frame
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("скейл: оружие не экипировалось")
		player.free()
		return
	var stats: Dictionary = player.get("stats")
	var derived: Dictionary = player.get("derived_parameters")
	var leadership := float(stats.get("leadership", 0.0))

	# Лидерство = uptime: жизнь ампа продлевается (min(lead*0.12, 3.0)).
	var lifetime_bonus := float(weapon.call("_amp_leadership_lifetime_bonus", player))
	var expected_lifetime := minf(leadership * 0.12, 3.0)
	if absf(lifetime_bonus - expected_lifetime) > EPS:
		_errors.append("скейл: uptime-бонус %.3f вместо %.3f" % [lifetime_bonus, expected_lifetime])

	# summon_amount = темп пульса (канон summoner haste).
	var haste := float(weapon.call("_amp_summon_haste_value", player))
	var expected_haste := minf(float(derived.get("summon_amount", 0.0)) * 0.014 + float(derived.get("leadership", 0.0)) * 0.006, 0.30)
	if haste <= 0.0 or absf(haste - expected_haste) > EPS:
		_errors.append("скейл: haste %.3f вместо %.3f" % [haste, expected_haste])
	player.free()

	# Друид с raven_totem НЕ подписан на правила ампа Гитариста.
	var druid := _make_player("druid", "raven_totem")
	await process_frame
	var totem: Node = druid.get("equipped_weapon")
	if totem == null:
		_errors.append("скейл: тотем Друида не экипировался")
	else:
		if bool(totem.get("amp_summon_haste")) or float(totem.get("amp_leadership_lifetime_per_point")) > 0.0:
			_errors.append("скейл: правила ампа Гитариста протекли в raven_totem Друида")
		if float(totem.call("_amp_leadership_lifetime_bonus", druid)) > 0.0:
			_errors.append("скейл: uptime-бонус протёк Друиду")
	druid.free()
	await process_frame


# --- SCRUM-1006: тайминг, кап и сбросы «Разогрева» ---------------------------------

func _check_warmup_trait_timing_and_reset() -> void:
	var player := _make_player("guitarist", "electric_guitar")
	await process_frame
	# Детерминизм тайминга: физика игрока накапливала бы real-time drift в
	# счётчик разогрева между await'ами — стопаем и начинаем с чистого нуля.
	player.set_physics_process(false)
	player.set("_warmup_no_hit_seconds", 0.0)

	if absf(float(player.call("warmup_magic_bonus"))) > EPS:
		_errors.append("разогрев: стартовый бонус не нулевой")

	# Детерминированная прогрессия: +2 п.п. за секунду, 0 -> 20% ровно за 10с.
	for i in range(5):
		player.call("_update_warmup_trait", 1.0)
	if absf(float(player.call("warmup_magic_bonus")) - 0.10) > EPS:
		_errors.append("разогрев: после 5с бонус %.3f вместо 0.10" % float(player.call("warmup_magic_bonus")))
	for i in range(5):
		player.call("_update_warmup_trait", 1.0)
	if absf(float(player.call("warmup_magic_bonus")) - 0.20) > EPS:
		_errors.append("разогрев: после 10с бонус %.3f вместо капа 0.20" % float(player.call("warmup_magic_bonus")))
	for i in range(12):
		player.call("_update_warmup_trait", 1.0)
	if float(player.call("warmup_magic_bonus")) > 0.20 + EPS:
		_errors.append("разогрев: кап превышен (%.3f)" % float(player.call("warmup_magic_bonus")))

	# Бонус применяется ТОЛЬКО к магическим hit-контекстам.
	if absf(float(player.call("meta_damage_multiplier", {"damage_type": "magic"})) - 1.20) > EPS:
		_errors.append("разогрев: magic-контекст дал %.3f вместо 1.20" % float(player.call("meta_damage_multiplier", {"damage_type": "magic"})))
	if absf(float(player.call("meta_damage_multiplier", {"damage_type": "physical"})) - 1.0) > EPS:
		_errors.append("разогрев: physical-контекст изменился")
	if absf(float(player.call("meta_damage_multiplier", {"damage_type": "dot"})) - 1.0) > EPS:
		_errors.append("разогрев: dot-контекст изменился")

	# Полностью предотвращенные события НЕ сбрасывают стек (явное правило).
	player.set("debug_godmode", true)
	player.call("take_damage", 25.0)
	player.set("debug_godmode", false)
	if absf(float(player.call("warmup_magic_bonus")) - 0.20) > EPS:
		_errors.append("разогрев: godmode-событие сбросило стек")
	player.set("_damage_invulnerability_left", 5.0)
	player.call("take_damage", 25.0)
	player.set("_damage_invulnerability_left", 0.0)
	if absf(float(player.call("warmup_magic_bonus")) - 0.20) > EPS:
		_errors.append("разогрев: удар в i-frames сбросил стек")

	# Квалифицированный удар сбрасывает в 0 (ролл уворота ретраим до попадания).
	var landed := false
	for attempt in range(64):
		if bool(player.call("take_damage", 5.0)):
			landed = true
			break
		player.set("_damage_invulnerability_left", 0.0)
	if not landed:
		_errors.append("разогрев: не удалось нанести квалифицированный удар (64 попытки)")
	elif absf(float(player.call("warmup_magic_bonus"))) > EPS:
		_errors.append("разогрев: полученный удар не сбросил стек (%.3f)" % float(player.call("warmup_magic_bonus")))
	elif absf(float(player.call("meta_damage_multiplier", {"damage_type": "magic"})) - 1.0) > EPS:
		_errors.append("разогрев: после сброса magic-множитель не 1.0")

	# После сброса копится заново.
	player.call("_update_warmup_trait", 2.0)
	if absf(float(player.call("warmup_magic_bonus")) - 0.04) > EPS:
		_errors.append("разогрев: после сброса не копится заново (%.3f)" % float(player.call("warmup_magic_bonus")))

	# Смена персонажа/забега не переносит stale-стеки.
	player.call("_update_warmup_trait", 8.0)
	player.call("configure_character", "guitarist", "electric_guitar")
	await process_frame
	if absf(float(player.call("warmup_magic_bonus"))) > EPS:
		_errors.append("разогрев: configure_character сохранил stale-стек")

	player.free()
	await process_frame


# --- SCRUM-1006: ownership деплоя и изоляция от других классов ---------------------

func _check_warmup_ownership_and_isolation() -> void:
	# Деплой-выход: разогретый владелец усиливает пульс ампа (ownership).
	var player := _make_player("guitarist", "sound_amp")
	await process_frame
	var weapon: Node = player.get("equipped_weapon")
	if weapon == null:
		_errors.append("ownership: оружие не экипировалось")
		player.free()
		return
	weapon.set_process(false)
	for stale_amp in get_nodes_in_group("deployed_sound_amps"):
		stale_amp.free()
	player.set_physics_process(false)
	player.set("_warmup_no_hit_seconds", 0.0)
	var derived: Dictionary = player.get("derived_parameters")
	derived["crit_chance"] = 0.0
	var magic_damage := float(derived.get("magic_damage", 0.0))
	for i in range(10):
		player.call("_update_warmup_trait", 1.0)

	var enemy := _make_dummy_enemy(player.global_position + Vector2(200, 0))
	await process_frame
	weapon.call("_attack")
	var hits: Array = enemy.get_meta("hits", [])
	if hits.is_empty():
		_errors.append("ownership: пульс разогретого ампа не нанёс урона")
	else:
		var direct := float((hits[0] as Dictionary).get("amount", 0.0))
		var expected := magic_damage * 1.20
		if absf(direct - expected) > expected * 0.01:
			_errors.append("ownership: пульс %.2f вместо %.2f (magic x1.20) — разогрев не дошёл до деплоя" % [direct, expected])
	player.free()
	enemy.free()
	await process_frame

	# Изоляция: другой класс не копит и не получает множитель.
	var berserk := _make_player("berserk", "sword")
	await process_frame
	for i in range(15):
		berserk.call("_update_warmup_trait", 1.0)
	if float(berserk.call("warmup_magic_bonus")) > 0.0:
		_errors.append("изоляция: Берсерк накопил чужой разогрев")
	if absf(float(berserk.call("meta_damage_multiplier", {"damage_type": "magic"})) - 1.0) > EPS:
		_errors.append("изоляция: magic-контекст Берсерка изменился")
	berserk.free()
	await process_frame


# --- helpers -----------------------------------------------------------------------

func _make_player(character_id: String, weapon_id := "") -> Node2D:
	var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(player)
	player.global_position = Vector2(600, 400)
	player.call("configure_character", character_id, weapon_id)
	return player


func _make_dummy_enemy(pos: Vector2) -> Node2D:
	var enemy := Area2D.new()
	enemy.add_to_group("enemies")
	enemy.set_meta("damage_taken", 0.0)
	enemy.set_meta("hits", [])
	enemy.set_script(_dummy_enemy_script())
	root.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _dummy_enemy_script() -> GDScript:
	# _show_combat_feedback — маркер для ClassWeapon._take_damage_accepts_feedback:
	# без него оружие шлёт урон БЕЗ typed-фидбэка и type-ассерты слепнут.
	var src := """
extends Area2D
func take_damage(amount: float, feedback := {}) -> bool:
	set_meta(\"damage_taken\", float(get_meta(\"damage_taken\", 0.0)) + amount)
	var hits: Array = get_meta(\"hits\", [])
	hits.append({\"amount\": amount, \"type\": str((feedback if feedback is Dictionary else {}).get(\"damage_type\", \"\"))})
	set_meta(\"hits\", hits)
	return true
func apply_knockback(_impulse: Vector2) -> void:
	pass
func _show_combat_feedback(_amount: float = 0.0, _feedback: Dictionary = {}) -> void:
	pass
"""
	var gd := GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd
