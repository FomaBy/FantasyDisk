extends SceneTree

# SCRUM-719: контракт «codex-открытий». Каждый ID, который игровой рантайм
# передаёт в MetaProgression.record_codex_discovery при убийстве врага/босса/
# мини-элитки, ОБЯЗАН быть каноническим codex-ID — иначе открытие молча теряется
# (record_codex_discovery возвращает state без изменений на невалидном id).
# Этот тест ловит «протухшие/отсутствующие ID» в обе стороны:
#   1) каждый рантайм-источник ID реально записывается метой (end-to-end);
#   2) нет «мёртвых» codex-монстров без рантайм-пути открытия.
# Источники ID рантайма (read-only зеркало gameplay-кода — НЕ меняем геймплей):
#   - main.gd CODEX_ENEMY_NAME_TO_ID         → обычные враги + элитки (категория monsters)
#   - ProgressionData.mini_elite_kinds()[].id → мини-элитки (категория monsters)
#   - route_map_screen.gd _random_boss_route_node → акт-боссы (категория bosses)
#
# Запуск: Godot --headless --path . --script res://tests/codex_discovery_contract_test.gd

const MetaProgression := preload("res://scripts/meta_progression.gd")
const CodexData := preload("res://scripts/codex_data.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const MainScript := preload("res://scripts/main.gd")

# Зеркало route_map_screen.gd::_random_boss_route_node() (акт-боссы маршрута).
# Если там добавится/переименуется босс — реверс-проверка ниже поймает рассинхрон.
const ACT_BOSS_IDS := ["rift_warden", "disk_devourer", "bone_archon", "brood_mother", "ashen_colossus"]


func _initialize() -> void:
	var errors: Array = []

	_check_enemy_name_map(errors)
	_check_mini_elite_kinds(errors)
	_check_act_bosses(errors)
	_check_no_dead_codex_monsters(errors)
	_check_secret_boss_gap_is_known(errors)

	if not errors.is_empty():
		for e in errors:
			push_error("Codex discovery contract: %s" % e)
		push_error("Codex discovery contract test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Codex discovery contract test passed (%d enemy-name id, %d mini-elite, %d act-boss; reverse coverage OK)." % [
		MainScript.CODEX_ENEMY_NAME_TO_ID.size(), ProgressionData.mini_elite_kinds().size(), ACT_BOSS_IDS.size()])
	quit(0)


# Реальный контракт: id записывается метой (а не молча отбрасывается).
func _records(category: String, content_id: String) -> bool:
	var state: Dictionary = MetaProgression.default_state()
	state = MetaProgression.record_codex_discovery(state, category, content_id)
	return MetaProgression.is_codex_discovered(state, category, content_id)


func _check_enemy_name_map(errors: Array) -> void:
	var name_map: Dictionary = MainScript.CODEX_ENEMY_NAME_TO_ID
	if name_map.is_empty():
		errors.append("CODEX_ENEMY_NAME_TO_ID пуст — гейт прошёл бы вакуумно.")
		return
	for enemy_name in name_map.keys():
		var content_id := str(name_map[enemy_name])
		if content_id == "":
			errors.append("CODEX_ENEMY_NAME_TO_ID['%s'] пуст." % enemy_name)
			continue
		# record_codex_enemy_discovery кладёт обычных врагов/элиток в monsters; для боссов
		# ID берётся из meta boss_id (категория bosses), а одноимённые записи в name-map —
		# вестигиальные (босс в группе 'bosses' уходит в первую ветку и до name-map не
		# доходит). Поэтому валидным считаем canonical-ID в monsters ИЛИ bosses — так тест
		# ловит реальный «протухший id», но не ложно-срабатывает на боссовых именах.
		if not _records("monsters", content_id) and not _records("bosses", content_id):
			errors.append("enemy-name '%s' → '%s' не является caноническим codex-id (ни monster, ни boss; протухший id)." % [enemy_name, content_id])


func _check_mini_elite_kinds(errors: Array) -> void:
	var kinds: Array = ProgressionData.mini_elite_kinds()
	if kinds.is_empty():
		errors.append("mini_elite_kinds() пуст — гейт прошёл бы вакуумно.")
		return
	for kind in kinds:
		var kind_id := str((kind as Dictionary).get("id", ""))
		if kind_id == "":
			errors.append("mini_elite kind без id: %s" % str(kind))
			continue
		# _apply_mini_elite_kind ставит meta mini_elite_kind=id; рантайм пишет в monsters.
		if not _records("monsters", kind_id):
			errors.append("mini_elite '%s' НЕ записывается как codex-monster (нет canonical-записи)." % kind_id)


func _check_act_bosses(errors: Array) -> void:
	for boss_id in ACT_BOSS_IDS:
		if not _records("bosses", boss_id):
			errors.append("act-boss '%s' НЕ записывается как codex-boss (протухший id)." % boss_id)


# Реверс: каждый codex-монстр (kind != boss) должен открываться хоть одним
# рантайм-путём (name-map ИЛИ mini-elite), иначе это «мёртвая» запись кодекса.
func _check_no_dead_codex_monsters(errors: Array) -> void:
	var reachable := {}
	for v in MainScript.CODEX_ENEMY_NAME_TO_ID.values():
		reachable[str(v)] = true
	for kind in ProgressionData.mini_elite_kinds():
		reachable[str((kind as Dictionary).get("id", ""))] = true
	for entry in CodexData.monsters():
		if str((entry as Dictionary).get("kind", "")) == "boss":
			continue
		var monster_id := str((entry as Dictionary).get("id", ""))
		if not reachable.has(monster_id):
			errors.append("codex-monster '%s' недостижим рантаймом (мёртвая запись или отсутствует источник открытия)." % monster_id)
	# Реверс для боссов: codex-боссы == акт-роумтер (секретный босс — отдельный кейс ниже).
	for entry in CodexData.monsters():
		if str((entry as Dictionary).get("kind", "")) != "boss":
			continue
		var boss_id := str((entry as Dictionary).get("id", ""))
		if not ACT_BOSS_IDS.has(boss_id):
			errors.append("codex-boss '%s' не входит в акт-роутер маршрута (рассинхрон бой/кодекс)." % boss_id)


# Известный задокументированный разрыв (SCRUM-719 finding): секретный босс
# secret_ascension_boss выставляет meta boss_id и при убийстве зовёт
# record_codex_discovery('bosses', SECRET_BOSS_ID), но codex-записи у него НЕТ →
# открытие молча теряется. Это player-facing контент-решение (показывать ли
# секретного босса в кодексе), поэтому фиксируется как finding, а не правится тут.
# Тест ЗАКРЕПЛЯЕТ текущую реальность: id не записывается. Когда разрыв осознанно
# закроют (добавят codex-запись), этот ассерт «покраснеет» и заставит обновить
# контракт намеренно — то есть служит напоминанием, а не молчаливым покрытием.
func _check_secret_boss_gap_is_known(errors: Array) -> void:
	var secret_id := str(MetaProgression.SECRET_BOSS_ID)
	if _records("bosses", secret_id):
		# Разрыв закрыт — это хорошо, но контракт устарел: обнови ACT_BOSS_IDS/доку.
		errors.append("secret-boss '%s' ТЕПЕРЬ открывается в кодексе — обнови контракт и аудит (finding закрыт)." % secret_id)
