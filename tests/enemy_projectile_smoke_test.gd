extends SceneTree

# Smoke-тест enemy_projectile.gd (был непокрыт). Вражеский снаряд бьёт игрока;
# ключевое — однократное попадание (_has_hit), иначе один снаряд бьёт много раз.
# Тестируем чистую логику прямыми вызовами (без физ-тика, без progression_data).
# Отдельный изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/enemy_projectile_smoke_test.gd

const EnemyProjectile := preload("res://scripts/enemy_projectile.gd")
const EnemyProjectileScene := preload("res://scenes/EnemyProjectile.tscn")

const EPS := 0.001


class MockPlayer extends Node:
	var hits := 0
	var last_damage := -1.0
	var last_source := ""
	func take_damage(amount: float, source := "") -> void:
		hits += 1
		last_damage = amount
		last_source = source


func _initialize() -> void:
	var errors: Array = []

	# --- setup(): позиция/урон/скорость/направление/поворот ---
	var p: Area2D = EnemyProjectile.new()
	p.setup(Vector2(200, 200), Vector2(200, 0), 12.0, 480.0)
	if not p.global_position.is_equal_approx(Vector2(200, 200)):
		errors.append("setup: позиция %s != (200,200)" % p.global_position)
	if absf(float(p.get("damage")) - 12.0) > EPS:
		errors.append("setup: damage %s != 12" % p.get("damage"))
	if absf(float(p.get("speed")) - 480.0) > EPS:
		errors.append("setup: speed %s != 480" % p.get("speed"))
	var dir: Vector2 = p.get("direction")
	if not dir.is_equal_approx(Vector2(0, -1)):
		errors.append("setup: direction %s != (0,-1) (вверх)" % dir)
	if absf(p.rotation - dir.angle()) > EPS:
		errors.append("setup: rotation != direction.angle()")
	p.free()

	# --- setup() edge: цель == старт -> дефолтное направление, без NaN ---
	var pe: Area2D = EnemyProjectile.new()
	pe.setup(Vector2(10, 10), Vector2(10, 10), 5.0, 300.0)
	var de: Vector2 = pe.get("direction")
	if not is_finite(de.x) or not is_finite(de.y) or de.length() < 0.5:
		errors.append("setup edge: вырожденное/NaN направление %s" % de)
	pe.free()

	# --- движение + lifetime ---
	var pm: Area2D = EnemyProjectile.new()
	pm.setup(Vector2(500, 500), Vector2(900, 500), 5.0, 360.0)  # вправо
	var before: Vector2 = pm.global_position
	pm.call("_physics_process", 0.1)
	var moved := pm.global_position - before
	if absf(moved.x - 360.0 * 0.1) > 0.01 or absf(moved.y) > EPS:
		errors.append("движение: сдвиг %s != (36,0)" % moved)
	var lt := float(pm.get("lifetime"))
	pm.call("_physics_process", 0.5)
	if absf((lt - 0.5) - float(pm.get("lifetime"))) > EPS:
		errors.append("lifetime не убывает на delta")
	pm.free()

	# --- _is_outside_arena ---
	var pa: Area2D = EnemyProjectile.new()
	pa.global_position = Vector2(1280, 720)
	if bool(pa.call("_is_outside_arena")):
		errors.append("_is_outside_arena: центр посчитан снаружи")
	pa.global_position = Vector2(1280, -300)  # y < -180
	if not bool(pa.call("_is_outside_arena")):
		errors.append("_is_outside_arena: точка сверху за полем не снаружи")
	pa.free()

	# --- коллизия: урон только игроку + ОДНОКРАТНОСТЬ (_has_hit) ---
	var pc: Area2D = EnemyProjectile.new()
	pc.setup(Vector2.ZERO, Vector2(0, 10), 9.0, 300.0)
	var player := MockPlayer.new()
	player.add_to_group("player")
	pc.call("_on_body_entered", player)
	if player.hits != 1 or absf(player.last_damage - 9.0) > EPS or player.last_source != "projectile":
		errors.append("коллизия: первый удар по игроку неверен (hits=%d dmg=%s src=%s)" % [player.hits, player.last_damage, player.last_source])
	# Второе попадание тем же снарядом НЕ должно бить повторно.
	pc.call("_on_body_entered", player)
	if player.hits != 1:
		errors.append("ОДНОКРАТНОСТЬ нарушена: _has_hit не предотвратил повторный удар (hits=%d)" % player.hits)
	pc.free()
	player.free()

	# --- не-игрок не получает урон ---
	var pc2: Area2D = EnemyProjectile.new()
	pc2.setup(Vector2.ZERO, Vector2(0, 10), 9.0, 300.0)
	var not_player := MockPlayer.new()  # НЕ в группе player
	pc2.call("_on_body_entered", not_player)
	if not_player.hits != 0:
		errors.append("коллизия: урон нанесён не-игроку (hits=%d)" % not_player.hits)
	pc2.free()
	not_player.free()

	# --- runtime VFX: scene projectile has a textured trail + impact feedback ---
	await process_frame
	var pv: Area2D = EnemyProjectileScene.instantiate()
	root.add_child(pv)
	await process_frame
	if pv.get_node_or_null("ProjectileTrailVfx") == null:
		errors.append("runtime VFX: снаряд без ProjectileTrailVfx")
	var vfx_player := MockPlayer.new()
	vfx_player.add_to_group("player")
	pv.setup(Vector2(64, 64), Vector2(128, 64), 7.0, 300.0)
	pv.call("_on_body_entered", vfx_player)
	var found_impact := false
	for child in root.get_children():
		if child.name == "EnemyProjectileImpactVfx":
			found_impact = true
			child.queue_free()
	if not found_impact:
		errors.append("runtime VFX: попадание не создало EnemyProjectileImpactVfx")
	vfx_player.free()
	await process_frame

	# --- despawn по истечении lifetime (в дереве) ---
	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame
	var pd: Area2D = EnemyProjectile.new()
	holder.add_child(pd)
	await process_frame
	pd.setup(Vector2(1280, 720), Vector2(1280, 820), 5.0, 300.0)
	pd.set("lifetime", 0.01)
	pd.call("_physics_process", 1.0)
	await process_frame
	if is_instance_valid(pd):
		errors.append("despawn: снаряд не освобождён после lifetime")
	holder.queue_free()
	await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Enemy projectile smoke: %s" % e)
		push_error("Enemy projectile smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Enemy projectile smoke test passed (setup/движение/arena/коллизия+однократность/runtime VFX/despawn).")
	quit(0)
