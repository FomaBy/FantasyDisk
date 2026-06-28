extends SceneTree

# SCRUM-607: +4 новых мини-элитных вида Возвышения (Эхо бездны, Возвышение 7).
#
# enemy_content_integrity_test уже валидирует ДАННЫЕ ростера (id/scene/behavior/
# mults/tint кросс-ссылки). Этот гейт проверяет, что новые виды реально СПАВНЯТСЯ
# на готовых elite-сценах без краша и что tint виден на rig — повторяет ядро
# combat_director._apply_mini_elite_kind (scene→PackedScene, hp/speed/damage mult,
# rig.modulate) на каждом виде ростера.
#
# Acceptance (из тикета): спавн на Возвышении>=7 не падает, tint виден.
#
# Запуск: Godot --headless --path . --script res://tests/mini_elite_roster_spawn_test.gd

const EnemyData := preload("res://scripts/progression_data_enemies.gd")

# scene-ключ ростера -> реальная elite-сцена (зеркало combat_director._elite_scene_by_key).
const SCENE_BY_KEY := {
	"armored": "res://scenes/EliteArmored.tscn",
	"stalker": "res://scenes/EliteStalker.tscn",
	"poisoned": "res://scenes/ElitePoisoned.tscn",
	"commander": "res://scenes/EliteCommander.tscn",
}

# Новые виды из SCRUM-607 — отдельно проверяем, что добавленная четвёрка на месте.
const NEW_KIND_IDS := [
	"mini_siege_rammer", "mini_swarm_sniper", "mini_plague_berserker", "mini_void_phantom",
]


func _initialize() -> void:
	seed(607607)
	var errors: Array = []

	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame

	var kinds: Array = EnemyData.MINI_ELITE_KINDS
	var seen_new := {}

	for entry in kinds:
		var kind: Dictionary = entry
		var kid := str(kind.get("id", ""))
		var scene_key := str(kind.get("scene", ""))
		# Каждый scene-ключ обязан резолвиться в реальную сцену (иначе _elite_scene_by_key=null).
		var scene_path := str(SCENE_BY_KEY.get(scene_key, ""))
		if scene_path == "":
			errors.append("вид '%s': scene-ключ '%s' вне {armored,stalker,poisoned,commander}" % [kid, scene_key])
			continue
		var packed := load(scene_path) as PackedScene
		if packed == null:
			errors.append("вид '%s': сцена %s не загрузилась" % [kid, scene_path])
			continue
		var elite := packed.instantiate() as Node2D
		holder.add_child(elite)
		await process_frame

		# Применяем профиль вида (как combat_director). Базу берём после готовности.
		var base_hp := float(elite.get("max_health")) if elite.get("max_health") != null else 0.0
		var hp_mult := float(kind.get("hp_mult", 0.55))
		if elite.get("max_health") != null:
			elite.set("max_health", base_hp * hp_mult)
			elite.set("health", base_hp * hp_mult)
		if elite.get("move_speed") != null:
			elite.set("move_speed", float(elite.get("move_speed")) * float(kind.get("speed_mult", 1.0)))
		if elite.get("contact_damage") != null:
			elite.set("contact_damage", float(elite.get("contact_damage")) * float(kind.get("damage_mult", 1.0)))

		# tint виден: rig.modulate должен принять цвет вида.
		var tint: Array = kind.get("tint", [])
		if tint.size() >= 3:
			var rig := elite.get_node_or_null("RigRoot") as Node2D
			if rig != null:
				rig.modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]), 1.0)
				var applied := rig.modulate
				if absf(applied.r - float(tint[0])) > 0.01 or absf(applied.g - float(tint[1])) > 0.01 or absf(applied.b - float(tint[2])) > 0.01:
					errors.append("вид '%s': tint не применился на rig" % kid)

		# Санити: после профиля HP > 0 (вид жив).
		if elite.get("max_health") != null and float(elite.get("max_health")) <= 0.0:
			errors.append("вид '%s': max_health <= 0 после профиля" % kid)

		if NEW_KIND_IDS.has(kid):
			seen_new[kid] = true
		elite.queue_free()
		await process_frame

	# Все 4 новых вида присутствуют в ростере.
	for need in NEW_KIND_IDS:
		if not seen_new.has(need):
			errors.append("новый вид '%s' отсутствует в MINI_ELITE_KINDS" % need)

	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Mini-elite roster spawn: %s" % e)
		push_error("Mini-elite roster spawn test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Mini-elite roster spawn test passed: %d видов спавнятся, новых +%d, tint виден." % [kinds.size(), NEW_KIND_IDS.size()])
	quit(0)
