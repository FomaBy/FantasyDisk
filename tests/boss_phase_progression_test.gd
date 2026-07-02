extends SceneTree

# SCRUM-713: контракт прогрессии фаз босса — чистая функция
# Boss.phase_for_ratio(behavior, ratio, current_phase, has_extra_phase).
# Проверяет пороги (обычный 0.66/0.33 vs секретный 0.50/0.25, фаза 4 = только
# на возвышении при ratio<=0.15), включающую семантику `<=` на границах и
# МОНОТОННОСТЬ (фаза не откатывается, даже если HP подскочил вверх от лечения).
# Без рендера/SceneTree — как boss_summon_cap_test.
#
# Запуск: Godot --headless --path . --script res://tests/boss_phase_progression_test.gd

const Boss := preload("res://scripts/boss.gd")


func _initialize() -> void:
	var errors: Array = []

	var check := func(behavior: String, ratio: float, cur: int, extra: bool, want: int, note: String) -> void:
		var got: int = Boss.phase_for_ratio(behavior, ratio, cur, extra)
		if got != want:
			errors.append("%s [%s ratio=%.3f cur=%d extra=%s]: ожид. %d, получено %d" % [note, behavior, ratio, cur, extra, want, got])

	# --- Обычный босс: пороги 0.66 / 0.33 (фаза 4 только extra+<=0.15) ---
	check.call("rift_warden", 1.00, 1, false, 1, "полное HP -> фаза 1")
	check.call("rift_warden", 0.67, 1, false, 1, "чуть выше 0.66 -> фаза 1")
	check.call("rift_warden", 0.66, 1, false, 2, "ровно 0.66 (<=) -> фаза 2")
	check.call("rift_warden", 0.50, 1, false, 2, "0.50 -> фаза 2")
	check.call("rift_warden", 0.34, 1, false, 2, "чуть выше 0.33 -> фаза 2")
	check.call("rift_warden", 0.33, 1, false, 3, "ровно 0.33 (<=) -> фаза 3")
	check.call("rift_warden", 0.15, 1, false, 3, "без extra: 0.15 остаётся фаза 3")
	check.call("rift_warden", 0.05, 1, false, 3, "без extra: даже 0.05 максимум фаза 3")

	# --- Обычный босс с extra-фазой (возвышение 9+): фаза 4 при ratio<=0.15 ---
	check.call("rift_warden", 0.16, 1, true, 3, "extra: чуть выше 0.15 -> фаза 3")
	check.call("rift_warden", 0.15, 1, true, 4, "extra: ровно 0.15 (<=) -> фаза 4")
	check.call("rift_warden", 0.05, 1, true, 4, "extra: 0.05 -> фаза 4")

	# --- Секретный босс: пороги 0.50 / 0.25 ---
	check.call("secret_ascension_boss", 0.51, 1, false, 1, "secret: выше 0.50 -> фаза 1")
	check.call("secret_ascension_boss", 0.50, 1, false, 2, "secret: ровно 0.50 -> фаза 2")
	check.call("secret_ascension_boss", 0.26, 1, false, 2, "secret: выше 0.25 -> фаза 2")
	check.call("secret_ascension_boss", 0.25, 1, false, 3, "secret: ровно 0.25 -> фаза 3")
	check.call("secret_ascension_boss", 0.15, 1, true, 4, "secret+extra: 0.15 -> фаза 4")
	check.call("secret_ascension_boss", 0.16, 1, true, 3, "secret+extra: выше 0.15 -> фаза 3")

	# --- Монотонность: фаза НЕ откатывается при росте HP (лечение/щит) ---
	check.call("rift_warden", 1.00, 3, false, 3, "HP восстановлено до 100%, но фаза 3 держится")
	check.call("rift_warden", 0.66, 3, false, 3, "вернулись к порогу фазы 2, но уже фаза 3")
	check.call("secret_ascension_boss", 0.90, 2, false, 2, "secret: фаза 2 не откатывается на высоком HP")
	check.call("rift_warden", 0.05, 4, true, 4, "фаза 4 остаётся фазой 4")
	check.call("rift_warden", 0.30, 4, false, 4, "фаза 4 не откатывается к 3 при росте HP")

	# --- current_phase уже выше расчётной -> возвращаем current (без даунгрейда) ---
	check.call("rift_warden", 0.40, 2, false, 2, "ratio даёт фазу 2, current 2 -> 2 (без изменений)")
	check.call("rift_warden", 0.20, 2, false, 3, "ratio даёт фазу 3 из current 2 -> повышение")

	# Анти-вакуум: функция реально различает фазы (не возвращает константу).
	var distinct := {}
	for r in [0.9, 0.5, 0.3, 0.1]:
		distinct[Boss.phase_for_ratio("rift_warden", r, 1, true)] = true
	if distinct.size() < 4:
		errors.append("phase_for_ratio не различает все 4 фазы на возрастающем уроне (получено %d уникальных)" % distinct.size())

	if not errors.is_empty():
		for e in errors:
			push_error("Boss phase progression: %s" % e)
		push_error("Boss phase progression test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Boss phase progression test passed (пороги обычный/секретный, границы <=, extra-фаза, монотонность).")
	quit(0)
