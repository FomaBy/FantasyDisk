extends SceneTree

# SCRUM-614: показ Level Up в бою длиннее и весомее. Лёгкий изолированный тест
# (без загрузки игровой сцены — full-scene smoke под параллельной Godot-нагрузкой
# флачит OOM/247). Инстанцирует LevelUpEffect и проверяет:
#   1) EFFECT_DURATION поднят до 1.35с (момент роста читается дольше);
#   2) бейдж всплывает выше (BADGE_FLOAT_DISTANCE=40);
#   3) на середине окна (~0.7с) эффект ещё ЖИВ и виден (не схлопнулся рано);
#   4) после EFFECT_DURATION + запас нода САМООСВОБОЖДАЕТСЯ (acceptance).
# Тайминги badge_tween (delay 1.05 + fade 0.30 = 1.35) укладываются ровно в окно.

const EffectScript := preload("res://scripts/level_up_effect.gd")
const EffectScene := preload("res://scenes/LevelUpEffect.tscn")


func _fail(msg: String) -> void:
	push_error("[level_up_effect_duration] FAIL: " + msg)
	quit(1)


func _initialize() -> void:
	# --- Контракт констант (статически, без рантайма) ---
	if absf(float(EffectScript.EFFECT_DURATION) - 1.35) > 0.001:
		_fail("EFFECT_DURATION ожидался 1.35, получено %s" % str(EffectScript.EFFECT_DURATION))
		return
	if absf(float(EffectScript.BADGE_FLOAT_DISTANCE) - 40.0) > 0.001:
		_fail("BADGE_FLOAT_DISTANCE ожидался 40.0, получено %s" % str(EffectScript.BADGE_FLOAT_DISTANCE))
		return

	# --- Рантайм: жизненный цикл ноды ---
	var effect: Node2D = EffectScene.instantiate()
	get_root().add_child(effect)
	await process_frame  # дать _ready/_build_visual отработать (собрать бейдж и твины)
	# badge должен существовать после _ready (визуал собран).
	var badge := effect.find_child("LevelUpPopupBadge", true, false) as Node2D
	if badge == null:
		_fail("LevelUpPopupBadge не создан в _ready")
		return
	var start_y := badge.position.y

	# Середина окна (~0.7с): эффект ещё жив, бейдж поднялся выше старта.
	await create_timer(0.7).timeout
	if not is_instance_valid(effect):
		_fail("эффект самоосвободился слишком рано (<0.7с) — момент роста не успеет прочитаться")
		return
	if not is_instance_valid(badge):
		_fail("badge исчез слишком рано")
		return
	# Бейдж всплывает вверх (y уменьшается). На 0.7с подъём уже заметен.
	if badge.position.y >= start_y - 1.0:
		_fail("badge не всплывает вверх к середине окна (y=%.2f, старт %.2f)" % [badge.position.y, start_y])
		return

	# После полного окна + запас: нода обязана самоосвободиться.
	await create_timer(1.1).timeout  # суммарно ~1.8с > EFFECT_DURATION=1.35
	if is_instance_valid(effect):
		_fail("эффект НЕ самоосвободился после EFFECT_DURATION (нода жива на ~1.8с)")
		return

	print("[level_up_effect_duration] PASSED — EFFECT_DURATION=1.35, float=40, alive@0.7s, freed<1.8s")
	quit(0)
