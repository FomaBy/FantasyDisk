extends SceneTree

# SCRUM-599: live-регресс на ваншот fragile-класса ОБЫЧНЫМ контактным уроном.
#
# Уникальные элитные атаки уже капятся 25% max HP (enemy._elite_attack_damage),
# но РЯДОВОЙ контактный урон (enemy._update_contact_damage) шёл в player.take_damage
# без потолка. На поздних стадиях combat_director множит enemy.contact_damage на
# damage_multiplier (~4.9x stage 10; bruiser-профиль ~6.8x базы) → один тычок
# ваншотил героя с 80 HP. Фикс: hit = minf(contact_damage, max_health * 0.20)
# ПЕРЕД take_damage.
#
# Гейт гоняет НАСТОЯЩИЕ Enemy + Player на боевом коде:
#   A. CAPPED: stage-10 bruiser (огромный contact_damage) бьёт за один тик
#      <= 20% max HP (16 при max_health=80) — ваншот fragile-класса невозможен.
#   B. PASSTHROUGH: мелкий контактный урон (ниже капа) проходит без срезки —
#      потолок не ломает обычный ранний бой.
#
# Митигацию (dodge/defense/absorb) обнуляем, чтобы ИЗОЛИРОВАТЬ сам кап:
# с нулевой защитой нанесённый HP-дроп == значению, переданному в take_damage,
# т.е. без капа дроп был бы ~68, с капом ровно <=16.
#
# Запуск: Godot --headless --path . --script res://tests/contact_damage_softcap_test.gd

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

const EPS := 0.01
const MAX_HP := 80.0
const CAP_FRACTION := 0.20  # должно совпадать с enemy._update_contact_damage


func _neutralize_mitigation(player: Node2D) -> void:
	# Обнуляем survivability-параметры, чтобы take_damage не срезал/не дожал удар:
	# тогда HP-дроп == ровно тому урону, что прошёл через кап.
	var dp: Dictionary = player.get("derived_parameters")
	if dp == null:
		dp = {}
	dp["dodge"] = 0.0
	dp["defense"] = 0.0
	dp["absorb"] = 0.0
	# Принятый контракт защиты/уворота считает митигацию из СЫРЫХ рейтингов, поэтому
	# обнуляем и их: effective_defense(0) == effective_dodge(0) == 0 на любой кривой,
	# а голый процент без raw-рейтинга оставил бы классовую защиту живой.
	dp["raw_dodge"] = 0.0
	dp["raw_defense"] = 0.0
	player.set("derived_parameters", dp)
	# Снимаем i-frames и любые рантайм-щиты от прошлого тика.
	player.set("_damage_invulnerability_left", 0.0)


# Прогоняет _update_contact_damage до тех пор, пока враг не нанесёт ОДИН удар,
# и возвращает фактический HP-дроп игрока за этот удар.
func _drive_single_contact_hit(enemy: Node2D, player: Node2D) -> float:
	var dt := 0.05
	# Враг вплотную: дистанция 0 заведомо <= contact_range.
	enemy.global_position = player.global_position
	player.set("health", MAX_HP)
	player.set("max_health", MAX_HP)
	_neutralize_mitigation(player)
	var hp_before := float(player.get("health"))
	# Окна хватает на windup (0.22с) + сам удар; режем на первом снижении HP.
	var steps := int(2.0 / dt)
	for _s in range(steps):
		_neutralize_mitigation(player)  # держим митигацию в нуле каждый тик
		enemy.call("_update_contact_damage", dt, player, 0.0)
		if float(player.get("health")) < hp_before - EPS:
			break
	return hp_before - float(player.get("health"))


func _initialize() -> void:
	seed(599599)
	var errors: Array = []

	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame

	# --- A. CAPPED: stage-10 bruiser, огромный contact_damage ---
	# Сырой урон сильно выше капа (имитируем damage_multiplier ~6.8x на базе ~10).
	var raw_contact := 68.0
	var enemy := ENEMY_SCENE.instantiate() as Node2D
	holder.add_child(enemy)
	enemy.add_to_group("enemies")
	var player := PLAYER_SCENE.instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	await process_frame
	if not player.has_method("take_damage") or not enemy.has_method("_update_contact_damage"):
		push_error("Contact softcap: нет take_damage/_update_contact_damage — гейт невозможен.")
		quit(1)
		return
	enemy.set("contact_damage", raw_contact)
	enemy.set("contact_windup_time", 0.05)  # быстрее дойти до удара в тесте
	var capped_drop := _drive_single_contact_hit(enemy, player)
	var cap_value := MAX_HP * CAP_FRACTION  # 16.0
	if capped_drop <= EPS:
		errors.append("CAPPED: удар не нанёс урона (drop=%.2f) — гейт не сработал" % capped_drop)
	if capped_drop > cap_value + EPS:
		errors.append("CAPPED: контактный урон %.2f > капа %.2f (20%% от %.0f) — ваншот всё ещё возможен" % [capped_drop, cap_value, MAX_HP])
	print("Contact[bruiser stage10]: raw=%.1f → drop=%.2f (cap %.2f)" % [raw_contact, capped_drop, cap_value])

	# --- B. PASSTHROUGH: мелкий контактный урон проходит без срезки ---
	var small_contact := 8.0  # заведомо ниже капа 16
	enemy.set("contact_damage", small_contact)
	enemy.set("contact_windup_time", 0.05)
	enemy.set("_contact_cooldown", 0.0)
	enemy.set("_contact_windup_left", -1.0)
	var small_drop := _drive_single_contact_hit(enemy, player)
	if absf(small_drop - small_contact) > 0.5:
		errors.append("PASSTHROUGH: мелкий урон %.1f срезан до %.2f — кап ломает ранний бой" % [small_contact, small_drop])
	print("Contact[small]: raw=%.1f → drop=%.2f (ожидали ~%.1f)" % [small_contact, small_drop, small_contact])

	enemy.queue_free()
	player.queue_free()
	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Contact damage softcap: %s" % e)
		push_error("Contact damage softcap test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Contact damage softcap test passed: рядовой контактный урон капится 20%% max HP, мелкий проходит без срезки.")
	quit(0)
