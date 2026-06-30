extends SceneTree

# Smoke-тест projectile.gd (был непокрыт). Снаряд — базовая боевая нода: неверное
# направление = промахи, сломанный lifetime/arena-cleanup = утечки/залёты,
# сломанный коллижн = нет урона. Тестируем чистую логику прямыми вызовами
# (без зависимости от физ-тика и без progression_data). Отдельный изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/projectile_smoke_test.gd

const Projectile := preload("res://scripts/projectile.gd")

const EPS := 0.001


class MockEnemy extends Node:
	var received := -1.0
	func take_damage(amount: float) -> void:
		received = amount


func _initialize() -> void:
	var errors: Array = []

	# --- setup(): позиция/урон/направление/поворот ---
	var p: Area2D = Projectile.new()
	p.setup(Vector2(100, 100), Vector2(100, 300), 25.0)
	if not p.global_position.is_equal_approx(Vector2(100, 100)):
		errors.append("setup: позиция %s != (100,100)" % p.global_position)
	if absf(float(p.get("damage")) - 25.0) > EPS:
		errors.append("setup: damage %s != 25" % p.get("damage"))
	var dir: Vector2 = p.get("direction")
	if not dir.is_equal_approx(Vector2(0, 1)):
		errors.append("setup: direction %s != (0,1) (вниз)" % dir)
	if absf(p.rotation - dir.angle()) > EPS:
		errors.append("setup: rotation %.4f != direction.angle() %.4f" % [p.rotation, dir.angle()])
	p.free()

	# --- setup() edge: цель == старт -> направление по умолчанию, без NaN ---
	var p2: Area2D = Projectile.new()
	p2.setup(Vector2(50, 50), Vector2(50, 50), 10.0)
	var d2: Vector2 = p2.get("direction")
	if not is_finite(d2.x) or not is_finite(d2.y) or d2.length() < 0.5:
		errors.append("setup edge: вырожденное/NaN направление %s" % d2)
	p2.free()

	# --- движение: _physics_process сдвигает на direction*speed*delta ---
	var p3: Area2D = Projectile.new()
	p3.setup(Vector2(500, 500), Vector2(900, 500), 5.0)  # вправо -> (1,0)
	var speed := float(p3.get("speed"))
	var before: Vector2 = p3.global_position
	p3.call("_physics_process", 0.1)
	var moved := p3.global_position - before
	if absf(moved.x - speed * 0.1) > 0.01 or absf(moved.y) > EPS:
		errors.append("движение: сдвиг %s != ожидаемого (%.1f,0)" % [moved, speed * 0.1])
	# lifetime убывает на delta.
	var lt_before := float(p3.get("lifetime"))
	p3.call("_physics_process", 0.5)
	if absf((lt_before - 0.5) - float(p3.get("lifetime"))) > EPS:
		errors.append("lifetime не убывает на delta")
	p3.free()

	# --- _is_outside_arena (границы выводим из констант снаряда, чтобы тест не
	#     устаревал при ребалансе арены — SCRUM-712: точка справа была захардкожена
	#     под старый 2560 и стала ВНУТРИ арены после бампа ARENA_SIZE до 4096 ×1.6). ---
	var arena: Vector2 = Projectile.ARENA_SIZE
	var margin: float = float(Projectile.CLEANUP_MARGIN)
	var center := arena * 0.5
	var p4: Area2D = Projectile.new()
	p4.global_position = center
	if bool(p4.call("_is_outside_arena")):
		errors.append("_is_outside_arena: центр арены посчитан снаружи")
	p4.global_position = Vector2(-(margin + 120.0), center.y)  # x < -CLEANUP_MARGIN
	if not bool(p4.call("_is_outside_arena")):
		errors.append("_is_outside_arena: точка слева за полем не посчитана снаружи")
	p4.global_position = Vector2(arena.x + margin + 120.0, center.y)  # x > ARENA_SIZE.x + margin
	if not bool(p4.call("_is_outside_arena")):
		errors.append("_is_outside_arena: точка справа за полем не посчитана снаружи")
	p4.global_position = Vector2(center.x, -(margin + 120.0))  # y < -CLEANUP_MARGIN
	if not bool(p4.call("_is_outside_arena")):
		errors.append("_is_outside_arena: точка сверху за полем не посчитана снаружи")
	p4.global_position = Vector2(center.x, arena.y + margin + 120.0)  # y > ARENA_SIZE.y + margin
	if not bool(p4.call("_is_outside_arena")):
		errors.append("_is_outside_arena: точка снизу за полем не посчитана снаружи")
	p4.free()

	# --- коллизия: урон только врагам ---
	var p5: Area2D = Projectile.new()
	p5.setup(Vector2.ZERO, Vector2(10, 0), 17.0)
	var enemy := MockEnemy.new()
	enemy.add_to_group("enemies")
	p5.call("_on_body_entered", enemy)
	if absf(enemy.received - 17.0) > EPS:
		errors.append("коллизия: врагу не нанесён урон (received=%s, ожидалось 17)" % enemy.received)
	var non_enemy := MockEnemy.new()  # НЕ в группе enemies
	p5.call("_on_body_entered", non_enemy)
	if non_enemy.received >= 0.0:
		errors.append("коллизия: урон нанесён не-врагу (received=%s)" % non_enemy.received)
	enemy.free()
	non_enemy.free()
	p5.free()

	# --- despawn по истечении lifetime (в дереве, queue_free) ---
	await process_frame
	var holder := Node2D.new()
	root.add_child(holder)
	await process_frame
	var p6: Area2D = Projectile.new()
	holder.add_child(p6)  # _ready: трейл/группа/сигнал
	await process_frame
	p6.setup(Vector2(1280, 720), Vector2(1380, 720), 5.0)
	p6.set("lifetime", 0.01)
	p6.call("_physics_process", 1.0)  # lifetime -> <0 -> queue_free
	await process_frame
	if is_instance_valid(p6):
		errors.append("despawn: снаряд не освобождён после истечения lifetime")

	# --- despawn по вылету за арену (в дереве): не-истёкший lifetime, но позиция
	#     за CLEANUP_MARGIN -> queue_free (защита от «залётных» снарядов-утечек). ---
	var p7: Area2D = Projectile.new()
	var holder2 := Node2D.new()
	root.add_child(holder2)
	await process_frame
	holder2.add_child(p7)
	await process_frame
	p7.setup(center, center + Vector2(100, 0), 5.0)
	p7.set("lifetime", 9.0)  # lifetime НЕ истёк — освобождение должно быть от вылета
	p7.global_position = Vector2(arena.x + margin + 400.0, center.y)
	p7.call("_physics_process", 0.016)
	await process_frame
	if is_instance_valid(p7):
		errors.append("despawn: снаряд не освобождён после вылета за арену (lifetime ещё жив)")

	holder.queue_free()
	holder2.queue_free()
	await process_frame

	if not errors.is_empty():
		for e in errors:
			push_error("Projectile smoke: %s" % e)
		push_error("Projectile smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Projectile smoke test passed (setup/движение/lifetime/arena XY±/коллизия/despawn lifetime+вылет).")
	quit(0)
