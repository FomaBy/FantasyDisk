extends SceneTree
## FAN-1447 — детерминизм и sorted discovery Encounter Beat Director.
##
## Прогон:
##   python3 tools/godot_gate.py --headless --path . \
##     --script res://tests/encounters/beat_director_determinism_test.gd
##
## Проверяет: тот же node seed → тот же бит и момент; другой seed → свой момент;
## планирование НЕ трогает глобальный game.rng (fake game его вовсе не имеет);
## каталог отдаёт биты, детерминированно отсортированные по id; default-off.

const CONFIG := preload("res://scripts/encounters/encounter_config.gd")
const CONTEXT := preload("res://scripts/encounters/encounter_context.gd")
const FEATURE := preload("res://scripts/encounters/features/marked_target_feature.gd")

var errors: Array = []


# Мини-двойник Main: только node_aspect_rng (та же формула, что в scripts/main.gd)
# и ARENA_CENTER. Намеренно БЕЗ поля `rng` — если планирование его коснётся,
# тест упадёт с ошибкой обращения к несуществующему свойству.
class FakeGame:
	var current_player = null
	var ARENA_CENTER := Vector2(960, 540)

	func node_aspect_rng(node_seed: int, salt: int) -> RandomNumberGenerator:
		var generator := RandomNumberGenerator.new()
		generator.seed = (int(node_seed) ^ int(salt)) & 0x7FFFFFFFFFFFFFFF
		return generator


func _initialize() -> void:
	_check_config_contract()
	_check_sorted_discovery()
	_check_sorted_discovery_is_discriminating()
	_check_plan_determinism()
	_check_eligibility()

	if not errors.is_empty():
		for e in errors:
			push_error("beat-determinism: %s" % str(e))
		quit(1)
		return
	print("FAN-1447 beat determinism/discovery test passed.")
	quit(0)


func _make_context(seed_value: int, combat_type := "battle", round_duration := 60.0) -> RefCounted:
	var context = CONTEXT.new()
	context.game = FakeGame.new()
	context.node_seed = seed_value
	context.combat_type = combat_type
	context.event_active = false
	context.boss_active = false
	context.round_duration = round_duration
	return context


func _check_config_contract() -> void:
	CONFIG.clear_enabled_override()
	CONFIG._reset_cache_for_tests()
	_expect(CONFIG.CONTRACT_VERSION == 1, "contract version must be 1")
	_expect(not CONFIG.is_enabled(), "beats must be default-off (enabled=false)")
	CONFIG.set_enabled_override(true)
	_expect(CONFIG.is_enabled(), "enabled override(true) must take effect")
	CONFIG.set_enabled_override(false)
	_expect(not CONFIG.is_enabled(), "enabled override(false) must take effect")
	CONFIG.clear_enabled_override()
	_expect(not CONFIG.is_enabled(), "clearing override returns to catalog default (false)")


func _check_sorted_discovery() -> void:
	var beats := CONFIG.all_beats()
	_expect(not beats.is_empty(), "catalog must expose at least one beat")
	var ids: Array = []
	for beat in beats:
		ids.append(str(beat.get("id", "")))
	var sorted_ids: Array = ids.duplicate()
	sorted_ids.sort()
	_expect(ids == sorted_ids, "all_beats() must be sorted by id (deterministic discovery)")

	var primaries := CONFIG.primary_beats()
	var primary_ids: Array = []
	for beat in primaries:
		primary_ids.append(str(beat.get("id", "")))
	_expect(primary_ids.has("marked_target"), "marked_target must be a primary beat")
	var sorted_primary := primary_ids.duplicate()
	sorted_primary.sort()
	_expect(primary_ids == sorted_primary, "primary_beats() must be sorted by id")


# Проверки выше сравнивают порядок каталога с его же сортировкой, а в прод-каталоге
# ровно один бит — массив из одного элемента всегда равен своей сортировке, поэтому
# такой assert не может провалиться. Здесь discovery гоняется на фикстуре каталога,
# где порядок «в файле» заведомо отличается от отсортированного: удаление
# sort_custom обязано покрасить тест. Прод-данные и правило «ровно один primary-бит»
# при этом не трогаются — фикстура живёт только в памяти процесса.
func _check_sorted_discovery_is_discriminating() -> void:
	CONFIG._set_catalog_for_tests({
		"schema_version": CONFIG.CONTRACT_VERSION,
		"contract": CONFIG.CONTRACT,
		"enabled": false,
		"beats": [
			_fixture_definition("zulu_probe", true),
			_fixture_definition("alpha_probe", false),
			_fixture_definition("mike_probe", true),
		],
	})

	var ids: Array = []
	for beat in CONFIG.all_beats():
		ids.append(str(beat.get("id", "")))
	_expect(ids == ["alpha_probe", "mike_probe", "zulu_probe"],
		"all_beats() must sort a deliberately unsorted catalog by id (got %s)" % str(ids))

	var primary_ids: Array = []
	for beat in CONFIG.primary_beats():
		primary_ids.append(str(beat.get("id", "")))
	_expect(primary_ids == ["mike_probe", "zulu_probe"],
		"primary_beats() must inherit the sorted order of all_beats() (got %s)" % str(primary_ids))

	CONFIG._reset_cache_for_tests()
	_expect(CONFIG.all_beats().size() >= 1, "real catalog must be restored after the fixture check")


func _fixture_definition(feature_id: String, primary: bool) -> Dictionary:
	return {
		"schema_version": CONFIG.CONTRACT_VERSION,
		"id": feature_id,
		"type": CONFIG.FEATURE_TYPE,
		"enabled": true,
		"primary": primary,
		"capabilities": ["primary_beat"] if primary else [],
		"script": "res://scripts/encounters/features/marked_target_feature.gd",
	}


func _marked_target_def() -> Dictionary:
	for beat in CONFIG.primary_beats():
		if str(beat.get("id", "")) == "marked_target":
			return beat
	return {}


func _check_plan_determinism() -> void:
	var beat_def := _marked_target_def()
	_expect(not beat_def.is_empty(), "marked_target beat_def must exist")
	if beat_def.is_empty():
		return
	var feature = FEATURE.new()

	# Один seed → один и тот же момент (bit-identical) при повторном планировании.
	var plan_a: Dictionary = feature.plan(_make_context(4242), beat_def)
	var plan_b: Dictionary = feature.plan(_make_context(4242), beat_def)
	_expect(not plan_a.is_empty(), "plan for a normal 60s battle must be produced")
	_expect(is_equal_approx(float(plan_a.get("trigger_at", -1.0)), float(plan_b.get("trigger_at", -2.0))),
		"same node seed must yield the same trigger moment")
	var trig := float(plan_a.get("trigger_at", -1.0))
	_expect(trig >= 20.0 and trig <= 40.0, "trigger must land inside the 20-40s window (got %f)" % trig)
	_expect(is_equal_approx(float(plan_a.get("window", -1.0)), 10.0), "window must equal duration_seconds (10)")

	# Другой seed → детерминированный и ИНОЙ момент; в любом случае в окне.
	var plan_c: Dictionary = feature.plan(_make_context(999983), beat_def)
	var plan_c2: Dictionary = feature.plan(_make_context(999983), beat_def)
	_expect(is_equal_approx(float(plan_c.get("trigger_at", -1.0)), float(plan_c2.get("trigger_at", -2.0))),
		"different seed must still be internally deterministic")
	var trig_c := float(plan_c.get("trigger_at", -1.0))
	_expect(trig_c >= 20.0 and trig_c <= 40.0, "second-seed trigger must land inside window")

	# Без этого момент, не зависящий от seed вовсе (константа), проходил бы весь
	# файл: повторяемость и попадание в окно у константы идеальные.
	_expect(not is_equal_approx(trig_c, trig),
		"a different node seed must yield a different trigger moment (both gave %f)" % trig)

	# И момент обязан меняться вместе с seed на всей выборке, а не только в одной паре.
	var distinct := {}
	for seed_value in [4242, 999983, 777, 5150, 31337]:
		var plan_n: Dictionary = feature.plan(_make_context(seed_value), beat_def)
		distinct[float(plan_n.get("trigger_at", -1.0))] = true
	_expect(distinct.size() >= 4,
		"trigger moment must vary with node seed (only %d distinct values for 5 seeds)" % distinct.size())

	# Слишком короткий раунд — план отклоняется (окно не влезает).
	var plan_short: Dictionary = feature.plan(_make_context(4242, "battle", 25.0), beat_def)
	_expect(plan_short.is_empty(), "plan must decline when the round is too short for the window")


func _check_eligibility() -> void:
	var feature = FEATURE.new()
	_expect(feature.id() == "marked_target", "feature id must be marked_target")
	_expect(feature.api_version() == 1, "feature API version must be 1")
	_expect(feature.is_eligible(_make_context(1, "battle")), "eligible in normal battle")
	_expect(not feature.is_eligible(_make_context(1, "elite")), "not eligible in elite battle")
	var boss_ctx := _make_context(1, "battle")
	boss_ctx.boss_active = true
	_expect(not feature.is_eligible(boss_ctx), "not eligible when boss_active")
	var event_ctx := _make_context(1, "battle")
	event_ctx.event_active = true
	_expect(not feature.is_eligible(event_ctx), "not eligible in event combat")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
