extends SceneTree

# Логика-гейт секретного боя конца Акта 3 (SCRUM-619). Проверяет ТОЛЬКО логику в
# scripts/meta_progression.gd (без рендера/арта):
#   1. secret_encounter_unlocked = true СТРОГО при всех условиях:
#      возвышение >= MIN_ASCENSION  И  (low-damage-boss  ИЛИ  артефакт-ключ);
#      ложь при невыполнении любого из условий;
#   2. ключ-артефакт открывает бой даже при высоком полученном уроне;
#      порог damage_taken — граничный (<= порога открывает, > порога нет);
#   3. record_secret_boss_victory начисляет meta-награду РОВНО один раз
#      (повтор не начисляет дважды) и поднимает secret_boss_defeated;
#   4. флаг secret_boss_defeated переживает save/load (персистентность);
#   5. свежий state: бой заблокирован, флаг не взят, награда не выдана.
#
# Отдельный изолированный файл (читает meta_progression + временный user://-путь).
# Запуск: Godot --headless --path . --script res://tests/secret_encounter_test.gd

const Meta := preload("res://scripts/meta_progression.gd")
const ContentData := preload("res://scripts/progression_data_content.gd")
const TEST_PATH := "user://test_secret_encounter.cfg"


# Хелпер: state с заданным возвышением одного класса.
func _state_with_ascension(character_id: String, level: int) -> Dictionary:
	var state := Meta.default_state()
	for _i in range(level):
		# run_level=current → каждая победа на текущем максимуме открывает +1 возвышение.
		state = Meta.record_boss_victory(state, character_id, Meta.ascension_level(state, character_id))
	return state


func _initialize() -> void:
	var errors: Array = []
	_cleanup()

	var min_asc: int = Meta.SECRET_ENCOUNTER_MIN_ASCENSION
	var max_dmg: float = Meta.SECRET_ENCOUNTER_MAX_DAMAGE_TAKEN
	var key: String = Meta.SECRET_ENCOUNTER_ARTIFACT_KEY

	# --- 5. Свежий state: всё закрыто/не выдано ---
	var fresh := Meta.default_state()
	if Meta.secret_boss_defeated(fresh):
		errors.append("свежий state: secret_boss_defeated должен быть false")
	if Meta.secret_encounter_unlocked(fresh, {"damage_taken": 0.0}, "berserk"):
		errors.append("свежий state (возвышение 0): бой не должен быть разблокирован")

	# Подготовка: класс на нужном возвышении (граница min_asc) и НИЖЕ границы.
	var asc_ok := _state_with_ascension("berserk", min_asc)
	var asc_low := _state_with_ascension("berserk", min_asc - 1)
	if Meta.ascension_level(asc_ok, "berserk") != min_asc:
		errors.append("setup: ожидалось возвышение %d, получено %d" % [min_asc, Meta.ascension_level(asc_ok, "berserk")])

	# --- 1. Гейт: возвышение И (low-damage ИЛИ ключ) ---
	var low_dmg_metrics := {"damage_taken": max_dmg - 1.0, "artifacts": []}
	var high_dmg_metrics := {"damage_taken": max_dmg + 1.0, "artifacts": []}

	# Возвышение OK + малый урон → открыт.
	if not Meta.secret_encounter_unlocked(asc_ok, low_dmg_metrics, "berserk"):
		errors.append("возвышение>=%d + малый урон должны открывать бой" % min_asc)
	# Возвышение OK + большой урон, без ключа → закрыт.
	if Meta.secret_encounter_unlocked(asc_ok, high_dmg_metrics, "berserk"):
		errors.append("большой урон без ключа НЕ должен открывать бой")
	# Возвышение НИЖЕ границы + малый урон → закрыт (возвышение обязательно).
	if Meta.secret_encounter_unlocked(asc_low, low_dmg_metrics, "berserk"):
		errors.append("возвышение %d (<%d) не должно открывать бой даже при малом уроне" % [min_asc - 1, min_asc])

	# --- 2. Артефакт-ключ открывает даже при большом уроне; граница порога урона ---
	var key_metrics := {"damage_taken": max_dmg + 999.0, "artifacts": [key]}
	if not Meta.secret_encounter_unlocked(asc_ok, key_metrics, "berserk"):
		errors.append("артефакт-ключ (строка) должен открывать бой при любом уроне (возвышение OK)")
	# SCRUM-623: LIVE формат артефактов — словари {id,title} (player.gd/combat_director/main).
	# Гейт обязан матчить ключ по dict["id"], иначе ветка не работает в живой игре.
	var live_key_metrics := {"damage_taken": max_dmg + 999.0,
		"artifacts": [{"id": "warrior_charm", "title": "Warrior Charm"}, {"id": key, "title": "Rift Key"}]}
	if not Meta.secret_encounter_unlocked(asc_ok, live_key_metrics, "berserk"):
		errors.append("SCRUM-623: ключ-артефакт в live dict-формате [{id:rift_key}] должен открывать бой")
	# Контроль: словари без ключа — не открывают (при большом уроне).
	var no_key_dicts := {"damage_taken": max_dmg + 999.0,
		"artifacts": [{"id": "warrior_charm", "title": "Warrior Charm"}]}
	if Meta.secret_encounter_unlocked(asc_ok, no_key_dicts, "berserk"):
		errors.append("SCRUM-623: словари без ключа не должны открывать бой при большом уроне")
	# SCRUM-623: ключ-артефакт должен СУЩЕСТВОВАТЬ в реальном контенте (иначе ветку не активировать).
	var key_in_content := false
	for artifact in ContentData.ARTIFACTS:
		if str((artifact as Dictionary).get("id", "")) == key:
			key_in_content = true
			break
	if not key_in_content:
		errors.append("SCRUM-623: артефакт '%s' отсутствует в ContentData.ARTIFACTS — ветка недостижима в игре" % key)
	# Граница: ровно порог открывает (<=), порог+эпсилон — нет.
	if not Meta.secret_encounter_unlocked(asc_ok, {"damage_taken": max_dmg}, "berserk"):
		errors.append("damage_taken == порог должен открывать (<=)")
	if Meta.secret_encounter_unlocked(asc_ok, {"damage_taken": max_dmg + 0.01}, "berserk"):
		errors.append("damage_taken > порога без ключа не должен открывать")
	# Ключ без возвышения → всё равно закрыт.
	if Meta.secret_encounter_unlocked(asc_low, key_metrics, "berserk"):
		errors.append("ключ без нужного возвышения не должен открывать бой")

	# character_id="" → берётся максимум возвышения по всем классам.
	if not Meta.secret_encounter_unlocked(asc_ok, low_dmg_metrics, ""):
		errors.append("без character_id должен учитываться максимум возвышения (открыт)")
	if Meta.secret_encounter_unlocked(fresh, low_dmg_metrics, ""):
		errors.append("без character_id на свежем state (возвышение 0) — закрыт")

	# --- 3. Разовая награда: повтор не начисляет дважды ---
	var reward: int = Meta.SECRET_ENCOUNTER_REWARD_META_POINTS
	var state := asc_ok.duplicate(true)
	var points_before := int(state.get("meta_points", 0))
	state = Meta.record_secret_boss_victory(state)
	if not Meta.secret_boss_defeated(state):
		errors.append("после победы secret_boss_defeated должен быть true")
	if int(state.get("meta_points", 0)) != points_before + reward:
		errors.append("награда meta_points ожид. +%d, получено +%d" % [reward, int(state.get("meta_points", 0)) - points_before])
	# Повтор — без второго начисления.
	var points_after_first := int(state.get("meta_points", 0))
	state = Meta.record_secret_boss_victory(state)
	if int(state.get("meta_points", 0)) != points_after_first:
		errors.append("повторная победа НЕ должна начислять очки второй раз (было %d, стало %d)" % [points_after_first, int(state.get("meta_points", 0))])

	# --- 4. Персистентность флага через save/load ---
	Meta.save_state(state, TEST_PATH)
	var loaded := Meta.load_state(TEST_PATH)
	if not Meta.secret_boss_defeated(loaded):
		errors.append("secret_boss_defeated не пережил save/load")
	# После загрузки повтор тоже не начисляет (флаг уже взят).
	var loaded_points := int(loaded.get("meta_points", 0))
	loaded = Meta.record_secret_boss_victory(loaded)
	if int(loaded.get("meta_points", 0)) != loaded_points:
		errors.append("после save/load повтор победы начислил очки (флаг не учтён)")

	# Анти-вакуум: награда положительна, порог возвышения в [1..MAX].
	if reward <= 0:
		errors.append("SECRET_ENCOUNTER_REWARD_META_POINTS должен быть > 0")
	if min_asc < 1 or min_asc > Meta.MAX_ASCENSION_LEVEL:
		errors.append("MIN_ASCENSION вне диапазона [1..%d]" % Meta.MAX_ASCENSION_LEVEL)

	_cleanup()

	if not errors.is_empty():
		for e in errors:
			push_error("Secret encounter: %s" % e)
		push_error("Secret encounter test: %d нарушений." % errors.size())
		quit(1)
		return
	print("Secret encounter test passed (гейт возвышение+урон/ключ, разовая награда, save/load).")
	quit(0)


func _cleanup() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(TEST_PATH):
		dir.remove(TEST_PATH)
