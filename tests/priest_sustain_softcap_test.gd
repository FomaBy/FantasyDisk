extends SceneTree

# SCRUM-603: live-регресс на «второй бессмертный класс» через heal-on-attack.
#
# SCRUM-517 закрыл drain-бессмертие per-second капом, но heal_percent_on_attack /
# melee_heal_percent_on_hit / summon_support_heal_percent шли в health БЕЗ потолка
# (через uncapped heal_percent). На толпе суммарное лечение/с (N целей × ward-тики)
# обходило cap → priest/biologist/engineer/bone_saw рисковали стать бессмертными.
# Фикс: эти боевые пути идут через player.heal_percent_capped → apply_drain_heal,
# списываясь из ЕДИНОГО per-second drain-heal бюджета.
#
# Гейт гоняет НАСТОЯЩЕГО Player.configure_character("priest","priest_censer") и
# проверяет на боевом коде:
#   A. CAPPED: суммарное heal-on-attack за окно <= DRAIN_HEAL_PER_SECOND_CAP × окно
#      (+ запас на дискретность бюджета). Лечение больше НЕ обходит per-second лимит.
#   B. MORTAL: под входящим митигированным DPS заметно выше cap чистый HP СТРОГО
#      убывает — бессмертие недостижимо даже при «8 целей × ward» спросе на лечение.
#
# Запуск: Godot --headless --path . --script res://tests/priest_sustain_softcap_test.gd

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ProgressionData := preload("res://scripts/progression_data.gd")

const EPS := 0.01
const CROWD := 8  # «8 врагов» из тикета: спрос на лечение в этот тик


# FAN-2476: делает мутационную порчу пары raw_dodge/dodge (или raw_defense/
# defense) видимой ИМЕННО этой сюите, а не только aggregate-ратчету в
# tests/attribute_consumability_fan1887_test.gd. Возвращает "" при консистентной
# паре, иначе — человеко-читаемую причину.
func _raw_pair_defect(container: Dictionary, legacy_key: String, raw_key: String) -> String:
	if not container.has(raw_key):
		return "FAN-2474: '%s' отсутствует рядом с '%s' — raw/legacy контракт нарушен." % [raw_key, legacy_key]
	var raw_value := float(container[raw_key])
	var expected := ProgressionData.effective_dodge(raw_value) if legacy_key == "dodge" else ProgressionData.effective_defense(raw_value)
	var actual := float(container.get(legacy_key, 0.0))
	if absf(actual - expected) > EPS:
		return "FAN-2474: '%s'=%.4f != effective(%s=%.2f)=%.4f — raw/legacy разошлись." % [legacy_key, actual, raw_key, raw_value, expected]
	return ""


func _neutralize_mitigation(player: Node2D, errors: Array) -> void:
	var dp: Dictionary = player.get("derived_parameters")
	if dp == null:
		dp = {}
	dp["dodge"] = 0.0
	dp["raw_dodge"] = 0.0
	dp["defense"] = 0.0
	dp["raw_defense"] = 0.0
	dp["absorb"] = 0.0
	dp["regeneration"] = 0.0  # изолируем именно heal-on-attack, не пассивный реген
	for defect in [_raw_pair_defect(dp, "dodge", "raw_dodge"), _raw_pair_defect(dp, "defense", "raw_defense")]:
		if defect != "":
			errors.append(defect)
	player.set("derived_parameters", dp)
	player.set("_damage_invulnerability_left", 0.0)


func _initialize() -> void:
	seed(603603)
	var errors: Array = []

	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame

	var drain_cap_default := float(ProgressionData.BalanceData.DRAIN_HEAL_PER_SECOND_CAP_DEFAULT)

	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	if not player.has_method("configure_character") or not player.has_method("heal_percent_capped"):
		push_error("Priest sustain gate: Player без configure_character/heal_percent_capped — гейт невозможен.")
		quit(1)
		return
	player.configure_character("priest", "priest_censer")
	await process_frame
	_neutralize_mitigation(player, errors)
	var max_hp := float(player.get("max_health"))

	# SCRUM-927/928: кит Священника больше НЕ лечит (heal_percent_on_attack убран
	# из конфигов/сцен; сустейн класса — trait «Молитва боя»). Гейт продолжает
	# сторожить КАППИРОВАННЫЙ pipeline heal-on-attack (heal_percent_capped →
	# apply_drain_heal) на живом Player+weapon — инжектим долю в оружие вручную,
	# как у любого будущего оружия с этим ключом.
	var weapon: Node = player.get("equipped_weapon")
	var per_attack := 0.012  # историческая доля censer до SCRUM-928
	if weapon != null:
		if float(weapon.get("heal_percent_on_attack")) > 0.0:
			push_error("Priest sustain gate: у кадила снова появился встроенный heal_percent_on_attack — SCRUM-928 запрещает скрытый оружейный сустейн.")
			quit(1)
			return
		weapon.set("heal_percent_on_attack", per_attack)
	var heal_pct := per_attack * float(ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER)

	# === A. CAPPED: heal-on-attack не обходит per-second бюджет ===
	# Пополняем бюджет ровно на 1 окно, затем заливаем заведомо избыточный спрос
	# (CROWD целей × несколько ward-тиков) и смотрим, сколько реально влилось.
	var window := 1.0
	# Ставим HP низко, чтобы лечение не упиралось в max_health и был виден весь бюджет.
	player.set("health", maxf(max_hp * 0.30, 1.0))
	player.call("_apply_regeneration", window)  # рефилл бюджета на окно
	var hp_before_burst := float(player.get("health"))
	for _t in range(CROWD * 4):  # 8 целей × 4 ward-тика = заведомо больше бюджета
		player.call("heal_percent_capped", heal_pct)
	var burst_heal := float(player.get("health")) - hp_before_burst
	var cap_for_window := drain_cap_default * window
	# Допуск: один «целый» heal-квант сверх бюджета (дискретное списание).
	var quantum := max_hp * heal_pct
	if burst_heal > cap_for_window + quantum + EPS:
		errors.append("CAPPED: heal-on-attack %.2f/окно > cap %.2f (+квант %.2f) — лимит обойдён" % [burst_heal, cap_for_window, quantum])
	print("Priest[censer]: capped heal/окно=%.2f (cap %.2f, квант %.2f)" % [burst_heal, cap_for_window, quantum])

	# === B. MORTAL: под входящим DPS >> cap чистый HP убывает ===
	var incoming_dps := drain_cap_default * 3.0 + 30.0  # заведомо выше потолка лечения
	var sim_seconds := 4.0
	var dt := 0.1
	player.set("health", max_hp)
	var hp_start := float(player.get("health"))
	var steps := int(sim_seconds / dt)
	for _s in range(steps):
		_neutralize_mitigation(player, errors)
		player.call("_apply_regeneration", dt)  # рефилл бюджета на dt
		# максимально возможный heal-on-attack в этот тик (толпа × ward)
		for _t in range(CROWD):
			player.call("heal_percent_capped", heal_pct)
		# входящий урон за тик
		player.set("health", float(player.get("health")) - incoming_dps * dt)
		if float(player.get("health")) <= 0.0:
			break
	var hp_end := float(player.get("health"))
	var net_drop := hp_start - hp_end
	if not (net_drop > 0.0):
		errors.append("MORTAL: HP НЕ упал за %.0fс под incoming %.1f/с (cap %.1f/с) — бессмертие" % [sim_seconds, incoming_dps, drain_cap_default])
	print("Priest[censer]: incoming=%.1f/с, HP %.1f→%.1f (drop %.1f)" % [incoming_dps, hp_start, hp_end, net_drop])

	player.queue_free()
	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Priest sustain softcap: %s" % e)
		push_error("Priest sustain softcap test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Priest sustain softcap test passed: heal-on-attack под per-second cap, priest смертен под толпой+DPS.")
	quit(0)
