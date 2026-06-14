extends SceneTree

# Гейт кривой возвышений (SCRUM-358): «усилить монстров на низких, меньше элиток
# на высоких». Проверяет кумулятивную ascension_difficulty_mods по уровням:
#   1. L0 — без усложнений (defaults);
#   2. монстерский пресс (enemy_hp/damage) монотонно неубывает с уровнем — сложность
#      на высоких держится за счёт ОБЫЧНЫХ монстров;
#   3. mini_elite_chance НЕмонотонна: вводится на средних, пик НЕ на максимуме,
#      на высших уровнях заметно спадает (меньше элиток), но не уходит в минус по
#      смыслу применения (combat_director трактует <=0 как «без элиток»).
#
# Отдельный изолированный файл (только ЧИТАЕТ ProgressionData).
# Запуск: Godot --headless --path . --script res://tests/ascension_curve_balance_test.gd

const PD := preload("res://scripts/progression_data.gd")


func _initialize() -> void:
	var errors: Array = []
	var max_level: int = PD.ASCENSION_MODIFIERS.size()

	# 1. L0 — чистые дефолты.
	var l0: Dictionary = PD.ascension_difficulty_mods(0)
	if not is_equal_approx(float(l0.get("enemy_hp_mult", 0.0)), 1.0) \
			or not is_equal_approx(float(l0.get("enemy_damage_mult", 0.0)), 1.0) \
			or not is_equal_approx(float(l0.get("mini_elite_chance", 1.0)), 0.0):
		errors.append("L0 должен быть без усложнений (enemy_hp/damage=1.0, mini_elite=0)")

	# Собираем кривые по уровням.
	var hp := []
	var dmg := []
	var elite := []
	for lvl in range(0, max_level + 1):
		var m: Dictionary = PD.ascension_difficulty_mods(lvl)
		hp.append(float(m.get("enemy_hp_mult", 1.0)))
		dmg.append(float(m.get("enemy_damage_mult", 1.0)))
		elite.append(float(m.get("mini_elite_chance", 0.0)))

	# 2. Монстерский пресс не убывает (кумулятивно крепчает).
	for lvl in range(1, max_level + 1):
		if hp[lvl] < hp[lvl - 1] - 0.0001:
			errors.append("enemy_hp_mult убывает на L%d (%.3f < %.3f)" % [lvl, hp[lvl], hp[lvl - 1]])
		if dmg[lvl] < dmg[lvl - 1] - 0.0001:
			errors.append("enemy_damage_mult убывает на L%d (%.3f < %.3f)" % [lvl, dmg[lvl], dmg[lvl - 1]])
	# Низкие возвышения реально усиливают монстров.
	if hp[1] <= 1.0 or dmg[1] <= 1.0:
		errors.append("L1 должен усиливать обычных монстров (hp %.2f, dmg %.2f)" % [hp[1], dmg[1]])
	# Высокие держат монстерский пресс выше низких.
	if hp[max_level] <= hp[1]:
		errors.append("на высоких монстры должны быть крепче, чем на L1 (%.2f vs %.2f)" % [hp[max_level], hp[1]])

	# 3. mini_elite_chance: вводится, пик НЕ на максимуме, спад на высоких.
	var peak := 0.0
	var peak_level := 0
	for lvl in range(0, max_level + 1):
		if elite[lvl] > peak:
			peak = elite[lvl]
			peak_level = lvl
	if peak <= 0.0:
		errors.append("mini_elite_chance нигде не вводится (элиток вообще нет)")
	if peak_level >= max_level:
		errors.append("пик элиток на максимальном уровне L%d — должно быть меньше элиток на высоких" % peak_level)
	# На максимальном уровне элиток заметно меньше пика (смещение в монстров/босса).
	if elite[max_level] >= peak:
		errors.append("на максимуме L%d элиток не меньше пика (%.3f >= %.3f)" % [max_level, elite[max_level], peak])
	if elite[max_level] > peak * 0.5:
		errors.append("спад элиток на высоких недостаточный (L%d %.3f > половины пика %.3f)" % [max_level, elite[max_level], peak])

	# Анти-вакуум.
	if max_level < 8:
		errors.append("уровней возвышения подозрительно мало (%d)" % max_level)

	if not errors.is_empty():
		for e in errors:
			push_error("Ascension curve: %s" % e)
		push_error("Ascension curve balance: %d нарушений." % errors.size())
		quit(1)
		return
	print("Ascension curve balance passed (монстры↑ монотонно до L%d hp×%.2f; элитки пик L%d=%.2f → L%d=%.2f спад)." % [
		max_level, hp[max_level], peak_level, peak, max_level, elite[max_level]])
	quit(0)
