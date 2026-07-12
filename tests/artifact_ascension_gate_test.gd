extends SceneTree

# SCRUM-961: гейт классовых артефактов (artifact_system_matrix §1.4-1.5, §5).
# Контракт is_reward_relevant(reward, character_id, ascension_level, cross_class_ids):
#   1) пустой class_affinity → true (универсал, гейта нет);
#   2) id в cross_class_ids → true (исключение «Украденного герба», §5);
#   3) иначе class∈affinity И ascension >= requires_ascension.
# Гейтит:
#   а) синтетика: все ветви правила, включая приоритет doctor-фильтра;
#   б) реальные 4 сэмплера (reward_pool/shop_items/elite_artifact_choices/
#      boss_completion_artifact_rewards) для всех 17 классов:
#      asc 0 → ни одного запертого (requires_ascension>0) и ни одного чужого;
#      asc 5 → ВСЕ свои классовые в пуле (boss — свои tier 3);
#   в) cross_class_ids пропускает РОВНО перечисленные чужие id и ничего сверх.
#
# Запуск: Godot --headless --path . --script res://tests/artifact_ascension_gate_test.gd

const PD := preload("res://scripts/progression_data.gd")

var _errors: Array = []


func _initialize() -> void:
	seed(961961)

	_check_synthetic_rule()
	_check_samplers_all_classes()
	_check_cross_class_exception()
	_check_stolen_crest_roll()

	if not _errors.is_empty():
		for e in _errors:
			push_error("Artifact ascension gate: %s" % str(e))
		push_error("Artifact ascension gate test: %d ошибок." % _errors.size())
		quit(1)
		return
	print("Artifact ascension gate test passed (%d классов, %d артефактов)." % [PD.character_ids().size(), PD.ARTIFACTS.size()])
	quit(0)


# (а) Синтетические записи: все ветви §1.4.
func _check_synthetic_rule() -> void:
	var gated := {"id": "synth_gated", "class_affinity": ["berserk"], "requires_ascension": 5}
	var legacy := {"id": "synth_legacy", "class_affinity": ["berserk"]}
	var universal := {"id": "synth_universal", "class_affinity": []}
	var cases := [
		# [reward, class, asc, cross_ids, expected, label]
		[gated, "berserk", 0, [], false, "свой класс asc0 заперт"],
		[gated, "berserk", 4, [], false, "свой класс asc4 заперт"],
		[gated, "berserk", 5, [], true, "свой класс asc5 открыт"],
		[gated, "berserk", 6, [], true, "свой класс asc6 открыт"],
		[gated, "thief", 5, [], false, "чужой класс asc5 заперт"],
		[gated, "thief", 0, ["synth_gated"], true, "cross_class_ids пробивает класс и возвышение"],
		[gated, "thief", 0, ["other_id"], false, "чужой id в cross_class_ids не открывает"],
		[legacy, "berserk", 0, [], true, "affinity без requires_ascension = только классовый гейт"],
		[legacy, "thief", 9, [], false, "affinity без requires_ascension чужому заперт"],
		[universal, "druid", 0, [], true, "пустой affinity всегда открыт"],
	]
	for case in cases:
		var got: bool = PD.is_reward_relevant(case[0], str(case[1]), int(case[2]), case[3] as Array)
		if got != bool(case[4]):
			_errors.append("синтетика: %s (ожидалось %s, получено %s)" % [case[5], case[4], got])
	# Doctor-sustain фильтр идёт ПЕРВЫМ и не отменяется cross_class_ids.
	var doctor_forbidden := {"id": "leech_heart", "class_affinity": [], "mods": {"kill_heal_percent": 0.02}}
	if PD.is_reward_relevant(doctor_forbidden, "doctor", 5, ["leech_heart"]):
		_errors.append("doctor-sustain фильтр должен резать до affinity/cross-веток")
	# Обратная совместимость: старый 2-аргументный вызов = asc 0 (заперто).
	if PD.is_reward_relevant(gated, "berserk"):
		_errors.append("2-аргументный вызов должен дефолтить ascension 0 (заперто)")


func _class_only_ids(character_id: String, min_tier := 0) -> Array:
	var ids := []
	for entry in PD.ARTIFACTS:
		var art: Dictionary = entry
		var affinity: Array = art.get("class_affinity", []) as Array
		if affinity.is_empty() or not affinity.has(character_id):
			continue
		if int(art.get("tier", 1)) < min_tier:
			continue
		ids.append(str(art.get("id", "")))
	return ids


# Пул одного сэмплера → множество id.
func _pool_ids(pool: Array) -> Dictionary:
	var ids := {}
	for entry in pool:
		ids[str((entry as Dictionary).get("id", ""))] = entry
	return ids


# Нарушения гейта в пуле: запертые (requires_ascension > asc) и чужие классовые.
func _gate_violations(pool: Array, character_id: String, ascension_level: int, label: String) -> void:
	for entry in pool:
		var art: Dictionary = entry
		var affinity: Array = art.get("class_affinity", []) as Array
		if affinity.is_empty():
			continue
		var aid := str(art.get("id", ""))
		if not affinity.has(character_id):
			_errors.append("%s: чужой классовый '%s' протёк в пул %s" % [label, aid, character_id])
		elif ascension_level < int(art.get("requires_ascension", 0)):
			_errors.append("%s: запертый '%s' (requires %d) протёк при asc %d" % [label, aid, int(art.get("requires_ascension", 0)), ascension_level])


# (б) Реальные сэмплеры для всех 17 классов.
func _check_samplers_all_classes() -> void:
	for character_id in PD.character_ids():
		var cid := str(character_id)
		# asc 0: ни запертых, ни чужих ни в одном сэмплере.
		_gate_violations(PD.reward_pool(cid, 0), cid, 0, "reward_pool")
		_gate_violations(PD.shop_items(0, cid, 0), cid, 0, "shop_items")
		_gate_violations(PD.elite_artifact_choices(2, 999, cid, 0), cid, 0, "elite_artifact_choices")
		_gate_violations(PD.boss_completion_artifact_rewards(cid, 0), cid, 0, "boss_completion")
		# asc 5: все свои классовые доступны (boss — свои tier 3).
		var own_ids := _class_only_ids(cid)
		var own_t3 := _class_only_ids(cid, 3)
		var reward_ids := _pool_ids(PD.reward_pool(cid, 5))
		var shop_ids := _pool_ids(PD.shop_items(0, cid, 5))
		var elite_ids := _pool_ids(PD.elite_artifact_choices(2, 999, cid, 5))
		var boss_ids := _pool_ids(PD.boss_completion_artifact_rewards(cid, 5))
		for own_id in own_ids:
			if not reward_ids.has(own_id):
				_errors.append("reward_pool(%s, asc5): нет своего классового '%s'" % [cid, own_id])
			if not shop_ids.has(own_id):
				_errors.append("shop_items(%s, asc5): нет своего классового '%s'" % [cid, own_id])
			if not elite_ids.has(own_id):
				_errors.append("elite_artifact_choices(%s, asc5): нет своего классового '%s'" % [cid, own_id])
		for own_id in own_t3:
			if not boss_ids.has(own_id):
				_errors.append("boss_completion(%s, asc5): нет своего классового t3 '%s'" % [cid, own_id])
		# Чужие не появляются и на asc 5.
		_gate_violations(PD.reward_pool(cid, 5), cid, 5, "reward_pool asc5")
		_gate_violations(PD.boss_completion_artifact_rewards(cid, 5), cid, 5, "boss asc5")


# (в) cross_class_ids пропускает ровно перечисленные чужие id.
func _check_cross_class_exception() -> void:
	# Берём два чужих для berserk классовых id из реальных данных (любой класс != berserk).
	var foreign_ids := []
	for entry in PD.ARTIFACTS:
		var art: Dictionary = entry
		var affinity: Array = art.get("class_affinity", []) as Array
		if affinity.is_empty() or affinity.has("berserk"):
			continue
		foreign_ids.append(str(art.get("id", "")))
		if foreign_ids.size() >= 2:
			break
	if foreign_ids.size() < 2:
		_errors.append("в ARTIFACTS нет двух чужих классовых id для cross-class проверки")
		return
	var pool_ids := _pool_ids(PD.reward_pool("berserk", 0, foreign_ids))
	for foreign_id in foreign_ids:
		if not pool_ids.has(foreign_id):
			_errors.append("cross_class_ids: '%s' не пропущен в reward_pool" % foreign_id)
	# Ничего сверх перечисленного: другие чужие классовые по-прежнему заперты.
	for entry in PD.reward_pool("berserk", 0, foreign_ids):
		var art: Dictionary = entry
		var affinity: Array = art.get("class_affinity", []) as Array
		if affinity.is_empty() or affinity.has("berserk"):
			continue
		if not foreign_ids.has(str(art.get("id", ""))):
			_errors.append("cross_class_ids: лишний чужой '%s' протёк в пул" % str(art.get("id", "")))
	# Магазин/элитка/босс тоже уважают исключение.
	var shop_ids := _pool_ids(PD.shop_items(0, "berserk", 0, foreign_ids))
	if not shop_ids.has(foreign_ids[0]):
		_errors.append("cross_class_ids: '%s' не пропущен в shop_items" % str(foreign_ids[0]))


# (г) «Украденный герб» (§5): apply_reward с cross_class_artifact_slots роллит
# ровно N чужих классовых id в run_modifiers.cross_class_artifact_ids (Array).
func _check_stolen_crest_roll() -> void:
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	if player_scene == null:
		_errors.append("stolen_crest: Player.tscn не загрузилась")
		return
	var player := player_scene.instantiate()
	root.add_child(player)
	player.call("configure_character", "thief")
	player.call("apply_reward", {
		"kind": "artifact", "id": "stolen_crest", "title": "Украденный герб",
		"mods": {"cross_class_artifact_slots": 2.0},
	})
	var modifiers: Dictionary = player.get("run_modifiers")
	var rolled_raw = modifiers.get("cross_class_artifact_ids", null)
	if not (rolled_raw is Array):
		_errors.append("stolen_crest: cross_class_artifact_ids не Array (%s)" % str(rolled_raw))
		player.free()
		return
	var rolled: Array = rolled_raw
	if rolled.size() != 2 or str(rolled[0]) == str(rolled[1]):
		_errors.append("stolen_crest: ожидались 2 уникальных чужих id, получено %s" % str(rolled))
	for rolled_id in rolled:
		var definition := PD.artifact_definition(str(rolled_id))
		var affinity: Array = definition.get("class_affinity", []) as Array
		if affinity.is_empty() or affinity.has("thief"):
			_errors.append("stolen_crest: id '%s' не чужой классовый" % str(rolled_id))
	# Роллнутые id реально открывают чужие артефакты в сэмплере этого забега.
	var pool_ids := _pool_ids(PD.reward_pool("thief", 0, rolled))
	for rolled_id in rolled:
		if not pool_ids.has(str(rolled_id)):
			_errors.append("stolen_crest: роллнутый '%s' не попал в reward_pool" % str(rolled_id))
	# Слот-ключ прошёл обычной float-коэрцией mods.
	if float(modifiers.get("cross_class_artifact_slots", 0.0)) < 2.0:
		_errors.append("stolen_crest: cross_class_artifact_slots не применился как мод")
	player.free()
