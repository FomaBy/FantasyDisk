extends RefCounted

# FAN-3923 (FD16, program:agent-ready-refactor): pure weapon-budget formulas
# extracted verbatim from progression_data.gd. This module owns the analytical
# DPS/EHP model of a weapon (estimate), the auto-tuning that maps a class budget
# profile onto a weapon (tuning_damage_multiplier/budget_tuning), the
# crowd-clear metric, the weapon archetype lookup and the shared distance and
# plague formulas that both the runtime and the model read.
#
# It is a pure function library: it never preloads progression_data.gd (no
# cyclic dependency) and never reads CLASS_TRAITS or ULTIMATE_CONFIGS. Every
# class-side input arrives through the `class_context` dictionary of estimate(),
# which the ProgressionData facade resolves with the same trait formulas the
# runtime uses:
#   damage_parameter            default damage channel of the class
#   trait_config                CLASS_TRAITS entry of the class (read-only)
#   action_echo_chance          ProgressionData.class_action_echo_chance
#   infected_direct_multiplier  ProgressionData.class_infected_direct_multiplier
#   wild_aura_factor            ProgressionData.class_wild_aura_damage_factor(params)
#   rage_factor                 ProgressionData.class_rage_expected_damage_factor
#   periodic_damage_multiplier  ProgressionData.class_periodic_damage_multiplier
#   ultimate_config             ProgressionData.ultimate_config
# BalanceData stays the only owner of tuning constants; nothing here is retuned
# and ProgressionData re-exports every public entrypoint as a delegator.
# Whole-result equality with the pre-extraction facade is pinned by
# tests/weapon_budget_model_characterization_test.gd.

const BalanceData := preload("res://scripts/progression_data_balance.gd")
const BALANCE_BASE_SOLO_DPS := BalanceData.BALANCE_BASE_SOLO_DPS
const BALANCE_BASE_AOE_DPS := BalanceData.BALANCE_BASE_AOE_DPS
const BALANCE_WINDOW_SECONDS := BalanceData.BALANCE_WINDOW_SECONDS
const CROWD_CLEAR_ENEMY_HP := BalanceData.CROWD_CLEAR_ENEMY_HP
const SURVIVABILITY_DEFENSE_CAP := BalanceData.SURVIVABILITY_DEFENSE_CAP
const SURVIVABILITY_DODGE_CAP := BalanceData.SURVIVABILITY_DODGE_CAP
const WEAPON_DRAIN_HEAL_MULTIPLIER := BalanceData.WEAPON_DRAIN_HEAL_MULTIPLIER
const WEAPON_ARCHETYPE_BY_MODE := BalanceData.WEAPON_ARCHETYPE_BY_MODE


# Budget copy of a weapon config: tags the owning class and, for an untuned
# estimate, drops the tuning keys a previous weapon() call may have baked in.
static func prepare_config(character_id: String, weapon_config: Dictionary, apply_budget := true) -> Dictionary:
	var config := weapon_config.duplicate(true)
	config["character_id"] = character_id
	if not apply_budget:
		config.erase("budget_damage_multiplier")
		config.erase("budget_tuning")
	return config


# Analytical solo/aoe DPS, EHP, cadence and hit model of one weapon.
# `config` comes from prepare_config(), `params` from
# ProgressionData.derived_parameters(stats, run_modifiers, config), `stats`
# are the raw attributes and `class_context` carries the class inputs listed
# in the header. Body moved verbatim from progression_data.gd.
static func estimate(config: Dictionary, params: Dictionary, stats: Dictionary, class_context: Dictionary, apply_budget := true, include_ultimate := true) -> Dictionary:
	var trait_config: Dictionary = class_context.get("trait_config", {})
	var periodic_mult := float(class_context.get("periodic_damage_multiplier", 1.0))
	var damage_parameter := str(config.get("damage_parameter", class_context.get("damage_parameter", "damage")))
	var base_damage := float(params.get(damage_parameter, params.get("damage", 1.0)))
	var crit_factor := 1.0 + float(params.get("crit_chance", 0.0)) * maxf(float(params.get("crit_damage_multiplier", 1.0)) - 1.0, 0.0)
	var interval := maxf(float(config.get("fire_interval", 1.0)) / maxf(float(params.get("attack_speed", 1.0)), 0.1), 0.18)
	var direct_dps := base_damage * crit_factor / interval
	if _is_pure_summon_weapon(config):
		direct_dps = 0.0
	elif bool(config.get("curse_only", false)):
		# SCRUM-940: curse-only оружие (cursed_skull) прямого урона не наносит —
		# весь его выход идёт через dot-ось (_budget_dot_dps), как и в рантайме.
		direct_dps = 0.0
	elif str(config.get("attack_mode", "")) == "engineer_orbit_drone":
		# SCRUM-906: оружие само не стреляет — обслуживает парк дронов; весь
		# урон контактный (summon-канал, _budget_orbit_drone_dps).
		direct_dps = 0.0
	elif str(config.get("summon_role", "")) != "":
		direct_dps *= _budget_summon_role_damage_factor(config, params, stats)
	var hit_model := _budget_hit_model(config)
	var melee_unique_budget := _budget_melee_unique_bonus(config)
	var dot_dps := _budget_dot_dps(config, params, interval, stats, periodic_mult)
	var pool_dps := _budget_pool_dps(config, params, interval, periodic_mult)
	var summon_dps := _budget_summon_dps(config, params, stats)
	# SCRUM-905/906: у устройств инженера собственные summon-модели, зеркалящие
	# рантайм (боезапас турелей / орбитальный контакт дронов); они замещают
	# generic _budget_summon_dps и пишут свой crowd-фактор в summon_targets.
	var sentry_model := _budget_sentry_ammo_model(config, params, stats)
	if not sentry_model.is_empty():
		summon_dps = float(sentry_model.get("summon_dps", summon_dps))
		hit_model["summon_targets"] = float(sentry_model.get("summon_targets", 1.0))
	var orbit_model := _budget_orbit_drone_dps(config, params, stats)
	if not orbit_model.is_empty():
		summon_dps = float(orbit_model.get("summon_dps", summon_dps))
		hit_model["summon_targets"] = float(orbit_model.get("summon_targets", 1.0))
	# SCRUM-935 «Двойное действие»: echo-trait создаёт полную копию действия оружия
	# с шансом p ⇒ матожидание выхода действия ×(1+p). Фактор применяется к
	# action-компонентам (direct/dot/pool), но НЕ к призывам (деплой исключён из
	# эха) и НЕ к ульте (не действие оружия). Благодаря этому budget_tuning_for
	# автоматически компенсирует урон кита (AC SCRUM-935: кит сопоставим с ростером).
	var action_echo_factor := 1.0 + float(class_context.get("action_echo_chance", 0.0))
	# SCRUM-946: периодические волны гомункула-кастера; по толпе волна накрывает
	# нескольких целей радиусом (зеркало клампа pool_targets: 1 + r/130, кап 4).
	# Волны — канал призыва (как summon_dps), echo-фактор действий на них не действует.
	var wave_dps := _budget_summon_wave_dps(config, params, periodic_mult)
	var wave_targets := clampf(1.0 + float(config.get("summon_wave_radius", 130.0)) / 130.0, 1.0, 4.0)
	# SCRUM-1005 «Разбор образцов»: прямой урон по целям под собственным DoT
	# усилен (Биолог ×1.20). Инфекция оружия с dot_ticks>0 живёт дольше
	# интервала каста (калибровка длительности в SCRUM-896), но первый хит боя
	# идёт по чистой цели — документированный uptime 0.75. Фактор применяется
	# ТОЛЬКО к прямому компоненту (не к dot/pool/summon/wave/ульте); у оружия без
	# собственного DoT (dot_ticks<=0) бонус в модели не учитывается.
	var infected_direct_factor := 1.0
	if float(config.get("dot_ticks", 0.0)) > 0.0:
		infected_direct_factor = 1.0 + (float(class_context.get("infected_direct_multiplier", 1.0)) - 1.0) * 0.75
	# SCRUM-930 «Дальний расчёт»: матожидание дистанс-множителя Снайпера по
	# типовой дистанции боя оружия (только ПРЯМОЙ компонент — тики DoT trait не
	# скейлит, зеркало гейта в ClassWeapon._damage_enemy). budget_tuning_for
	# компенсирует кит, как у прочих trait-факторов.
	var distance_factors := _budget_distance_trait_factors(trait_config, config)
	var distance_solo_factor := float(distance_factors.get("solo", 1.0))
	var distance_aoe_factor := float(distance_factors.get("aoe", 1.0))
	# SCRUM-902 «Аура дикой силы»: постоянный классовый бафф урона владельца И
	# призывов — множит ВСЕ каналы выхода (в отличие от echo, который не трогает
	# призывы). budget_tuning_for компенсирует кит (см. class_wild_aura_damage_factor).
	var wild_aura_factor := float(class_context.get("wild_aura_factor", 1.0))
	# SCRUM-930 «Дальний расчёт» (distance_*_factor) впаян в объявления; сеть
	# устройств и Ярость домножают ниже — все trait-факторы кита сохранены.
	var solo_dps := ((direct_dps * infected_direct_factor * distance_solo_factor * float(hit_model.get("solo_hits", 1.0)) * float(melee_unique_budget.get("solo", 1.0)) + dot_dps + pool_dps) * action_echo_factor + summon_dps + wave_dps) * wild_aura_factor
	var aoe_dps := ((direct_dps * infected_direct_factor * distance_aoe_factor * float(hit_model.get("five_hits", 1.0)) * float(melee_unique_budget.get("aoe", 1.0)) + dot_dps * float(hit_model.get("dot_targets", 1.0)) + pool_dps * float(hit_model.get("pool_targets", 1.0))) * action_echo_factor + summon_dps * float(hit_model.get("summon_targets", 1.0)) + wave_dps * wave_targets) * wild_aura_factor
	# SCRUM-908 «Сеть мастерской»: ожидаемые стеки устройств усиливают выход
	# оружия-устройства (ульта НЕ устройство — фактор до её добавления).
	var network_factor := _budget_network_factor(config, params, stats, trait_config)
	solo_dps *= network_factor
	aoe_dps *= network_factor

	# SCRUM-1004 «Ярость»: матожидание low-HP бонуса Берсерка (кап 0.40 ×
	# ожидаемое missing_hp 0.30 ⇒ ×1.12) — trait множит ВЕСЬ исходящий урон
	# оружий кита (BerserkWeapon._rolled_damage), поэтому фактор применяется ко
	# всем канальным выходам ДО ульты (ульта не действие оружия — паттерн
	# action_echo); budget_tuning_for компенсирует кит. Другим классам фактор 1.0.
	var rage_factor := float(class_context.get("rage_factor", 1.0))
	solo_dps *= rage_factor
	aoe_dps *= rage_factor
	if include_ultimate:
		var ultimate := _budget_ultimate_dps(class_context.get("ultimate_config", {}), params)
		solo_dps += float(ultimate.get("solo", 0.0))
		aoe_dps += float(ultimate.get("aoe", 0.0))
	if apply_budget:
		solo_dps *= float(config.get("budget_solo_multiplier", 1.0))
		aoe_dps *= float(config.get("budget_aoe_multiplier", 1.0))
	return {
		"solo_dps": snappedf(solo_dps, 0.01),
		"aoe_dps": snappedf(aoe_dps, 0.01),
		"ehp": snappedf(_budget_ehp(config, params), 0.01),
		"interval": snappedf(interval, 0.001),
		"direct_dps": snappedf(direct_dps, 0.01),
		"hit_model": hit_model,
	}


# Formula targets of a class budget profile: BalanceData base DPS × profile
# axis × damage_budget (same expression for tuning and crowd-clear).
static func _budget_targets(profile: Dictionary) -> Dictionary:
	return {
		"solo_target": BALANCE_BASE_SOLO_DPS * float(profile.get("solo_target", 1.0)) * float(profile.get("damage_budget", 1.0)),
		"aoe_target": BALANCE_BASE_AOE_DPS * float(profile.get("aoe_target", 1.0)) * float(profile.get("damage_budget", 1.0)),
	}


# Geometric-mean damage multiplier that pulls the untuned solo/aoe metrics of a
# weapon onto the profile targets, clamped to [0.28, 2.80].
static func tuning_damage_multiplier(profile: Dictionary, base_metrics: Dictionary) -> float:
	var targets := _budget_targets(profile)
	var solo_dps := maxf(float(base_metrics.get("solo_dps", 0.0)), 0.001)
	var aoe_dps := maxf(float(base_metrics.get("aoe_dps", 0.0)), 0.001)
	var solo_scale := float(targets["solo_target"]) / solo_dps
	var aoe_scale := float(targets["aoe_target"]) / aoe_dps
	return clampf(sqrt(solo_scale * aoe_scale), 0.28, 2.80)


# Tuning record of a weapon: `base_metrics` is the untuned estimate,
# `scaled_metrics` the estimate with tuning_damage_multiplier() applied.
static func budget_tuning(profile: Dictionary, base_metrics: Dictionary, scaled_metrics: Dictionary) -> Dictionary:
	var targets := _budget_targets(profile)
	var solo_target := float(targets["solo_target"])
	var aoe_target := float(targets["aoe_target"])
	var solo_dps := maxf(float(base_metrics.get("solo_dps", 0.0)), 0.001)
	var aoe_dps := maxf(float(base_metrics.get("aoe_dps", 0.0)), 0.001)
	var damage_multiplier := tuning_damage_multiplier(profile, base_metrics)
	var scaled_solo := maxf(float(scaled_metrics.get("solo_dps", solo_dps)), 0.001)
	var scaled_aoe := maxf(float(scaled_metrics.get("aoe_dps", aoe_dps)), 0.001)
	return {
		"damage_multiplier": snappedf(damage_multiplier, 0.001),
		"solo_budget_multiplier": snappedf(solo_target / scaled_solo, 0.001),
		"aoe_budget_multiplier": snappedf(aoe_target / scaled_aoe, 0.001),
		"solo_target": snappedf(solo_target, 0.01),
		"aoe_target": snappedf(aoe_target, 0.01),
		"base_solo_dps": snappedf(solo_dps, 0.01),
		"base_aoe_dps": snappedf(aoe_dps, 0.01),
	}


# Crowd-clear metric of a weapon against `target_count` enemies of
# CROWD_CLEAR_ENEMY_HP. `metrics` is the estimate() result for the same
# config/stats and `profile` the class budget profile. Body moved verbatim.
static func crowd_clear_budget(weapon_config: Dictionary, target_count: int, metrics: Dictionary, profile: Dictionary) -> Dictionary:
	var count: int = maxi(target_count, 1)
	var tuning: Dictionary = weapon_config.get("budget_tuning", {})
	var aoe_target := float(tuning.get("aoe_target", float(_budget_targets(profile)["aoe_target"])))
	var crowd_dps := maxf(float(metrics.get("aoe_dps", 0.0)) * _crowd_clear_density_factor(weapon_config, count), 0.001)
	var target_dps := maxf(aoe_target * _crowd_clear_target_factor(weapon_config, count), 0.001)
	var total_hp := CROWD_CLEAR_ENEMY_HP * float(count)
	var cct := total_hp / crowd_dps
	var target_cct := total_hp / target_dps
	return {
		"target_count": count,
		"crowd_dps": snappedf(crowd_dps, 0.01),
		"target_dps": snappedf(target_dps, 0.01),
		"cct": snappedf(cct, 0.01),
		"target_cct": snappedf(target_cct, 0.01),
		"cct_dev": snappedf(cct / maxf(target_cct, 0.001) - 1.0, 0.001),
		"enemy_hp": CROWD_CLEAR_ENEMY_HP,
	}


static func _crowd_clear_density_factor(config: Dictionary, target_count: int) -> float:
	var mode := str(config.get("attack_mode", config.get("attack_shape", "single")))
	var archetype := weapon_archetype(config)
	var count := float(maxi(target_count, 1))
	var factor := 1.0
	if count >= 10.0:
		factor *= 0.96
	if count >= 20.0:
		factor *= 0.94
	match archetype:
		"aoe", "aura":
			factor *= 1.05
		"summon":
			factor *= 0.96
		"beam":
			factor *= 0.98
		"melee":
			factor *= 0.98
	if ["sniper_lockshot", "moon_crossbow", "drain_link"].has(mode):
		factor *= 0.92
	elif ["aoe_projectile", "grenade_fuse", "smoke_bomb", "meteor_shards", "bio_spore_bloom", "engineer_pressure_mines", "dark_mirror_blast"].has(mode):
		factor *= 1.04
	return clampf(factor, 0.82, 1.12)


static func _crowd_clear_target_factor(config: Dictionary, target_count: int) -> float:
	var archetype := weapon_archetype(config)
	var count := float(maxi(target_count, 1))
	var factor := 1.0
	if count >= 20.0 and ["aoe", "aura", "summon"].has(archetype):
		factor = 1.04
	return factor


static func weapon_archetype(weapon_config: Dictionary) -> String:
	if int(weapon_config.get("max_summons", 0)) > 0 or weapon_config.has("summon_damage_multiplier") or str(weapon_config.get("summon_role", "")) != "":
		return "summon"
	var mode := str(weapon_config.get("attack_mode", weapon_config.get("attack_shape", "single")))
	return str(WEAPON_ARCHETYPE_BY_MODE.get(mode, "projectile"))


# SCRUM-930 «Дальний расчёт»: каноническая формула множителя дистанции —
# ЕДИНАЯ точка правды для рантайма (ClassWeapon._class_distance_trait_multiplier),
# budget-модели (_budget_distance_trait_factors) и тестов. В пределах free_range
# ровно ×1.0 (AC: близкая цель получает базовый урон), дальше линейный рост
# per_100 за каждые 100px, жёсткий кап +cap_bonus (с дефолтами Снайпера кап
# ×1.60 достигается на 120 + 0.60/0.10×100 = 720px и держится дальше).
static func distance_trait_multiplier(per_100: float, cap_bonus: float, free_range: float, distance: float) -> float:
	if per_100 <= 0.0:
		return 1.0
	var scaled := maxf(distance - maxf(free_range, 0.0), 0.0) / 100.0 * per_100
	return 1.0 + minf(scaled, maxf(cap_bonus, 0.0))


# Distance multiplier of a class trait entry at one distance (mirror of
# ProgressionData.class_distance_multiplier_at on the passed CLASS_TRAITS entry).
static func _distance_multiplier_at(trait_config: Dictionary, distance: float) -> float:
	return distance_trait_multiplier(
		float(trait_config.get("distance_damage_per_100px", 0.0)),
		float(trait_config.get("distance_damage_cap_bonus", 0.0)),
		float(trait_config.get("distance_damage_free_range", 0.0)),
		distance
	)


# Бюджет-зеркало «Дальнего расчёта»: матожидание множителя по ТИПОВОЙ дистанции
# боя оружия (документированные допущения по attack_mode; budget_tuning_for
# затем компенсирует кит — инвестиция в позиционирование остаётся живой наградой):
#   sniper_lockshot   — винтовка сама берёт САМУЮ ДАЛЬНЮЮ цель: соло-дуэль
#     ~0.75×attack_range (около капа); по толпе часть выхода — ближний
#     самоподрыв у ног (×1.0) → бонус срезается вдвое (доля дальних хитов 0.55);
#   sniper_kill_zone  — снаряд по метке у выбранной цели: типовая зона
#     ~0.55×attack_range, все жертвы в зоне на схожей дистанции;
#   sniper_split_round — круговой веер по БЛИЖНИМ монстрам: типовая цель
#     ~0.60×aoe_radius (радиус разлёта пуль) — почти без бонуса;
#   иное оружие класса с trait'ом — консервативно 0.5×attack_range.
static func _budget_distance_trait_factors(trait_config: Dictionary, config: Dictionary) -> Dictionary:
	if float(trait_config.get("distance_damage_per_100px", 0.0)) <= 0.0:
		return {"solo": 1.0, "aoe": 1.0}
	var attack_range := float(config.get("attack_range", 240.0))
	var aoe_radius := float(config.get("aoe_radius", 120.0))
	match str(config.get("attack_mode", config.get("attack_shape", "single"))):
		"sniper_lockshot":
			var far_mult := _distance_multiplier_at(trait_config, attack_range * 0.75)
			return {"solo": far_mult, "aoe": 1.0 + (far_mult - 1.0) * 0.55}
		"sniper_kill_zone":
			var zone_mult := _distance_multiplier_at(trait_config, attack_range * 0.55)
			return {"solo": zone_mult, "aoe": zone_mult}
		"sniper_split_round":
			var spray_mult := _distance_multiplier_at(trait_config, aoe_radius * 0.60)
			return {"solo": spray_mult, "aoe": spray_mult}
	var default_mult := _distance_multiplier_at(trait_config, attack_range * 0.5)
	return {"solo": default_mult, "aoe": default_mult}


# FAN-1031 3c-final (peer review MAJOR): калибровочная база силы взрыва ворона для бюджет-модели.
# raven_damage_multiplier — per-hit СИЛА (рантайм), не hit-COUNT: держим модель на этой фикс-базе,
# чтобы доводка множителя двигала живой per-hit «сверх бюджета», а не съедалась авто-тюнером bdm.
const RAVEN_BUDGET_REF_MULTIPLIER := 0.85


# FAN-1031 3c-final (peer review MINOR): Σ диминиш-факторов по `count` целям — зеркало рантайм-капа
# `_damage_enemies_in_circle_capped` (ближние `full` полный вес, дальше 1/(1+(rank−full+1)·diminish)).
# Сентинел override <0 → (full_default/diminish_default). Дробный count — линейно на последней цели.
static func _capped_coverage(count: float, full_override: int, diminish_override: float, full_default: int, diminish_default: float) -> float:
	var full := full_override if full_override >= 0 else full_default
	var diminish := diminish_override if diminish_override >= 0.0 else diminish_default
	var total := 0.0
	var whole := int(floor(count))
	for i in range(whole):
		total += 1.0 if i < full else 1.0 / (1.0 + float(i - full + 1) * diminish)
	var frac := count - float(whole)
	if frac > 0.0:
		total += frac * (1.0 if whole < full else 1.0 / (1.0 + float(whole - full + 1) * diminish))
	return total


static func _budget_hit_model(config: Dictionary) -> Dictionary:
	var mode := str(config.get("attack_mode", config.get("attack_shape", "single")))
	var attack_range := float(config.get("attack_range", 240.0))
	var aoe_radius := float(config.get("aoe_radius", 120.0))
	match mode:
		"frustum":
			var outer_width := float(config.get("outer_width", aoe_radius))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + outer_width / 290.0, 1.0, 5.0)}
		"sweep":
			var sweep := float(config.get("sweep_degrees", config.get("cone_degrees", 90.0)))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + (sweep / 45.0) * (attack_range / 320.0), 1.0, 5.0)}
		"circle", "pulse":
			# SCRUM-923: спиральный каст (spiral_steps>0) кроет диск не мгновенно —
			# фронт дуги достигает внешнего кольца только к концу оборота, часть
			# внешних целей остаётся за фронтом (рантайм: BerserkWeapon._run_spiral_step,
			# 1 хит/цель/каст). Документированное среднее покрытие диска за оборот 0.85.
			if float(config.get("spiral_steps", 0.0)) > 0.0:
				return {"solo_hits": 1.0, "five_hits": clampf(1.0 + (aoe_radius / 72.0) * 0.85, 1.0, 5.0)}
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 72.0, 1.0, 5.0)}
		"strip":
			# SCRUM-921: тройной укол (thrust_count>1) — веер полос под ±fan°:
			# покрытие толпы растёт от углового размаха на дистанции. Дедуп
			# рантайма (1 хит/цель/цикл, BerserkWeapon._run_thrust_step) держит
			# solo_hits=1.0 — по одиночной цели цикл стоит столько же, сколько
			# один укол; веер оплачивается aoe-осью тюнинга.
			var strip_five := 1.0 + float(config.get("inner_width", 60.0)) / 160.0
			var thrust_count := float(config.get("thrust_count", 1.0))
			var thrust_fan := float(config.get("thrust_fan_degrees", 0.0))
			if thrust_count > 1.0 and thrust_fan > 0.0:
				strip_five += (attack_range * sin(deg_to_rad(thrust_fan))) / 260.0
				return {"solo_hits": 1.0, "five_hits": clampf(strip_five, 1.0, 3.2)}
			return {"solo_hits": 1.0, "five_hits": clampf(strip_five, 1.0, 2.1)}
		"aoe_projectile":
			var projectile_count := float(config.get("projectile_count", 1.0))
			var blast_hits := clampf(1.0 + aoe_radius / 145.0, 1.0, 3.0)
			# FAN-1031 3c-final (peer review MINOR): зеркалим per-weapon кап прямого AoE-взрыва
			# (S1 aoe_full_targets/aoe_target_diminish) в оценку hits. Без этого для оружий с
			# override (restore_potion F=1/D=4.0) модель считала полный blast_hits, завышая
			# aoe_dps ×1.7 → bdm не отражал живой срез. Сентинел <0 → дефолт (mirror class_weapon
			# AOE_PROJECTILE_* = 5/2.0); при blast_hits ≤ 3 < full=5 diminish не срабатывает →
			# нулевое изменение для всех оружий, кроме тех, у кого full < blast_hits (restore_potion).
			var capped_blast := _capped_coverage(blast_hits, int(config.get("aoe_full_targets", -1)), float(config.get("aoe_target_diminish", -1.0)), 5, 2.0)
			return {"solo_hits": 1.0, "five_hits": clampf(projectile_count * capped_blast, 1.0, 5.0), "pool_targets": clampf(1.0 + aoe_radius / 130.0, 1.0, 4.0)}
		"homing_curse":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 180.0, 1.0, 2.0), "dot_targets": 1.0}
		"dark_chain_burst":
			# SCRUM-939: цепь до chain_targets целей со спадом pierce_damage_falloff
			# по прыжкам; на каждом попадании малый бурст (chain_burst_ratio от
			# урона хита) бьёт СОСЕДЕЙ жертвы (сама жертва исключена). Solo: одна
			# цель = только первый хит, бурсту некого задевать → 1.0.
			var chain_count := clampf(float(config.get("chain_targets", 3.0)), 1.0, 5.0)
			var chain_falloff := clampf(float(config.get("pierce_damage_falloff", 0.82)), 0.1, 1.0)
			var chain_direct := 0.0
			for chain_index in range(int(chain_count)):
				chain_direct += pow(chain_falloff, float(chain_index))
			var burst_ratio := clampf(float(config.get("chain_burst_ratio", 0.45)), 0.0, 1.0)
			var burst_neighbors := clampf(aoe_radius / 95.0, 0.0, 2.0)
			return {"solo_hits": 1.0, "five_hits": clampf(chain_direct + chain_count * burst_ratio * burst_neighbors, 1.0, 5.0)}
		"skull_curse_burn":
			# SCRUM-940: прямого урона нет (curse_only гасит direct_dps выше);
			# solo = 1 проклятая цель, в толпе зона курсит несколько целей разом.
			return {"solo_hits": 1.0, "five_hits": 1.0, "dot_targets": clampf(1.0 + aoe_radius / 110.0, 1.0, 4.0)}
		"dark_mirror_blast":
			# SCRUM-941: пара взрывов. Первичный кроет кластер у цели; зеркальный
			# в среднем добавляет mirror-долю покрытия (в кластерном 5t-сценарии
			# зеркало чаще бьёт по краю/пустоте — коэффициент 0.45 покрытия).
			var mirror_ratio := maxf(float(config.get("mirror_damage_ratio", 1.0)), 0.0)
			var primary_blast := clampf(1.0 + aoe_radius / 145.0, 1.0, 3.0)
			return {"solo_hits": 1.0, "five_hits": clampf(primary_blast * (1.0 + mirror_ratio * 0.45), 1.0, 5.0), "pool_targets": clampf(1.0 + aoe_radius / 130.0, 1.0, 4.0)}
		"beam":
			var beam_count := float(config.get("beam_count", 1.0))
			var pierce := float(config.get("pierce_count", 1.0))
			return {"solo_hits": clampf(beam_count, 1.0, 2.0), "five_hits": clampf(beam_count * pierce, 1.0, 5.0)}
		"moon_split_shot":
			# SCRUM-910: болт бьёт первичную цель + расщепляется в до split_count
			# РАЗНЫХ соседей с тем же уроном. Соло — ровно 1 хит (веткам нужны
			# соседи), 5-пак — первичная + все ветки (без повторных хитов).
			var moon_splits := clampf(float(config.get("split_count", 4.0)), 0.0, 4.0)
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + moon_splits, 1.0, 5.0)}
		"storm_pierce_cone":
			# SCRUM-911: конус пробивающих стрел. Соло — один хит (дедуп на весь
			# залп: цель у вершины не собирает несколько стрел). Толпа — покрытие
			# раствором конуса на дальней дистанции (модель sweep) + пирс вглубь.
			var storm_cone := float(config.get("cone_degrees", 34.0))
			var cone_range := float(config.get("attack_range", 900.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + (storm_cone / 45.0) * (cone_range / 320.0), 1.0, 5.0)}
		"sound_wave":
			var wave_width := float(config.get("wave_width", 180.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + wave_width / 78.0, 1.0, 5.0)}
		"riff_strip":
			# SCRUM-899: узкая передняя полоса Гитариста — ПОСТОЯННАЯ полная
			# ширина wave_width на всю attack_range (в отличие от расширяющейся
			# sound_wave). В кластере из 5 ловит ~2 цели: узость — цена частых
			# хитов, позиционирование корпусом обязательное.
			var strip_width := float(config.get("wave_width", 118.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + strip_width / 105.0 + attack_range / 2600.0, 1.0, 2.6)}
		"amp":
			# SCRUM-903 raven_homing: тотемы пускают самонаводящихся воронов раз в
			# amp_pulse_interval каждый; взрыв кроет explosion_targets целей
			# (зеркало _launch_totem_raven/_resolve_raven_impact: полный урон
			# первым 3, дальше диминиш). Одновременные тотемы ограничены
			# lifetime/deploy-темпом и жёстким капом (Leadership-скейл лимита
			# сверх — рантайм-бонус, как у прочих лимитов вне модели).
			if bool(config.get("raven_homing", false)):
				var deploy_interval := maxf(float(config.get("fire_interval", 2.35)), 0.25)
				var raven_pulse := maxf(float(config.get("amp_pulse_interval", 1.1)), 0.2)
				var raven_lifetime := maxf(float(config.get("amp_lifetime", 8.0)), deploy_interval)
				var totems := minf(raven_lifetime / deploy_interval, maxf(float(config.get("max_summons_cap", 6.0)), 1.0))
				# FAN-1031 3c-final fix (peer review MAJOR): raven_damage_multiplier — это per-hit
				# СИЛА взрыва (рантайм _resolve_raven_impact: _rolled_damage × множитель), НЕ hit-COUNT.
				# Раньше она зеркалилась в hits → авто-тюнер (bdm) компенсировал ×1.59-буст оживления
				# вдвое (bdm 1.671→1.235, live per-hit +17% вместо +59%). Модель нормирует по СТРУКТУРНОМУ
				# числу воронов (rate × totems) при ФИКСИРОВАННОЙ калибровочной силе взрыва
				# RAVEN_BUDGET_REF_MULTIPLIER, поэтому доводка raven_damage_multiplier двигает живой
				# per-hit «сверх бюджета» напрямую (как summon-множители у pure_summon) и НЕ сдвигает bdm.
				var ravens_per_deploy := (deploy_interval / raven_pulse) * totems * RAVEN_BUDGET_REF_MULTIPLIER
				var explosion_targets := clampf(1.0 + float(config.get("raven_explosion_radius", 120.0)) / 145.0, 1.0, 3.0)
				return {"solo_hits": clampf(ravens_per_deploy, 1.0, 8.0), "five_hits": clampf(ravens_per_deploy * explosion_targets, 1.0, 16.0)}
			var active_ratio := float(config.get("amp_lifetime", 6.0)) / maxf(float(config.get("fire_interval", 2.0)), 0.25)
			return {"solo_hits": clampf(active_ratio / 4.0, 1.0, 2.0), "five_hits": clampf((1.0 + aoe_radius / 80.0) * active_ratio / 3.5, 1.0, 5.0)}
		"boomerang":
			# SCRUM-894: возврат идёт ЛЕВОЙ дугой, а не тем же коридором — соло-цель
			# на прямой получает гарантированно 1 проход, двойной проход требует
			# позиционирования (у разворота/у героя). Бюджетное матожидание 1.6
			# (позиционная средняя), навык двойного прохода — награда сверх бюджета.
			return {"solo_hits": 1.6, "five_hits": clampf(1.6 + float(config.get("beam_width", 48.0)) / 34.0, 1.6, 3.4)}
		"stab_flurry":
			var targets := float(config.get("projectile_count", 1.0))
			return {"solo_hits": 1.0, "five_hits": clampf(targets, 1.0, 4.0), "dot_targets": clampf(targets, 1.0, 4.0)}
		"saw_sector":
			# SCRUM-900 bone_saw: melee-сектор 120-150° — покрытие толпы растёт от
			# ширины дуги и дистанции; диминиш по целям учтён sector_full_targets.
			var cone := float(config.get("cone_degrees", 130.0))
			var full_targets := float(config.get("sector_full_targets", 4.0))
			var sector_hits := clampf(1.0 + (cone / 52.0) * (attack_range / 300.0), 1.0, minf(full_targets + 0.6, 5.0))
			return {"solo_hits": 1.0, "five_hits": sector_hits}
		"plague_dart":
			# SCRUM-900 plague_syringe: прямой дротик бьёт одну цель; ценность в
			# толпе — распространение заразы (dot_targets = ожидаемое число
			# одновременно заражённых из 5-пака при spread-шансе за тик).
			var spread_chance := clampf(float(config.get("plague_spread_chance", 0.0)), 0.0, 1.0)
			var infected := clampf(1.0 + spread_chance * 10.0, 1.0, minf(float(config.get("plague_max_infected", 5.0)), 4.4))
			return {"solo_hits": 1.0, "five_hits": 1.0, "dot_targets": infected}
		"dot_beam":
			var pierce := float(config.get("pierce_count", 1.0))
			return {"solo_hits": 1.0, "five_hits": clampf(pierce, 1.0, 5.0), "dot_targets": clampf(pierce, 1.0, 5.0)}
		"drain_link":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + float(config.get("beam_width", 40.0)) / 120.0, 1.0, 1.6), "dot_targets": 1.0}
		"trap":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 85.0, 1.0, 4.2)}
		"arquebus_shot":
			# SCRUM-936: одна взрывная пуля — полный урон цели + малый AoE соседям
			# с falloff (модель как aoe_projectile при projectile_count=1).
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 145.0, 1.0, 3.0)}
		"grenade_fuse":
			# SCRUM-937: медленный снаряд + фитиль; вся ценность — тяжёлый AoE-взрыв.
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 72.0, 1.0, 5.0)}
		"bayonet_cone":
			# SCRUM-938: ближний конус + редкий авто-выстрел (chance*mult добавкой к
			# обеим осям — пуля бьёт одну цель за конусом).
			var cone := float(config.get("cone_degrees", 100.0))
			var shot_bonus := clampf(float(config.get("bayonet_auto_shot_chance", 0.0)), 0.0, 1.0) * float(config.get("bayonet_shot_damage_multiplier", 0.7))
			var cone_hits := 1.0 + (cone / 110.0) * (attack_range / 260.0) * 1.9
			return {"solo_hits": 1.0 + shot_bonus, "five_hits": clampf(cone_hits + shot_bonus, 1.0, 4.4)}
		"coin_ricochet":
			# SCRUM-897 «Кошель Рикошета»: цепь = projectile_count прыжков (рантайм
			# капит COIN_CHAIN_HARD_CAP=8 в class_weapon.gd), урон убывает монотонно
			# до damage_falloff-доли (0.5) на ПОСЛЕДНЕМ прыжке: hit_i = tail^(i/(n-1)).
			# Толпа из 5 = сумма долей первых 5 звеньев цепи (зеркало _fire_coin_ricochet).
			var chain_count := clampf(float(config.get("projectile_count", 3.0)), 1.0, 8.0)
			var chain_tail := clampf(float(config.get("damage_falloff", 0.5)), 0.1, 1.0)
			var chain_crowd := 0.0
			for chain_index in range(mini(int(chain_count), 5)):
				chain_crowd += pow(chain_tail, float(chain_index) / maxf(chain_count - 1.0, 1.0))
			return {"solo_hits": 1.0, "five_hits": clampf(chain_crowd, 1.0, 5.0)}
		"shadow_backstab":
			# SCRUM-897 «Отравленный Кинжал»: фантом бьёт 1.22 ролла; удар в спину
			# (цель смотрит прочь от фантома — чейзеры, uptime ~0.75) даёт ×1.35
			# (BACKSTAB_* в class_weapon.gd) → соло ≈ 1.22×(1+0.35×0.75) = 1.54.
			# Соседи у точки удара получают 0.35 ролла (aoe/150 ≈ 2.7 соседа × 0.35).
			var backstab_solo := 1.22 * (1.0 + 0.35 * 0.75)
			return {"solo_hits": backstab_solo, "five_hits": clampf(backstab_solo + aoe_radius / 150.0, backstab_solo, 3.4)}
		"smoke_bomb":
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + aoe_radius / 84.0, 1.0, 4.4)}
		"elemental_orbit":
			# SCRUM-948: квадрат четырёх стихий. Соло за каст = полный ролл магии
			# + физ.доля SQUARE_PHYSICAL_SHARE (0.45 × канал damage ≈ +11% на
			# базе Элементалиста, см. class_weapon.gd), периодика — dot_ticks
			# (отдельная ось _budget_dot_dps). Толпа — по площади квадрата.
			return {"solo_hits": 1.11, "five_hits": clampf(1.0 + aoe_radius / 60.0, 1.0, 5.0), "dot_targets": clampf(1.0 + aoe_radius / 90.0, 1.0, 4.0)}
		"prism_rift":
			# SCRUM-949: полнокартный X. Соло у фокуса = луч (0.72) + центр (0.55)
			# = 1.27 ролла; толпа — пирс двух диагоналей через всю арену + центр
			# (доли PRISM_* в class_weapon.gd).
			var prism_width := float(config.get("beam_width", 58.0))
			return {"solo_hits": 1.27, "five_hits": clampf(2.5 + prism_width / 45.0, 2.5, 5.0)}
		"meteor_shards":
			# SCRUM-950: одиночный тяжёлый нюк (веер осколков удалён). Соло =
			# полный центр; толпа — большой AoE с falloff (×0.78 средняя доля);
			# догорающая зона — dot_ticks по dot-оси со спадом по рангу
			# (METEOR_ZONE_* в class_weapon.gd → dot_targets ≈ 3 на 5 целях).
			return {"solo_hits": 1.0, "five_hits": clampf((1.0 + aoe_radius / 95.0) * 0.78, 1.0, 5.0), "dot_targets": 3.0}
		"sniper_lockshot":
			# SCRUM-931 (preferred-вариант): тяжёлый хит ×1.34 по САМОЙ ДАЛЬНЕЙ
			# цели + терминальный взрыв на конце (DEADEYE_ENDPOINT_BLAST_RATIO
			# 0.35, цель в центре ловит полную долю) → соло 1.69. Толпа: соло +
			# overpen-коридор (damage_falloff-доля ~1 попутчику) + сосед взрыва
			# (×0.7 средний falloff) + ближний самоподрыв close_burst_ratio от
			# хита винтовки по врагам у ног (зеркало _fire_sniper_lockshot).
			var endpoint_ratio := 0.35
			var lockshot_solo := 1.34 * (1.0 + endpoint_ratio / 1.34)
			var close_targets := clampf(float(config.get("close_burst_radius", 150.0)) / 95.0, 1.0, 2.2)
			var close_share := clampf(float(config.get("close_burst_ratio", 0.8)), 0.0, 1.5) * 1.34 * close_targets
			return {"solo_hits": lockshot_solo, "five_hits": clampf(lockshot_solo + float(config.get("damage_falloff", 0.38)) + endpoint_ratio * 0.7 + close_share, lockshot_solo, 4.6)}
		"sniper_kill_zone":
			# SCRUM-932: отложенный артиллерийский снаряд по красной метке —
			# ОДИН тяжёлый AoE через grenade_delay (~1с), серия прицельных
			# ударов удалена. Соло: полный ролл в центре зоны. Толпа: по площади
			# зоны с усреднённой falloff-долей 0.85 (зеркало
			# _damage_enemies_in_circle_falloff в _land_spotter_shell).
			return {"solo_hits": 1.0, "five_hits": clampf((1.0 + aoe_radius / 85.0) * 0.85, 1.0, 4.6)}
		"sniper_split_round":
			# SCRUM-933: скорострельный круговой веер пуль по ближним монстрам
			# (сплит-чейн удалён). Соло: одна цель ловит не больше
			# SHATTER_VOLLEY_HIT_LIMIT (2) пуль за залп (анти-runaway кап,
			# зеркало _fire_sniper_split_round). Толпа: почти все пули находят
			# цель round-robin'ом (эффективность прицеливания 0.92); пули без
			# цели уходят радиально и урона не наносят.
			var spray_bullets := float(config.get("projectile_count", 6.0))
			return {"solo_hits": minf(spray_bullets, 2.0), "five_hits": clampf(spray_bullets * 0.92, 1.0, 5.2)}
		"priest_sanctify":
			# SCRUM-927: бурст «тик-тик-тик» — серия storm_ticks вспышек по
			# sanctify_tick_ratio ролла каждая; соло-цель ловит ВСЕ тики (знак
			# ведёт цель), толпа — по малому радиусу с falloff (зеркало
			# class_weapon._sanctify_burst_tick). Лечения у оружия нет.
			var sanctify_ticks := maxf(float(config.get("storm_ticks", 3.0)), 1.0)
			var sanctify_ratio := clampf(float(config.get("sanctify_tick_ratio", 0.38)), 0.05, 1.0)
			var sanctify_total := sanctify_ticks * sanctify_ratio
			return {"solo_hits": clampf(sanctify_total, 0.5, 2.4), "five_hits": clampf(sanctify_total * (1.0 + aoe_radius / 145.0), 1.0, 4.8)}
		"priest_ward":
			# SCRUM-928: редкие тяжёлые волны вокруг Священника, последняя —
			# ПОЛНЫЙ aoe_radius (радиусный AoE-специалист с медленной каденцией;
			# зеркало lerp(0.80,1.0) в class_weapon._fire_priest_ward — соло-цель
			# вплотную ловит обе волны, 0.85-дисконт за раскрытие радиуса).
			var ward_ticks := float(config.get("storm_ticks", 2.0))
			return {"solo_hits": clampf(ward_ticks * 0.85, 1.0, 2.6), "five_hits": clampf(1.0 + aoe_radius / 70.0, 1.0, 4.5)}
		"priest_dual_toll":
			# SCRUM-929: dual toll — два одновременных взрыва (у цели и у Жреца)
			# с общим дедупом (враг ≤ 1 взрыв за каст) → соло ровно 1 полный хит.
			# Толпа: покрытие цели (1 + aoe/95 с запасом на второй центр у Жреца,
			# ~0.55 средней добавки — часть толпы прессует героя), кап 4.4.
			return {"solo_hits": 1.0, "five_hits": clampf(1.55 + aoe_radius / 105.0, 1.0, 4.4)}
		"bio_spore_bloom":
			# SCRUM-896: три расширяющихся кольца у персонажа — соло-цель ловит
			# все кольца с falloff (1+0.7+0.49≈2.19 → сохранена 0.34-модель),
			# толпа — по радиусу; биоинфекция вешается на ВСЕХ задетых
			# (dot_targets), зеркало class_weapon._bio_spore_pulse.
			var bloom_ticks := float(config.get("storm_ticks", 3.0))
			return {"solo_hits": clampf(1.0 + bloom_ticks * 0.34, 1.0, 2.4), "five_hits": clampf(1.0 + aoe_radius / 58.0, 1.0, 5.0), "dot_targets": clampf(1.0 + aoe_radius / 85.0, 1.0, 4.0)}
		"bio_sample_dart":
			# SCRUM-896: пирсинг-луч на всю длину (полный ролл каждому на линии)
			# + малый бурст анализа на конце (tip_burst_ratio) + физ.доля
			# INJECTOR_PHYSICAL_SHARE канала damage на каждый хит луча: базовый
			# факт-фактор 1.13 = 1 + 0.5×(damage/magic на базе Биолога 3/11.2),
			# зеркало class_weapon._fire_bio_sample_dart. Инфекция — только
			# ближайший на луче (dot_targets 1).
			var tip_ratio := clampf(float(config.get("tip_burst_ratio", 0.55)), 0.0, 1.0)
			var line_hits := clampf(1.0 + (attack_range / 420.0) * (float(config.get("beam_width", 46.0)) / 60.0), 1.0, 3.2)
			var injector_phys_factor := 1.13
			return {"solo_hits": (1.0 + tip_ratio) * injector_phys_factor, "five_hits": clampf((line_hits + tip_ratio * clampf(aoe_radius / 145.0, 0.0, 2.0)) * injector_phys_factor, 1.0, 4.8), "dot_targets": 1.0}
		"bio_symbiote_web":
			# SCRUM-896: семя-зона с прорастанием — стартовый маг.хит
			# seed_impact_ratio с falloff по области, главный пейофф в
			# биоинфекции всех задетых (dot-ось), зеркало
			# class_weapon._germinate_symbiote_seed.
			var impact_ratio := clampf(float(config.get("seed_impact_ratio", 0.85)), 0.0, 1.5)
			return {"solo_hits": impact_ratio, "five_hits": clampf(impact_ratio * (1.0 + aoe_radius / 110.0), 0.5, 4.0), "dot_targets": clampf(1.0 + aoe_radius / 95.0, 1.0, 4.0)}
		"robot_magnetic_anchor":
			# SCRUM-915: тяжёлый AoE-пулл — рядовые стягиваются к центру зоны
			# (конвергенция 0.85, ClassWeapon._pull_enemies_toward), поэтому
			# следующие касты бьют сгруппированную толпу ближе к falloff-центру:
			# группировка учтена мягким бонусом плотности +12% к толпе. Элитки/
			# боссы не смещаются (контроль-ось, в DPS-модель не входит).
			return {"solo_hits": 1.0, "five_hits": clampf((1.0 + aoe_radius / 80.0) * 1.12, 1.0, 4.8)}
		"robot_compression_line":
			# SCRUM-916: урон по ВСЕЙ ширине коридора suppression_width
			# (зеркало _fire_robot_compression_line: width_override), компрессия
			# к оси — контроль-ось. Толпа — от полной ширины коридора.
			var compression_width := float(config.get("suppression_width", 220.0))
			return {"solo_hits": 1.0, "five_hits": clampf(1.0 + compression_width / 82.0, 1.0, 4.6)}
		"robot_reactor_vent":
			# SCRUM-918: вращающийся веер — ровно 4 фикс-вентиля (без
			# самонаведения), пер-вентильный урон = ролл × vent_ratio (зеркало
			# ClassWeapon.REACTOR_VENT_DAMAGE_RATIO). Соло: identity ближнего
			# контроля — чейзер на контактной дистанции покрыт лопастью
			# (coverage ~1.0) => один вентиль за каст = vent_ratio ролла; толпа —
			# прежняя форма «вентили + площадь», масштабированная vent_ratio.
			var vent_count := float(config.get("projectile_count", 4.0))
			var vent_ratio := 0.42
			return {"solo_hits": vent_ratio, "five_hits": clampf((1.0 + vent_count * 0.70 + aoe_radius / 150.0) * vent_ratio, 0.5, 5.0)}
		"engineer_sentry_link":
			# SCRUM-888: турели. Прямой компонент — мгновенный первый выстрел при
			# развёртке (1 цель); сустейн стрельбы турелей считает _budget_summon_dps
			# (max_summons × damage × summon_damage_multiplier / summon_attack_interval).
			# Толпу добирают: залп по РАЗНЫМ ближайшим целям (projectile_count со
			# спадом damage_falloff^i; одиночная цель получает только 1-й снаряд —
			# соло-ось не греется) и сплэш снаряда (cap целей со спадом 1/(1+0.75i))
			# — зеркала sentry_turret.try_fire и _damage_engineer_sentry_splash.
			var sentry_splash_bonus := 0.0
			if float(config.get("sentry_splash_radius", 0.0)) > 0.0:
				var sentry_splash_cap := maxi(int(config.get("sentry_splash_target_cap", 0)), 0)
				var sentry_splash_mult := maxf(float(config.get("sentry_splash_damage_multiplier", 0.0)), 0.0)
				for sentry_splash_index in range(sentry_splash_cap):
					sentry_splash_bonus += sentry_splash_mult / (1.0 + float(sentry_splash_index) * 0.75)
			var sentry_volley := maxi(int(config.get("projectile_count", 1)), 1)
			var sentry_volley_falloff := clampf(float(config.get("damage_falloff", 0.55)), 0.05, 1.0)
			var sentry_volley_crowd := 1.0
			for sentry_volley_index in range(1, sentry_volley):
				sentry_volley_crowd += pow(sentry_volley_falloff, float(sentry_volley_index))
			var sentry_crowd_factor := sentry_volley_crowd * (1.0 + sentry_splash_bonus)
			return {"solo_hits": 1.0, "five_hits": sentry_crowd_factor, "summon_targets": sentry_crowd_factor}
		"engineer_orbit_drone":
			# SCRUM-906: прямого канала нет (direct_dps = 0); crowd-фактор
			# контакта пишет _budget_orbit_drone_dps в summon_targets.
			return {"solo_hits": 1.0, "five_hits": 1.0}
		"engineer_pressure_mines":
			var mine_count := float(config.get("projectile_count", 3.0))
			return {"solo_hits": 1.0, "five_hits": clampf(mine_count * (1.0 + aoe_radius / 170.0), 1.0, 5.0)}
		_:
			if int(config.get("max_summons", 0)) > 0:
				return {"solo_hits": 1.0, "five_hits": clampf(1.0 + float(config.get("max_summons", 1)) * 0.8, 1.0, 3.5), "summon_targets": clampf(float(config.get("max_summons", 1)), 1.0, 4.0)}
	return {"solo_hits": 1.0, "five_hits": 1.0}


static func _budget_melee_unique_bonus(config: Dictionary) -> Dictionary:
	var solo_bonus := 1.0
	var aoe_bonus := 1.0
	var close_multiplier := float(config.get("melee_close_damage_multiplier", 1.0))
	if float(config.get("melee_close_bonus_radius", 0.0)) > 0.0 and close_multiplier > 1.0:
		var close_uptime := 0.58 if weapon_archetype(config) == "melee" else 0.34
		solo_bonus += (close_multiplier - 1.0) * close_uptime
		aoe_bonus += (close_multiplier - 1.0) * close_uptime
	var execute_multiplier := float(config.get("melee_execute_multiplier", 1.0))
	var execute_threshold := float(config.get("melee_execute_threshold", 0.0))
	if execute_threshold > 0.0 and execute_multiplier > 1.0:
		var execute_uptime := clampf(execute_threshold, 0.0, 0.55) * 0.72
		solo_bonus += (execute_multiplier - 1.0) * execute_uptime
		aoe_bonus += (execute_multiplier - 1.0) * execute_uptime
	var followup_radius := float(config.get("melee_arc_followup_radius", 0.0))
	var followup_multiplier := float(config.get("melee_arc_followup_multiplier", 0.0))
	if followup_radius > 0.0 and followup_multiplier > 0.0:
		var followup_targets := clampf(followup_radius / 115.0, 0.45, 2.4)
		aoe_bonus += followup_multiplier * followup_targets
	return {"solo": solo_bonus, "aoe": aoe_bonus}


# SCRUM-900: старт ramp-фактора чумного тика (первые тики слабее — «давление
# по карте», а не мгновенный бурст; растёт до 1.0 за plague_ramp_ticks).
const PLAGUE_RAMP_START := 0.45


# SCRUM-900: единый профиль чумного DoT — источник истины и для рантайма
# (ClassWeapon._apply_plague_infection), и для budget-модели (_budget_dot_dps),
# чтобы тюнинг-гейт считал ту же чуму, что тикает в бою.
# Скейл: тик = magic_damage × plague_tick_ratio + dot_damage × plague_dot_coupling;
# интервал тика ускоряется статом dot_speed; длительность фиксирована конфигом.
static func plague_tick_profile(config: Dictionary, params: Dictionary) -> Dictionary:
	var magic := float(params.get("magic_damage", params.get("damage", 1.0)))
	var dot_damage := float(params.get("dot_damage", 1.0))
	var dot_speed := maxf(float(params.get("dot_speed", 1.0)), 0.2)
	var tick_interval := maxf(float(config.get("plague_tick_interval", 2.0)) / dot_speed, 0.45)
	var duration := maxf(float(config.get("plague_duration", 24.0)), tick_interval)
	var ticks := maxi(int(floor(duration / tick_interval)), 1)
	var ramp_ticks := maxi(int(config.get("plague_ramp_ticks", 5)), 1)
	var tick_damage := magic * float(config.get("plague_tick_ratio", 0.22)) \
		+ dot_damage * float(config.get("plague_dot_coupling", 0.6))
	var ramp_sum := 0.0
	for tick_index in range(ticks):
		ramp_sum += plague_ramp_factor(tick_index, ramp_ticks)
	return {
		"tick_damage": tick_damage,
		"tick_interval": tick_interval,
		"ticks": ticks,
		"ramp_average": ramp_sum / float(ticks),
	}


static func plague_ramp_factor(tick_index: int, ramp_ticks: int) -> float:
	var progress := clampf(float(tick_index) / float(maxi(ramp_ticks, 1)), 0.0, 1.0)
	return lerpf(PLAGUE_RAMP_START, 1.0, progress)


static func _budget_dot_dps(config: Dictionary, params: Dictionary, interval: float, stats: Dictionary, periodic_mult: float) -> float:
	# SCRUM-900 plague_dart: длинная зараза (24с) с рефрешем при повторном
	# попадании ⇒ на одиночной цели устойчивый DoT-поток, независимый от
	# fire_interval (перезаражение лишь поддерживает 100% uptime).
	if str(config.get("attack_mode", "")) == "plague_dart":
		var profile := plague_tick_profile(config, params)
		return float(profile.get("tick_damage", 0.0)) * float(profile.get("ramp_average", 1.0)) \
			/ maxf(float(profile.get("tick_interval", 1.0)), 0.18) \
			* periodic_mult
	var ticks := float(config.get("dot_ticks", 0.0))
	if ticks <= 0.0:
		return 0.0
	# SCRUM-940: документированный curse-пайплайн черепа — сила тика =
	# dot_damage * curse_tick_multiplier * (1 + Интеллект * curse_int_scale);
	# зеркалит class_weapon._apply_skull_curse_zone. Для прочих оружий
	# multiplier=1.0 / int_scale=0.0 — формула тождественна прежней.
	var tick_multiplier := maxf(float(config.get("curse_tick_multiplier", 1.0)), 0.0)
	# SCRUM-896: биоинфекции — status-based с refresh (1 стак): перекаст НЕ
	# мультиплицирует тики, поэтому устоявшийся DPS = тик × каденция
	# (dot_speed × curse_tick_rate; интервал ≥0.1с — кламп StatusEffects.tick),
	# а НЕ ticks/каст. Ось скейлится dot_damage/dot_speed (Знание/Энергия), не
	# скоростью атаки; длительность (dot_ticks+0.99)×интервал перекрывает
	# интервал каста — uptime в затяжном бою ≈1. Зеркало —
	# class_weapon._apply_bio_infection (рантайм применяет статус через
	# StatusEffects.apply_status_from — классовый периодический множитель
	# SCRUM-942 запекается там же; у Биолога он 1.0).
	if str(config.get("attack_mode", "")).begins_with("bio_"):
		var bio_rate := maxf(float(config.get("curse_tick_rate", 1.0)), 0.2)
		var bio_interval := maxf(1.0 / (maxf(float(params.get("dot_speed", 1.0)), 0.2) * bio_rate), 0.1)
		return float(params.get("dot_damage", 1.0)) * tick_multiplier / bio_interval \
			* periodic_mult
	var stats_map: Dictionary = stats if stats is Dictionary else {}
	var curse_depth := 1.0 + maxf(float(stats_map.get("intelligence", 0.0)), 0.0) * maxf(float(config.get("curse_int_scale", 0.0)), 0.0)
	# SCRUM-942: DoT-тики — периодический канал, множится классовым trait'ом
	# (у классов без trait'а множитель 1.0 — формула тождественна прежней).
	return float(params.get("dot_damage", 1.0)) * tick_multiplier * curse_depth * ticks / maxf(interval, 0.18) \
		* periodic_mult


static func _budget_pool_dps(config: Dictionary, params: Dictionary, interval: float, periodic_mult: float) -> float:
	if not bool(config.get("leaves_pool", false)):
		return 0.0
	# SCRUM-903: терновая зона Друида — повторные ФИЗИЧЕСКИЕ хиты с капом на
	# врага/зону (зеркало class_weapon._briar_zone_tick): хит = damage-параметр
	# оружия × briar_hit_multiplier, хитов на врага с одной зоны =
	# min(briar_hit_cap, duration/tick). Периодик-множители НЕ применяются —
	# это не dot-ось (dot_damage в терновом канале не участвует).
	if bool(config.get("briar_zone", false)):
		var briar_tick := maxf(float(config.get("pool_tick_interval", 0.6)), 0.18)
		var briar_hits := minf(float(config.get("briar_hit_cap", 5)), floor(maxf(float(config.get("pool_duration", 3.0)), briar_tick) / briar_tick))
		var briar_hit_damage := float(params.get(str(config.get("damage_parameter", "damage")), params.get("damage", 1.0))) * maxf(float(config.get("briar_hit_multiplier", 0.34)), 0.0)
		return briar_hit_damage * briar_hits / maxf(interval, 0.18)
	var tick_interval := maxf(float(config.get("pool_tick_interval", 0.6)), 0.18)
	var uptime := minf(float(config.get("pool_duration", 3.0)) / maxf(interval, 0.18), 1.0)
	# SCRUM-944: per-weapon скалер тика лужи (зеркало ClassWeapon._spawn_damage_pool).
	var tick_scale := maxf(float(config.get("pool_tick_damage_multiplier", 1.0)), 0.0)
	# SCRUM-942: тики лужи — периодический канал, множится классовым trait'ом.
	var pool_dps := float(params.get("dot_damage", 1.0)) * tick_scale / tick_interval * uptime * periodic_mult
	return pool_dps + _budget_pool_charge_dps(config, params, periodic_mult)


# SCRUM-944: бюджет перманентных контактных зарядов лужи (кислотная колба).
# Зеркалит ClassWeapon._apply_pool_contact_statuses: враг копит по одному вечному
# DoT-заряду с каждой РАЗНОЙ лужи (кап pool_charge_cap), тик = dot_damage ×
# pool_charge_tick_multiplier / pool_charge_tick_interval. Ramp-фактор 0.5 —
# заряды набираются по мере прохода луж, к концу бюджет-окна выходят на кап.
static func _budget_pool_charge_dps(config: Dictionary, params: Dictionary, periodic_mult: float) -> float:
	if not bool(config.get("pool_contact_charges", false)):
		return 0.0
	var cap := maxf(float(config.get("pool_charge_cap", 5.0)), 1.0)
	var tick_multiplier := maxf(float(config.get("pool_charge_tick_multiplier", 0.30)), 0.0)
	var tick_interval := maxf(float(config.get("pool_charge_tick_interval", 0.9)), 0.18)
	const CHARGE_RAMP_FACTOR := 0.5
	return float(params.get("dot_damage", 1.0)) * tick_multiplier * cap * CHARGE_RAMP_FACTOR / tick_interval * periodic_mult


# SCRUM-946: бюджет волн гомункула-кастера (пара «танк+кастер»). Зеркалит
# summoner_weapon._update_homunculus_pair: неуязвимый кастер каждые
# summon_wave_interval вешает вечный DoT-заряд (кап summon_wave_stack_cap),
# тик = dot_damage × summon_wave_dot_multiplier / summon_wave_dot_interval.
# Ramp-фактор 0.5 — стаки волн копятся к капу за первые ~cap×interval секунд окна.
static func _budget_summon_wave_dps(config: Dictionary, params: Dictionary, periodic_mult: float) -> float:
	if float(config.get("summon_wave_interval", 0.0)) <= 0.0:
		return 0.0
	var cap := maxf(float(config.get("summon_wave_stack_cap", 4.0)), 1.0)
	var tick_multiplier := maxf(float(config.get("summon_wave_dot_multiplier", 0.35)), 0.0)
	var tick_interval := maxf(float(config.get("summon_wave_dot_interval", 1.0)), 0.18)
	const WAVE_RAMP_FACTOR := 0.5
	return float(params.get("dot_damage", 1.0)) * tick_multiplier * cap * WAVE_RAMP_FACTOR / tick_interval \
		* periodic_mult


static func _budget_summon_dps(config: Dictionary, params: Dictionary, stats := {}) -> float:
	if int(config.get("max_summons", 0)) <= 0 and not config.has("summon_damage_multiplier"):
		return 0.0
	# SCRUM-903: выход вороньего тотема ЦЕЛИКОМ смоделирован amp-веткой
	# _budget_hit_model (raven_homing) — фантомный summon-канал от max_summons
	# создал бы двойной счёт одного и того же урона.
	if bool(config.get("raven_homing", false)):
		return 0.0
	var summon_count: float = maxf(float(config.get("max_summons", 1.0)), 1.0) + floor(float(params.get("summon_amount", 0.0)) / 4.0)
	var summon_amount := float(params.get("summon_amount", 0.0))
	var leadership := float(stats.get("leadership", summon_amount)) if stats is Dictionary else summon_amount
	var attack_interval := maxf(float(config.get("summon_attack_interval", 0.45)) / (1.0 + minf(summon_amount * 0.014 + leadership * 0.006, 0.30)), 0.18)
	var role_factor := _budget_summon_role_damage_factor(config, params, stats)
	# SCRUM-902: ростер-оружие (амулет Друида) — базовый стат КОМПОЗИЦИОННО
	# взвешен по семьям ростера: physical-звери растут от damage (Сила),
	# magic-духи — от magic_damage (Интеллект). Зеркалит summoner_weapon
	# ._summon_profile (family_parameter per запись; дальние духи бьют реже, но
	# тяжелее — per-body DPS равен melee, отдельная модель темпа не нужна).
	var base_stat := float(params.get(str(config.get("damage_parameter", "damage")), params.get("damage", 1.0)))
	var roster: Array = config.get("summon_roster", [])
	if not roster.is_empty():
		var weighted := 0.0
		for entry_raw in roster:
			var entry: Dictionary = entry_raw if entry_raw is Dictionary else {}
			var family_parameter := "magic_damage" if str(entry.get("family", "")) == "magic" else "damage"
			weighted += float(params.get(family_parameter, params.get("damage", 1.0)))
		base_stat = weighted / float(roster.size())
	var summon_damage := base_stat * float(config.get("summon_damage_multiplier", 0.36)) * role_factor
	return summon_count * summon_damage / attack_interval


# SCRUM-905: пропускная способность турелей с боезапасом — зеркало
# scripts/sentry_turret.gd + class_weapon._engineer_turret_limit 1:1.
# Спрос парка = capacity выстрелов раз в effective-pulse (pulse / tempo-lift /
# attack_speed, пол 0.10с; соло — 1 снаряд/пульс на турель, толпа — залп
# projectile_count); предложение = magazine выстрелов с каждым деплоем
# (fire_interval / attack_speed). Устойчивый DPS = min(спрос, предложение) —
# скорость атаки ускоряет и стрельбу, и восполнение (AC SCRUM-905), Лидерство
# растит capacity (2 + floor(summon_amount/4), рельс max_summons_cap).
static func _budget_sentry_ammo_model(config: Dictionary, params: Dictionary, stats := {}) -> Dictionary:
	if str(config.get("attack_mode", "")) != "engineer_sentry_link" or int(config.get("sentry_shot_magazine", 0)) <= 0:
		return {}
	var magazine := float(config.get("sentry_shot_magazine", 15))
	var attack_speed := maxf(float(params.get("attack_speed", 1.0)), 0.1)
	var deploy_interval := maxf(float(config.get("fire_interval", 2.7)) / attack_speed, 0.18)
	var supply_rate := magazine / deploy_interval
	var summon_amount := maxf(float(params.get("summon_amount", 0.0)), 0.0)
	var leadership := float(stats.get("leadership", summon_amount)) if stats is Dictionary else summon_amount
	var tempo := 1.0 + minf(summon_amount * 0.014 + leadership * 0.006, 0.30)
	var pulse := maxf(maxf(float(config.get("amp_pulse_interval", 0.55)), 0.18) / tempo / attack_speed, 0.10)
	var capacity := maxf(float(maxi(int(config.get("max_summons", 1)), 1)) + floor(summon_amount / 4.0), 1.0)
	if int(config.get("max_summons_cap", 0)) > 0:
		capacity = minf(capacity, float(config.get("max_summons_cap", 6)))
	var demand_solo := capacity / pulse
	var volley := maxi(int(config.get("projectile_count", 1)), 1)
	var falloff := clampf(float(config.get("damage_falloff", 0.55)), 0.05, 1.0)
	var volley_quality := 0.0
	for volley_index in range(volley):
		volley_quality += pow(falloff, float(volley_index))
	var splash_bonus := 0.0
	if float(config.get("sentry_splash_radius", 0.0)) > 0.0:
		var splash_cap := maxi(int(config.get("sentry_splash_target_cap", 0)), 0)
		var splash_mult := maxf(float(config.get("sentry_splash_damage_multiplier", 0.0)), 0.0)
		for splash_index in range(splash_cap):
			splash_bonus += splash_mult / (1.0 + float(splash_index) * 0.75)
	var role_factor := _budget_summon_role_damage_factor(config, params, stats)
	var shot_damage := float(params.get(str(config.get("damage_parameter", "damage")), params.get("damage", 1.0))) 		* float(config.get("summon_damage_multiplier", 1.0)) * role_factor
	var solo_dps := minf(demand_solo, supply_rate) * shot_damage
	var aoe_dps := minf(demand_solo * float(volley), supply_rate) * shot_damage 		* (volley_quality / float(volley)) * (1.0 + splash_bonus)
	return {
		"summon_dps": solo_dps,
		"summon_targets": aoe_dps / maxf(solo_dps, 0.001),
	}


# SCRUM-906: контактный DPS орбитальных дронов — зеркало
# scripts/engineer_orbit_drone.gd + class_weapon._engineer_drone_target_count.
# Число дронов = max_summons + floor(max(summon_amount - threshold, 0) / step),
# рельс max_summons_cap (база Инженера ~12.5 → ровно 2 дрона). Оборотов/с =
# drone_orbit_speed × attack_speed / TAU (скорость атаки крутит RPM, AC);
# хитов/с на дрона по одной цели = min(обороты, 1/hit_cooldown) — дрон
# пересекает угловую позицию цели раз за оборот, per-enemy кулдаун гейтит
# сверху. Толпа: кольцо орбиты накрывает clamp(1 + (внешний радиус спирали +
# контакт)/58, 1, 5) целей бюджет-пятёрки.
static func _budget_orbit_drone_dps(config: Dictionary, params: Dictionary, stats := {}) -> Dictionary:
	if str(config.get("attack_mode", "")) != "engineer_orbit_drone":
		return {}
	var attack_speed := maxf(float(params.get("attack_speed", 1.0)), 0.1)
	var rev_rate := maxf(float(config.get("drone_orbit_speed", 3.6)), 0.5) * attack_speed / TAU
	var hit_cooldown := maxf(float(config.get("drone_hit_cooldown", 0.85)), 0.1)
	var pass_rate := minf(rev_rate, 1.0 / hit_cooldown)
	var summon_amount := maxf(float(params.get("summon_amount", 0.0)), 0.0)
	var threshold := float(config.get("drone_count_threshold", 12.0))
	var step := maxf(float(config.get("drone_count_step", 4.0)), 0.5)
	var count := maxf(float(maxi(int(config.get("max_summons", 1)), 1)) + floor(maxf(summon_amount - threshold, 0.0) / step), 1.0)
	if int(config.get("max_summons_cap", 0)) > 0:
		count = minf(count, float(config.get("max_summons_cap", 6)))
	var role_factor := _budget_summon_role_damage_factor(config, params, stats)
	var contact_damage := float(params.get(str(config.get("damage_parameter", "damage")), params.get("damage", 1.0))) 		* float(config.get("summon_damage_multiplier", 0.9)) * role_factor
	var solo_dps := count * contact_damage * pass_rate
	# FAN-1075: стартовая пара находится на одном кольце; спираль начинается
	# с третьего дрона и зеркалит engineer_orbit_drone._orbit_radius.
	var outer_slot := 0.0
	if count > 2.0:
		outer_slot = count - 1.0
	var outer_radius := maxf(float(config.get("drone_orbit_radius", 121.0)), 24.0) * (1.0 + 0.14 * outer_slot)
	var ring_coverage := clampf(1.0 + (outer_radius + maxf(float(config.get("drone_contact_radius", 44.0)), 8.0)) / 58.0, 1.0, 5.0)
	return {
		"summon_dps": solo_dps,
		"summon_targets": ring_coverage,
	}


# SCRUM-908 «Сеть мастерской»: бюджет-зеркало ClassWeapon._workshop_network_factor.
# Ожидаемые стеки в устойчивом бою (по типу устройства):
#   - турели: min(capacity, жизнь магазина / интервал деплоя) — боезапас
#     ограничивает одновременный парк;
#   - дроны: постоянный парк = число дронов;
#   - мины: кап × вес 0.5 × заполненность 0.33 (в бою мины детонируют быстро).
# Стеки клампятся капом сети (cap_base + floor(Лидерство/step)); фактор =
# 1 + стеки × per_stack. У классов без trait'а per_stack = 0 → фактор 1.0.
static func _budget_network_factor(config: Dictionary, params: Dictionary, stats: Dictionary, trait_config: Dictionary) -> float:
	var per_stack := float(trait_config.get("network_damage_per_stack", 0.0))
	if per_stack <= 0.0:
		return 1.0
	var summon_amount := maxf(float(params.get("summon_amount", 0.0)), 0.0)
	var leadership := float(stats.get("leadership", summon_amount)) if stats is Dictionary else summon_amount
	var cap := maxf(float(trait_config.get("network_stack_cap_base", 3.0)) 		+ floor(maxf(leadership, 0.0) / maxf(float(trait_config.get("network_cap_leadership_step", 6.0)), 1.0)), 0.0)
	var mode := str(config.get("attack_mode", ""))
	var expected := 0.0
	match mode:
		"engineer_sentry_link":
			var attack_speed := maxf(float(params.get("attack_speed", 1.0)), 0.1)
			var tempo := 1.0 + minf(summon_amount * 0.014 + leadership * 0.006, 0.30)
			var pulse := maxf(maxf(float(config.get("amp_pulse_interval", 0.55)), 0.18) / tempo / attack_speed, 0.10)
			var magazine_life := float(config.get("sentry_shot_magazine", 15)) * pulse
			var deploy_interval := maxf(float(config.get("fire_interval", 2.7)) / attack_speed, 0.18)
			var capacity := maxf(float(maxi(int(config.get("max_summons", 1)), 1)) + floor(summon_amount / 4.0), 1.0)
			if int(config.get("max_summons_cap", 0)) > 0:
				capacity = minf(capacity, float(config.get("max_summons_cap", 6)))
			expected = minf(capacity, magazine_life / deploy_interval)
		"engineer_orbit_drone":
			var threshold := float(config.get("drone_count_threshold", 12.0))
			var step := maxf(float(config.get("drone_count_step", 4.0)), 0.5)
			expected = maxf(float(maxi(int(config.get("max_summons", 1)), 1)) + floor(maxf(summon_amount - threshold, 0.0) / step), 1.0)
			if int(config.get("max_summons_cap", 0)) > 0:
				expected = minf(expected, float(config.get("max_summons_cap", 6)))
		"engineer_pressure_mines":
			expected = float(config.get("mine_active_cap", 6)) * float(trait_config.get("network_mine_weight", 0.5)) * 0.33
		_:
			return 1.0
	return 1.0 + minf(expected, cap) * per_stack


static func _is_pure_summon_weapon(config: Dictionary) -> bool:
	return config.has("summon_damage_multiplier") and not config.has("attack_mode") and not config.has("attack_shape")


static func _budget_summon_role_damage_factor(config: Dictionary, params: Dictionary, stats := {}) -> float:
	var summon_amount := float(params.get("summon_amount", 0.0))
	var leadership := float(stats.get("leadership", summon_amount)) if stats is Dictionary else summon_amount
	var knowledge := float(stats.get("knowledge", 0.0)) if stats is Dictionary else 0.0
	var intelligence := float(stats.get("intelligence", 0.0)) if stats is Dictionary else 0.0
	var energy := float(stats.get("energy", 0.0)) if stats is Dictionary else 0.0
	# SCRUM-546: Лидерство — главный драйвер силы саммонов. Коэффициент и потолок
	# подняты (0.020/0.42 → 0.060/1.15), чтобы прокачка саммонера ощутимо усиливала
	# питомцев. Зеркалит summoner_weapon._summon_profile (тот же runtime-расчёт).
	var leadership_damage := 1.0 + minf(leadership * 0.060, 1.15)
	var attribute_damage := 1.0 + minf(summon_amount * 0.016 + knowledge * 0.004 + intelligence * 0.004 + energy * 0.003, 0.40)
	return float(config.get("summon_role_damage_multiplier", 1.0)) * leadership_damage * attribute_damage


# Ultimate DPS share over the balance window; `config` is the class ultimate
# entry (ProgressionData.ultimate_config), resolved by the facade.
static func _budget_ultimate_dps(config: Dictionary, params: Dictionary) -> Dictionary:
	var multiplier := float(params.get("ultimate_multiplier", 1.0))
	var base_damage := maxf(float(params.get("damage", 1.0)), float(params.get("magic_damage", 1.0)))
	var damage := base_damage * float(config.get("damage", 1.0)) * multiplier
	var target_count := float(config.get("target_count", 5.0))
	if not config.has("target_count"):
		target_count = clampf(1.0 + float(config.get("radius", 250.0)) / 115.0, 1.0, 5.0)
	var charge_window_factor := 0.42
	return {
		"solo": damage * charge_window_factor / BALANCE_WINDOW_SECONDS,
		"aoe": damage * minf(target_count, 5.0) * charge_window_factor / BALANCE_WINDOW_SECONDS,
	}


static func _budget_ehp(config: Dictionary, params: Dictionary) -> float:
	var health := float(params.get("health_point", 1.0))
	var defense := clampf(float(params.get("defense", 0.0)), 0.0, SURVIVABILITY_DEFENSE_CAP)
	var dodge := clampf(float(params.get("dodge", 0.0)), 0.0, SURVIVABILITY_DODGE_CAP)
	var absorb := float(params.get("absorb", 0.0))
	var regen := float(params.get("regeneration", 0.0))
	var lifesteal := (
		float(config.get("heal_percent_of_damage", 0.0)) * 120.0
		+ float(config.get("heal_percent_on_attack", 0.0)) * health * 2.0
	) * WEAPON_DRAIN_HEAL_MULTIPLIER
	return health / maxf(1.0 - defense, 0.10) / maxf(1.0 - dodge, 0.10) + absorb * 6.0 + regen * BALANCE_WINDOW_SECONDS + lifesteal
