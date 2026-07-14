class_name WeaponCrowdCaps
extends RefCounted

# FAN-1031 3c: единая крауд-fan-out математика class_weapon (извлечена из монолита по
# ратчету dev-гейта; поведение неизменно). Диминиш-фактор per-target по ЧИСЛУ целей:
# ближние `full` целей — полный тик (1.0), дальний хвост душится геометрически
# 1/(1+(rank−full+1)·diminish); жёсткий кап ШИРИНЫ (max_targets>=0) → цели за ним получают
# ноль. Сентинел-контракт: поле <0 → дефолт (diminish 0 → factor==1 ВСЕГДА → нулевое
# изменение без override). Канон: docs/design/systems/progression_balance.md; гейты
# tests/status_fanout_cap_gate.gd, tests/orbit_falloff_cap_gate.gd.
static func fanout_factor(rank: int, full_field: int, diminish_field: float, max_targets: int, default_full: int, default_diminish: float) -> float:
	if max_targets >= 0 and rank >= max_targets:
		return 0.0
	var full := full_field if full_field >= 0 else default_full
	var diminish := diminish_field if diminish_field >= 0.0 else default_diminish
	if diminish <= 0.0 or rank < full:
		return 1.0
	return 1.0 / (1.0 + float(rank - full + 1) * diminish)
