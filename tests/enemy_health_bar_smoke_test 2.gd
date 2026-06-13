extends SceneTree

# Smoke-тест enemy_health_bar.gd (был непокрыт). Полоса HP над врагом — базовый
# боевой фидбэк; ошибка в клэмпах value/width = вводящие в заблуждение полоски
# (длиннее бара / value вне [0,max] / нулевой max → деление). Тестируем чистую
# логику configure/setup/set_value прямыми вызовами (без _draw, без дерева,
# без progression_data). Отдельный изолированный файл.
#
# Запуск: Godot --headless --path . --script res://tests/enemy_health_bar_smoke_test.gd

const HealthBar := preload("res://scripts/enemy_health_bar.gd")

const EPS := 0.0001


func _initialize() -> void:
	var errors: Array = []

	# --- setup(): max=value=max, заданная ширина ---
	var b: Node2D = HealthBar.new()
	b.setup(100.0, 60.0)
	_eq(errors, "setup max", b.get("max_value"), 100.0)
	_eq(errors, "setup value", b.get("value"), 100.0)
	_eq(errors, "setup width", b.get("bar_width"), 60.0)

	# --- configure: value > max клэмпится к max; width<0 сохраняет текущую ---
	b.configure(80.0, 200.0, -1.0)
	_eq(errors, "value clamp high", b.get("value"), 80.0)
	_eq(errors, "max set", b.get("max_value"), 80.0)
	_eq(errors, "width keep (<0)", b.get("bar_width"), 60.0)

	# --- value < 0 клэмпится к 0; width клэмпится снизу к 30 ---
	b.configure(80.0, -5.0, 10.0)
	_eq(errors, "value clamp low", b.get("value"), 0.0)
	_eq(errors, "width clamp min", b.get("bar_width"), 30.0)

	# --- width клэмпится сверху к 150 ---
	b.configure(200.0, 100.0, 999.0)
	_eq(errors, "width clamp max", b.get("bar_width"), 150.0)

	# --- max <= 0 → пол 0.001 (защита от деления в ratio) ---
	b.configure(0.0, 50.0, 60.0)
	if float(b.get("max_value")) <= 0.0:
		errors.append("max не защищён от <=0 (%s) — ratio делил бы на 0" % b.get("max_value"))
	if float(b.get("value")) > float(b.get("max_value")) + EPS:
		errors.append("value > max после клэмпа (%s > %s)" % [b.get("value"), b.get("max_value")])

	# --- set_value меняет value, сохраняет max/width ---
	b.configure(100.0, 100.0, 44.0)
	b.set_value(25.0)
	_eq(errors, "set_value value", b.get("value"), 25.0)
	_eq(errors, "set_value keeps max", b.get("max_value"), 100.0)
	_eq(errors, "set_value keeps width", b.get("bar_width"), 44.0)
	# ratio корректен.
	var ratio := float(b.get("value")) / float(b.get("max_value"))
	if absf(ratio - 0.25) > EPS:
		errors.append("ratio неверен (%.4f != 0.25)" % ratio)
	b.free()

	if not errors.is_empty():
		for e in errors:
			push_error("Enemy health bar smoke: %s" % e)
		push_error("Enemy health bar smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Enemy health bar smoke test passed (setup/configure-клэмпы/set_value/ratio).")
	quit(0)


func _eq(errors: Array, name: String, got, want: float) -> void:
	if absf(float(got) - want) > EPS:
		errors.append("%s = %s, ожидалось %.4f" % [name, got, want])
