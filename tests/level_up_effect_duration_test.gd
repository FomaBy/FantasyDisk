extends SceneTree

# SCRUM-614/user bugfix: level-up burst in combat stays long enough to read while
# the textual plaque lives in LevelUpToast. Лёгкий изолированный тест
# (без загрузки игровой сцены — full-scene smoke под параллельной Godot-нагрузкой
# флачит OOM/247). Инстанцирует LevelUpEffect и проверяет:
#   1) EFFECT_DURATION поднят до 1.35с (момент роста читается дольше);
#   2) LevelUpEffect больше не создаёт отдельный бейдж/Label с текстом;
#   3) на середине окна (~0.7с) эффект ещё ЖИВ (не схлопнулся рано);
#   4) после EFFECT_DURATION + запас нода САМООСВОБОЖДАЕТСЯ (acceptance).

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

	# --- Рантайм: жизненный цикл ноды ---
	var effect: Node2D = EffectScene.instantiate()
	get_root().add_child(effect)
	await process_frame  # дать _ready/_build_visual отработать (собрать вспышку и твины)
	var badge := effect.find_child("LevelUpPopupBadge", true, false) as Node2D
	if badge != null:
		_fail("LevelUpEffect больше не должен создавать отдельный LevelUpPopupBadge")
		return
	if not effect.find_children("*", "Label", true, false).is_empty():
		_fail("LevelUpEffect must not create standalone Label text; LevelUpToast owns the only Level Up plaque")
		return

	# Середина окна (~0.7с): эффект ещё жив.
	await create_timer(0.7).timeout
	if not is_instance_valid(effect):
		_fail("эффект самоосвободился слишком рано (<0.7с) — момент роста не успеет прочитаться")
		return

	# После полного окна + запас: нода обязана самоосвободиться.
	await create_timer(1.1).timeout  # суммарно ~1.8с > EFFECT_DURATION=1.35
	if is_instance_valid(effect):
		_fail("эффект НЕ самоосвободился после EFFECT_DURATION (нода жива на ~1.8с)")
		return

	print("[level_up_effect_duration] PASSED — EFFECT_DURATION=1.35, no badge label, alive@0.7s, freed<1.8s")
	quit(0)
