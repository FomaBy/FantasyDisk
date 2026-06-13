extends SceneTree

## Survivability Scenario Harness (SCRUM-190).
##
## Детерминированная модель выживаемости для профилей fragile/steady/sturdy/tank
## против 4 сценариев урона (contact swarm / shooter crossfire / elite burst /
## boss phase hazard). Считает EHP, time-to-death, вклад dodge/defense/absorb и
## вклад лечения (regen), сверяет с ожиданиями и помечает выбросы.
##
## Модель использует ТОЧНУЮ боевую формулу из ProgressionData.derived_parameters +
## порядок митигейта Player.take_damage (absorb -> defense -> dodge, затем regen):
##   after_absorb = max(a - absorb, 0.2*a)
##   after_defense = after_absorb * (1 - defense)
##   after_dodge   = after_defense * (1 - dodge)            (ожидание по вероятности)
##   effective_dps = max(after_dodge * cadence - regen, 0.05)
## Корректность формулы относительно реального кода якорится тестом
## tests/survivability_scenario_test.gd (реальный Player.take_damage).
##
## БАЛАНСОВЫЕ ЗНАЧЕНИЯ НЕ МЕНЯЮТСЯ (требование задачи) — только замер/отчёт.
##
## Запуск: Godot --headless --path . --script res://tools/survivability_harness.gd
## Вывод: build/survivability_report.md

const ProgressionData := preload("res://scripts/progression_data.gd")

const REPORT_PATH := "res://build/survivability_report.md"

# Профили выживаемости: синтетические стат-блоки, монотонные по endurance
# (здоровье/защита/absorb) и agility (dodge). Порядок = ожидаемая стойкость.
const PROFILES := [
	{"id": "fragile", "title": "Хрупкий", "endurance": 3.0, "agility": 4.0, "knowledge": 2.0},
	{"id": "steady", "title": "Уверенный", "endurance": 8.0, "agility": 6.0, "knowledge": 5.0},
	{"id": "sturdy", "title": "Крепкий", "endurance": 14.0, "agility": 7.0, "knowledge": 8.0},
	{"id": "tank", "title": "Танк", "endurance": 22.0, "agility": 6.0, "knowledge": 11.0},
]

# Сценарии: профиль входящего урона. amount — урон на попадание (ДО митигейта),
# cadence — попаданий в секунду. Разный размер удара ВАЖЕН: absorb плоский и
# сильнее против роя мелких ударов, defense/dodge мультипликативны.
const SCENARIOS := [
	{"id": "contact_swarm", "title": "Контактный рой", "amount": 6.0, "cadence": 5.0,
	 "note": "много мелких ударов — тест absorb"},
	{"id": "shooter_crossfire", "title": "Перекрёстный обстрел", "amount": 14.0, "cadence": 2.0,
	 "note": "средние снаряды"},
	{"id": "elite_burst", "title": "Бурст элитки", "amount": 45.0, "cadence": 0.6,
	 "note": "крупный спайк — absorb почти не помогает"},
	{"id": "boss_phase_hazard", "title": "Хазард фазы босса", "amount": 22.0, "cadence": 1.5,
	 "note": "устойчивая зона"},
]


# Возвращает derived_parameters для профиля (чистая боевая формула, нейтральные
# модификаторы забега, без оружия).
static func profile_params(profile: Dictionary) -> Dictionary:
	var stats := {
		"strength": 6.0, "agility": float(profile["agility"]), "intelligence": 6.0,
		"perception": 6.0, "energy": 6.0, "knowledge": float(profile["knowledge"]),
		"endurance": float(profile["endurance"]), "leadership": 6.0,
	}
	return ProgressionData.derived_parameters(stats, {}, {})


# Точный ожидаемый урон за ОДНО попадание после absorb+defense+dodge.
static func expected_hit_damage(amount: float, defense: float, absorb: float, dodge: float) -> float:
	var after_absorb: float = maxf(amount - absorb, amount * 0.2)
	var after_defense := after_absorb * (1.0 - defense)
	return after_defense * (1.0 - clampf(dodge, 0.0, 0.8))


# Строит одну строку модели (profile x scenario) с TTD и разложением митигейта.
static func model_row(profile: Dictionary, scenario: Dictionary) -> Dictionary:
	var p := profile_params(profile)
	var health := float(p.get("health_point", 1.0))
	var defense := clampf(float(p.get("defense", 0.0)), 0.0, 0.95)
	var absorb := float(p.get("absorb", 0.0))
	var dodge := clampf(float(p.get("dodge", 0.0)), 0.0, 0.8)
	var regen := float(p.get("regeneration", 0.0))
	var amount := float(scenario["amount"])
	var cadence := float(scenario["cadence"])

	var raw_dps := amount * cadence
	var after_absorb_dps: float = maxf(amount - absorb, amount * 0.2) * cadence
	var after_defense_dps := after_absorb_dps * (1.0 - defense)
	var after_dodge_dps := after_defense_dps * (1.0 - dodge)
	var effective_dps: float = maxf(after_dodge_dps - regen, 0.05)

	return {
		"profile": profile["id"], "scenario": scenario["id"],
		"health": health, "defense": defense, "absorb": absorb, "dodge": dodge, "regen": regen,
		"raw_dps": raw_dps,
		"mitigated_dps": after_dodge_dps,
		"effective_dps": effective_dps,
		"ttd": health / effective_dps,
		# Вклад каждого слоя (dps, который он срезал).
		"absorb_prev": raw_dps - after_absorb_dps,
		"defense_prev": after_absorb_dps - after_defense_dps,
		"dodge_prev": after_defense_dps - after_dodge_dps,
		"regen_prev": after_dodge_dps - effective_dps,
	}


static func build_model() -> Array:
	var rows: Array = []
	for profile in PROFILES:
		for scenario in SCENARIOS:
			rows.append(model_row(profile, scenario))
	return rows


func _initialize() -> void:
	var rows := build_model()
	_write_report(rows)
	for row in rows:
		print("%s/%s: TTD=%.1fс EHP-mitig=%.0f%% regen=%.1f/с" % [
			row["profile"], row["scenario"], row["ttd"],
			(1.0 - float(row["mitigated_dps"]) / maxf(float(row["raw_dps"]), 0.001)) * 100.0,
			row["regen"]])
	quit(0)


func _write_report(rows: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var lines := PackedStringArray()
	lines.append("# FantasyDisk — отчёт выживаемости (SCRUM-190)")
	lines.append("")
	lines.append("Сгенерировано `tools/survivability_harness.gd`. Детерминированная модель")
	lines.append("на боевой формуле `derived_parameters` + порядок митигейта `Player.take_damage`.")
	lines.append("Балансовые значения НЕ менялись — только замер.")
	lines.append("")
	lines.append("Профили (синтетические стат-блоки):")
	for profile in PROFILES:
		var p := profile_params(profile)
		lines.append("- **%s** (END %d, AGI %d): HP %.0f, defense %.0f%%, absorb %.1f, dodge %.0f%%, regen %.2f/с" % [
			profile["title"], int(profile["endurance"]), int(profile["agility"]),
			float(p.get("health_point", 0.0)), float(p.get("defense", 0.0)) * 100.0,
			float(p.get("absorb", 0.0)), float(p.get("dodge", 0.0)) * 100.0,
			float(p.get("regeneration", 0.0))])
	lines.append("")
	lines.append("Сценарии входящего урона:")
	for scenario in SCENARIOS:
		lines.append("- **%s**: %.0f урона × %.1f/с (raw %.0f dps) — %s" % [
			scenario["title"], float(scenario["amount"]), float(scenario["cadence"]),
			float(scenario["amount"]) * float(scenario["cadence"]), scenario["note"]])
	lines.append("")
	lines.append("| Профиль | Сценарий | TTD | raw dps | effective dps | absorb | defense | dodge | regen |")
	lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	for row in rows:
		lines.append("| %s | %s | %.1fс | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |" % [
			row["profile"], row["scenario"], row["ttd"], row["raw_dps"], row["effective_dps"],
			row["absorb_prev"], row["defense_prev"], row["dodge_prev"], row["regen_prev"]])
	lines.append("")
	lines.append("Колонки absorb/defense/dodge/regen — dps, срезанный соответствующим слоем")
	lines.append("(absorb→defense→dodge→regen, как в `take_damage`). TTD = HP / effective dps.")
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать отчёт: %s" % REPORT_PATH)
		return
	file.store_string("\n".join(lines))
	file.close()
	print("Survivability report: %s (строк %d)" % [ProjectSettings.globalize_path(REPORT_PATH), rows.size()])
