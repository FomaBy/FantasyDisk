extends SceneTree

# FAN-1031 S4 (random-floor, план §2.1-S4): КАЖДЫЙ level-up-показ обязан содержать ≥1 карту,
# релевантную УРОНУ текущего класса. Контекст: слабые/дно-классы в v8 имели random-билд-пол
# ниже коридора (worst 0.86), потому что часть оферов не давала ни одной damage-карты и билд
# вынужденно уходил в защиту/утилиту. LEVEL_UP_REWARDS уже вычищен FAN-1034 — здесь вводится
# только ОФЕР-ГАРАНТИЯ (ProgressionData.weighted_level_up_selection + reward_is_damage_relevant).
#
# Гейт — лёгкий, детерминированный (перебор seed'ов на чистой выборке, без боевого сима):
#   1. Satisfiability: у КАЖДОГО класса в regular-пуле есть ≥1 damage-релевантная карта
#      (иначе гарантия неисполнима — контракт матрицы сломан).
#   2. reward_is_damage_relevant — A/B по осям: физ-«damage» релевантен физ-классу и НЕ маг-классу;
#      «magic_focus» — наоборот; не-урон-ось (defense) не релевантна никому.
#   3. Гарантия показа: по всем 17 классам × N seed'ов КАЖДЫЙ офер (в т.ч. с prefill capstone)
#      несёт ≥1 damage-карту, и при этом старые инварианты (≤1 optional) не нарушены.
#
# Запуск: Godot --headless --path . --script res://tests/level_up_damage_floor_gate.gd

const ProgressionData := preload("res://scripts/progression_data.gd")

const OFFER_SIZE := 3
const SAMPLE_SEEDS := 200

var _failed := false


func _fail(message: String) -> void:
	push_error("[levelup-damage-floor] FAIL: %s" % message)
	_failed = true


func _initialize() -> void:
	var classes: Array = ProgressionData.character_ids()
	if classes.size() != 17:
		_fail("Ожидалось 17 классов, получено %d." % classes.size())

	_test_helper_ab()
	_test_satisfiability(classes)
	_test_offer_guarantee(classes)

	if _failed:
		push_error("Level-up damage floor gate FAILED.")
		quit(1)
		return
	print("Level-up damage floor gate passed (FAN-1031 S4: каждый показ ≥1 damage-карта класса; %d классов × %d seed'ов; helper A/B; satisfiability)." % [classes.size(), SAMPLE_SEEDS])
	quit(0)


# 2. reward_is_damage_relevant — A/B по урон-осям и классам.
func _test_helper_ab() -> void:
	var dmg := {"id": "damage_up", "attr": "damage"}
	var magic := {"id": "magic_focus_up", "attr": "magic_focus"}
	var defense := {"id": "defense_up", "attr": "defense"}
	# Физ-урон: релевантен физ-берсерку (primary), НЕ маг-жрецу (для него damage = optional).
	if not ProgressionData.reward_is_damage_relevant(dmg, "berserk"):
		_fail("damage должен быть damage-релевантен берсерку (primary).")
	if ProgressionData.reward_is_damage_relevant(dmg, "priest"):
		_fail("физ-damage НЕ должен считаться damage-релевантным жрецу (для мага ось optional).")
	# Маг-урон: наоборот.
	if not ProgressionData.reward_is_damage_relevant(magic, "priest"):
		_fail("magic_focus должен быть damage-релевантен жрецу (secondary).")
	if ProgressionData.reward_is_damage_relevant(magic, "berserk"):
		_fail("magic_focus НЕ должен считаться damage-релевантным берсерку (маг-ось у него мертва).")
	# Не-урон ось не релевантна никому.
	if ProgressionData.reward_is_damage_relevant(defense, "knight"):
		_fail("defense — не урон-ось, не должна считаться damage-релевантной.")


# 1. Satisfiability: у каждого класса в regular-пуле есть damage-карта (иначе форс неисполним).
func _test_satisfiability(classes: Array) -> void:
	for character_id in classes:
		var regular_pool: Array = ProgressionData.level_up_rewards(character_id)
		if not ProgressionData._reg_has_damage_relevant(regular_pool, character_id):
			_fail("%s: в regular-пуле НЕТ ни одной damage-релевантной карты — гарантия неисполнима." % character_id)


# 3. Гарантия показа по всем классам × seed'ам (в т.ч. с prefill capstone-стат-карты).
func _test_offer_guarantee(classes: Array) -> void:
	for character_id in classes:
		var regular_pool: Array = ProgressionData.level_up_rewards(character_id)
		var stat_pool: Array = ProgressionData.main_stat_level_up_rewards(character_id)
		for seed_index in range(SAMPLE_SEEDS):
			var rng := RandomNumberGenerator.new()
			rng.seed = 880000 + seed_index
			# Половина прогонов — с prefill (симулируем capstone «Озарение»: стат-карта в слоте).
			var prefill: Array = []
			if seed_index % 2 == 1 and not stat_pool.is_empty():
				prefill = [stat_pool[seed_index % stat_pool.size()]]
			var offer: Array = ProgressionData.weighted_level_up_selection(
				regular_pool, stat_pool, OFFER_SIZE, character_id, rng, 0.05, prefill)
			if offer.size() != OFFER_SIZE:
				_fail("%s seed %d: набор %d != %d." % [character_id, seed_index, offer.size(), OFFER_SIZE])
				break
			var damage_in_offer := 0
			var optional_in_offer := 0
			for reward in offer:
				if ProgressionData.reward_is_damage_relevant(reward, character_id):
					damage_in_offer += 1
				if ProgressionData.reward_is_optional(reward, character_id):
					optional_in_offer += 1
			if damage_in_offer < 1:
				_fail("%s seed %d (prefill=%d): показ БЕЗ damage-карты — random-floor гарантия нарушена." % [character_id, seed_index, prefill.size()])
				break
			# Регресс-страховка: новая гарантия не должна ломать старый инвариант «≤1 optional».
			if optional_in_offer > 1:
				_fail("%s seed %d: %d optional (>1) — форс damage сломал optional-инвариант." % [character_id, seed_index, optional_in_offer])
				break
