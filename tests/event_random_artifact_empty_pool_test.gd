extends SceneTree

# SCRUM-634: random_artifact при ПУСТОМ пуле артефактов не должен молча терять
# награду. Раньше _apply_event_outcome_to_player при random_artifact=true и пустом
# артефакт-пуле списывал цену события (HP/золото), помечал success и НЕ выдавал
# ничего (молчаливая деградация). Теперь — золотая компенсация + push_warning.
#
# Гейт гонит РЕАЛЬНЫЙ ui_screens._apply_event_outcome_to_player с подставным game,
# у которого reward_pool отдаёт 0 или N артефактов.
# Ассерты:
#   - пустой пул: функция резолвит (true), цена HP списана, но выдана золотая
#     компенсация (gain_money > 0) и НИ одного артефакта не применено;
#   - непустой пул: ровно один артефакт применён, компенсации золотом нет.
#
# Запуск: Godot --headless --path . --script res://tests/event_random_artifact_empty_pool_test.gd

const UIScreens := preload("res://scripts/ui_screens.gd")


class StubPlayer extends Node:
	var max_health: float = 100.0
	var health: float = 100.0
	var money_gained: int = 0
	var rewards: Array = []
	func gain_money(amount: int) -> void:
		money_gained += amount
	func spend_money(_amount: int) -> bool:
		return true
	func apply_reward(reward: Dictionary) -> void:
		rewards.append(reward)
	func artifact_rewards() -> Array:
		return rewards.filter(func(r: Dictionary) -> bool:
			return str(r.get("kind", "")) == "artifact"
		)


class StubProgression extends RefCounted:
	var artifact_count: int = 0
	# SCRUM-961: сигнатура зеркалит боевую — опциональные хвосты гейта возвышения.
	func reward_pool(_character_id := "", _ascension_level := 0, _cross_class_ids: Array = []) -> Array:
		var pool: Array = []
		for i in range(artifact_count):
			pool.append({"kind": "artifact", "id": "stub_art_%d" % i, "title": "Stub Artifact %d" % i, "weight": 1.0})
		return pool
	func stage_scaled_cost(base_cost: int, _route_stage: int) -> int:
		return base_cost


class StubGame extends RefCounted:
	var selected_character_id: String = "berserk"
	var rng := RandomNumberGenerator.new()
	var PROGRESSION_DATA := StubProgression.new()
	# Кодекс-открытия: ui_screens.gd:8964 зовёт record_codex_artifact_discovery
	# при выдаче артефакта события (добавлено 2026-06-28, ПОСЛЕ написания гейта) —
	# стаб обязан нести этот контракт game, иначе непустой пул падает.
	var codex_discoveries: Array = []
	# SCRUM-961: ui_screens._run_ascension_level/_run_cross_class_artifact_ids
	# читают мета-возвышение и снапшот забега — стаб несёт этот контракт game.
	var current_player: Node = null
	var run_player_snapshot: Dictionary = {}
	func route_scaling_stage() -> int:
		return 0
	func ascension_level_for(_character_id: String) -> int:
		return 0
	func record_codex_artifact_discovery(reward: Dictionary) -> void:
		codex_discoveries.append(reward)


func _initialize() -> void:
	var errors: Array = []
	var stub := StubGame.new()
	stub.rng.seed = 1234
	var ui = UIScreens.new(stub)

	# Эталон blood_price: цена 30% HP + random_artifact.
	var make_outcome := func() -> Dictionary:
		return {"health_percent_cost": 0.30, "random_artifact": true}

	# 1) ПУСТОЙ пул артефактов.
	stub.PROGRESSION_DATA.artifact_count = 0
	var p_empty := StubPlayer.new()
	var ok_empty: bool = ui._apply_event_outcome_to_player(make_outcome.call(), p_empty)
	if not ok_empty:
		errors.append("пустой пул: _apply_event_outcome_to_player вернул false (событие должно резолвиться)")
	if not p_empty.artifact_rewards().is_empty():
		errors.append("пустой пул: применён артефакт, хотя пул пуст (%d)" % p_empty.artifact_rewards().size())
	if p_empty.money_gained <= 0:
		errors.append("пустой пул: молчаливая потеря награды — компенсация золотом не выдана (gain_money=%d)" % p_empty.money_gained)
	if p_empty.health >= 100.0:
		errors.append("пустой пул: цена HP не списана (health=%.1f), тест-эталон некорректен" % p_empty.health)
	print("пустой пул → resolved=%s, артефактов=%d, золото-компенсация=%d, HP=%.1f" % [str(ok_empty), p_empty.artifact_rewards().size(), p_empty.money_gained, p_empty.health])

	# 2) НЕПУСТОЙ пул артефактов.
	stub.PROGRESSION_DATA.artifact_count = 3
	var p_full := StubPlayer.new()
	var ok_full: bool = ui._apply_event_outcome_to_player(make_outcome.call(), p_full)
	if not ok_full:
		errors.append("непустой пул: _apply_event_outcome_to_player вернул false")
	if p_full.artifact_rewards().size() != 1:
		errors.append("непустой пул: ожидался ровно 1 артефакт, выдано %d" % p_full.artifact_rewards().size())
	if p_full.money_gained != 0:
		errors.append("непустой пул: лишняя золотая компенсация при доступном артефакте (gain_money=%d)" % p_full.money_gained)
	print("непустой пул → resolved=%s, артефактов=%d, золото-компенсация=%d" % [str(ok_full), p_full.artifact_rewards().size(), p_full.money_gained])

	p_empty.free()
	p_full.free()

	if not errors.is_empty():
		for e in errors:
			push_error("Event random_artifact empty-pool gate: %s" % e)
		push_error("Event random_artifact empty-pool gate: %d ошибок." % errors.size())
		quit(1)
		return
	print("Event random_artifact empty-pool gate passed (пустой пул → золотая компенсация без тихой потери; непустой пул → ровно 1 артефакт).")
	quit(0)
