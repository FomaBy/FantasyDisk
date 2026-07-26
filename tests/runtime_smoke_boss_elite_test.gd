extends "res://tests/runtime_smoke_test.gd"


func _initialize() -> void:
	var main_scene := load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene did not load for boss/elite smoke.")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await _test_elite_flow(main_scene)
	await _test_elite_unique_attacks()
	await _test_enemy_stage_scaling_and_elite_rewards(main_scene)
	await _test_epic_elite_boss_scale_hitbox()
	await _test_elite_phase2_escalation()
	await _test_boss_zone_wave_safe_corridor()
	await _test_elite_boss_presentation(main_scene)
	# SCRUM-799 renamed _test_boss_hud_omits_timer -> _test_boss_hud_shows_timer
	# (boss/elite fights now SHOW the kill-timer) but missed updating this child call,
	# which broke the boss/elite smoke with a parse error. Point at the renamed fn.
	await _test_boss_hud_shows_timer(main_scene)
	await _test_mini_elite_roster(main_scene)
	await _test_new_boss_roster(main_scene)
	await _test_bloodthorn_lion_boss(main_scene)
	await _test_secret_boss_after_final_act_flow(main_scene)
	await _test_secret_boss_uses_full_frame()
	_test_hazard_telegraph_texture_param()
	await _test_boss_death_victory_delay(main)
	await _test_victory_flow(main)

	main.queue_free()
	await process_frame
	_finish("Runtime boss/elite smoke suite passed.")


# SCRUM-702: секретный босс должен использовать ДОСТАВЛЕННУЮ анимацию
# (secret_ascension_boss_spriteframes.tres) через meta-путь full_frame_spriteframes_path,
# а не плейсхолдер-спрайт disk_devourer. Раньше арт был не подключён; гейтим, чтобы
# регрессия (снос меты/спрайтфреймов) падала здесь.
func _test_secret_boss_uses_full_frame() -> void:
	var boss_scene := load("res://scenes/BossSecretAscension.tscn") as PackedScene
	if boss_scene == null:
		_fail("BossSecretAscension scene did not load.")
		return
	var boss := boss_scene.instantiate()
	root.add_child(boss)
	await process_frame
	await process_frame
	var expected_frames := "res://assets/sprites/bosses/full_frame/secret_ascension_boss_spriteframes.tres"
	if str(boss.get_meta("full_frame_spriteframes_path", "")) != expected_frames:
		_fail("Secret boss scene must expose full_frame_spriteframes_path meta to the delivered SpriteFrames.")
		boss.queue_free()
		return
	var full_frame_body := boss.get_node_or_null("FullFrameBody") as AnimatedSprite2D
	if full_frame_body == null or full_frame_body.sprite_frames == null:
		_fail("Secret boss must configure a FullFrameBody from the delivered SpriteFrames (got static fallback).")
		boss.queue_free()
		return
	if full_frame_body.sprite_frames.resource_path != expected_frames:
		_fail("Secret boss FullFrameBody must use the delivered secret_ascension_boss SpriteFrames, got %s." % full_frame_body.sprite_frames.resource_path)
		boss.queue_free()
		return
	# Плейсхолдер-Sprite2D (disk_devourer) должен быть скрыт, когда играет full-frame.
	var static_sprite := boss.get_node_or_null("Sprite2D") as CanvasItem
	if static_sprite != null and static_sprite.visible:
		_fail("Secret boss static placeholder Sprite2D must be hidden once the full-frame body is active.")
		boss.queue_free()
		return
	boss.queue_free()
	await process_frame


func _test_boss_death_victory_delay(main: Node) -> void:
	main.set("combat_active", true)
	main.set("boss_combat_active", true)
	main.set("current_combat_type", "boss")
	main.combat.request_boss_victory_after_death()
	if not main.combat.is_boss_victory_pending():
		_fail("Expected boss victory to become pending so the death animation can play before _end_combat.")
	if not bool(main.get("combat_active")):
		_fail("Expected boss death victory delay to avoid immediate combat end.")
	main.combat.set("_boss_victory_pending", false)
	main.set("boss_combat_active", false)
	main.set("combat_active", false)
	await process_frame


# SCRUM-790: HazardVfx.telegraph texture-параметр. Переданная текстура попадает в zone-
# Sprite2D; без неё (null, путь остальных боссов) — процедурный круг. Гейтит и фичу
# (доставленный PNG секретного босса), и регресс-безопасность (null = прежнее поведение).
func _test_hazard_telegraph_texture_param() -> void:
	var HazardVfxScript := load("res://scripts/hazard_vfx.gd")
	var ring_tex := load("res://assets/sprites/effects/secret_ascension_boss_ring_telegraph.png") as Texture2D
	if ring_tex == null:
		_fail("Secret boss ring telegraph PNG must load.")
		return
	var host_custom := Node2D.new()
	root.add_child(host_custom)
	var tele_custom: Node2D = HazardVfxScript.telegraph(host_custom, 120.0, Color.WHITE, 0.4, ring_tex)
	var zone_custom := tele_custom.get_child(0) as Sprite2D
	if zone_custom == null or zone_custom.texture != ring_tex:
		_fail("HazardVfx.telegraph must use the supplied delivered texture on the zone sprite.")
		host_custom.queue_free()
		return
	host_custom.queue_free()
	# Регресс: без текстуры процедурный круг сохраняется (не null, не доставленный PNG).
	var host_default := Node2D.new()
	root.add_child(host_default)
	var tele_default: Node2D = HazardVfxScript.telegraph(host_default, 120.0, Color.WHITE, 0.4)
	var zone_default := tele_default.get_child(0) as Sprite2D
	if zone_default == null or zone_default.texture == null or zone_default.texture == ring_tex:
		_fail("HazardVfx.telegraph without texture must keep the procedural zone texture (regression).")
		host_default.queue_free()
		return
	host_default.queue_free()


# SCRUM-794: новый босс bloodthorn_lion из design-пакета SCRUM-779 — сцена/поведение/
# уникальная механика/паттерн-мета/кодекс готовы к рантайму. Босс ПОКА НЕ в случайном
# route-пуле (route_map_screen._random_boss_route_node) — ротация подключается отдельной
# задачей после QA; здесь гейтим, что он корректно резолвится и дерётся при прямом спавне.
func _test_bloodthorn_lion_boss(main_scene: PackedScene) -> void:
	var boss_id := "bloodthorn_lion"
	var m := main_scene.instantiate()
	root.add_child(m)
	await process_frame
	# 1. Сцена резолвится через combat-директор.
	var scene: PackedScene = m.combat.call("_boss_scene_for_id", boss_id)
	if scene == null:
		_fail("Expected boss scene for '%s'." % boss_id)
		m.queue_free()
		return
	# Регресс-инвариант: новый босс НЕ должен протечь в случайную ротацию маршрута
	# (пул остаётся детерминированным набором из 5 боссов до отдельной QA-задачи).
	var seen_bosses := {}
	for _roll in range(120):
		var node: Dictionary = m.route.call("_random_boss_route_node")
		seen_bosses[str(node.get("boss_id", ""))] = true
	if seen_bosses.has(boss_id):
		_fail("Bloodthorn Lion must stay OUT of the random boss route pool until QA-gated rotation task.")
		m.queue_free()
		return
	var holder := Node2D.new()
	root.add_child(holder)
	current_scene = holder
	var boss := scene.instantiate() as Node2D
	holder.add_child(boss)
	await process_frame
	# 2. Поведение/титул/эпик-скейл.
	if str(boss.get("boss_behavior")) != boss_id:
		_fail("Expected boss behavior '%s', got '%s'." % [boss_id, str(boss.get("boss_behavior"))])
		holder.queue_free()
		m.queue_free()
		return
	if str(boss.get("boss_display_name")) != "Кровавый Шипастый Лев":
		_fail("Expected Russian display name for '%s'." % boss_id)
		holder.queue_free()
		m.queue_free()
		return
	# 3. Паттерн-мета из UNIQUE_ENCOUNTER_PATTERNS (>=3 механики).
	if str(boss.get_meta("unique_pattern_id", "")) != boss_id:
		_fail("Expected boss '%s' to expose its unique encounter pattern meta." % boss_id)
		holder.queue_free()
		m.queue_free()
		return
	var boss_mechanics: Array = boss.get_meta("unique_mechanics", []) as Array
	if boss_mechanics.size() < 3:
		_fail("Expected boss '%s' to expose at least 3 unique mechanics." % boss_id)
		holder.queue_free()
		m.queue_free()
		return
	var expected_boss_scale: float = float(ProgressionData.enemy_size_profile("boss").get("scale", 1.9))
	if absf(boss.scale.x - expected_boss_scale) > 0.01:
		_fail("Expected epic boss scale %.2f for '%s'." % [expected_boss_scale, boss_id])
		holder.queue_free()
		m.queue_free()
		return
	# 4. Уникальная механика создаёт опознаваемый узел BloodthornSpikeRing.
	var player := (load("res://scenes/Player.tscn") as PackedScene).instantiate() as Node2D
	holder.add_child(player)
	player.add_to_group("player")
	player.global_position = boss.global_position + Vector2(280, 0)
	await process_frame
	boss.set("_boss_unique_cooldown", 0.0)
	boss.call("_update_boss_attacks", 0.1)
	await process_frame
	if holder.find_child("BloodthornSpikeRing", true, false) == null:
		_fail("Expected boss '%s' unique mechanic to spawn BloodthornSpikeRing." % boss_id)
		holder.queue_free()
		m.queue_free()
		return
	# 5. Ротация атак создаёт хазарды/зоны без ошибок.
	var hazards_before := holder.find_children("*", "Node2D", true, false).size()
	for _tick in range(220):
		boss.call("_update_boss_attacks", 0.05)
	await process_frame
	if holder.find_children("*", "Node2D", true, false).size() <= hazards_before:
		_fail("Expected boss '%s' attack rotation to spawn hazards/summons." % boss_id)
		holder.queue_free()
		m.queue_free()
		return
	# 6. Фаза 3 при 30% HP (обычный боссовый порог).
	boss.set("health", float(boss.get("max_health")) * 0.30)
	boss.call("_update_boss_phase")
	if int(boss.get("boss_phase")) < 3:
		_fail("Expected boss '%s' to reach phase 3 at 30%% HP." % boss_id)
		holder.queue_free()
		m.queue_free()
		return
	holder.queue_free()
	current_scene = null
	m.queue_free()
	await process_frame
