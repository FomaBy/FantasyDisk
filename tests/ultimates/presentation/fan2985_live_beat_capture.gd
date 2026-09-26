extends SceneTree

## FAN-2985 live evidence: three consecutive ultimates — berserk, sniper,
## soldier — cast through the real Player and the real controller, captured
## windowed mid-cast. With the fix, each frame shows only the weapon's authored
## presentation: no shared pale-blue controller ring over it.
##
## Output PNGs go to the directory in FAN2985_OUT (filename
## fan2985_<class>_<weapon>_<frame>.png). Headless runs skip rendering.

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const PlayerHost := preload("res://scripts/ultimates/controller/ultimate_player_host.gd")

const CAPTURES := [
	["berserk", "sword"],
	["sniper", "sniper_deadeye_rifle"],
	["soldier", "soldier_rifle"],
]
## Wall-clock seconds into the cast for each snapshot: right at the execute
## beat, mid-active, and late — wherever each weapon's own beats land.
const SNAPSHOTS := [0.25, 0.7, 1.6]
## Live targets around the hero so executor beats actually fire.
const TARGET_OFFSETS := [Vector2(180, 0), Vector2(-160, 90), Vector2(60, -170)]


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAN-2985 live capture skipped (headless); run windowed for PNGs.")
		quit(0)
		return
	var out := OS.get_environment("FAN2985_OUT").strip_edges()
	if out.is_empty():
		push_error("FAN-2985 live capture: FAN2985_OUT must name the output directory")
		quit(1)
		return

	var holder := Node2D.new()
	holder.position = Vector2(400, 320)
	root.add_child(holder)
	current_scene = holder
	var background := ColorRect.new()
	background.color = Color(0.05, 0.055, 0.06, 1.0)
	background.size = Vector2(1920, 1080)
	background.z_index = -50
	holder.add_child(background)
	await process_frame

	for capture in CAPTURES:
		var class_id := str(capture[0])
		var weapon_id := str(capture[1])
		var player := PlayerScene.instantiate() as Node2D
		holder.add_child(player)
		await process_frame
		player.call("configure_character", class_id, weapon_id)
		await process_frame
		var targets: Array[Node2D] = []
		for offset in TARGET_OFFSETS:
			var enemy := EnemyScene.instantiate() as Node2D
			enemy.position = offset
			enemy.set("health", 100000.0)
			enemy.set("max_health", 100000.0)
			player.add_child(enemy)
			targets.append(enemy)
		await process_frame

		var status := PlayerHost.activate(player)
		if status != PlayerHost.ACTIVATION_STARTED:
			push_error("FAN-2985 live capture: %s/%s did not start (status %d)" % [class_id, weapon_id, status])
			quit(1)
			return
		var marks := SNAPSHOTS.duplicate()
		marks.sort()
		var elapsed := 0.0
		var index := 0
		while index < marks.size():
			var target := float(marks[index])
			while elapsed < target:
				await process_frame
				elapsed += 1.0 / 60.0
			await RenderingServer.frame_post_draw
			var path := "%s/fan2985_%s_%s_%d.png" % [out, class_id, weapon_id, index]
			var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			if error != OK:
				push_error("FAN-2985 live capture failed: %s" % error_string(error))
				quit(1)
				return
			print("FAN-2985 live capture saved: %s" % path)
			index += 1

		PlayerHost.reset(player)
		for enemy in targets:
			enemy.queue_free()
		player.queue_free()
		await process_frame

	print("FAN-2985 live capture: PASS")
	quit(0)
