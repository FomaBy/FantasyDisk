extends SceneTree

# SCRUM-597: фолбэк-выбор события при исчерпанном reward-пуле не должен падать.
# _random_event_choices индексировал rewards[0]/rewards[1] вслепую, но
# _weighted_sample отдаёт МЕНЬШЕ count при пустом/коротком пуле → 'Index out of
# bounds' (фолбэк зовётся из ui_screens при пустом event_definition.choices).
#
# Гейт гонит РЕАЛЬНЫЙ ui_screens._random_event_choices (UIScreens extends
# RefCounted, _init только хранит game) c подставным game, у которого reward_pool
# отдаёт ровно 0/1/2/5 наград. Ассерт: не падает, всегда 3 валидных выбора,
# у каждого есть title и хотя бы один применимый эффект (reward/mods/heal_percent),
# каждый reward (если есть) — из пула (в границах), индекса за границу нет.
#
# Запуск: Godot --headless --path . --script res://tests/event_choices_empty_pool_test.gd

const UIScreens := preload("res://scripts/ui_screens.gd")


# Подставной PROGRESSION_DATA: reward_pool отдаёт массив фиксированного размера.
class StubProgression extends RefCounted:
	var pool_size: int = 0
	func reward_pool(_character_id := "", _ascension_level := 0, _cross_class_ids: Array = []) -> Array:
		var pool: Array = []
		for i in range(pool_size):
			pool.append({"kind": "stat", "title": "Stub %d" % i, "weight": 1.0, "stats": {"strength": 1.0}})
		return pool


# Подставной game с минимумом, который трогает _random_event_choices →
# _random_rewards → _weighted_sample.
class StubGame extends RefCounted:
	var selected_character_id: String = "berserk"
	var rng := RandomNumberGenerator.new()
	var PROGRESSION_DATA := StubProgression.new()
	var current_player = null
	var run_player_snapshot := {"run_modifiers": {}}
	func ascension_level_for(_character_id: String) -> int:
		return 0


func _initialize() -> void:
	var errors: Array = []
	var stub := StubGame.new()
	stub.rng.seed = 777
	var ui = UIScreens.new(stub)

	# Применимый эффект выбора (как трактует _apply_event_outcome_to_player).
	var applicable := func(choice: Dictionary) -> bool:
		return choice.has("reward") or choice.has("mods") or choice.has("stats") or choice.has("heal_percent")

	for pool_size in [0, 1, 2, 3, 5]:
		stub.PROGRESSION_DATA.pool_size = pool_size
		# Вызов реального метода — раньше тут был Index out of bounds при pool<2.
		var choices = ui._random_event_choices()
		if not (choices is Array):
			errors.append("pool=%d: _random_event_choices вернул не Array" % pool_size)
			continue
		if choices.size() != 3:
			errors.append("pool=%d: ожидалось 3 выбора, есть %d" % [pool_size, choices.size()])
		for idx in range(choices.size()):
			var c: Dictionary = choices[idx]
			if str(c.get("title", "")).strip_edges() == "":
				errors.append("pool=%d: выбор %d без title" % [pool_size, idx])
			if not applicable.call(c):
				errors.append("pool=%d: выбор %d ('%s') без применимого эффекта (reward/mods/stats/heal)" % [pool_size, idx, c.get("title", "")])
			# reward, если присутствует, должен быть валидным словарём (взят из пула, не за границей).
			if c.has("reward") and not (c["reward"] is Dictionary):
				errors.append("pool=%d: выбор %d reward не Dictionary (индекс за границей?)" % [pool_size, idx])
		print("pool=%d → %d выборов: %s" % [pool_size, choices.size(), str(choices.map(func(c): return c.get("title", "?")))])

	if not errors.is_empty():
		for e in errors:
			push_error("Event choices empty-pool gate: %s" % e)
		push_error("Event choices empty-pool gate: %d ошибок." % errors.size())
		quit(1)
		return
	print("Event choices empty-pool gate passed (pool 0/1/2/3/5 → всегда 3 валидных выбора, без Index out of bounds).")
	quit(0)
