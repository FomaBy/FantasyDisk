extends SceneTree

# FAN-1032 (Stage 4, DoD FAN-1028): формальный гейт проходимости возвышений.
#
# Утверждает по ПРИЁМОЧНОМУ живому CSV (build/character_balance_dps.csv —
# среднее ≥2 честных прогонов tools/character_balance_csv.gd --mode=live):
#   1. ideal-маржа A5 ≥ 1.5 у каждого класса: kit_dps(ideal,1t) × asc-награды(A5)
#      против worst-босса Акта 2 на A5 за kill-or-lose 300с;
#   2. ideal-маржа по секретному боссу (A5) ≥ 1.2;
#   3. random-маржа A1 ≥ 0.95 (порог 1.0 минус шумовой пол живого замера ±0.05 —
#      см. no-silent-retune лог FAN-1031, приёмка = среднее 2+ прогонов);
#   4. CONST-guard: BOSS_HAZARD_MAX_HP_FRACTION ≤ 0.80 существует (ваншоты с
#      полного HP исключены механикой — S2 FAN-1031).
#
# Гейт детерминирован (CSV фиксирован в git); ребаланс без пересъёма CSV
# провалит его осознанно — это контракт «пересняли → перепроверили».
# Зеркало математики: tools/ascension_viability_report.py (там же оговорки).

const PD := preload("res://scripts/progression_data.gd")
const PDB := preload("res://scripts/progression_data_balance.gd")
const MainScript := preload("res://scripts/main.gd")

const CSV_PATH := "res://build/character_balance_dps.csv"
const FIGHT_TIMER := 300.0
const STAGE_BOSS_A2 := 16
const MIN_IDEAL_A5 := 1.5
const MIN_IDEAL_SECRET := 1.2
const MIN_RANDOM_A1 := 0.95
const BOSS_ROTATION_A2 := {
	"rift_warden": "res://scenes/BossWarden.tscn",
	"disk_devourer": "res://scenes/BossDiskDevourer.tscn",
	"bone_archon": "res://scenes/BossBoneArchon.tscn",
	"brood_mother": "res://scenes/BossBroodMother.tscn",
	"ashen_colossus": "res://scenes/BossAshenColossus.tscn",
}
const SECRET_BOSS_SCENE := "res://scenes/BossSecretAscension.tscn"


func _boss_hp(scene_path: String, level: int, secret: bool) -> float:
	var boss := (load(scene_path) as PackedScene).instantiate()
	var base := float(boss.get("max_health"))
	boss.free()
	var scale: float = PD.stage_scale(STAGE_BOSS_A2)
	var mult: float = float(MainScript.ENEMY_BALANCE["boss"]["hp_multiplier"]) * (5.40 + scale * 1.55)
	if secret:
		mult *= 1.18
	var asc: Dictionary = PD.ascension_difficulty_mods(level)
	return base * mult * float(asc["boss_hp_mult"])


func _initialize() -> void:
	var errors: Array = []

	# 4. CONST-guard ваншот-капа.
	var frac: float = float(PDB.BOSS_HAZARD_MAX_HP_FRACTION)
	if frac <= 0.0 or frac > 0.80:
		errors.append("BOSS_HAZARD_MAX_HP_FRACTION=%s вне (0..0.80] — ваншот-контракт нарушен" % frac)

	# Приёмочный CSV.
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("Ascension viability gate: нет %s — сначала пересъём live CSV" % CSV_PATH)
		quit(1)
		return
	var header := Array(file.get_csv_line())
	var idx_class := header.find("class")
	var idx_ideal := header.find("lvl20_ideal_1t")
	var idx_random := header.find("lvl20_random_1t")
	var kits := {}  # cid -> {"ideal": [..], "random": [..]}
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() <= maxi(idx_ideal, idx_random):
			continue
		var cid := str(line[idx_class])
		if cid == "":
			continue
		if not kits.has(cid):
			kits[cid] = {"ideal": [], "random": []}
		kits[cid]["ideal"].append(float(line[idx_ideal]))
		kits[cid]["random"].append(float(line[idx_random]))
	file.close()
	if kits.size() < 10:
		errors.append("подозрительно мало классов в CSV (%d) — гейт вакуумен" % kits.size())

	# Пороги угрозы.
	var required_a5 := 0.0
	for boss_id in BOSS_ROTATION_A2:
		required_a5 = maxf(required_a5, _boss_hp(BOSS_ROTATION_A2[boss_id], 5, false) / FIGHT_TIMER)
	var required_a1 := 0.0
	for boss_id in BOSS_ROTATION_A2:
		required_a1 = maxf(required_a1, _boss_hp(BOSS_ROTATION_A2[boss_id], 1, false) / FIGHT_TIMER)
	var required_secret: float = _boss_hp(SECRET_BOSS_SCENE, 5, true) / FIGHT_TIMER

	for cid in kits.keys():
		var weapons: int = kits[cid]["ideal"].size()
		if weapons < 3:
			errors.append("%s: только %d оружий в CSV" % [cid, weapons])
			continue
		var kit_ideal := 0.0
		var kit_random := 0.0
		for v in kits[cid]["ideal"]:
			kit_ideal += float(v)
		for v in kits[cid]["random"]:
			kit_random += float(v)
		kit_ideal /= weapons
		kit_random /= weapons
		var mods5: Dictionary = PD.ascension_mods(str(cid), 5)
		var mods1: Dictionary = PD.ascension_mods(str(cid), 1)
		var p5: float = float(mods5.get("damage_multiplier", 1.0)) * float(mods5.get("attack_speed_multiplier", 1.0))
		var p1: float = float(mods1.get("damage_multiplier", 1.0)) * float(mods1.get("attack_speed_multiplier", 1.0))
		var margin_a5 := kit_ideal * p5 / required_a5
		var margin_secret := kit_ideal * p5 / required_secret
		var margin_a1_random := kit_random * p1 / required_a1
		print("[asc-gate] %s: A5 ideal=%.2f secret=%.2f | A1 random=%.2f" % [cid, margin_a5, margin_secret, margin_a1_random])
		if margin_a5 < MIN_IDEAL_A5:
			errors.append("%s: ideal-маржа A5 %.2f < %.1f" % [cid, margin_a5, MIN_IDEAL_A5])
		if margin_secret < MIN_IDEAL_SECRET:
			errors.append("%s: маржа секретного босса %.2f < %.1f" % [cid, margin_secret, MIN_IDEAL_SECRET])
		if margin_a1_random < MIN_RANDOM_A1:
			errors.append("%s: random-маржа A1 %.2f < %.2f" % [cid, margin_a1_random, MIN_RANDOM_A1])

	if not errors.is_empty():
		for e in errors:
			push_error("Ascension viability gate: %s" % e)
		quit(1)
		return
	print("Ascension viability gate passed (%d классов: A5 ideal ≥%.1f, секрет ≥%.1f, A1 random ≥%.2f, hazard-кап ≤0.80)." % [kits.size(), MIN_IDEAL_A5, MIN_IDEAL_SECRET, MIN_RANDOM_A1])
	quit(0)
