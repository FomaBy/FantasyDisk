extends "res://scripts/classes/biologist_weapon.gd"

# FAN-3840: модуль распределённого боевого класса ClassWeapon — класс-локальные исполнители и приватные хелперы класса chemist.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


# FAN-2238: окно жизни реагентного следа взрыва. Больше базового fire_interval
# пыли (0.62) — соседние броски успевают встретиться, но пауза в стрельбе след
# гасит. Это темп продакшен-оружия, а не балансный кап финала: манифестные капы
# (reactions_per_cloud / combo_damage_ratio / same_reagent_reaction) живут в
# schema-6 и читаются из профиля.
const POWDER_REAGENT_TRACE_SECONDS := 0.9


func _find_combo_cloud(pool_position: Vector2) -> Node2D:
	if not combo_clouds:
		return null
	for cloud in get_tree().get_nodes_in_group("chemist_clouds"):
		var cloud_node := cloud as Node2D
		if cloud_node == null or not is_instance_valid(cloud_node):
			continue
		var cloud_element := str(cloud_node.get_meta("pool_element", ""))
		if pool_element != "" and cloud_element == pool_element:
			continue
		if cloud_node.global_position.distance_squared_to(pool_position) <= pow(aoe_radius * 0.95, 2.0):
			return cloud_node
	return null


## `direct_share` — доля БАЗОВОЙ смешанной вспышки. Пул-канал (встреча двух луж)
## существует и без созвездия, поэтому платит полную долю; реагентная пара пыли
## (FAN-2238) базового аналога не имеет и приходит с 0.0 — там весь урон реакции
## равен объявленному в манифесте `combo_damage_ratio` финала, и без финала
## оружие не получает ничего.
func _trigger_chemist_combo(new_cloud: Node2D, old_cloud: Node2D, tick_damage: float, direct_share := 1.0) -> void:
	if bool(new_cloud.get_meta("constellation_powder_reacted", false)) or bool(old_cloud.get_meta("constellation_powder_reacted", false)):
		return
	new_cloud.set_meta("constellation_powder_reacted", true)
	old_cloud.set_meta("constellation_powder_reacted", true)
	var combo_position := (new_cloud.global_position + old_cloud.global_position) * 0.5
	var combo_radius := aoe_radius * 1.05
	var combo_damage := maxf(damage, tick_damage * 5.5) * pool_direct_damage_multiplier
	AttackVfx.orb_burst(_projectile_parent(), combo_position, combo_radius, Color(1.0, 0.75, 0.16, 0.50))
	if direct_share > 0.0:
		_damage_enemies_in_circle_capped(combo_position, combo_radius, combo_damage * direct_share, POOL_PROJECTILE_FULL_TARGETS, POOL_PROJECTILE_TARGET_DIMINISH)
	var combo_target := TARGET_QUERY.nearest(self, combo_position, combo_radius)
	var reaction := _constellation_event("cross_reagent", combo_target, 0.0)
	if bool(reaction.get("triggered", false)):
		_damage_enemies_in_circle_capped(combo_position, combo_radius, combo_damage * _constellation_result_param(reaction, "combo_damage_ratio", 0.48), POOL_PROJECTILE_FULL_TARGETS, POOL_PROJECTILE_TARGET_DIMINISH)


## FAN-2238: продакшен-вход финала «Несовместимые реагенты». Взрывная пыль давно
## идёт прямым AoE без луж, поэтому облачный вход `_spawn_damage_pool` для неё
## мёртв — реакцию поднимает РЕАЛЬНЫЙ прилёт снаряда. Каждый взрыв оставляет
## короткий инертный след своего реагента (не `chemist_clouds`, без тиков, DoT и
## статусов), и соседний взрыв другого реагента внутри следа расходует пару на
## одну реакцию (`reactions_per_cloud` = 1 через латч `_trigger_chemist_combo`).
## Без купленного финала след не создаётся вовсе.
func _mark_powder_reagent_impact(impact_position: Vector2, reagent: int) -> void:
	var profile := _constellation_profile("powder_cross_reagent_combo")
	if profile.is_empty():
		return
	var params: Dictionary = profile.get("params", {})
	var previous := _powder_reagent_trace
	var trace := _spawn_powder_reagent_trace(impact_position, reagent)
	_powder_reagent_trace = trace
	if previous == null or not is_instance_valid(previous):
		return
	if Time.get_ticks_msec() > int(previous.get_meta("powder_reagent_until_msec", 0)):
		return
	var cross_reagent := int(previous.get_meta("powder_reagent", reagent)) != reagent
	if not cross_reagent and not bool(params.get("same_reagent_reaction", false)):
		return
	if previous.global_position.distance_squared_to(impact_position) > pow(aoe_radius, 2.0):
		return
	_trigger_chemist_combo(trace, previous, 0.0, 0.0)
	_release_effect(previous)
	_release_effect(trace)
	_powder_reagent_trace = null


func _spawn_powder_reagent_trace(trace_position: Vector2, reagent: int) -> Node2D:
	var trace := Node2D.new()
	trace.name = "PowderReagentTrace"
	trace.set_meta("powder_reagent", reagent)
	trace.set_meta("powder_reagent_until_msec", Time.get_ticks_msec() + int(POWDER_REAGENT_TRACE_SECONDS * 1000.0))
	_register_effect(trace)
	_projectile_parent().add_child(trace)
	trace.global_position = trace_position
	var expiry := trace.create_tween()
	expiry.tween_interval(POWDER_REAGENT_TRACE_SECONDS)
	expiry.tween_callback(Callable(self, "_release_effect").bind(trace))
	return trace


# SCRUM-961 «Летучая пыль»: blast_powder переведён в режим быстрого AoE без облака.
func _volatile_powder_active() -> bool:
	return weapon_id == "blast_powder" and _owner_mod("volatile_powder_mode") > 0.0
