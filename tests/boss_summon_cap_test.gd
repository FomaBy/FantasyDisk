extends SceneTree

# SCRUM-596: лимит одновременных призывов босса (_summon_riftlings).
# Регресс на чистую функцию Boss.riftling_summon_count(phase, active_summons):
# она обязана ТОЛЬКО дозаполнять до MAX_SUMMONED_RIFTLINGS (учитывая уже живых),
# а не спавнить безусловную пачку поверх лимита. Без рендера/SceneTree.
#
# Баг (до фикса): проверка active>=8 стояла один раз, затем безусловно спавнилось
# 3+phase-1 → на фазе 3 при 7 живых получалось 12 вместо 8, плюс риск /float(0).
#
# Запуск: Godot --headless --path . --script res://tests/boss_summon_cap_test.gd

const Boss := preload("res://scripts/boss.gd")


func _initialize() -> void:
	var errors: Array = []
	var cap: int = Boss.MAX_SUMMONED_RIFTLINGS

	if cap <= 0:
		errors.append("MAX_SUMMONED_RIFTLINGS должен быть > 0 (получено %d)" % cap)

	# Хелпер: ожидаемое значение по контракту (база 3+phase-1, обрезка остатком, >=0).
	var expected := func(phase: int, active: int) -> int:
		return maxi(mini(3 + phase - 1, cap - active), 0)

	# 1. Пустое поле — спавним полную базу по фазе (но не больше cap).
	for phase in range(1, 4):
		var got: int = Boss.riftling_summon_count(phase, 0)
		var want: int = expected.call(phase, 0)
		if got != want:
			errors.append("phase=%d active=0: ожид. %d, получено %d" % [phase, want, got])

	# 2. Никогда не превышаем cap: count + active <= cap для всех комбинаций.
	for phase in range(1, 6):
		for active in range(0, cap + 4):
			var count: int = Boss.riftling_summon_count(phase, active)
			if count < 0:
				errors.append("phase=%d active=%d: отрицательный count %d (риск range/float)" % [phase, active, count])
			# Если что-то спавним — итог не должен переходить cap.
			if count > 0 and count + active > cap:
				errors.append("phase=%d active=%d: count %d переполняет cap (итог %d > %d)" % [phase, active, count, count + active, cap])
			# Поле уже на потолке (или сверх) → ничего не добавляем.
			if active >= cap and count != 0:
				errors.append("phase=%d active=%d (>=cap): ожид. 0, получено %d" % [phase, active, count])

	# 3. Дозаполнение до максимума при почти полном поле (ключевой кейс из тикета).
	# Фаза 3 (база 3+3-1=5), 6 живых → ровно 2 (итог 8), 7 живых → 1, 8 живых → 0.
	if Boss.riftling_summon_count(3, 6) != cap - 6:
		errors.append("phase=3 active=6: ожид. дозаполнение до cap (%d), получено %d" % [cap - 6, Boss.riftling_summon_count(3, 6)])
	if Boss.riftling_summon_count(3, 7) != cap - 7:
		errors.append("phase=3 active=7: ожид. %d, получено %d" % [cap - 7, Boss.riftling_summon_count(3, 7)])
	if Boss.riftling_summon_count(3, cap) != 0:
		errors.append("phase=3 active=cap: ожид. 0, получено %d" % Boss.riftling_summon_count(3, cap))

	# 4. Переполнение поля (active > cap, теоретически) → 0, без отрицательного range.
	if Boss.riftling_summon_count(5, cap + 3) != 0:
		errors.append("active>cap должен давать 0 (без отрицательного count)")

	# 5. База на пустом поле: фаза 1 = 3, фаза 2 = 4, фаза 3 = 5 (контракт 3+phase-1).
	if Boss.riftling_summon_count(1, 0) != 3:
		errors.append("phase=1 active=0: ожид. база 3, получено %d" % Boss.riftling_summon_count(1, 0))
	if Boss.riftling_summon_count(2, 0) != 4:
		errors.append("phase=2 active=0: ожид. база 4, получено %d" % Boss.riftling_summon_count(2, 0))

	if not errors.is_empty():
		for e in errors:
			push_error("Boss summon cap: %s" % e)
		push_error("Boss summon cap test: %d нарушений." % errors.size())
		quit(1)
		return
	print("Boss summon cap test passed (дозаполнение до %d, без превышения/отрицательного count)." % cap)
	quit(0)
