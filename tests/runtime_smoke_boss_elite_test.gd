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
	await _test_boss_hud_omits_timer(main_scene)
	await _test_mini_elite_roster(main_scene)
	await _test_new_boss_roster(main_scene)
	await _test_secret_boss_after_act3_flow(main_scene)
	await _test_secret_boss_uses_full_frame()
	_test_hazard_telegraph_texture_param()
	await _test_victory_flow(main)

	main.queue_free()
	await process_frame
	print("Runtime boss/elite smoke suite passed.")
	quit()


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
