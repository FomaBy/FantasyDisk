class_name ClassWeapon
extends Node2D

const SOUND_AMP_TEXTURE := preload("res://assets/sprites/weapons/sound_amp.png")
const POISON_POOL_TEXTURE := preload("res://assets/sprites/effects/poison_pool.png")
const SPARK_POOL_TEXTURE := preload("res://assets/sprites/effects/spark_pool.png")
const BRIAR_POOL_TEXTURE := preload("res://assets/sprites/effects/briar_pool.png")
const TARGET_QUERY := preload("res://scripts/combat_target_query.gd")
const ProgressionData := preload("res://scripts/progression_data.gd")
const PROJECTILE_VISUALS := preload("res://scripts/projectile_visual_registry.gd")
const STORM_LONGBOW_VOLLEY_VFX_SCENE := preload("res://scenes/vfx/StormLongbowVolleyVfx.tscn")
const SENTRY_TURRET_SCENE := preload("res://scenes/SentryTurret.tscn")
const ENGINEER_ORBIT_DRONE_SCRIPT := preload("res://scripts/engineer_orbit_drone.gd")
const ENGINEER_MINE_SCRIPT := preload("res://scripts/engineer_mine.gd")
const WEAPON_CROWD_CAPS := preload("res://scripts/weapon_crowd_caps.gd")

# SCRUM-553: абсолютный z-слой наземных луж/декалей (summon-пулы химика и пр.).
# Ниже сущностей (игрок/монстры/пикапы z≈0), но выше фона арены (-100) и бордера (-20).
const GROUND_POOL_Z := -3
const CONTACT_STUCK_HIT_BACK_ALLOWANCE := 40.0
# SCRUM-894: число сегментов полилинии дуги возврата чакрамов (урон + полёт орба).
const BOOMERANG_ARC_SAMPLES := 12

const DEFAULT_ATTACK_MODE := "sound_wave"
const CONSTELLATION_FINAL_EVENT_HOOKS := {
	"rifle_suppression_mark": "hit", "grenade_shrapnel_second_wave": "explosion",
	"bayonet_brace_countershot": "brace_hit", "coin_unique_target_return": "return",
	"dagger_backstab_execute_mark": "hit", "smoke_dodge_triggered_burst": "dodge",
	"orb_four_element_resonance": "hit", "prism_intersection_rift": "intersection",
	"meteor_shard_recall": "return", "deadeye_weakpoint_cycle": "hit",
	"spotter_highest_hp_priority": "target_acquired", "shatter_extra_pierce_falloff": "pierce",
	"reliquary_mark_expiry_burst": "expiry", "censer_absorb_retaliation": "damage_absorbed",
	"chime_owner_return_shield": "return", "spore_final_ring_blooms": "final_ring",
	"injector_sample_analysis_ramp": "hit", "symbiote_link_transfer": "link",
	"anchor_next_heavy_hit_setup": "hit", "reactor_vent_cycle_pulse": "cast",
	"mine_adjacency_chain": "mine_explosion", "book_mirror_midpoint_collapse": "mirror_midpoint",
	"skull_death_curse_transfer": "kill", "wand_pierce_decay_echo": "pierce",
	"guitar_riff_harmony_lane": "hit", "bass_every_nth_stagger": "pulse",
	"amp_instrument_echo": "amp_pulse", "chakram_return_execute_mark": "return",
	"dagger_execute_shadow_window": "execute", "wire_poison_ramp_snap": "hit",
	"crossbow_full_charge_mark": "full_charge", "longbow_outer_storm_branch": "outer_hit",
	"trap_prey_mark_distribution": "trap_trigger", "potion_overheal_absorb_pool": "overheal",
	"syringe_infection_threshold_spread": "hit", "saw_wound_execute_heal": "hit",
	"powder_cross_reagent_combo": "cross_reagent", "acid_stack_detonation": "pool_stack",
	"briar_sustained_root_burst": "root_matured", "totem_every_nth_raven_strike": "totem_pulse",
}
const PRIMARY_CAST_ACTION_MODES := {
	"aoe_projectile": true,
	"homing_curse": true,
	"beam": true,
	"drain_link": true,
	# SCRUM-939..941: новый кит Тёмного мага кастует, как и прежние формы.
	"dark_chain_burst": true,
	"skull_curse_burn": true,
	"dark_mirror_blast": true,
	"plague_dart": true,  # SCRUM-900: бросок чумного дротика — каст-жест
	# SCRUM-910/911: лучные режимы Рейнджера сохраняют каст-жест прежнего beam.
	"moon_split_shot": true,
	"storm_pierce_cone": true,
}
const EVENT_CAST_ACTION_MODES := {
	"aoe_projectile": true,
	"homing_curse": true,
	"beam": true,
	"dot_beam": true,
	"drain_link": true,
	"plague_dart": true,  # SCRUM-900
	"priest_dual_toll": true,
	"bio_symbiote_web": true,
	"dark_chain_burst": true,
	"skull_curse_burn": true,
	"dark_mirror_blast": true,
	"moon_split_shot": true,   # SCRUM-910
	"storm_pierce_cone": true,  # SCRUM-911
}
const ATTACK_MODE_EXECUTORS := {
	"aoe_projectile": "_exec_aoe_projectile",
	"boomerang": "_exec_boomerang",
	"stab_flurry": "_exec_stab_flurry",
	"dot_beam": "_exec_dot_beam",
	"homing_curse": "_exec_homing_curse",
	"dark_chain_burst": "_exec_dark_chain_burst",
	"skull_curse_burn": "_exec_skull_curse_burn",
	"dark_mirror_blast": "_exec_dark_mirror_blast",
	"beam": "_exec_beam",
	"drain_link": "_exec_drain_link",
	"sound_wave": "_exec_sound_wave",
	"riff_strip": "_exec_riff_strip",
	"pulse": "_exec_pulse",
	"amp": "_exec_amp",
	"trap": "_exec_trap",
	"arquebus_shot": "_exec_arquebus_shot",
	"grenade_fuse": "_exec_grenade_fuse",
	"bayonet_cone": "_exec_bayonet_cone",
	"coin_ricochet": "_exec_coin_ricochet",
	"shadow_backstab": "_exec_shadow_backstab",
	"smoke_bomb": "_exec_smoke_bomb",
	"elemental_orbit": "_exec_elemental_orbit",
	"prism_rift": "_exec_prism_rift",
	"meteor_shards": "_exec_meteor_shards",
	"sniper_lockshot": "_exec_sniper_lockshot",
	"sniper_kill_zone": "_exec_sniper_kill_zone",
	"sniper_split_round": "_exec_sniper_split_round",
	"priest_sanctify": "_exec_priest_sanctify",
	"priest_ward": "_exec_priest_ward",
	"priest_dual_toll": "_exec_priest_dual_toll",
	"bio_spore_bloom": "_exec_bio_spore_bloom",
	"bio_sample_dart": "_exec_bio_sample_dart",
	"bio_symbiote_web": "_exec_bio_symbiote_web",
	"robot_magnetic_anchor": "_exec_robot_magnetic_anchor",
	"robot_compression_line": "_exec_robot_compression_line",
	"robot_reactor_vent": "_exec_robot_reactor_vent",
	"engineer_sentry_link": "_exec_engineer_sentry_link",
	"engineer_orbit_drone": "_exec_engineer_orbit_drone",
	"engineer_pressure_mines": "_exec_engineer_pressure_mines",
	"plague_dart": "_exec_plague_dart",  # SCRUM-900 doctor/plague_syringe
	"saw_sector": "_exec_saw_sector",  # SCRUM-900 doctor/bone_saw
	"moon_split_shot": "_exec_moon_split_shot",  # SCRUM-910 ranger/moon_crossbow
	"storm_pierce_cone": "_exec_storm_pierce_cone",  # SCRUM-911 ranger/storm_longbow
}

@export var weapon_id := "dark_book"
@export var display_name := "Class Weapon"
@export var attack_mode := "aoe_projectile"
@export var damage_parameter := "damage"
@export var fire_interval := 0.8
@export var damage := 10.0
@export var attack_range := 520.0
@export var aoe_radius := 160.0
@export var projectile_speed := 520.0
@export var beam_width := 52.0
@export var wave_width := 220.0
@export var knockback := 80.0
@export var pierce_count := 4
@export var dot_ticks := 0
@export var beam_count := 1
@export var beam_fan_degrees := 12.0
@export var projectile_count := 1
# FAN-1893: явная capability оружия — числом реальных снарядов управляет
# generic-ось run_modifiers.extra_projectile ТОЛЬКО при real_projectile_count > 0
# (см. _extra_projectiles). Обычное оружие добавляет снаряд к своему выстрелу,
# а каждая активная «Часовая турель» — к собственному залпу, без роста парка.
# 0 (fail-closed дефолт) = ловушки/тики/звенья/ширина/рикошеты снарядами не
# считаются и «+1 снаряд» не потребляют. FAN-2247:
# player-facing source отсутствует — active reward/config/source не выдаёт
# run_modifiers.extra_projectile; прямой probe/injected value не является наградой.
@export var real_projectile_count := 0
@export var burst_interval := 0.08
@export var grenade_delay := 0.42
@export var brace_duration := 0.34
@export var suppression_width := 120.0
# SCRUM-938 «Штык-конус»: сектор ближнего укола + редкий авто-выстрел винтовки.
@export var cone_degrees := 100.0
@export var bayonet_auto_shot_chance := 0.0
@export var bayonet_shot_range := 560.0
@export var bayonet_shot_damage_multiplier := 0.7
@export var damage_falloff := 0.55
@export var pierce_damage_falloff := 1.0
# SCRUM-897 «Кошель Рикошета»: steal_hits — сколько ПЕРВЫХ целей цепи обворовываются
# детерминированно (золото начисляется мгновенно, без пикапа).
@export var steal_money := 0
@export var steal_hits := 0
@export var dodge_bonus := 0.0
@export var smoke_duration := 1.8
# SCRUM-897 «Отравленный Кинжал»: встроенное окно паралича-яда (сек); артефакт
# «Парализующее лезвие» (backstab_root_duration) добавляется поверх, суммарно
# не выше POISON_PARALYSIS_CAP.
@export var poison_paralysis_duration := 0.0
# SCRUM-909 «Сторожевой лук»: опт-ин лучного оружия Рейнджера — каждый прямой
# хит отбрасывает жертву ОТ ИГРОКА (см. _apply_ranger_bow_knockback). Классы
# без trait'а bow_hit_knockback (CLASS_TRAITS) флаг игнорируют — утечки нет.
@export var bow_knockback_trait := false
# SCRUM-913 «Охотничий капкан»: жёсткий паралич на триггере (сек; боссы/элиты
# ×POISON_PARALYSIS_BOSS_FACTOR) и интервал тика зелёного кровотечения
# (dot-ось: dot_ticks тиков по dot_damage владельца).
@export var trap_paralyze_seconds := 0.0
@export var trap_bleed_tick_interval := 0.5
@export var orbit_duration := 1.6
@export var storm_ticks := 4
# SCRUM-927: доля ролла на один тик бурста реликвария (серия storm_ticks вспышек).
@export var sanctify_tick_ratio := 0.38
@export var shard_count := 3
@export var split_count := 3
@export var mark_duration := 1.2
@export var amp_lifetime := 7.0
@export var amp_pulse_interval := 1.1
# SCRUM-899: opt-in правила саммонер-скейлинга деплой-ампов (включает ТОЛЬКО
# sound_amp Гитариста через конфиг; raven_totem Друида не подписан и не меняется):
# Лидерство продлевает жизнь ампа (uptime), summon_amount учащает пульс (сила
# через темп, канон summoner_weapon._summon_profile). Полные правила —
# progression_data_weapons.GUITARIST_WEAPONS + docs/design/systems/characters_weapons.md.
@export var amp_leadership_lifetime_per_point := 0.0
@export var amp_leadership_lifetime_cap := 0.0
@export var amp_summon_haste := false
@export var max_summons := 0
@export var max_summons_cap := 0
@export var heal_percent_on_attack := 0.0
@export var heal_percent_of_damage := 0.0
@export var leaves_pool := false
@export var pool_element := ""
@export var combo_clouds := false
@export var pool_duration := 3.0
@export var pool_tick_interval := 0.6
@export var pool_direct_damage_multiplier := 1.0
# SCRUM-944: per-weapon скалер тика лужи (зеркалится в _budget_pool_dps).
@export var pool_tick_damage_multiplier := 1.0
# FAN-1031 3c(a): data-driven кап ПУЛ-канала — аналог S1 (aoe_full_targets) для луж.
# (см. gate tests/pool_target_cap_gate.gd).
@export var pool_full_targets := -1
@export var pool_target_diminish := -1.0
# FAN-1031 3c(b): STATUS fan-out кап (диминиш хвоста крауд-DoT) — ближние N носителей полный
# тик, дальше ослаблен; сентинел <0 → STATUS_FANOUT_* (нулевое изменение без override). Канон
# и профиль: docs/design/systems/progression_balance.md; гейт tests/status_fanout_cap_gate.gd.
@export var status_full_targets := -1
@export var status_target_diminish := -1.0
# FAN-1031 3c(b2): FALLOFF/ORBIT fan-out капы (_damage_enemies_in_circle_falloff /
# _elemental_square_tick) — диминиш хвоста по числу целей поверх радиального спада; сентинел
# <0 → *_FANOUT_* дефолт (нулевое изменение без override). Канон: progression_balance.md;
# гейт tests/orbit_falloff_cap_gate.gd.
@export var falloff_full_targets := -1
@export var falloff_target_diminish := -1.0
@export var orbit_full_targets := -1
@export var orbit_target_diminish := -1.0

# FAN-1031 3c(final): ЖЁСТКИЙ кап ШИРИНЫ (coverage) крауд-каналов — ближние N целей получают
# урон/статус, дальше НОЛЬ (продуктовое решение «резать ширину, не per-hit», 2026-07-13);
# сентинел <0 → без потолка. Канон: docs/design/systems/progression_balance.md.
@export var aoe_max_targets := -1     # кап _damage_enemies_in_circle_capped (прямой AoE-взрыв)
@export var pool_max_targets := -1    # кап _damage_enemies_in_pool (тик лужи)
@export var status_max_targets := -1  # кап _status_fanout_factor (крауд-DoT/статусы)
@export var orbit_max_targets := -1   # кап _orbit_fanout_factor (тик квадрата орбит)
# SCRUM-944: полупрозрачная наземная лужа (visual-polish кислотной колбы).
@export var pool_translucent := false
# SCRUM-944: перманентные контактные заряды лужи — один вечный DoT-заряд с КАЖДОЙ
# отдельной лужи (кап pool_charge_cap на цель; артефакт acid_charge_stacks: +3).
@export var pool_contact_charges := false
@export var pool_charge_tick_multiplier := 0.30
@export var pool_charge_tick_interval := 0.9
@export var pool_charge_cap := 5
# SCRUM-903 briar_staff: терновая зона — слоу + ПОВТОРНЫЕ ФИЗИЧЕСКИЕ хиты
# (masштаб от стата damage/Сила, НЕ dot-ось). Кап briar_hit_cap хитов на одного
# врага с ОДНОЙ зоны (время внутри / проход сквозь зону), интервал —
# pool_tick_interval; анти-runaway: повторный вход хиты не сбрасывает, общий
# потолок живых зон MAX_ACTIVE_DAMAGE_POOLS. Зеркало бюджета — _budget_pool_dps.
@export var briar_zone := false
@export var briar_hit_multiplier := 0.34
@export var briar_hit_cap := 5
@export var briar_slow_multiplier := 0.62
# SCRUM-903 raven_totem: тотем-деплой пускает самонаводящихся воронов (кривая
# Безье с живым доведением); взрыв по области в точке попадания (полный урон
# первым RAVEN_EXPLOSION_FULL_TARGETS, дальше диминиш). Зеркало — _budget_hit_model.
@export var raven_homing := false
@export var raven_damage_multiplier := 0.85
@export var raven_explosion_radius := 120.0
@export var charge_seconds := 0.0
@export var charge_max_multiplier := 1.0
@export var crit_shadow_burst_radius := 0.0
# SCRUM-894 (кит Ассасина): дуга возврата чакрамов / point-blank покрытие серии
# кинжалов / близкий контакт и крит-снапшот яда струны. 0 = поведение без фичи.
@export var return_arc_offset := 0.0
@export var point_blank_radius := 0.0
@export var close_contact_radius := 0.0
@export var dot_crit_snapshot_ratio := 0.0
# FAN-1031 v7: ядовитый крауд-спред dot_beam (assassin venom_wire). Сентинел 0.0 → no-op
# (ни один спред) → нулевое изменение без override. При >0 после пирса струна брызгает
# ядом по врагам ВНЕ пробитой линии — крауд-канал В СУЩЕСТВУЮЩИХ капах ширины
# (aoe_max_targets/aoe_full_targets/aoe_target_diminish), ОРТОГОНАЛЬНЫЙ solo (пробитые
# исключены → на 1 цели спреда нет → solo не меняется).
@export var dot_beam_spread_ratio := 0.0
@export var melee_close_bonus_radius := 0.0
@export var melee_close_damage_multiplier := 1.0
@export var melee_execute_threshold := 0.0
@export var melee_execute_multiplier := 1.0
@export var melee_stagger_knockback_multiplier := 0.0
@export var melee_arc_followup_radius := 0.0
@export var melee_arc_followup_multiplier := 0.0
@export var melee_heal_percent_on_hit := 0.0
# SCRUM-900 doctor/bone_saw (saw_sector): диминиш урона по целям сверх
# sector_full_targets — сектор чистит толпу, но не масштабируется линейно.
@export var sector_full_targets := 4
@export var sector_target_diminish := 0.72
# FAN-1031 S1 (Stage 3a): data-driven кап «полных» целей и диминиш дальних целей
# tests/aoe_target_cap_gate.gd; S3 применяет к doctor/restore_potion).
@export var aoe_full_targets := -1
@export var aoe_target_diminish := -1.0
# SCRUM-900 doctor/plague_syringe (plague_dart): параметры чумы. Профиль тика —
# ProgressionData.plague_tick_profile (единый источник для боя и budget-модели).
@export var plague_duration := 24.0
@export var plague_tick_interval := 2.0
@export var plague_tick_ratio := 0.22
@export var plague_dot_coupling := 0.6
@export var plague_ramp_ticks := 5
@export var plague_spread_chance := 0.22
@export var plague_spread_radius := 200.0
@export var plague_max_infected := 10
@export var summon_role := ""
@export var summon_role_damage_multiplier := 1.0
@export var summon_support_heal_percent := 0.0
@export var summon_control_knockback := 0.0
@export var sentry_splash_radius := 0.0
@export var sentry_splash_damage_multiplier := 0.0
@export var sentry_splash_target_cap := 0
# SCRUM-905: боезапас турели (выстрелов на турель; расстреляла — свернулась).
@export var sentry_shot_magazine := 15
# SCRUM-906, FAN-1075: орбитальные дроны (см. scripts/engineer_orbit_drone.gd).
@export var drone_orbit_radius := 121.0
@export var drone_visual_scale := 0.36
@export var drone_orbit_speed := 3.6
@export var drone_contact_radius := 66.0
@export var drone_hit_cooldown := 0.85
@export var drone_count_threshold := 12.0
@export var drone_count_step := 4.0
# SCRUM-907: персистентные мины (см. scripts/engineer_mine.gd).
@export var mine_trigger_radius := 84.0
@export var mine_self_arm_delay := 3.0
@export var mine_active_cap := 6
@export var mine_place_min_distance := 110.0
@export var mine_place_max_distance := 260.0
@export var deploy_texture_path := ""
# SCRUM-939..941: параметры кита Тёмного мага (цепь / curse-прожиг / зеркало).
@export var chain_targets := 3
@export var chain_hop_range := 300.0
@export var chain_burst_ratio := 0.45
@export var mirror_damage_ratio := 1.0
@export var curse_only := false
@export var curse_tick_rate := 7.0
@export var curse_tick_multiplier := 1.0
@export var curse_int_scale := 0.0
# SCRUM-896: параметры кита Биолога (локальные споры / пирсинг-луч / семя).
# curse_tick_rate/curse_tick_multiplier переиспользуются биоинфекцией как
# generic-ключи каденции/силы периодики (см. _apply_bio_infection).
@export var spore_slow_base := 0.0
@export var spore_slow_max := 0.0
@export var tip_burst_ratio := 0.0
@export var seed_impact_ratio := 0.0
# SCRUM-931: ближний самоподрыв Винтовки Мертвого Глаза — доля урона выстрела
# по врагам в радиусе вокруг САМОГО Снайпера (страховка «беззащитен вплотную»).
@export var close_burst_radius := 0.0
@export var close_burst_ratio := 0.0
@export var visual_color := Color(0.5, 0.8, 1.0, 0.35)

var _cooldown := 0.0
var _last_direction := Vector2.RIGHT
var _last_attack_crit := false
var _charge_time := 0.0
var _current_charge_multiplier := 1.0
var _deployed_amps: Array[Node] = []
var _spawned_effects: Array[Node] = []
var _effects_shutdown := false
# SCRUM-961: состояние классовых артефактов (счётчик ритма / эхо-скейл).
var _rhythm_cast_counter := 0
var _rhythm_echo_scale := 1.0
# SCRUM-918: каноническое состояние ротации Реакторного Ядра. Старт всегда 0°
# (восток): аттач оружия/новый забег пересоздают инстанс ClassWeapon, поэтому
# застарелой фазы между забегами/сменами оружия нет. После КАЖДОЙ атаки фаза
# доворачивается на REACTOR_ROTATION_STEP_DEG по часовой (см.
# _fire_robot_reactor_vent); скорость атаки ускоряет только частоту шагов.
var _reactor_vent_phase := 0.0
var _constellation_mirror_pair_token := 0
var _constellation_mirror_pairs: Dictionary = {}
var _constellation_mirror_cast_token := 0
var _constellation_mirror_casts: Dictionary = {}
var _constellation_local_state: Dictionary = {}
var _constellation_shatter_volley_token := 0
var _constellation_shatter_volleys: Dictionary = {}
# FAN-2238: пыль без облака заряжает КАЖДЫЙ бросок одним реагентом и чередует их
# между бросками; след последнего взрыва живёт короткое окно, чтобы соседний
# взрыв несовместимого реагента дал ровно одну финальную реакцию.
var _powder_reagent_cast := 0
var _powder_reagent_trace: Node2D = null

# SCRUM-915/916/918: константы редизайна кита Робота.
# Импульс knockback гасится врагом с постоянным замедлением 2400 px/s^2
# (enemy._consume_knockback: move_toward(ZERO, 2400*delta)) => путь = v^2/4800.
# Для смещения на d нужен импульс sqrt(4800*d) — этим зеркалом пулл/компрессия
# переводят «долю пути» в импульс.
const KNOCKBACK_IMPULSE_TRAVEL_FACTOR := 4800.0
# Якорь (SCRUM-915): рядовые враги стягиваются к ЦЕНТРУ AoE на долю пути
# ANCHOR_PULL_CONVERGENCE за каст (без овершута через центр); элитки/боссы НЕ
# смещаются вовсе (урон полный). Импульс зажат капом — анти-runaway физики.
# Конфиг-ключ knockback якоря = базовая мощь пулла (норма ANCHOR_PULL_FORCE_NORM).
const ANCHOR_PULL_CONVERGENCE := 0.85
const ANCHOR_PULL_CONVERGENCE_CAP := 0.95
const ANCHOR_PULL_IMPULSE_CAP := 1500.0
const ANCHOR_PULL_FORCE_NORM := 170.0
# Пресс (SCRUM-916): врагов в коридоре прижимает к осевой линии на долю бокового
# отступа PRESS_COMPRESSION_CONVERGENCE за каст (ось не пересекается —
# «выравнивание в линию»). Элитки/боссы смещаются с резистом x0.25 (прецедент
# Thief-паралича POISON_PARALYSIS_BOSS_FACTOR — вечный стаклок недопустим),
# урон по ним полный. Конфиг-ключ knockback пресса = сила компрессии (норма 130).
const PRESS_COMPRESSION_CONVERGENCE := 0.80
const PRESS_COMPRESSION_IMPULSE_CAP := 1100.0
const PRESS_COMPRESSION_FORCE_NORM := 130.0
const PRESS_ELITE_BOSS_COMPRESSION_FACTOR := 0.25
# Реактор (SCRUM-918): ровно 4 вентиля с шагом 90°, ротация паттерна +6° по
const REACTOR_VENT_COUNT := 4
const REACTOR_ROTATION_STEP_DEG := 6.0
const REACTOR_VENT_DAMAGE_RATIO := 0.42
# SCRUM-900 plague_dart: реестр живых зараз этого оружия (enemy_id → Tween).
# Дедуп повторного заражения (рефреш), spread-исключение и кап plague_max_infected.
var _plague_tweens := {}
# SCRUM-896: гибрид Биолога — доля канала damage (ось Силы) на КАЖДЫЙ хит луча
# Инъектора (паттерн SQUARE_PHYSICAL_SHARE Элементалиста). Базовый факт-фактор
# 1.13 задокументирован в _budget_hit_model (bio_sample_dart).
const INJECTOR_PHYSICAL_SHARE := 0.50
# SCRUM-896: кэш lvl1-базы magic_damage класса владельца для нормированной
# прогрессии замедления линзы (_spore_slow_power).
var _bio_magic_baseline := 0.0


# SCRUM-961: чтение ключа классового артефакта из run_modifiers владельца.
func _owner_mod(key: String, default_value := 0.0) -> float:
	var owner_node := _owner_node()
	if owner_node == null:
		return default_value
	var mods = owner_node.get("run_modifiers")
	if mods is Dictionary:
		return float((mods as Dictionary).get(key, default_value))
	return default_value


static func registered_attack_modes() -> Array:
	return ATTACK_MODE_EXECUTORS.keys()


static func has_attack_mode_executor(mode: String) -> bool:
	return ATTACK_MODE_EXECUTORS.has(mode)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player_weapons")
	_capture_base_values()


func _exit_tree() -> void:
	cleanup_effects()


func cleanup_effects() -> void:
	_effects_shutdown = true
	_constellation_mirror_pairs.clear()
	_constellation_mirror_casts.clear()
	_constellation_local_state.clear()
	_constellation_shatter_volleys.clear()
	# SCRUM-900: гасим живые заразы чумы (tween'ы) вместе с эффектами.
	for enemy_id in _plague_tweens.keys():
		var plague_tween: Tween = _plague_tweens[enemy_id]
		if plague_tween != null and plague_tween.is_valid():
			plague_tween.kill()
	_plague_tweens.clear()
	# Самоочищающиеся VFX могли уже освободиться — отфильтровать мертвые ссылки.
	var tracked_effects := _alive_effects()
	_spawned_effects.clear()
	_deployed_amps.clear()
	for effect in tracked_effects:
		_release_effect(effect)


func configure_weapon(config: Dictionary) -> void:
	weapon_id = str(config.get("id", weapon_id))
	display_name = str(config.get("title", display_name))
	attack_mode = str(config.get("attack_mode", attack_mode))
	damage_parameter = str(config.get("damage_parameter", damage_parameter))
	fire_interval = float(config.get("fire_interval", fire_interval))
	damage *= float(config.get("damage_multiplier", 1.0))
	attack_range = float(config.get("attack_range", attack_range))
	aoe_radius = float(config.get("aoe_radius", aoe_radius))
	projectile_speed = float(config.get("projectile_speed", projectile_speed))
	beam_width = float(config.get("beam_width", beam_width))
	wave_width = float(config.get("wave_width", wave_width))
	knockback = float(config.get("knockback", knockback))
	pierce_count = int(config.get("pierce_count", pierce_count))
	dot_ticks = int(config.get("dot_ticks", dot_ticks))
	beam_count = int(config.get("beam_count", beam_count))
	beam_fan_degrees = float(config.get("beam_fan_degrees", beam_fan_degrees))
	projectile_count = int(config.get("projectile_count", projectile_count))
	real_projectile_count = maxi(int(config.get("real_projectile_count", 0)), 0)
	burst_interval = float(config.get("burst_interval", burst_interval))
	grenade_delay = float(config.get("grenade_delay", grenade_delay))
	brace_duration = float(config.get("brace_duration", brace_duration))
	suppression_width = float(config.get("suppression_width", suppression_width))
	cone_degrees = float(config.get("cone_degrees", cone_degrees))
	bayonet_auto_shot_chance = float(config.get("bayonet_auto_shot_chance", bayonet_auto_shot_chance))
	bayonet_shot_range = float(config.get("bayonet_shot_range", bayonet_shot_range))
	bayonet_shot_damage_multiplier = float(config.get("bayonet_shot_damage_multiplier", bayonet_shot_damage_multiplier))
	damage_falloff = float(config.get("damage_falloff", damage_falloff))
	pierce_damage_falloff = float(config.get("pierce_damage_falloff", pierce_damage_falloff))
	steal_money = int(config.get("steal_money", steal_money))
	steal_hits = int(config.get("steal_hits", steal_hits))
	dodge_bonus = float(config.get("dodge_bonus", dodge_bonus))
	smoke_duration = float(config.get("smoke_duration", smoke_duration))
	poison_paralysis_duration = float(config.get("poison_paralysis_duration", poison_paralysis_duration))
	bow_knockback_trait = bool(config.get("bow_knockback_trait", bow_knockback_trait))
	trap_paralyze_seconds = float(config.get("trap_paralyze_seconds", trap_paralyze_seconds))
	trap_bleed_tick_interval = float(config.get("trap_bleed_tick_interval", trap_bleed_tick_interval))
	orbit_duration = float(config.get("orbit_duration", orbit_duration))
	storm_ticks = int(config.get("storm_ticks", storm_ticks))
	sanctify_tick_ratio = float(config.get("sanctify_tick_ratio", sanctify_tick_ratio))
	shard_count = int(config.get("shard_count", shard_count))
	split_count = int(config.get("split_count", split_count))
	mark_duration = float(config.get("mark_duration", mark_duration))
	amp_lifetime = float(config.get("amp_lifetime", amp_lifetime))
	amp_pulse_interval = float(config.get("amp_pulse_interval", amp_pulse_interval))
	amp_leadership_lifetime_per_point = float(config.get("amp_leadership_lifetime_per_point", amp_leadership_lifetime_per_point))
	amp_leadership_lifetime_cap = float(config.get("amp_leadership_lifetime_cap", amp_leadership_lifetime_cap))
	amp_summon_haste = bool(config.get("amp_summon_haste", amp_summon_haste))
	max_summons = int(config.get("max_summons", max_summons))
	max_summons_cap = int(config.get("max_summons_cap", max_summons_cap))
	heal_percent_on_attack = float(config.get("heal_percent_on_attack", heal_percent_on_attack))
	heal_percent_of_damage = float(config.get("heal_percent_of_damage", heal_percent_of_damage))
	leaves_pool = bool(config.get("leaves_pool", leaves_pool))
	pool_element = str(config.get("pool_element", pool_element))
	combo_clouds = bool(config.get("combo_clouds", combo_clouds))
	pool_duration = float(config.get("pool_duration", pool_duration))
	pool_tick_interval = float(config.get("pool_tick_interval", pool_tick_interval))
	pool_direct_damage_multiplier = float(config.get("pool_direct_damage_multiplier", pool_direct_damage_multiplier))
	pool_tick_damage_multiplier = float(config.get("pool_tick_damage_multiplier", pool_tick_damage_multiplier))
	pool_translucent = bool(config.get("pool_translucent", pool_translucent))
	pool_contact_charges = bool(config.get("pool_contact_charges", pool_contact_charges))
	pool_charge_tick_multiplier = float(config.get("pool_charge_tick_multiplier", pool_charge_tick_multiplier))
	pool_charge_tick_interval = float(config.get("pool_charge_tick_interval", pool_charge_tick_interval))
	pool_charge_cap = int(config.get("pool_charge_cap", pool_charge_cap))
	# SCRUM-903: терновая зона Друида (слоу + повторные физ-хиты с капом).
	briar_zone = bool(config.get("briar_zone", briar_zone))
	briar_hit_multiplier = maxf(float(config.get("briar_hit_multiplier", briar_hit_multiplier)), 0.0)
	briar_hit_cap = maxi(int(config.get("briar_hit_cap", briar_hit_cap)), 1)
	briar_slow_multiplier = clampf(float(config.get("briar_slow_multiplier", briar_slow_multiplier)), 0.25, 1.0)
	# SCRUM-903: вороний тотем — самонаводящиеся вороны с AoE-взрывом.
	raven_homing = bool(config.get("raven_homing", raven_homing))
	raven_damage_multiplier = maxf(float(config.get("raven_damage_multiplier", raven_damage_multiplier)), 0.0)
	raven_explosion_radius = maxf(float(config.get("raven_explosion_radius", raven_explosion_radius)), 24.0)
	charge_seconds = float(config.get("charge_seconds", charge_seconds))
	charge_max_multiplier = float(config.get("charge_max_multiplier", charge_max_multiplier))
	crit_shadow_burst_radius = float(config.get("crit_shadow_burst_radius", config.get("dash_on_crit_distance", crit_shadow_burst_radius)))
	return_arc_offset = float(config.get("return_arc_offset", return_arc_offset))
	point_blank_radius = float(config.get("point_blank_radius", point_blank_radius))
	close_contact_radius = float(config.get("close_contact_radius", close_contact_radius))
	dot_crit_snapshot_ratio = float(config.get("dot_crit_snapshot_ratio", dot_crit_snapshot_ratio))
	dot_beam_spread_ratio = float(config.get("dot_beam_spread_ratio", dot_beam_spread_ratio))
	melee_close_bonus_radius = float(config.get("melee_close_bonus_radius", melee_close_bonus_radius))
	melee_close_damage_multiplier = float(config.get("melee_close_damage_multiplier", melee_close_damage_multiplier))
	melee_execute_threshold = float(config.get("melee_execute_threshold", melee_execute_threshold))
	melee_execute_multiplier = float(config.get("melee_execute_multiplier", melee_execute_multiplier))
	melee_stagger_knockback_multiplier = float(config.get("melee_stagger_knockback_multiplier", melee_stagger_knockback_multiplier))
	melee_arc_followup_radius = float(config.get("melee_arc_followup_radius", melee_arc_followup_radius))
	melee_arc_followup_multiplier = float(config.get("melee_arc_followup_multiplier", melee_arc_followup_multiplier))
	melee_heal_percent_on_hit = float(config.get("melee_heal_percent_on_hit", melee_heal_percent_on_hit))
	# SCRUM-900: докторский кит — сектор пилы и профиль чумы.
	sector_full_targets = int(config.get("sector_full_targets", sector_full_targets))
	sector_target_diminish = float(config.get("sector_target_diminish", sector_target_diminish))
	# FAN-1031 S1: data-driven кап прямого AoE-взрыва (см. _damage_aoe_projectile_explosion).
	aoe_full_targets = int(config.get("aoe_full_targets", aoe_full_targets))
	aoe_target_diminish = float(config.get("aoe_target_diminish", aoe_target_diminish))
	# FAN-1031 3c(a): data-driven кап пул-канала (тик лужи + leaves_pool-ветка).
	pool_full_targets = int(config.get("pool_full_targets", pool_full_targets))
	pool_target_diminish = float(config.get("pool_target_diminish", pool_target_diminish))
	# FAN-1031 3c(b): data-driven кап STATUS fan-out (крауд-раздача DoT-статусов).
	status_full_targets = int(config.get("status_full_targets", status_full_targets))
	status_target_diminish = float(config.get("status_target_diminish", status_target_diminish))
	# FAN-1031 3c(b2): data-driven кап FALLOFF/ORBIT крауд-fan-out каналов.
	falloff_full_targets = int(config.get("falloff_full_targets", falloff_full_targets))
	falloff_target_diminish = float(config.get("falloff_target_diminish", falloff_target_diminish))
	orbit_full_targets = int(config.get("orbit_full_targets", orbit_full_targets))
	orbit_target_diminish = float(config.get("orbit_target_diminish", orbit_target_diminish))
	# FAN-1031 3c(final): жёсткий кап ШИРИНЫ (coverage) крауд-fan-out каналов.
	aoe_max_targets = int(config.get("aoe_max_targets", aoe_max_targets))
	pool_max_targets = int(config.get("pool_max_targets", pool_max_targets))
	status_max_targets = int(config.get("status_max_targets", status_max_targets))
	orbit_max_targets = int(config.get("orbit_max_targets", orbit_max_targets))
	plague_duration = float(config.get("plague_duration", plague_duration))
	plague_tick_interval = float(config.get("plague_tick_interval", plague_tick_interval))
	plague_tick_ratio = float(config.get("plague_tick_ratio", plague_tick_ratio))
	plague_dot_coupling = float(config.get("plague_dot_coupling", plague_dot_coupling))
	plague_ramp_ticks = int(config.get("plague_ramp_ticks", plague_ramp_ticks))
	plague_spread_chance = float(config.get("plague_spread_chance", plague_spread_chance))
	plague_spread_radius = float(config.get("plague_spread_radius", plague_spread_radius))
	plague_max_infected = int(config.get("plague_max_infected", plague_max_infected))
	summon_role = str(config.get("summon_role", summon_role))
	summon_role_damage_multiplier = float(config.get("summon_role_damage_multiplier", summon_role_damage_multiplier))
	summon_support_heal_percent = float(config.get("summon_support_heal_percent", summon_support_heal_percent))
	summon_control_knockback = float(config.get("summon_control_knockback", summon_control_knockback))
	sentry_splash_radius = float(config.get("sentry_splash_radius", sentry_splash_radius))
	sentry_splash_damage_multiplier = float(config.get("sentry_splash_damage_multiplier", sentry_splash_damage_multiplier))
	sentry_splash_target_cap = int(config.get("sentry_splash_target_cap", sentry_splash_target_cap))
	sentry_shot_magazine = int(config.get("sentry_shot_magazine", sentry_shot_magazine))
	drone_orbit_radius = float(config.get("drone_orbit_radius", drone_orbit_radius))
	drone_visual_scale = float(config.get("drone_visual_scale", drone_visual_scale))
	drone_orbit_speed = float(config.get("drone_orbit_speed", drone_orbit_speed))
	drone_contact_radius = float(config.get("drone_contact_radius", drone_contact_radius))
	drone_hit_cooldown = float(config.get("drone_hit_cooldown", drone_hit_cooldown))
	drone_count_threshold = float(config.get("drone_count_threshold", drone_count_threshold))
	drone_count_step = float(config.get("drone_count_step", drone_count_step))
	mine_trigger_radius = float(config.get("mine_trigger_radius", mine_trigger_radius))
	mine_self_arm_delay = float(config.get("mine_self_arm_delay", mine_self_arm_delay))
	mine_active_cap = int(config.get("mine_active_cap", mine_active_cap))
	mine_place_min_distance = float(config.get("mine_place_min_distance", mine_place_min_distance))
	mine_place_max_distance = float(config.get("mine_place_max_distance", mine_place_max_distance))
	deploy_texture_path = str(config.get("deploy_texture_path", deploy_texture_path))
	chain_targets = int(config.get("chain_targets", chain_targets))
	chain_hop_range = float(config.get("chain_hop_range", chain_hop_range))
	chain_burst_ratio = float(config.get("chain_burst_ratio", chain_burst_ratio))
	mirror_damage_ratio = float(config.get("mirror_damage_ratio", mirror_damage_ratio))
	curse_only = bool(config.get("curse_only", curse_only))
	curse_tick_rate = float(config.get("curse_tick_rate", curse_tick_rate))
	curse_tick_multiplier = float(config.get("curse_tick_multiplier", curse_tick_multiplier))
	curse_int_scale = float(config.get("curse_int_scale", curse_int_scale))
	spore_slow_base = float(config.get("spore_slow_base", spore_slow_base))
	spore_slow_max = float(config.get("spore_slow_max", spore_slow_max))
	tip_burst_ratio = float(config.get("tip_burst_ratio", tip_burst_ratio))
	seed_impact_ratio = float(config.get("seed_impact_ratio", seed_impact_ratio))
	close_burst_radius = float(config.get("close_burst_radius", close_burst_radius))
	close_burst_ratio = float(config.get("close_burst_ratio", close_burst_ratio))
	visual_color = config.get("visual_color", visual_color)
	_capture_base_values()


func _process(delta: float) -> void:
	# Направление атаки задает только ближайший враг; движение влияет
	# только на walk-анимацию персонажа.
	_update_charge(delta)
	_cooldown -= delta
	if _cooldown > 0.0:
		return

	_attack()


func _attack() -> void:
	var owner_node := _owner_node()
	if owner_node == null:
		return

	var cursor_aim := _owner_uses_cursor_aim(owner_node)
	var target: Node2D = null if cursor_aim else _find_closest_enemy(owner_node)
	var direction := _last_direction
	if target != null:
		direction = (target.global_position - owner_node.global_position).normalized()
	elif not cursor_aim:
		# Вне радиуса целимся в ближайшего врага на арене, чтобы удар не уходил «в никуда».
		var distant_enemy := _find_closest_enemy(owner_node, INF)
		if distant_enemy != null:
			direction = (distant_enemy.global_position - owner_node.global_position).normalized()
	if cursor_aim and owner_node.has_method("attack_aim_direction"):
		direction = owner_node.call("attack_aim_direction", direction, attack_range)
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	_last_direction = direction
	_cooldown = fire_interval * _fire_interval_artifact_factor()

	if owner_node.has_method("play_action_animation"):
		owner_node.play_action_animation(_primary_action_animation_for_mode(), direction)
	if owner_node.has_method("record_weapon_cast"):
		owner_node.call("record_weapon_cast", weapon_id, attack_mode, _event_action_animation_for_mode(), _estimated_windup_duration())
	_emit_weapon_animation_event(owner_node, "windup", _estimated_windup_duration(), direction)

	# SCRUM-603: лечение-от-атаки идёт через per-second бюджет (capped), как drain.
	if heal_percent_on_attack > 0.0 and owner_node.has_method("heal_percent_capped"):
		owner_node.heal_percent_capped(heal_percent_on_attack * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER)
	elif heal_percent_on_attack > 0.0 and owner_node.has_method("heal_percent"):
		owner_node.heal_percent(heal_percent_on_attack * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER)

	_current_charge_multiplier = _charge_multiplier()
	var full_charge_release := charge_seconds > 0.0 and _current_charge_multiplier >= maxf(charge_max_multiplier - 0.01, 1.0)
	_execute_attack_mode(owner_node, target, direction)
	if full_charge_release:
		_charge_time = 0.0
	_current_charge_multiplier = 1.0
	_maybe_fire_rhythm_echo(owner_node, target, direction)
	_maybe_fire_action_echo(owner_node, target, direction)


# SCRUM-961: mode-rework артефакты меняют пейсинг оружия на точке потребления
# (само поле fire_interval пересобирает player._apply_weapon_scaling — не трогаем).
func _fire_interval_artifact_factor() -> float:
	var factor := 1.0
	# FAN-1031 v7 (координаторское решение): priest crowd 1.89 — КАДЕНС-driven, не width.
	if weapon_id == "priest_reliquary":
		# FAN-1031 v9-финал: 1.18→1.08 — ДОСМЯГЧАЕМ каденс-налог (координаторское решение,
		factor *= 1.08  # быстрый бурст-крауд, но каденс-налог досмягчён под random-floor лифт
	if weapon_id == "priest_censer":
		factor *= 1.15  # большой близкий AoE — вторичный крауд-вклад
	if weapon_id == "priest_reliquary" and _owner_mod("reliquary_barrage_mode") > 0.0:
		factor *= 0.75  # «Реликварный залп»: частые залпы вместо лечения
	if weapon_id == "priest_censer" and _owner_mod("censer_vow_mode") > 0.0:
		factor *= 1.35  # «Обет кадила»: реже, но шире и больнее (DPS ≈ паритет)
	if weapon_id == "blast_powder" and _owner_mod("volatile_powder_mode") > 0.0:
		factor *= 0.78  # «Летучая пыль»: быстрый комфортный AoE без облака
	if weapon_id == "elementalist_meteor_core" and _owner_mod("meteor_heart_mode") > 0.0:
		factor *= 1.45  # «Сердце метеора»: самый долгий и жирный пэйофф
	return factor


# SCRUM-961 «Счетчик ритма»: каждый N-й гитарный каст срабатывает дважды — повтор
# на 55% урона с короткой задержкой. Деплой amp исключён (эхо не ставит второй
# усилитель), эхо не порождает эхо (гард по _rhythm_echo_scale).
# SCRUM-898: гейт по weapon_id гитариста — sound_wave_damage удалён, гитарные
# оружия теперь бьют магией и по damage_parameter неотличимы от прочей магии.
const _RHYTHM_ECHO_WEAPON_IDS := ["electric_guitar", "bass_guitar", "sound_amp"]


func _maybe_fire_rhythm_echo(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	if _rhythm_echo_scale < 1.0:
		return
	var echo_every := int(_owner_mod("rhythm_echo_every"))
	if echo_every <= 0 or attack_mode == "amp" or not weapon_id in _RHYTHM_ECHO_WEAPON_IDS:
		return
	_rhythm_cast_counter += 1
	if _rhythm_cast_counter < echo_every:
		return
	_rhythm_cast_counter = 0
	var weapon_self_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var target_id := target.get_instance_id() if target != null else 0
	var echo_tween := create_tween()
	echo_tween.tween_interval(0.12)
	echo_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_self_id) as ClassWeapon
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_weapon == null or current_owner == null or not is_instance_valid(current_weapon) or not is_instance_valid(current_owner):
			return
		current_weapon._rhythm_echo_scale = 0.55
		current_weapon._execute_attack_mode(current_owner, instance_from_id(target_id) as Node2D, direction)
		current_weapon._rhythm_echo_scale = 1.0
	)


# SCRUM-935 «Двойное действие» (class trait Солдата, data-driven): каждое действие
const ACTION_ECHO_EXCLUDED_MODES := {
	"amp": true, "trap": true,
	"engineer_sentry_link": true, "engineer_orbit_drone": true, "engineer_pressure_mines": true,
}
const ACTION_ECHO_DEFAULT_DELAY := 0.18

var _action_echo_active := false
# SCRUM-908: последний целый уровень стеков «Сети мастерской» (для VFX-кью).
var _network_cue_tier := 0.0


func _maybe_fire_action_echo(owner_node: Node2D, target: Node2D, direction: Vector2) -> bool:
	if _action_echo_active or _effects_shutdown:
		return false
	if ACTION_ECHO_EXCLUDED_MODES.has(attack_mode):
		return false
	if owner_node == null or not is_instance_valid(owner_node) or not owner_node.has_method("class_trait_value"):
		return false
	var echo_chance := clampf(float(owner_node.call("class_trait_value", "action_echo_chance", 0.0)), 0.0, 1.0)
	if echo_chance <= 0.0 or randf() >= echo_chance:
		return false
	var echo_delay := maxf(float(owner_node.call("class_trait_value", "action_echo_delay", ACTION_ECHO_DEFAULT_DELAY)), 0.01)
	var target_id := 0
	if target != null and is_instance_valid(target):
		target_id = target.get_instance_id()
	var echo_tween := create_tween()
	echo_tween.tween_interval(echo_delay)
	# SCRUM-551: без лямбды с захватом узлов — Callable + примитивные bind-аргументы.
	echo_tween.tween_callback(Callable(self, "_fire_action_echo").bind(owner_node.get_instance_id(), target_id, direction))
	return true


func _fire_action_echo(owner_id: int, target_id: int, direction: Vector2) -> void:
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	var current_target: Node2D = null
	if target_id != 0:
		var target_candidate := instance_from_id(target_id) as Node2D
		if target_candidate != null and is_instance_valid(target_candidate):
			current_target = target_candidate
	_action_echo_active = true
	_emit_weapon_animation_event(current_owner, "pulse", 0.0, direction, {"action_echo": true})
	_execute_attack_mode(current_owner, current_target, direction)
	_action_echo_active = false


func _primary_action_animation_for_mode() -> String:
	return "cast" if PRIMARY_CAST_ACTION_MODES.has(attack_mode) else "shoot"


func _event_action_animation_for_mode() -> String:
	return "cast" if EVENT_CAST_ACTION_MODES.has(attack_mode) else "shoot"


func _execute_attack_mode(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_spawn_weapon_signature(owner_node, target, direction)
	var executor_name := str(ATTACK_MODE_EXECUTORS.get(attack_mode, ATTACK_MODE_EXECUTORS[DEFAULT_ATTACK_MODE]))
	call(executor_name, owner_node, target, direction)


func _spawn_weapon_signature(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	if owner_node == null or direction.length_squared() <= 0.001:
		return
	var release_origin := owner_node.global_position + direction * 26.0
	var radius := maxf(aoe_radius, beam_width * 1.4)
	var signature := AttackVfx.weapon_signature(
		_projectile_parent(),
		release_origin,
		weapon_id,
		radius,
		visual_color,
		direction.angle(),
		null,
		0.0,
		0.58,
		Vector2.ZERO,
		AttackVfx.owner_class_id(owner_node)
	)
	if signature != null:
		_register_effect(signature)


func _exec_aoe_projectile(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_aoe_projectile(owner_node, target, direction)


func _exec_boomerang(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_boomerang(owner_node, direction)


func _exec_stab_flurry(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_stab_flurry(owner_node, direction)


func _exec_dot_beam(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_dot_beam(owner_node, direction)


func _exec_homing_curse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_curse(owner_node, target, direction)


func _exec_dark_chain_burst(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_dark_chain_burst(owner_node, target, direction)


func _exec_skull_curse_burn(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_skull_curse_burn(owner_node, target, direction)


func _exec_dark_mirror_blast(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_dark_mirror_blast(owner_node, target, direction)


func _exec_beam(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_beam(owner_node, direction)


func _exec_plague_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_plague_dart(owner_node, target, direction)


func _exec_saw_sector(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_saw_sector(owner_node, direction)


func _exec_drain_link(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_drain_link(owner_node, target, direction)


func _exec_sound_wave(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_sound_wave(owner_node, direction)


func _exec_riff_strip(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_riff_strip(owner_node, direction)


func _exec_pulse(owner_node: Node2D, _target: Node2D, _direction: Vector2) -> void:
	_fire_pulse(owner_node, owner_node.global_position)


func _exec_amp(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_amp(owner_node, direction)


func _exec_trap(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_trap(owner_node, direction)


func _exec_moon_split_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_moon_split_shot(owner_node, target, direction)


func _exec_storm_pierce_cone(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_storm_pierce_cone(owner_node, direction)


func _exec_arquebus_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_arquebus_shot(owner_node, target, direction)


func _exec_grenade_fuse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_grenade_fuse(owner_node, target, direction)


func _exec_bayonet_cone(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_bayonet_cone(owner_node, direction)


func _exec_coin_ricochet(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_coin_ricochet(owner_node, target, direction)


func _exec_shadow_backstab(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_shadow_backstab(owner_node, target, direction)


func _exec_smoke_bomb(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_smoke_bomb(owner_node, target, direction)


func _exec_elemental_orbit(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_elemental_orbit(owner_node, direction)


func _exec_prism_rift(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_prism_rift(owner_node, target, direction)


func _exec_meteor_shards(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_meteor_shards(owner_node, target, direction)


func _exec_sniper_lockshot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_sniper_lockshot(owner_node, target, direction)


func _exec_sniper_kill_zone(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_sniper_kill_zone(owner_node, target, direction)


func _exec_sniper_split_round(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_sniper_split_round(owner_node, target, direction)


func _exec_priest_sanctify(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_priest_sanctify(owner_node, target, direction)


func _exec_priest_ward(owner_node: Node2D, _target: Node2D, _direction: Vector2) -> void:
	_fire_priest_ward(owner_node)


func _exec_priest_dual_toll(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_priest_dual_toll(owner_node, target, direction)


func _exec_bio_spore_bloom(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_bio_spore_bloom(owner_node, target, direction)


func _exec_bio_sample_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_bio_sample_dart(owner_node, target, direction)


func _exec_bio_symbiote_web(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_bio_symbiote_web(owner_node, target, direction)


func _exec_robot_magnetic_anchor(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_robot_magnetic_anchor(owner_node, target, direction)


func _exec_robot_compression_line(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_fire_robot_compression_line(owner_node, target, direction)


func _exec_robot_reactor_vent(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_robot_reactor_vent(owner_node, direction)


func _exec_engineer_sentry_link(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_engineer_sentry_link(owner_node, direction)


func _exec_engineer_orbit_drone(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_engineer_orbit_drone(owner_node, direction)


func _exec_engineer_pressure_mines(owner_node: Node2D, _target: Node2D, direction: Vector2) -> void:
	_fire_engineer_pressure_mines(owner_node, direction)


func _fire_aoe_projectile(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# FAN-2238: один бросок несёт ОДИН реагент, соседние броски — разные. Пара
	# снарядов одного каста поэтому не реагирует сама с собой (same-reagent), а
	# несовместимый соседний взрыв даёт реакцию (см. _mark_powder_reagent_impact).
	_powder_reagent_cast = (_powder_reagent_cast + 1) % 2
	var targets := _find_closest_enemies(owner_node, maxi(projectile_count + _extra_projectiles(), 1))
	if targets.is_empty():
		_launch_aoe_projectile(owner_node, null, direction, _powder_reagent_cast)
		return
	for target_node in targets:
		var to_target: Vector2 = target_node.global_position - owner_node.global_position
		var aim := direction if to_target.length_squared() <= 0.001 else to_target.normalized()
		_launch_aoe_projectile(owner_node, target_node, aim, _powder_reagent_cast)


func _fire_boomerang(owner_node: Node2D, direction: Vector2) -> void:
	# Чакрамы: урон по коридору к цели сразу и повторно на «возврате» через 0.25с.
	var origin := owner_node.global_position
	var outbound_damage := _rolled_damage(owner_node)
	var chakram_profile := _constellation_profile("chakram_return_execute_mark")
	for hit in _enemies_in_corridor(origin, direction, beam_width, attack_range):
		var outbound_target := hit["node"] as Node2D
		_damage_enemy(outbound_target, outbound_damage)
		if not chakram_profile.is_empty() and is_instance_valid(outbound_target):
			var params: Dictionary = chakram_profile.get("params", {})
			_arm_constellation_target_mark(outbound_target, "chakram", float(params.get("mark_seconds", 1.8)), float(params.get("return_bonus_cap", 0.30)), float(params.get("execute_threshold", 0.28)))
	var orb := _spawn_projectile_visual(origin + direction * 24.0, direction)
	_register_effect(orb)
	var far_point := origin + direction * attack_range
	var orb_tween := create_tween()
	orb_tween.tween_property(orb, "global_position", far_point, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# SCRUM-551: захват owner_node/orb (Node) в lambda интермиттентно «освобождался»
	# под быстрым create/free в balance-CSV. Резолвим по instance_id внутри + гвард.
	var owner_id := owner_node.get_instance_id()
	var orb_id := orb.get_instance_id()
	var weapon_self_id := get_instance_id()
	if return_arc_offset > 0.0:
		orb_tween.tween_callback(Callable(self, "_begin_boomerang_return_arc").bind(owner_id, orb_id, far_point, direction))
		return
	orb_tween.tween_property(orb, "global_position", origin, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	orb_tween.tween_callback(func() -> void:
		var w := instance_from_id(weapon_self_id) as Node
		var o := instance_from_id(owner_id) as Node2D
		if w != null and o != null and is_instance_valid(w) and is_instance_valid(o):
			w.call("_damage_boomerang_return", o.global_position, direction, w.call("_rolled_damage", o))
		var orb_node := instance_from_id(orb_id) as Node
		if w != null and is_instance_valid(w) and orb_node != null and is_instance_valid(orb_node):
			w.call("_release_effect", orb_node)
	)


# SCRUM-961 «Руна обратной дуги»: обратный проход чакрамов идёт по широкой дуге
# (+boomerang_return_width_mult к коридору) и бьёт больнее (+boomerang_return_damage_mult).
# Без ключей тождествен прежнему возврату.
func _damage_boomerang_return(origin: Vector2, direction: Vector2, amount: float) -> void:
	var return_width := beam_width * (1.0 + _owner_mod("boomerang_return_width_mult"))
	var return_damage := amount * (1.0 + _owner_mod("boomerang_return_damage_mult"))
	for hit in _enemies_in_corridor(origin, direction, return_width, attack_range):
		var enemy_node := hit["node"] as Node2D
		var return_event := _constellation_event("return", enemy_node, 0.0, {"constellation_consumer_event": true})
		var marked_damage := return_damage * _consume_constellation_target_mark(enemy_node, "chakram") if bool(return_event.get("triggered", false)) else return_damage
		_damage_enemy(enemy_node, marked_damage)


# SCRUM-894: разворот чакрамов — считаем дугу от точки разворота к текущей позиции
# героя, наносим return-урон вдоль дуги и ведём орб по той же кривой. Bound-метод
# вместо лямбды с захватом узлов (канон SCRUM-551), резолв по instance_id + гварды.
func _begin_boomerang_return_arc(owner_id: int, orb_id: int, far_point: Vector2, direction: Vector2) -> void:
	var owner_node := instance_from_id(owner_id) as Node2D
	var orb := instance_from_id(orb_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node) or not is_inside_tree():
		if orb != null and is_instance_valid(orb):
			_release_effect(orb)
		return
	var home := owner_node.global_position
	var control := _boomerang_return_control_point(far_point, home, direction)
	_damage_boomerang_return_arc(far_point, control, home, _rolled_damage(owner_node))
	if orb == null or not is_instance_valid(orb):
		return
	var arc_tween := create_tween()
	arc_tween.tween_method(Callable(self, "_step_orb_along_return_arc").bind(orb_id, far_point, control, home), 0.0, 1.0, 0.25)
	arc_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(orb_id))


# Контрольная точка возврата: середина хорды + смещение в ЛЕВУЮ сторону
# относительно направления броска (в экранных координатах Godot y вниз,
# левая нормаль = (dir.y, -dir.x)).
func _boomerang_return_control_point(from_point: Vector2, home: Vector2, direction: Vector2) -> Vector2:
	var left_normal := Vector2(direction.y, -direction.x)
	return (from_point + home) * 0.5 + left_normal * return_arc_offset


func _quadratic_bezier_point(from_point: Vector2, control: Vector2, to_point: Vector2, t: float) -> Vector2:
	var inv := 1.0 - t
	return from_point * (inv * inv) + control * (2.0 * inv * t) + to_point * (t * t)


# Возврат-урон вдоль дуги: сэмплируем кривую полилинией и бьём каждого врага
# коридора НЕ БОЛЕЕ ОДНОГО РАЗА (дедуп по instance_id — per-cast/per-target гейт).
# Артефактные ключи SCRUM-961 (ширина/урон возврата) продолжают действовать.
func _damage_boomerang_return_arc(from_point: Vector2, control: Vector2, home: Vector2, amount: float) -> void:
	var return_width := beam_width * (1.0 + _owner_mod("boomerang_return_width_mult"))
	var return_damage := amount * (1.0 + _owner_mod("boomerang_return_damage_mult"))
	var hit_ids := {}
	var previous := from_point
	for step in range(1, BOOMERANG_ARC_SAMPLES + 1):
		var point := _quadratic_bezier_point(from_point, control, home, float(step) / float(BOOMERANG_ARC_SAMPLES))
		for enemy_raw in TARGET_QUERY.in_segment(self, previous, point, return_width):
			var enemy_node := enemy_raw as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			var enemy_id := enemy_node.get_instance_id()
			if hit_ids.has(enemy_id):
				continue
			hit_ids[enemy_id] = true
			var return_event := _constellation_event("return", enemy_node, 0.0, {"constellation_consumer_event": true})
			var marked_damage := return_damage * _consume_constellation_target_mark(enemy_node, "chakram") if bool(return_event.get("triggered", false)) else return_damage
			_damage_enemy(enemy_node, marked_damage)
		previous = point


func _step_orb_along_return_arc(progress: float, orb_id: int, from_point: Vector2, control: Vector2, home: Vector2) -> void:
	var orb := instance_from_id(orb_id) as Node2D
	if orb == null or not is_instance_valid(orb):
		return
	orb.global_position = _quadratic_bezier_point(from_point, control, home, clampf(progress, 0.0, 1.0))


func _fire_stab_flurry(owner_node: Node2D, direction: Vector2) -> void:
	# Быстрый ближний веер: несколько целей в короткой зоне перед персонажем.
	# SCRUM-894: при point_blank_radius > 0 (Теневые кинжалы) серия дополнительно
	# покрывает врагов вплотную ВОКРУГ героя (под ногами/за спиной) — мёртвой зоны
	# в упор нет. Лимит целей общий (projectile_count) — бесплатных хитов нет.
	var slash := AttackVfx.slash(owner_node, direction, attack_range, visual_color)
	_register_effect(slash)
	if point_blank_radius > 0.0:
		AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, point_blank_radius, Color(visual_color.r, visual_color.g, visual_color.b, 0.20), false)
	var candidates := []
	for enemy_node in TARGET_QUERY.enemies(self):
		if not is_instance_valid(enemy_node):
			continue
		var distance_squared := owner_node.global_position.distance_squared_to(enemy_node.global_position)
		var inside_point_blank := point_blank_radius > 0.0 and distance_squared <= point_blank_radius * point_blank_radius
		if not inside_point_blank and not _is_enemy_inside_wave(owner_node.global_position, enemy_node.global_position, direction):
			continue
		candidates.append({
			"node": enemy_node,
			"distance": distance_squared,
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var damage_value := _rolled_damage(owner_node)
	var hit_limit := maxi(projectile_count, 1)
	var hit_count := 0
	for candidate in candidates:
		if hit_count >= hit_limit:
			break
		var enemy_node := candidate["node"] as Node2D
		if dot_ticks > 0:
			_damage_enemy_with_dot(enemy_node, damage_value, owner_node)
		else:
			_damage_enemy(enemy_node, damage_value)
		hit_count += 1
	# SCRUM-894 «Рывок темпа»: серия, задевшая врага, даёт короткий бафф
	# скорости+уворота. Величины/кулдаун — data-driven из weapon_config владельца
	# (Player.trigger_flurry_tempo — no-op у оружий без flurry_tempo_* ключей).
	if hit_count > 0 and owner_node.has_method("trigger_flurry_tempo"):
		owner_node.call("trigger_flurry_tempo")


func _damage_enemies_in_corridor(origin: Vector2, direction: Vector2, amount: float, width_override := -1.0) -> void:
	# SCRUM-916: width_override позволяет бить ПОЛНУЮ ширину коридора компрессии
	# (suppression_width Пресса), не только центральный beam_width.
	var corridor_hit_width := width_override if width_override > 0.0 else beam_width
	for hit in _enemies_in_corridor(origin, direction, corridor_hit_width, attack_range):
		_damage_enemy(hit["node"], amount)


func _spawn_damage_pool(pool_position: Vector2, tick_damage: float) -> void:
	# Ядовитое облако химика: тики по врагам в радиусе, группа player_weapon_effects.
	# SCRUM-944: pool_tick_damage_multiplier — per-weapon скалер (зеркален в бюджете).
	tick_damage *= POOL_TICK_DAMAGE_MULTIPLIER * pool_tick_damage_multiplier
	var combo_target := _find_combo_cloud(pool_position)
	var pool := Node2D.new()
	pool.name = "ChemistPoisonPool"
	_register_effect(pool)
	pool.add_to_group("chemist_clouds")
	pool.set_meta("pool_weapon_owner", get_instance_id())
	pool.set_meta("pool_duration", pool_duration)
	pool.set_meta("pool_tick_interval", pool_tick_interval)
	if pool_element != "":
		pool.set_meta("pool_element", pool_element)
	# SCRUM-553: наземная декаль — пул рисуется ПОД всеми боевыми сущностями
	# (игрок/монстры/пикапы z≈0), но над фоном (-100) и бордером (-20) арены.
	# Абсолютный слой (z_as_relative=false), чтобы не зависеть от z родителя-контейнера.
	pool.z_as_relative = false
	pool.z_index = GROUND_POOL_Z
	var visual := Node2D.new()
	visual.name = "PoolVisual"
	var pool_sprite := Sprite2D.new()
	pool_sprite.name = "PoolSprite"
	pool_sprite.texture = _pool_visual_texture()
	# SCRUM-944 (визуальный контракт кита): pool_translucent-лужи (кислота) всегда
	# полупрозрачны — поле боя/UI читаются сквозь зону; SCRUM-961 «Прозрачная
	# кислота» дополнительно подчёркивает опасность яркой danger-кромкой при спавне.
	var clear_pool := weapon_id == "acid_flask" and _owner_mod("pool_duration_mult") > 0.0
	var pool_alpha := 0.82
	if pool_translucent:
		pool_alpha = 0.50
	elif clear_pool:
		pool_alpha = 0.58
	pool_sprite.modulate = Color(1.0, 1.0, 1.0, pool_alpha)
	var pool_scale := (aoe_radius * 1.42) / 256.0
	pool_sprite.scale = Vector2.ONE * pool_scale
	visual.add_child(pool_sprite)
	pool.add_child(visual)
	_projectile_parent().add_child(pool)
	pool.global_position = pool_position
	if clear_pool:
		AttackVfx.ring_pulse(_projectile_parent(), pool_position, aoe_radius * 0.78, Color(0.70, 1.0, 0.30, 0.55), true)
	_retire_excess_damage_pools(pool)
	if combo_target != null:
		_trigger_chemist_combo(pool, combo_target, tick_damage)

	var visual_tween := pool.create_tween()
	visual_tween.set_loops()
	visual_tween.tween_property(pool_sprite, "scale", Vector2.ONE * pool_scale * 1.045, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	visual_tween.parallel().tween_property(pool_sprite, "rotation", 0.045, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	visual_tween.tween_property(pool_sprite, "scale", Vector2.ONE * pool_scale * 0.985, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	visual_tween.parallel().tween_property(pool_sprite, "rotation", -0.035, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# SCRUM-649: гарантируем минимум 1 тик — при коротком pool_duration (< tick interval)
	# floor давал 0, и заспавненный пул не наносил урона (потраченная впустую атака).
	var tick_count := maxi(int(floor(pool_duration / maxf(pool_tick_interval, 0.2))), 1)
	var pool_tween := pool.create_tween()
	var pool_id := pool.get_instance_id()
	var weapon_id := get_instance_id()
	for tick_index in range(tick_count):
		pool_tween.tween_interval(pool_tick_interval)
		pool_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_pool := instance_from_id(pool_id) as Node2D
			if current_weapon != null and current_pool != null:
				# SCRUM-903: терновая зона — слоу + повторные ФИЗИЧЕСКИЕ хиты с
				# капом на врага/зону (не dot-тик; см. _briar_zone_tick).
				if bool(current_weapon.get("briar_zone")):
					current_weapon.call("_briar_zone_tick", current_pool)
				else:
					# SCRUM-944: лужа передаёт себя тику — контактные заряды с per-pool
					# идентичностью («одна лужа = один вечный заряд», без повторов).
					current_weapon.call("_damage_enemies_in_pool", current_pool.global_position, aoe_radius * 0.7, tick_damage, current_pool)
		)
	pool_tween.tween_property(pool_sprite, "modulate:a", 0.0, 0.2)
	pool_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_pool := instance_from_id(pool_id) as Node
		if current_pool == null:
			return
		if current_weapon != null:
			current_pool.remove_from_group("chemist_clouds")
			current_weapon.call("_release_effect", current_pool)
		else:
			current_pool.queue_free()
	)


func _pool_visual_texture() -> Texture2D:
	match pool_element:
		"spark":
			return SPARK_POOL_TEXTURE
		"briar":
			return BRIAR_POOL_TEXTURE
		_:
			return POISON_POOL_TEXTURE


func _find_combo_cloud(pool_position: Vector2) -> Node2D:
	if not combo_clouds:
		return null
	for cloud in get_tree().get_nodes_in_group("chemist_clouds"):
		var cloud_node := cloud as Node2D
		if cloud_node == null or not is_instance_valid(cloud_node):
			continue
		var cloud_element := str(cloud_node.get_meta("pool_element", ""))
		if pool_element != "" and cloud_element == pool_element:
			continue
		if cloud_node.global_position.distance_squared_to(pool_position) <= pow(aoe_radius * 0.95, 2.0):
			return cloud_node
	return null


## `direct_share` — доля БАЗОВОЙ смешанной вспышки. Пул-канал (встреча двух луж)
## существует и без созвездия, поэтому платит полную долю; реагентная пара пыли
## (FAN-2238) базового аналога не имеет и приходит с 0.0 — там весь урон реакции
## равен объявленному в манифесте `combo_damage_ratio` финала, и без финала
## оружие не получает ничего.
func _trigger_chemist_combo(new_cloud: Node2D, old_cloud: Node2D, tick_damage: float, direct_share := 1.0) -> void:
	if bool(new_cloud.get_meta("constellation_powder_reacted", false)) or bool(old_cloud.get_meta("constellation_powder_reacted", false)):
		return
	new_cloud.set_meta("constellation_powder_reacted", true)
	old_cloud.set_meta("constellation_powder_reacted", true)
	var combo_position := (new_cloud.global_position + old_cloud.global_position) * 0.5
	var combo_radius := aoe_radius * 1.05
	var combo_damage := maxf(damage, tick_damage * 5.5) * pool_direct_damage_multiplier
	AttackVfx.orb_burst(_projectile_parent(), combo_position, combo_radius, Color(1.0, 0.75, 0.16, 0.50))
	if direct_share > 0.0:
		_damage_enemies_in_circle_capped(combo_position, combo_radius, combo_damage * direct_share, POOL_PROJECTILE_FULL_TARGETS, POOL_PROJECTILE_TARGET_DIMINISH)
	var combo_target := TARGET_QUERY.nearest(self, combo_position, combo_radius)
	var reaction := _constellation_event("cross_reagent", combo_target, 0.0)
	if bool(reaction.get("triggered", false)):
		_damage_enemies_in_circle_capped(combo_position, combo_radius, combo_damage * _constellation_result_param(reaction, "combo_damage_ratio", 0.48), POOL_PROJECTILE_FULL_TARGETS, POOL_PROJECTILE_TARGET_DIMINISH)


# FAN-2238: окно жизни реагентного следа взрыва. Больше базового fire_interval
# пыли (0.62) — соседние броски успевают встретиться, но пауза в стрельбе след
# гасит. Это темп продакшен-оружия, а не балансный кап финала: манифестные капы
# (reactions_per_cloud / combo_damage_ratio / same_reagent_reaction) живут в
# schema-6 и читаются из профиля.
const POWDER_REAGENT_TRACE_SECONDS := 0.9


## FAN-2238: продакшен-вход финала «Несовместимые реагенты». Взрывная пыль давно
## идёт прямым AoE без луж, поэтому облачный вход `_spawn_damage_pool` для неё
## мёртв — реакцию поднимает РЕАЛЬНЫЙ прилёт снаряда. Каждый взрыв оставляет
## короткий инертный след своего реагента (не `chemist_clouds`, без тиков, DoT и
## статусов), и соседний взрыв другого реагента внутри следа расходует пару на
## одну реакцию (`reactions_per_cloud` = 1 через латч `_trigger_chemist_combo`).
## Без купленного финала след не создаётся вовсе.
func _mark_powder_reagent_impact(impact_position: Vector2, reagent: int) -> void:
	var profile := _constellation_profile("powder_cross_reagent_combo")
	if profile.is_empty():
		return
	var params: Dictionary = profile.get("params", {})
	var previous := _powder_reagent_trace
	var trace := _spawn_powder_reagent_trace(impact_position, reagent)
	_powder_reagent_trace = trace
	if previous == null or not is_instance_valid(previous):
		return
	if Time.get_ticks_msec() > int(previous.get_meta("powder_reagent_until_msec", 0)):
		return
	var cross_reagent := int(previous.get_meta("powder_reagent", reagent)) != reagent
	if not cross_reagent and not bool(params.get("same_reagent_reaction", false)):
		return
	if previous.global_position.distance_squared_to(impact_position) > pow(aoe_radius, 2.0):
		return
	_trigger_chemist_combo(trace, previous, 0.0, 0.0)
	_release_effect(previous)
	_release_effect(trace)
	_powder_reagent_trace = null


func _spawn_powder_reagent_trace(trace_position: Vector2, reagent: int) -> Node2D:
	var trace := Node2D.new()
	trace.name = "PowderReagentTrace"
	trace.set_meta("powder_reagent", reagent)
	trace.set_meta("powder_reagent_until_msec", Time.get_ticks_msec() + int(POWDER_REAGENT_TRACE_SECONDS * 1000.0))
	_register_effect(trace)
	_projectile_parent().add_child(trace)
	trace.global_position = trace_position
	var expiry := trace.create_tween()
	expiry.tween_interval(POWDER_REAGENT_TRACE_SECONDS)
	expiry.tween_callback(Callable(self, "_release_effect").bind(trace))
	return trace


func _find_closest_enemies(owner_node: Node2D, count: int) -> Array:
	return TARGET_QUERY.nearest_many(self, owner_node.global_position, attack_range, count)


func _launch_aoe_projectile(owner_node: Node2D, target: Node2D, direction: Vector2, reagent := 0) -> void:
	var target_position: Vector2 = owner_node.global_position + direction * min(attack_range, 360.0)
	if target != null:
		target_position = target.global_position
	elif _owner_uses_cursor_aim(owner_node) and owner_node.has_method("attack_aim_position"):
		target_position = owner_node.call("attack_aim_position", attack_range)

	var projectile := _spawn_projectile_visual(owner_node.global_position + direction * 28.0, target_position - owner_node.global_position)
	_register_effect(projectile)

	var travel_time: float = clamp(projectile.global_position.distance_to(target_position) / max(projectile_speed, 1.0), 0.08, 0.45)
	var tween := create_tween()
	var projectile_id := projectile.get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var weapon_id := get_instance_id()
	tween.tween_property(projectile, "global_position", target_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		if current_weapon != null:
			var current_owner := instance_from_id(owner_id) as Node2D
			var explosion_damage := damage if current_owner == null else float(current_weapon.call("_rolled_damage", current_owner))
			current_weapon.call("_damage_aoe_projectile_explosion", target_position, aoe_radius, explosion_damage)
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), target_position, aoe_radius, current_weapon.call("_projectile_impact_color"))
			# FAN-2238: реагентный след ставит РЕАЛЬНЫЙ прилёт снаряда; без финала
			# созвездия вызов сразу выходит и базовое оружие не меняется.
			current_weapon.call("_mark_powder_reagent_impact", target_position, reagent)
			# SCRUM-941: старый хук «Зеркальной страницы» удалён — dark_book ушёл
			# с aoe_projectile на dark_mirror_blast (зеркало теперь база оружия,
			# артефакт репозиционирован в book_mirror_echo).
			# SCRUM-961 «Восстановительный пар» (SCRUM-900: хук на взрыве зелья —
			# restore_potion теперь aoe_projectile, а не drain_link).
			if current_owner != null and str(current_weapon.get("weapon_id")) == "restore_potion" and float(current_weapon.call("_owner_mod", "restore_vapor_power")) > 0.0:
				current_weapon.call("_spawn_restore_vapor", current_owner, target_position, explosion_damage)
			# SCRUM-961 «Летучая пыль»: blast_powder без облака-DoT (трейд на темп).
			if leaves_pool and not bool(current_weapon.call("_volatile_powder_active")):
				var parameters_raw = current_owner.get("derived_parameters") if current_owner != null else null
				var tick_damage := 2.0
				if parameters_raw is Dictionary:
					tick_damage = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)), 1.0)
				current_weapon.call("_spawn_damage_pool", target_position, tick_damage)
			var current_projectile := instance_from_id(projectile_id) as Node
			if current_projectile != null:
				current_weapon.call("_release_effect", current_projectile)
	)


func _fire_curse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	if target == null:
		var miss_target: Vector2 = owner_node.global_position + direction * min(attack_range, 260.0)
		var miss_skull := AttackVfx.curse_skull(_projectile_parent(), owner_node.global_position + direction * 24.0, miss_target, visual_color, 0.22, Callable(), _projectile_visual_profile())
		_register_effect(miss_skull)
		return

	var target_position := target.global_position
	var rolled := _rolled_damage(owner_node)
	var target_id := target.get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var weapon_id := get_instance_id()
	var skull := AttackVfx.curse_skull(_projectile_parent(), owner_node.global_position + direction * 24.0, target_position, visual_color, 0.20, func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		if current_weapon == null:
			return
		var current_target := instance_from_id(target_id) as Node2D
		var current_owner := instance_from_id(owner_id) as Node2D
		if current_target != null:
			current_weapon.call("_damage_enemy_with_dot", current_target, rolled, current_owner)
		if aoe_radius > 0.0:
			current_weapon.call("_damage_enemies_in_circle_falloff", target_position, aoe_radius * 0.72, rolled * 0.42, current_weapon.get("damage_falloff"))
			AttackVfx.orb_burst(current_weapon.call("_projectile_parent"), target_position, aoe_radius * 0.72, current_weapon.call("_projectile_impact_color"))
	, _projectile_visual_profile())
	_register_effect(skull)


# ============================================================================
# SCRUM-939..941: кит Тёмного мага (цепь палочки / curse-прожиг черепа /
# зеркальные взрывы книги). Все лямбды в tween_callback заменены на
# Callable(self, "...").bind(...) (канон SCRUM-551 против freed-lambda).
# ============================================================================


# SCRUM-939: Тёмная палочка — видимый цепной/рикошет-снаряд.
func _fire_dark_chain_burst(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var first_target := target
	if first_target == null:
		first_target = _find_closest_enemy(owner_node, INF)
	if first_target == null:
		# Пустая арена: видимый снаряд «в никуда», урона нет.
		var miss := _spawn_projectile_visual(owner_node.global_position + direction * 24.0, direction)
		_register_effect(miss)
		var miss_tween := create_tween()
		miss_tween.tween_property(miss, "global_position", owner_node.global_position + direction * minf(attack_range, 300.0), 0.2)
		miss_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(miss.get_instance_id()))
		return
	# Цепь выбирается детерминированно в момент каста.
	var chain: Array = [first_target]
	var used := {first_target.get_instance_id(): true}
	var hop_origin: Vector2 = first_target.global_position
	# FAN-1893: прыжки цепи — не снаряды; generic «+1 снаряд» цепь не удлиняет
	# (длину растит только классовый артефакт wand_extra_chain).
	var chain_limit := maxi(chain_targets + int(_owner_mod("wand_extra_chain")), 1)
	for hop_index in range(chain_limit - 1):
		var next_target := _find_nearest_enemy_from(hop_origin, chain_hop_range, used)
		if next_target == null:
			break  # документированный fallback: цепь обрывается без повторов
		chain.append(next_target)
		used[next_target.get_instance_id()] = true
		hop_origin = next_target.global_position
	_launch_dark_chain_hop(owner_node.global_position + direction * 26.0, chain, 0, _rolled_damage(owner_node))


# Один видимый прыжок цепи: орб летит из точки предыдущего попадания в
# следующую цель; попадание резолвится по прилёту.
func _launch_dark_chain_hop(from_position: Vector2, chain: Array, hop_index: int, damage_value: float) -> void:
	if _effects_shutdown or hop_index >= chain.size():
		return
	var enemy_node := chain[hop_index] as Node2D
	if enemy_node == null or not is_instance_valid(enemy_node):
		# Цель умерла в полёте — цепь продолжает к следующей из той же точки.
		_launch_dark_chain_hop(from_position, chain, hop_index + 1, damage_value)
		return
	var target_position := enemy_node.global_position
	var orb := _spawn_projectile_visual(from_position, target_position - from_position)
	_register_effect(orb)
	var travel_time := clampf(from_position.distance_to(target_position) / maxf(projectile_speed, 1.0), 0.05, 0.30)
	var hop_tween := create_tween()
	hop_tween.tween_property(orb, "global_position", target_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop_tween.tween_callback(Callable(self, "_resolve_dark_chain_hit").bind(orb.get_instance_id(), chain, hop_index, damage_value))


func _resolve_dark_chain_hit(orb_id: int, chain: Array, hop_index: int, damage_value: float) -> void:
	if _effects_shutdown:
		return
	var orb := instance_from_id(orb_id) as Node2D
	if orb == null or not is_instance_valid(orb):
		return
	var impact_position := orb.global_position
	_release_effect(orb)
	var falloff := clampf(pierce_damage_falloff, 0.1, 1.0)
	var enemy_node := chain[hop_index] as Node2D
	if enemy_node != null and is_instance_valid(enemy_node):
		impact_position = enemy_node.global_position
		var hit_damage := damage_value * pow(falloff, float(hop_index))
		_damage_enemy(enemy_node, hit_damage)
		_constellation_event("pierce", enemy_node, hit_damage)
		_fire_dark_chain_hit_burst(enemy_node, impact_position, hit_damage * chain_burst_ratio * (1.0 + _owner_mod("wand_burst_bonus")))
	_launch_dark_chain_hop(impact_position, chain, hop_index + 1, damage_value)


# Малый бурст у точки попадания цепи: соседи жертвы получают долю урона хита.
# Прямой урон без он-хит проков (анти-каскад §8.4: бурст не рикошетит и не
# порождает новые бурсты); сама жертва исключена (уже получила прямой хит).
func _fire_dark_chain_hit_burst(victim: Node2D, center: Vector2, amount: float) -> void:
	if amount <= 0.0 or aoe_radius <= 0.0:
		return
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius, _projectile_impact_color())
	for enemy_node in TARGET_QUERY.in_radius(self, center, aoe_radius):
		if enemy_node == victim:
			continue
		if enemy_node.has_method("take_damage"):
			_call_take_damage(enemy_node, amount, {"damage_type": _weapon_damage_type()})


# SCRUM-940: Проклятый череп — ЧИСТОЕ проклятие, прямого урона нет.
func _fire_skull_curse_burn(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var target_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 300.0)
	if target != null:
		target_position = target.global_position
	elif _owner_uses_cursor_aim(owner_node) and owner_node.has_method("attack_aim_position"):
		target_position = owner_node.call("attack_aim_position", attack_range)
	var skull := AttackVfx.curse_skull(_projectile_parent(), owner_node.global_position + direction * 24.0, target_position, visual_color, 0.20, Callable(self, "_apply_skull_curse_zone").bind(target_position), _projectile_visual_profile())
	_register_effect(skull)


func _apply_skull_curse_zone(center: Vector2) -> void:
	if _effects_shutdown:
		return
	var owner_node := _owner_node()
	if owner_node == null:
		return
	AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, false)
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	# Документированный curse-пайплайн (SCRUM-940): сила тика = dot_damage *
	# curse_tick_multiplier * (1 + Интеллект * curse_int_scale). Интеллект
	# «углубляет» проклятие (канон identity), Знание/флэты дают dot_damage;
	# магические множители не участвуют. Зеркало — _budget_dot_dps.
	var owner_stats_raw = owner_node.get("stats")
	var owner_stats: Dictionary = owner_stats_raw if owner_stats_raw is Dictionary else {}
	var curse_depth := 1.0 + maxf(float(owner_stats.get("intelligence", 0.0)), 0.0) * maxf(curse_int_scale, 0.0)
	var tick_damage := maxf(float(parameters.get("dot_damage", 1.0)), 1.0) * maxf(curse_tick_multiplier, 0.0) * curse_depth
	var tick_speed := maxf(float(parameters.get("dot_speed", 1.0)), 0.2) * maxf(curse_tick_rate, 0.2)
	# Floor 0.1с зеркалит кламп StatusEffects.tick: выше ~10 тик/с прожиг не
	# ускоряется, но суммарный урон каста сохраняется (число тиков фиксировано).
	var tick_interval := maxf(1.0 / tick_speed, 0.1)
	var ticks := maxi(dot_ticks, 1)
	# +0.99 тика запаса: StatusEffects.tick списывает remaining ДО проверки
	# тика, и k-й тик реально срабатывает на первом кадре ПОСЛЕ k*interval —
	# с меньшим буфером последний тик терялся. +0.99 (а не +1.0) не даёт
	# родиться лишнему (ticks+1)-му тику на границе.
	var duration := (float(ticks) + 0.99) * tick_interval
	var cursed_count := 0
	var curse_burn_total := 0.0
	# FAN-1031 3c(b): крауд-проклятие ранжируется по дистанции от центра каста —
	# ближние status_full_targets прогорают полным тиком, дальний хвост толпы
	# диминишится (_status_fanout_factor). Кап бьёт крауд-runaway 20t (v3
	# cursed_skull 96.9k ≈21× медианы), НЕ трогая силу тика 1t/5t (identity кита).
	# Сентинел по умолчанию (без override) = factor 1.0 → прежнее поведение.
	for enemy_node in _status_fanout_order(center, TARGET_QUERY.in_radius(self, center, aoe_radius)):
		var target_tick := tick_damage * _status_fanout_factor(cursed_count)
		# FAN-1031 3c-final fix (peer review MINOR): жёсткий кап ШИРИНЫ = skip. Цель за
		# status_max_targets (factor==0) НЕ получает 0-уронный skull_curse (refresh затирал бы
		# живое проклятие) и НЕ кормит ульту — как в bio-ветках. order отсортирован → break.
		if target_tick <= 0.0:
			break
		StatusEffects.apply_status(enemy_node, "skull_curse", {
			"duration": duration,
			"dot_damage": target_tick,
			"dot_interval": tick_interval,
			"max_stacks": 1,
			"stack_mode": "refresh",
			"marker_color": Color(0.78, 0.16, 1.0, 1.0),
			# SCRUM-1007: тики проклятия — урон игрока (атрибуция он-килл trait).
			"tick_feedback": {"damage_type": "dot", "player_owned": true, "curse": true},
		})
		enemy_node.set_meta(_constellation_mark_key("skull_curse"), {
			"status": {
				"duration": duration,
				"dot_damage": target_tick,
				"dot_interval": tick_interval,
				"max_stacks": 1,
				"stack_mode": "refresh",
				"marker_color": Color(0.78, 0.16, 1.0, 1.0),
				"tick_feedback": {"damage_type": "dot", "player_owned": true, "curse": true},
			},
			"depth": 0,
		})
		if enemy_node is Node2D:
			HazardVfx.dot_tick(enemy_node, Color(visual_color.r, visual_color.g, visual_color.b, 1.0))
		curse_burn_total += target_tick
		cursed_count += 1
	# Прямого урона нет → on_weapon_hit не зовётся; заряд ульты кормим явно
	# ожидаемым прожигом каста (половинный вес, без он-хит проков/вампиризма).
	# FAN-1031 3c-final fix (peer review MINOR): фид считаем от ФАКТИЧЕСКОГО прожига каста на
	# толпе (Σ диминишированных тиков = tick_damage × Σfactor), а НЕ tick_damage × cursed_count —
	# status fan-out кап (cursed_skull 4/1.0) теперь корректно урезает крауд-фид ульты.
	if cursed_count > 0 and owner_node.has_method("on_curse_applied"):
		owner_node.call("on_curse_applied", curse_burn_total * float(ticks) * 0.5)


# SCRUM-941: Книга тьмы — зеркальные AoE-взрывы вокруг мага.
func _fire_dark_mirror_blast(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var primary_targets: Array = []
	if target != null:
		# FAN-1893: единица атаки книги — зеркальная ПАРА (2 сферы); «+1 снаряд»
		# дал бы сразу две, поэтому generic-ось книгой не потребляется
		# (real_projectile_count 0) и пара всегда одна.
		primary_targets = _find_closest_enemies(owner_node, 1)
	var target_positions: Array[Vector2] = []
	if primary_targets.is_empty():
		var aim_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 360.0)
		if _owner_uses_cursor_aim(owner_node) and owner_node.has_method("attack_aim_position"):
			aim_position = owner_node.call("attack_aim_position", attack_range)
		target_positions.append(aim_position)
	else:
		for target_node in primary_targets:
			var enemy_node := target_node as Node2D
			if enemy_node != null and is_instance_valid(enemy_node):
				target_positions.append(enemy_node.global_position)
	if target_positions.is_empty():
		return
	_constellation_mirror_cast_token += 1
	var cast_token := _constellation_mirror_cast_token
	_constellation_mirror_casts[cast_token] = {"pending_pairs": target_positions.size(), "collapsed": false}
	for target_position in target_positions:
		_launch_dark_mirror_pair(owner_node, target_position, cast_token)


func _launch_dark_mirror_pair(owner_node: Node2D, target_position: Vector2, cast_token := 0) -> void:
	if cast_token <= 0:
		_constellation_mirror_cast_token += 1
		cast_token = _constellation_mirror_cast_token
		_constellation_mirror_casts[cast_token] = {"pending_pairs": 1, "collapsed": false}
	var mirror_position: Vector2 = owner_node.global_position * 2.0 - target_position
	var damage_value := _rolled_damage(owner_node)
	_constellation_mirror_pair_token += 1
	var pair_token := _constellation_mirror_pair_token
	_constellation_mirror_pairs[pair_token] = {
		"resolved": 0,
		"positions": [],
		"base_damage": damage_value,
		"cast_token": cast_token,
	}
	var to_target := (target_position - owner_node.global_position).normalized()
	if to_target.length_squared() <= 0.001:
		to_target = Vector2.RIGHT
	_launch_dark_mirror_orb(owner_node.global_position + to_target * 28.0, target_position, damage_value, pair_token)
	_launch_dark_mirror_orb(owner_node.global_position - to_target * 28.0, mirror_position, damage_value * maxf(mirror_damage_ratio, 0.0), pair_token)


func _launch_dark_mirror_orb(start: Vector2, blast_position: Vector2, blast_damage: float, pair_token: int) -> void:
	if blast_damage <= 0.0:
		return
	var orb := _spawn_projectile_visual(start, blast_position - start)
	_register_effect(orb)
	var travel_time := clampf(start.distance_to(blast_position) / maxf(projectile_speed, 1.0), 0.08, 0.45)
	var orb_tween := create_tween()
	orb_tween.tween_property(orb, "global_position", blast_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	orb_tween.tween_callback(Callable(self, "_resolve_dark_mirror_blast").bind(orb.get_instance_id(), blast_position, blast_damage, pair_token))


func _resolve_dark_mirror_blast(orb_id: int, blast_position: Vector2, blast_damage: float, pair_token := 0) -> void:
	if _effects_shutdown:
		return
	var orb := instance_from_id(orb_id) as Node2D
	if orb == null or not is_instance_valid(orb):
		return
	_release_effect(orb)
	AttackVfx.orb_burst(_projectile_parent(), blast_position, aoe_radius, _projectile_impact_color())
	var pair_probe = _constellation_mirror_pairs.get(pair_token, {})
	var cast_probe := int((pair_probe as Dictionary).get("cast_token", 0)) if pair_probe is Dictionary else 0
	_damage_dark_mirror_explosion(blast_position, aoe_radius, blast_damage, cast_probe, AOE_PROJECTILE_FULL_TARGETS, AOE_PROJECTILE_TARGET_DIMINISH)
	var pair_raw = _constellation_mirror_pairs.get(pair_token, {})
	if pair_raw is Dictionary and not (pair_raw as Dictionary).is_empty():
		var pair: Dictionary = pair_raw
		var positions_raw = pair.get("positions", [])
		var positions: Array = positions_raw if positions_raw is Array else []
		positions.append(blast_position)
		pair["positions"] = positions
		pair["resolved"] = int(pair.get("resolved", 0)) + 1
		if int(pair["resolved"]) >= 2 and positions.size() >= 2:
			var cast_token := int(pair.get("cast_token", 0))
			var cast_raw = _constellation_mirror_casts.get(cast_token, {})
			var cast_state: Dictionary = cast_raw if cast_raw is Dictionary else {}
			if not bool(cast_state.get("collapsed", false)):
				var midpoint := (Vector2(positions[0]) + Vector2(positions[1])) * 0.5
				var midpoint_target := TARGET_QUERY.nearest(self, midpoint, aoe_radius)
				var collapse := _constellation_event("mirror_midpoint", midpoint_target, 0.0)
				if bool(collapse.get("triggered", false)):
					var collapse_damage := float(pair.get("base_damage", blast_damage)) * _constellation_result_param(collapse, "collapse_damage_ratio", 0.42)
					_damage_dark_mirror_explosion(midpoint, aoe_radius, collapse_damage, cast_token, 1, 1.0)
					cast_state["collapsed"] = true
			cast_state["pending_pairs"] = maxi(int(cast_state.get("pending_pairs", 1)) - 1, 0)
			if int(cast_state["pending_pairs"]) <= 0:
				_constellation_mirror_casts.erase(cast_token)
			else:
				_constellation_mirror_casts[cast_token] = cast_state
			_constellation_mirror_pairs.erase(pair_token)
		else:
			_constellation_mirror_pairs[pair_token] = pair
	# SCRUM-961 «Зеркальная страница» (репозиционирована под новый кит): взрыв
	# отдаётся эхом на долю урона; эхо НЕ зеркалится и НЕ эхоится повторно.
	var echo_ratio := _owner_mod("book_mirror_echo")
	if echo_ratio > 0.0:
		var echo_tween := create_tween()
		echo_tween.tween_interval(0.22)
		echo_tween.tween_callback(Callable(self, "_resolve_dark_mirror_echo").bind(blast_position, blast_damage * clampf(echo_ratio, 0.0, 1.0)))


func _damage_dark_mirror_explosion(origin: Vector2, radius: float, amount: float, cast_token: int, full_targets: int, diminish: float) -> void:
	var cast_raw = _constellation_mirror_casts.get(cast_token, {})
	if not cast_raw is Dictionary or (cast_raw as Dictionary).is_empty():
		return
	var cast_state: Dictionary = cast_raw
	var hit_counts_raw = cast_state.get("hit_counts", {})
	var hit_counts: Dictionary = hit_counts_raw if hit_counts_raw is Dictionary else {}
	var enemies: Array = TARGET_QUERY.in_radius(self, origin, radius)
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		var enemy := enemies[index] as Node2D
		var enemy_id := enemy.get_instance_id()
		if int(hit_counts.get(enemy_id, 0)) >= 3:
			continue
		var factor := 1.0
		if index >= full_targets:
			factor = 1.0 / (1.0 + float(index - full_targets + 1) * diminish)
		_damage_enemy(enemy, amount * factor, index < full_targets)
		hit_counts[enemy_id] = int(hit_counts.get(enemy_id, 0)) + 1
	cast_state["hit_counts"] = hit_counts
	_constellation_mirror_casts[cast_token] = cast_state


func _resolve_dark_mirror_echo(blast_position: Vector2, echo_damage: float) -> void:
	if _effects_shutdown or echo_damage <= 0.0:
		return
	AttackVfx.orb_burst(_projectile_parent(), blast_position, aoe_radius * 0.8, Color(visual_color.r, visual_color.g, visual_color.b, visual_color.a * 0.7))
	_damage_aoe_projectile_explosion(blast_position, aoe_radius * 0.8, echo_damage)


func _fire_beam(owner_node: Node2D, direction: Vector2) -> void:
	# Веер из beam_count лучей с шагом beam_fan_degrees, центрированный на цели.
	# FAN-1893: луч — не снаряд; generic «+1 снаряд» веер лучей не расширяет.
	var count := maxi(beam_count, 1)
	_emit_weapon_animation_event(owner_node, "channel", 0.16, direction, {"beam_count": count})
	for beam_index in range(count):
		var fan_offset := 0.0
		if count > 1:
			fan_offset = deg_to_rad(beam_fan_degrees) * (float(beam_index) - float(count - 1) * 0.5)
		_fire_single_beam(owner_node, direction.rotated(fan_offset))


func _fire_dot_beam(owner_node: Node2D, direction: Vector2) -> void:
	# FAN-1893: луч — не снаряд; generic «+1 снаряд» веер лучей не расширяет.
	var count := maxi(beam_count, 1)
	_emit_weapon_animation_event(owner_node, "channel", maxf(0.16, float(maxi(dot_ticks, 1)) * 0.04), direction, {"beam_count": count, "dot_ticks": dot_ticks})
	for beam_index in range(count):
		var fan_offset := 0.0
		if count > 1:
			fan_offset = deg_to_rad(beam_fan_degrees) * (float(beam_index) - float(count - 1) * 0.5)
		_fire_single_dot_beam(owner_node, direction.rotated(fan_offset))


func _fire_single_beam(owner_node: Node2D, direction: Vector2) -> void:
	var start := owner_node.global_position + direction * 26.0
	var finish := owner_node.global_position + direction * attack_range
	var beam_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
	_register_effect(beam_visual)

	var hits := []
	for hit in _enemies_in_corridor(start, direction, beam_width, attack_range):
		hits.append(hit)

	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["forward"]) < float(b["forward"])
	)

	var damage_value := _rolled_damage(owner_node)
	var hit_count := 0
	var hit_limit := _effective_pierce_count()
	var falloff := clampf(pierce_damage_falloff, 0.1, 1.0)
	# SCRUM-939: хук «Цепной палочки» (wand_chain_blasts) удалён — dark_wand
	# ушёл с beam на dark_chain_burst, артефакт репозиционирован (wand_extra_chain).
	# SCRUM-910: moon-сплит переехал из beam-хука в собственный режим
	# moon_split_shot (_fire_moon_split_shot) — beam снова универсален.
	for hit in hits:
		if hit_count >= hit_limit:
			break
		_damage_enemy(hit["node"], damage_value * pow(falloff, float(hit_count)))
		hit_count += 1


# SCRUM-910 «Лунный арбалет»: одиночный физический болт в цель; после попадания
func _fire_moon_split_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "channel", 0.16, direction, {"split_count": split_count})
	var primary := target
	if primary == null or not is_instance_valid(primary):
		primary = _find_closest_enemy(owner_node)
	var start := owner_node.global_position + direction * 26.0
	if primary == null:
		# Холостой болт: цели нет — рисуем трассер по направлению, урона нет.
		var miss_finish := owner_node.global_position + direction * attack_range
		var miss_visual := AttackVfx.projectile_trace(_projectile_parent(), start, miss_finish, visual_color, _projectile_visual_profile(), 0.14)
		_register_effect(miss_visual)
		return
	var bolt_visual := AttackVfx.beam(_projectile_parent(), start, primary.global_position, beam_width, visual_color)
	_register_effect(bolt_visual)
	_register_effect(AttackVfx.projectile_trace(_projectile_parent(), start, primary.global_position, visual_color, _projectile_visual_profile(), 0.12))
	var damage_value := _rolled_damage(owner_node)
	_damage_enemy(primary, damage_value)
	if charge_seconds > 0.0 and _current_charge_multiplier >= maxf(charge_max_multiplier - 0.01, 1.0):
		var moon_mark := _constellation_event("full_charge", primary, 0.0, {"constellation_consumer_event": true})
		if bool(moon_mark.get("triggered", false)) and is_instance_valid(primary):
			_arm_constellation_target_mark(primary, "moon", _constellation_result_param(moon_mark, "mark_seconds", 4.0), _constellation_result_param(moon_mark, "bonus_damage_cap", 0.28))
	var split_targets := maxi(split_count + int(_owner_mod("moon_split_targets")), 0)
	if split_targets <= 0 or not is_instance_valid(primary):
		return
	var excluded := {primary.get_instance_id(): true}
	for branch_raw in TARGET_QUERY.nearest_many(self, primary.global_position, maxf(aoe_radius, 120.0), split_targets, excluded):
		var branch_target := branch_raw as Node2D
		if branch_target == null or not is_instance_valid(branch_target):
			continue
		var branch := AttackVfx.beam(_projectile_parent(), primary.global_position, branch_target.global_position, beam_width * 0.55, Color(visual_color.r, visual_color.g, visual_color.b, 0.36))
		_register_effect(branch)
		_register_effect(AttackVfx.projectile_trace(_projectile_parent(), primary.global_position, branch_target.global_position, visual_color, _projectile_visual_profile(), 0.10))
		_damage_enemy(branch_target, damage_value)


# SCRUM-911 «Грозовой длинный лук»: дальнобойный КОНУС пробивающих стрел.
func _fire_storm_pierce_cone(owner_node: Node2D, direction: Vector2) -> void:
	var arrow_count := maxi(beam_count + _extra_projectiles(), 1)
	_emit_weapon_animation_event(owner_node, "channel", 0.18, direction, {"beam_count": arrow_count, "cone_degrees": cone_degrees})
	_spawn_storm_longbow_release_vfx(owner_node, direction)
	var damage_value := _rolled_damage(owner_node)
	var hit_limit := _effective_pierce_count()
	var falloff := clampf(pierce_damage_falloff, 0.1, 1.0)
	var hit_ids := {}
	for arrow_index in range(arrow_count):
		var fan_offset := 0.0
		if arrow_count > 1:
			fan_offset = deg_to_rad(cone_degrees) * (float(arrow_index) / float(arrow_count - 1) - 0.5)
		var arrow_direction := direction.rotated(fan_offset)
		var start := owner_node.global_position + arrow_direction * 26.0
		var finish := owner_node.global_position + arrow_direction * attack_range
		var arrow_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
		_register_effect(arrow_visual)
		_register_effect(AttackVfx.projectile_trace(_projectile_parent(), start, finish, visual_color, _projectile_visual_profile(), 0.16))

		var hits := []
		for hit in _enemies_in_corridor(start, arrow_direction, beam_width, attack_range):
			hits.append(hit)
		hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["forward"]) < float(b["forward"])
		)
		var pierced := 0
		var outer_primary: Node2D = null
		for hit in hits:
			if pierced >= hit_limit:
				break
			var enemy_node := hit["node"] as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			if hit_ids.has(enemy_node.get_instance_id()):
				pierced += 1  # тело уже поражено другой стрелой — бюджет пирса съеден
				continue
			hit_ids[enemy_node.get_instance_id()] = true
			_damage_enemy(enemy_node, damage_value * pow(falloff, float(pierced)))
			if outer_primary == null and (arrow_index == 0 or arrow_index == arrow_count - 1):
				outer_primary = enemy_node
			pierced += 1
		if outer_primary != null:
			var branch_result := _constellation_event("outer_hit", outer_primary, 0.0)
			if bool(branch_result.get("triggered", false)):
				var branch_target := TARGET_QUERY.nearest(self, outer_primary.global_position, maxf(aoe_radius, 160.0), hit_ids)
				if branch_target != null:
					hit_ids[branch_target.get_instance_id()] = true
					var branch_ratio := maxf(float(branch_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
					_register_effect(AttackVfx.beam(_projectile_parent(), outer_primary.global_position, branch_target.global_position, maxf(beam_width * 0.55, 10.0), visual_color))
					_call_take_damage(branch_target, damage_value * branch_ratio, {"damage_type": _weapon_damage_type(), "constellation_final": "longbow_outer_storm_branch"})


# SCRUM-1037: Animator-owned release is an additive one-shot cue. It is
# registered through the same lifecycle path as the five gameplay corridors;
# damage, hit queries, pierce budget and cooldown remain entirely above.
func _spawn_storm_longbow_release_vfx(owner_node: Node2D, direction: Vector2) -> void:
	if owner_node == null or not is_instance_valid(owner_node) or _effects_shutdown:
		return
	var release_vfx := STORM_LONGBOW_VOLLEY_VFX_SCENE.instantiate() as Node2D
	if release_vfx == null:
		return
	_projectile_parent().add_child(release_vfx)
	if release_vfx.has_method("configure"):
		release_vfx.call("configure", owner_node.global_position, direction, attack_range)
	_register_effect(release_vfx)


func _fire_single_dot_beam(owner_node: Node2D, direction: Vector2) -> void:
	# SCRUM-894: при close_contact_radius > 0 (Ядовитая струна) линия начинается
	# у самого героя, а враги вплотную (с любой стороны) становятся ПЕРВЫМИ
	# кандидатами — точка в упор не мёртвая. Пирс-лимит общий для близких и
	# коридорных целей — бесплатных дополнительных хитов нет.
	var beam_visual_offset := 6.0 if close_contact_radius > 0.0 else 26.0
	var start := owner_node.global_position + direction * beam_visual_offset
	var finish := owner_node.global_position + direction * attack_range
	var beam_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
	_register_effect(beam_visual)

	var hits := []
	var seen_ids := {}
	if close_contact_radius > 0.0:
		AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, close_contact_radius, Color(visual_color.r, visual_color.g, visual_color.b, 0.18), false)
		for enemy_node in TARGET_QUERY.in_radius(self, owner_node.global_position, close_contact_radius):
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			seen_ids[enemy_node.get_instance_id()] = true
			# Отрицательный forward ставит цели в упор впереди коридорных при сортировке.
			hits.append({
				"node": enemy_node,
				"forward": owner_node.global_position.distance_to(enemy_node.global_position) - close_contact_radius,
			})
	var corridor_origin := owner_node.global_position if close_contact_radius > 0.0 else start
	for hit in _enemies_in_corridor(corridor_origin, direction, beam_width, attack_range):
		var corridor_enemy := hit["node"] as Node2D
		if corridor_enemy != null and seen_ids.has(corridor_enemy.get_instance_id()):
			continue
		hits.append(hit)

	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["forward"]) < float(b["forward"])
	)

	var damage_value := _rolled_damage(owner_node)
	var hit_count := 0
	var hit_limit := _effective_pierce_count()
	var falloff := clampf(pierce_damage_falloff, 0.1, 1.0)
	var pierced_ids := {}
	var spread_center := finish
	for hit in hits:
		if hit_count >= hit_limit:
			break
		var hit_node := hit["node"] as Node2D
		_damage_enemy_with_dot(hit_node, damage_value * pow(falloff, float(hit_count)), owner_node)
		if hit_node != null and is_instance_valid(hit_node):
			pierced_ids[hit_node.get_instance_id()] = true
			spread_center = hit_node.global_position  # ядро спреда — самый глубокий пробитый (там плотнее толпа)
		hit_count += 1
	# FAN-1031 v7: ядовитый крауд-спред (assassin venom_wire) — крауд-канал В СУЩЕСТВУЮЩИХ капах,
	# ортогональный solo (пробитые исключены). Сентинел 0.0 → ветка не выполняется (no-op).
	if dot_beam_spread_ratio > 0.0 and hit_count > 0:
		_venom_crowd_spread(spread_center, damage_value * dot_beam_spread_ratio, pierced_ids)


# FAN-1031 v7: ядовитый крауд-спред dot_beam (assassin venom_wire crowd-ниша). Брызг яда
# по врагам ВНЕ пробитой линии (exclude_ids) — отдельный крауд-канал, ОРТОГОНАЛЬНЫЙ solo:
# на 1 цели она пробита → исключена → спреда нет → solo не двигается. Кап ШИРИНЫ — те же
# aoe_max_targets/aoe_full_targets/aoe_target_diminish, что и прямой AoE (сентинел <0 → дефолт),
# та же диминиш-формула по рангу удалённости. Урон прямой (не DoT), доля direct×spread_ratio.
func _venom_crowd_spread(center: Vector2, amount: float, exclude_ids: Dictionary) -> void:
	var enemies: Array = []
	for enemy_node in TARGET_QUERY.in_radius(self, center, aoe_radius):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if exclude_ids.has((enemy_node as Node).get_instance_id()):
			continue
		enemies.append(enemy_node)
	if enemies.is_empty():
		return
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius * 0.6, Color(visual_color.r, visual_color.g, visual_color.b, 0.28))
	var full_targets := aoe_full_targets if aoe_full_targets >= 0 else AOE_PROJECTILE_FULL_TARGETS
	var diminish := aoe_target_diminish if aoe_target_diminish >= 0.0 else AOE_PROJECTILE_TARGET_DIMINISH
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return center.distance_squared_to(a.global_position) < center.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		# Жёсткий кап ШИРИНЫ — дальше aoe_max_targets НОЛЬ (как у прямого AoE, coverage-контракт).
		if aoe_max_targets >= 0 and index >= aoe_max_targets:
			break
		var factor := 1.0
		if index >= full_targets:
			factor = 1.0 / (1.0 + float(index - full_targets + 1) * diminish)
		_damage_enemy(enemies[index] as Node2D, amount * factor)


func _fire_drain_link(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "channel", 0.20, direction, {"chain": true})
	var finish: Vector2 = owner_node.global_position + direction * min(attack_range, 520.0)
	if target != null:
		finish = target.global_position
	var start := owner_node.global_position + direction * 24.0
	var link_visual := AttackVfx.beam(_projectile_parent(), start, finish, beam_width, visual_color)
	_register_effect(link_visual)
	if target == null:
		return

	var damage_value := _rolled_damage(owner_node)
	if dot_ticks > 0:
		_damage_enemy_with_dot(target, damage_value, owner_node)
	else:
		_damage_enemy(target, damage_value)
	var extra_links := int(_extra_projectiles())
	if extra_links <= 0:
		return
	var used := {target.get_instance_id(): true}
	var previous_position := target.global_position
	for link_index in range(extra_links):
		var next_target := _find_nearest_enemy_from(previous_position, aoe_radius, used)
		if next_target == null:
			break
		used[next_target.get_instance_id()] = true
		var width: float = beam_width * maxf(0.42, pow(damage_falloff, float(link_index + 1)) + 0.10)
		var tether := AttackVfx.beam(_projectile_parent(), previous_position, next_target.global_position, width, visual_color)
		_register_effect(tether)
		var chained_damage := damage_value * pow(damage_falloff, float(link_index + 1))
		if dot_ticks > 0:
			_damage_enemy_with_dot(next_target, chained_damage, owner_node)
		else:
			_damage_enemy(next_target, chained_damage)
		previous_position = next_target.global_position


func _heal_owner_from_damage(owner_node: Node2D, dealt_damage: float) -> void:
	if heal_percent_of_damage <= 0.0 or owner_node == null or not is_instance_valid(owner_node):
		return
	if owner_node.get("health") == null or owner_node.get("max_health") == null:
		return
	# SCRUM-961 «Зубья костяной пилы»: пила возвращает больше здоровья с урона.
	# Бонус только поверх живого heal-канала оружия — сустейн-гейт Доктора цел.
	# SCRUM-900: пила переехала на режим saw_sector.
	var heal_ratio := heal_percent_of_damage
	if attack_mode == "saw_sector":
		heal_ratio += _owner_mod("saw_heal_ratio_bonus")
	var heal_amount := dealt_damage * heal_ratio * ProgressionData.WEAPON_DRAIN_HEAL_MULTIPLIER
	if heal_amount <= 0.0:
		return
	# Overheal is the portion that could not fit under max HP. A per-second heal
	# budget denial is not overheal and must never mint absorb while still hurt.
	var missing_health_before := maxf(float(owner_node.get("max_health")) - float(owner_node.get("health")), 0.0)
	var overflow := 0.0
	# SCRUM-517: drain-heal обязан уважать per-second бюджет (как вампиризм), иначе
	# Доктор бессмертен (DoT-стак чумы × число целей лил сотни HP/с прямо в health).
	# Маршрутизируем через capped-метод игрока; для owner-ов без него (саммоны и т.п.)
	# сохраняем прежнее прямое поведение, чтобы не сломать чужой sustain.
	var healed := 0.0
	if owner_node.has_method("apply_drain_heal"):
		healed = float(owner_node.call("apply_drain_heal", heal_amount))
	else:
		var before := float(owner_node.get("health"))
		owner_node.set("health", minf(before + heal_amount, float(owner_node.get("max_health"))))
		healed = float(owner_node.get("health")) - before
	if healed > 0.01 and owner_node.has_method("show_combat_feedback_number"):
		owner_node.show_combat_feedback_number(healed, "heal")
	# Convert only a real max-HP overflow. If the drain budget denied healing and
	# the owner is still hurt, no shield can be minted from the rejected amount.
	if float(owner_node.get("health")) >= float(owner_node.get("max_health")) - 0.001:
		overflow = maxf(heal_amount - missing_health_before, 0.0)
	if overflow > 0.0:
		var overheal_result := _constellation_event("overheal", null, 0.0, {"overheal": overflow})
		if bool(overheal_result.get("triggered", false)) and owner_node.has_method("constellation_set_timed_absorb"):
			var mechanic = owner_node.call("constellation_weapon_mechanic", weapon_id, "potion_overheal_absorb_pool") if owner_node.has_method("constellation_weapon_mechanic") else {}
			var params: Dictionary = (mechanic as Dictionary).get("params", {}) if mechanic is Dictionary else {}
			var cap := clampf(float(params.get("absorb_cap", 22.0)), 0.0, 30.0)
			var source_id := "overheal_%d" % get_instance_id()
			var previous := float(owner_node.call("constellation_timed_absorb", source_id)) if owner_node.has_method("constellation_timed_absorb") else 0.0
			var absorb_gain := overflow * clampf(float(params.get("conversion_ratio", 0.45)), 0.0, 1.0)
			owner_node.call("constellation_set_timed_absorb", source_id, minf(previous + absorb_gain, cap), maxf(float(params.get("duration_seconds", 4.0)), 0.0))


# ============================ SCRUM-900: кит Доктора ============================
# «Клятва чумного доктора»: весь сустейн класса — heal_percent_of_damage от
# ФАКТИЧЕСКИ нанесённого урона (_damage_enemy → _heal_owner_from_damage →
# apply_drain_heal с per-second бюджетом SCRUM-517). Нет урона — нет лечения.


# Чумной дротик: летящий снаряд в цель; на попадании — малый прямой урон и
# долгая зараза (см. _apply_plague_infection). Мета-ветка drain_extra_targets
# (Атлас Доктора) добавляет дротики по ближайшим соседям первичной цели.
func _fire_plague_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	if target == null:
		return
	var targets: Array = [target]
	var extra_darts := _extra_projectiles()
	if extra_darts > 0:
		var used := {target.get_instance_id(): true}
		var previous_position := target.global_position
		for _extra_index in range(extra_darts):
			var next_target := _find_nearest_enemy_from(previous_position, maxf(plague_spread_radius, aoe_radius), used)
			if next_target == null:
				break
			used[next_target.get_instance_id()] = true
			targets.append(next_target)
			previous_position = next_target.global_position
	for dart_target_raw in targets:
		var dart_target := dart_target_raw as Node2D
		if dart_target == null or not is_instance_valid(dart_target):
			continue
		_launch_plague_dart_at(owner_node, dart_target, direction)


func _launch_plague_dart_at(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var dart := _spawn_projectile_visual(owner_node.global_position + direction * 26.0, target.global_position - owner_node.global_position)
	_register_effect(dart)
	var travel_time: float = clampf(dart.global_position.distance_to(target.global_position) / maxf(projectile_speed, 1.0), 0.06, 0.42)
	var tween := create_tween()
	tween.tween_property(dart, "global_position", target.global_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# SCRUM-551: bound-метод вместо лямбды (захват узлов в лямбде — use-after-free).
	tween.tween_callback(Callable(self, "_plague_dart_arrive").bind(dart.get_instance_id(), owner_node.get_instance_id(), target.get_instance_id()))


func _plague_dart_arrive(dart_id: int, owner_id: int, target_id: int) -> void:
	var dart := instance_from_id(dart_id) as Node
	if dart != null:
		_release_effect(dart)
	if _effects_shutdown:
		return
	var owner_node := instance_from_id(owner_id) as Node2D
	var target := instance_from_id(target_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node) or target == null or not is_instance_valid(target):
		return
	# Прямой урон дротика: небольшой укол (magic), лечит через heal_percent_of_damage.
	_damage_enemy(target, _rolled_damage(owner_node))
	_apply_plague_infection(target, owner_node)


# Профиль чумы из текущих полей оружия + derived-статов владельца.
func _plague_runtime_profile(owner_node: Node2D) -> Dictionary:
	var params_raw = owner_node.get("derived_parameters") if owner_node != null else null
	var params: Dictionary = params_raw if params_raw is Dictionary else {}
	return ProgressionData.plague_tick_profile({
		"plague_duration": plague_duration,
		"plague_tick_interval": plague_tick_interval,
		"plague_tick_ratio": plague_tick_ratio,
		"plague_dot_coupling": plague_dot_coupling,
		"plague_ramp_ticks": plague_ramp_ticks,
	}, params)


func _plague_active_count() -> int:
	# Чистка мёртвых записей (враг умер/освобождён — tween-тики уже no-op).
	for enemy_id in _plague_tweens.keys().duplicate():
		var enemy := instance_from_id(int(enemy_id)) as Node2D
		if enemy == null or not is_instance_valid(enemy):
			var stale_tween: Tween = _plague_tweens[enemy_id]
			if stale_tween != null and stale_tween.is_valid():
				stale_tween.kill()
			_plague_tweens.erase(enemy_id)
	return _plague_tweens.size()


# Заражение цели чумой: долгий DoT с медленным ramp'ом тиков. Повторное
# попадание РЕФРЕШИТ заразу (полная длительность, ramp заново — без стакинга).
# Кап одновременных зараз plague_max_infected — «бессмертие от полного
# заражения карты» отрезано и здесь, и per-second drain-бюджетом лечения.
func _apply_plague_infection(enemy: Node2D, owner_node: Node2D, constellation_depth := 0, duration_scale := 1.0) -> void:
	if enemy == null or not is_instance_valid(enemy) or owner_node == null or not is_instance_valid(owner_node):
		return
	if _effects_shutdown:
		return
	var enemy_id := enemy.get_instance_id()
	var refreshing := _plague_tweens.has(enemy_id)
	if not refreshing and _plague_active_count() >= maxi(plague_max_infected, 1):
		return
	if refreshing:
		var old_tween: Tween = _plague_tweens[enemy_id]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
		_plague_tweens.erase(enemy_id)
	var profile := _plague_runtime_profile(owner_node)
	var tick_interval := maxf(float(profile.get("tick_interval", 1.0)), 0.2)
	var ticks := maxi(int(ceil(float(profile.get("ticks", 1)) * clampf(duration_scale, 0.05, 1.0))), 1)
	AttackVfx.ring_pulse(_projectile_parent(), enemy.global_position, 44.0, visual_color, false)
	var tween := create_tween()
	_plague_tweens[enemy_id] = tween
	var owner_id := owner_node.get_instance_id()
	for tick_index in range(ticks):
		tween.tween_interval(tick_interval)
		tween.tween_callback(Callable(self, "_plague_tick").bind(enemy_id, owner_id, tick_index))
	tween.tween_callback(Callable(self, "_end_plague_infection").bind(enemy_id))
	if constellation_depth == 0 and not _constellation_profile("syringe_infection_threshold_spread").is_empty():
		var stack_key := _constellation_mark_key("syringe_infection")
		var stack_raw = enemy.get_meta(stack_key, {})
		var stack_state: Dictionary = stack_raw if stack_raw is Dictionary else {}
		var now_msec := Time.get_ticks_msec()
		if now_msec > int(stack_state.get("until_msec", 0)):
			stack_state = {"count": 0, "spread": false}
		stack_state["count"] = mini(int(stack_state.get("count", 0)) + 1, 4)
		stack_state["until_msec"] = now_msec + int(tick_interval * float(ticks) * 1000.0)
		var infection_event := {"valid": true, "triggered": false}
		if not bool(stack_state.get("spread", false)):
			infection_event = _constellation_event("hit", enemy, 0.0, {"infection_stacks": int(stack_state["count"]), "constellation_consumer_event": true})
		if int(stack_state["count"]) >= 4 and not bool(stack_state.get("spread", false)) and bool(infection_event.get("triggered", false)):
			stack_state["spread"] = true
			var excluded := {enemy.get_instance_id(): true}
			for infected_id in _plague_tweens.keys():
				excluded[int(infected_id)] = true
			var spread_cap := maxi(int(_constellation_result_param(infection_event, "spread_targets", 3.0)), 0)
			var duration_ratio := _constellation_result_param(infection_event, "spread_duration_ratio", 0.50)
			for spread_raw in TARGET_QUERY.nearest_many(self, enemy.global_position, plague_spread_radius, spread_cap, excluded):
				var spread_target := spread_raw as Node2D
				if spread_target != null and is_instance_valid(spread_target):
					_apply_plague_infection(spread_target, owner_node, 1, duration_ratio)
		enemy.set_meta(stack_key, stack_state)


func _plague_tick(enemy_id: int, owner_id: int, tick_index: int) -> void:
	if _effects_shutdown:
		return
	var enemy := instance_from_id(enemy_id) as Node2D
	if enemy == null or not is_instance_valid(enemy):
		_end_plague_infection(enemy_id)
		return
	var owner_node := instance_from_id(owner_id) as Node2D
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var profile := _plague_runtime_profile(owner_node)
	var tick_damage := float(profile.get("tick_damage", 0.0)) * ProgressionData.plague_ramp_factor(tick_index, plague_ramp_ticks)
	if tick_damage <= 0.0:
		return
	# Тик чумы: dot-канал, без melee-эффектов и без owner-hit нотификаций;
	# лечение Доктора идёт внутри _damage_enemy → _heal_owner_from_damage.
	_damage_enemy(enemy, tick_damage, false, "dot", false)
	HazardVfx.dot_tick(enemy, Color(visual_color.r, visual_color.g, visual_color.b, 1.0))
	# Распространение: тикающая зараза с ограниченным шансом перескакивает на
	# ближайшего НЕзаражённого соседа (кап учтён в _apply_plague_infection).
	if plague_spread_chance > 0.0 and randf() < plague_spread_chance:
		_spread_plague_from(enemy, owner_node)


func _spread_plague_from(enemy: Node2D, owner_node: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _plague_active_count() >= maxi(plague_max_infected, 1):
		return
	var excluded := {}
	for infected_id in _plague_tweens.keys():
		excluded[int(infected_id)] = true
	var next_target := _find_nearest_enemy_from(enemy.global_position, plague_spread_radius, excluded)
	if next_target == null:
		return
	AttackVfx.beam(_projectile_parent(), enemy.global_position, next_target.global_position, 10.0, Color(visual_color.r, visual_color.g, visual_color.b, 0.30))
	_apply_plague_infection(next_target, owner_node, 1, 1.0)


func _end_plague_infection(enemy_id: int) -> void:
	_plague_tweens.erase(enemy_id)


# Костяная пила: melee-сектор cone_degrees (120-150°) перед Доктором с реальной
# дальностью. Бьёт все цели в дуге (диминиш сверх sector_full_targets), лечит
# сильнее всех оружий Доктора (heal_percent_of_damage) — но только по фронту:
# враги с флангов/спины давят безнаказанно, позиционирование = выживание.
func _fire_saw_sector(owner_node: Node2D, direction: Vector2) -> void:
	var slash := AttackVfx.slash(owner_node, direction, attack_range, visual_color)
	_register_effect(slash)
	# cone_degrees уже масштабирован Player единым множителем области атаки.
	var cone_effective := clampf(
		cone_degrees * (1.0 + _owner_mod("saw_arc_width_mult")),
		20.0, 360.0)
	var half_angle := deg_to_rad(cone_effective * 0.5)
	var candidates := []
	for enemy_node in TARGET_QUERY.enemies(self):
		if not is_instance_valid(enemy_node):
			continue
		var offset: Vector2 = enemy_node.global_position - owner_node.global_position
		var distance := offset.length()
		if distance > attack_range:
			continue
		if distance > 0.001 and absf(direction.angle_to(offset)) > half_angle:
			continue
		candidates.append({"node": enemy_node, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var damage_value := _rolled_damage(owner_node)
	var hit_index := 0
	for candidate in candidates:
		var saw_target := candidate["node"] as Node2D
		var hit_damage := damage_value
		if hit_index >= maxi(sector_full_targets, 1) and sector_target_diminish > 0.0:
			hit_damage *= pow(sector_target_diminish, float(hit_index - maxi(sector_full_targets, 1) + 1))
		_damage_enemy(saw_target, hit_damage)
		if not _constellation_profile("saw_wound_execute_heal").is_empty() and is_instance_valid(saw_target):
			var wound_count := _advance_constellation_target_stack(saw_target, "saw_wound", 5, 6.0)
			var wound_event := _constellation_event("hit", saw_target, 0.0, {"wounds": wound_count, "constellation_consumer_event": true})
			var hp_value = saw_target.get("health")
			var max_hp_value = saw_target.get("max_health")
			var low_enough := hp_value != null and max_hp_value != null and float(max_hp_value) > 0.0 and float(hp_value) / float(max_hp_value) <= _constellation_result_param(wound_event, "execute_threshold", 0.25)
			if wound_count >= 5 and low_enough and bool(wound_event.get("triggered", false)):
				saw_target.remove_meta(_constellation_mark_key("saw_wound"))
				if owner_node.has_method("apply_drain_heal"):
					owner_node.call("apply_drain_heal", hit_damage * _constellation_result_param(wound_event, "heal_ratio", 0.06))
		hit_index += 1
# ========================== конец кита Доктора (SCRUM-900) ==========================


# SCRUM-961 «Восстановительный пар»: короткая паровая зона у цели — 2 тика
# за 1.4с, тик жжёт 28% урона, 20% урона пара лечит Доктора через
# apply_drain_heal (капы drain-бюджета соблюдены). SCRUM-900: хук переехал с
# drain_link-связи на взрыв зелья (см. _launch_aoe_projectile).
func _spawn_restore_vapor(owner_node: Node2D, center: Vector2, link_damage: float) -> void:
	var vapor_radius := maxf(aoe_radius * 0.8, 90.0)
	var tick_damage := link_damage * 0.28
	# FAN-1031 S3 (3c): артефактный vapor-канал «Восстановительного пара» теперь
	var vapor_full := aoe_full_targets if aoe_full_targets >= 0 else 2
	var vapor_diminish := aoe_target_diminish if aoe_target_diminish >= 0.0 else 1.5
	var weapon_self_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	AttackVfx.ring_pulse(_projectile_parent(), center, vapor_radius, Color(0.45, 1.0, 0.75, 0.35), true)
	var vapor_tween := create_tween()
	for tick_index in range(2):
		vapor_tween.tween_interval(0.7)
		vapor_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_self_id) as ClassWeapon
			if current_weapon == null or not is_instance_valid(current_weapon) or current_weapon._effects_shutdown:
				return
			AttackVfx.ring_pulse(current_weapon._projectile_parent(), center, vapor_radius, Color(0.45, 1.0, 0.75, 0.26), false)
			current_weapon._damage_enemies_in_circle_capped(center, vapor_radius, tick_damage, vapor_full, vapor_diminish)
			var current_owner := instance_from_id(owner_id) as Node2D
			if current_owner != null and is_instance_valid(current_owner) and current_owner.has_method("apply_drain_heal"):
				current_owner.call("apply_drain_heal", tick_damage * 0.20)
		)


func _fire_sound_wave(owner_node: Node2D, direction: Vector2) -> void:
	var wave_visual := AttackVfx.sound_wave_blast(_projectile_parent(), owner_node.global_position + direction * 24.0, direction, attack_range, visual_color)
	_register_effect(wave_visual)
	var damage_value := _rolled_damage(owner_node)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not _is_enemy_inside_wave(owner_node.global_position, enemy_node.global_position, direction):
			continue
		_damage_enemy(enemy_node, damage_value)
		_push_enemy(enemy_node, direction)


# SCRUM-899: «рифф-полоса» Электрогитары — узкий передний коридор ПОСТОЯННОЙ
func _fire_riff_strip(owner_node: Node2D, direction: Vector2) -> void:
	var origin := owner_node.global_position
	var strip_visual := AttackVfx.beam(_projectile_parent(), origin + direction * 18.0, origin + direction * attack_range, maxf(wave_width, 24.0), visual_color)
	_register_effect(strip_visual)
	var damage_value := _rolled_damage(owner_node)
	var harmony_triggered := false
	for hit in _enemies_in_corridor(origin, direction, wave_width, attack_range):
		var enemy_node: Node2D = hit["node"]
		_damage_enemy(enemy_node, damage_value)
		_push_enemy(enemy_node, direction)
		var harmony := _constellation_event("hit", enemy_node, 0.0, {"now_msec": Time.get_ticks_msec(), "constellation_consumer_event": true})
		harmony_triggered = harmony_triggered or bool(harmony.get("triggered", false))
	if harmony_triggered:
		var perpendicular := Vector2(-direction.y, direction.x).normalized()
		var lane_origin := origin + perpendicular * maxf(wave_width * 0.65, 36.0)
		var lane_damage := damage_value * 0.38
		_register_effect(AttackVfx.beam(_projectile_parent(), lane_origin + direction * 18.0, lane_origin + direction * attack_range, maxf(wave_width * 0.72, 24.0), visual_color))
		for lane_hit in _enemies_in_corridor(lane_origin, direction, wave_width * 0.72, attack_range):
			_call_take_damage(lane_hit["node"], lane_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "guitar_riff_harmony_lane"})


# SCRUM-903: маршрутизация «пульса» деплой-устройства: вороний тотем
# (raven_homing) вместо зонного пульса пускает самонаводящегося ворона;
# остальные ампы (sound_amp и т.п.) пульсируют как прежде.
func _fire_deployable_pulse(owner_node: Node2D, origin: Vector2) -> void:
	if raven_homing:
		_launch_totem_raven(owner_node, origin)
		var strike_result := _constellation_event("totem_pulse", null, 0.0)
		if bool(strike_result.get("triggered", false)):
			var strike_ratio := maxf(float(strike_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
			_launch_totem_raven(owner_node, origin, strike_ratio, 1.5)
		return
	if weapon_id == "sound_amp":
		var echo_result := _constellation_event("amp_pulse", null, 0.0)
		if bool(echo_result.get("triggered", false)):
			_constellation_instrument_echo(owner_node, origin, echo_result)
	_fire_pulse(owner_node, origin)


func _constellation_instrument_echo(owner_node: Node2D, origin: Vector2, result: Dictionary) -> void:
	var echo_damage := _rolled_damage(owner_node) * _constellation_result_param(result, "echo_damage_ratio", 0.30)
	var current_instrument := str(owner_node.get("weapon_id"))
	match current_instrument:
		"electric_guitar":
			var direction := _last_direction.normalized() if _last_direction.length_squared() > 0.001 else Vector2.RIGHT
			_register_effect(AttackVfx.beam(_projectile_parent(), origin + direction * 18.0, origin + direction * attack_range, maxf(wave_width, 24.0), visual_color))
			for hit in _enemies_in_corridor(origin, direction, wave_width, attack_range):
				_call_take_damage(hit["node"], echo_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "amp_instrument_echo", "instrument": current_instrument})
		"bass_guitar", "sound_amp", "":
			_register_effect(AttackVfx.ring_pulse(_projectile_parent(), origin, aoe_radius, visual_color, false))
			for target in TARGET_QUERY.in_radius(self, origin, aoe_radius):
				_call_take_damage(target, echo_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "amp_instrument_echo", "instrument": current_instrument if current_instrument != "" else "sound_amp"})
		_:
			return


func _fire_pulse(owner_node: Node2D, origin: Vector2) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var pulse_damage := _rolled_damage(owner_node)
	var bass_result := {"triggered": false}
	if weapon_id == "bass_guitar":
		bass_result = _constellation_event("pulse", TARGET_QUERY.nearest(self, origin, aoe_radius), 0.0, {"constellation_consumer_event": true})
		if bool(bass_result.get("triggered", false)):
			pulse_damage *= _constellation_result_param(bass_result, "damage_ratio", 1.25)
	_damage_enemies_in_circle(origin, aoe_radius, pulse_damage)
	var pulse_visual := AttackVfx.ring_pulse(_projectile_parent(), origin, aoe_radius, visual_color, attack_mode in ["pulse", "amp"])
	_register_effect(pulse_visual)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var away := enemy_node.global_position - origin
		if away.length_squared() > 0.001 and away.length() <= aoe_radius:
			_push_enemy(enemy_node, away.normalized())
			if bool(bass_result.get("triggered", false)):
				var stagger := _constellation_result_param(bass_result, "stagger_seconds", 0.7)
				if TARGET_QUERY.is_epic_displacement_immune(enemy_node):
					stagger *= _constellation_result_param(bass_result, "boss_factor", 0.25)
				StatusEffects.apply_status(enemy_node, "constellation_bass_stagger", {"duration": stagger, "speed_multiplier": 0.35})


func _fire_amp(owner_node: Node2D, direction: Vector2) -> void:
	# SCRUM-961: «Сценический усилитель» продлевает жизнь ампа (+amp_lifetime_bonus,
	# кап деплоя — через amp_cap_bonus в player._apply_weapon_scaling); «Голубой
	# тотем» учащает пульс вороньего тотема (−15% интервала).
	# SCRUM-899: поверх — opt-in саммонер-скейлинг (только sound_amp): Лидерство
	# продлевает uptime ампа, summon_amount учащает пульс (сила через темп).
	var effective_amp_lifetime := amp_lifetime + _owner_mod("amp_lifetime_bonus") + _amp_leadership_lifetime_bonus(owner_node)
	var effective_pulse_interval := amp_pulse_interval
	if amp_summon_haste:
		effective_pulse_interval /= 1.0 + _amp_summon_haste_value(owner_node)
	if weapon_id == "raven_totem" and _owner_mod("raven_pulse_bonus") > 0.0:
		effective_pulse_interval *= 0.85
	_emit_weapon_animation_event(owner_node, "deploy", effective_amp_lifetime, direction, {"pulse_interval": effective_pulse_interval})
	# Деплой: усилитель ставится на землю, живет amp_lifetime секунд и пульсирует
	var alive_amps: Array[Node] = []
	for tracked_amp in _deployed_amps:
		if tracked_amp != null and is_instance_valid(tracked_amp):
			alive_amps.append(tracked_amp)
	_deployed_amps = alive_amps

	var amp := Node2D.new()
	amp.name = "SoundAmpPulseNode"
	amp.add_to_group("deployed_sound_amps")
	amp.z_index = 5
	var amp_visual := Sprite2D.new()
	amp_visual.texture = _deploy_visual_texture()
	amp_visual.scale = Vector2(0.42, 0.42)
	amp.add_child(amp_visual)
	_projectile_parent().add_child(amp)
	_register_effect(amp)
	amp.global_position = owner_node.global_position + direction * 92.0
	_deployed_amps.append(amp)

	var amp_limit := maxi(max_summons, 1)
	while _deployed_amps.size() > amp_limit:
		var oldest: Node = _deployed_amps.pop_front()
		_release_effect(oldest)

	var pulse_tween := amp.create_tween()
	var pulse_count := maxi(int(floor(effective_amp_lifetime / maxf(effective_pulse_interval, 0.2))), 1)
	var amp_id := amp.get_instance_id()
	var weapon_id := get_instance_id()
	for pulse_index in range(pulse_count):
		pulse_tween.tween_interval(effective_pulse_interval)
		pulse_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_amp := instance_from_id(amp_id) as Node2D
			if current_weapon != null and current_amp != null and not bool(current_weapon.get("_effects_shutdown")):
				var current_owner := current_weapon.call("_owner_node") as Node2D
				if current_owner != null:
					var pulse_direction := current_amp.global_position - current_owner.global_position
					current_weapon.call("_emit_weapon_animation_event", current_owner, "pulse", maxf(float(current_weapon.get("amp_pulse_interval")), 0.2), pulse_direction.normalized(), {"index": pulse_index, "count": pulse_count})
				# SCRUM-903: вороний тотем пускает homing-ворона вместо зонного пульса.
				current_weapon.call("_fire_deployable_pulse", current_owner, current_amp.global_position)
		)
	pulse_tween.tween_callback(func() -> void:
		var current_weapon := instance_from_id(weapon_id) as Node
		var current_amp := instance_from_id(amp_id) as Node
		if current_amp == null:
			return
		if current_weapon != null:
			var amps: Array = current_weapon.get("_deployed_amps")
			amps.erase(current_amp)
			current_weapon.call("_release_effect", current_amp)
			current_weapon.call("_salvage_device_refund")  # SCRUM-961 «Ядро утилизации»
		else:
			current_amp.queue_free()
	)

	# Первый пульс сразу при установке.
	_emit_weapon_animation_event(owner_node, "pulse", maxf(effective_pulse_interval, 0.2), direction, {"index": 0, "count": pulse_count})
	_fire_deployable_pulse(owner_node, amp.global_position)


# ==================== SCRUM-903: вороны тотема (raven_homing) ====================
const RAVEN_EXPLOSION_FULL_TARGETS := 3
const RAVEN_EXPLOSION_TARGET_DIMINISH := 0.60
const RAVEN_CURVE_BEND := 0.38

var _raven_side_toggle := 1.0


func _launch_totem_raven(owner_node: Node2D, origin: Vector2, damage_scale := 1.0, support_seconds := 0.0) -> void:
	if _effects_shutdown or not is_inside_tree():
		return
	var target := TARGET_QUERY.nearest(self, origin, attack_range) as Node2D
	if target == null or not is_instance_valid(target):
		return
	var raven := _spawn_projectile_visual(origin + Vector2(0.0, -34.0), target.global_position - origin)
	_register_effect(raven)
	raven.set_meta("raven_last_target_position", target.global_position)
	raven.set_meta("constellation_damage_scale", clampf(damage_scale, 0.0, 1.0))
	raven.set_meta("constellation_support_seconds", maxf(support_seconds, 0.0))
	_raven_side_toggle = -_raven_side_toggle
	var travel_time := clampf(origin.distance_to(target.global_position) / maxf(projectile_speed, 120.0), 0.28, 0.75)
	var owner_id := owner_node.get_instance_id() if owner_node != null and is_instance_valid(owner_node) else 0
	var flight_tween := create_tween()
	flight_tween.tween_method(
		Callable(self, "_step_raven_flight").bind(raven.get_instance_id(), target.get_instance_id(), raven.global_position, _raven_side_toggle),
		0.0, 1.0, travel_time)
	flight_tween.tween_callback(Callable(self, "_resolve_raven_impact").bind(raven.get_instance_id(), owner_id))


func _step_raven_flight(progress: float, raven_id: int, target_id: int, start_position: Vector2, side_sign: float) -> void:
	var raven := instance_from_id(raven_id) as Node2D
	if raven == null or not is_instance_valid(raven):
		return
	var end_position: Vector2 = raven.get_meta("raven_last_target_position", start_position)
	var target := instance_from_id(target_id) as Node2D
	if target != null and is_instance_valid(target):
		end_position = target.global_position
		raven.set_meta("raven_last_target_position", end_position)
	var chord := end_position - start_position
	if chord.length_squared() < 1.0:
		raven.global_position = end_position
		return
	var control := (start_position + end_position) * 0.5 + Vector2(chord.y, -chord.x).normalized() * chord.length() * RAVEN_CURVE_BEND * side_sign
	raven.global_position = _quadratic_bezier_point(start_position, control, end_position, clampf(progress, 0.0, 1.0))


func _resolve_raven_impact(raven_id: int, owner_id: int) -> void:
	var raven := instance_from_id(raven_id) as Node2D
	if raven == null or not is_instance_valid(raven):
		return
	var impact_position := raven.global_position
	if _effects_shutdown or not is_inside_tree():
		_release_effect(raven)
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var explosion_damage := damage * raven_damage_multiplier
	if current_owner != null and is_instance_valid(current_owner):
		explosion_damage = _rolled_damage(current_owner) * raven_damage_multiplier
	explosion_damage *= float(raven.get_meta("constellation_damage_scale", 1.0))
	# SCRUM-961 «Голубой тотем» поверх SCRUM-903: вороны бьют злее (+25%).
	explosion_damage *= 1.0 + _owner_mod("raven_pulse_bonus")
	AttackVfx.orb_burst(_projectile_parent(), impact_position, raven_explosion_radius, _projectile_impact_color())
	_damage_enemies_in_circle_capped(impact_position, raven_explosion_radius, explosion_damage, RAVEN_EXPLOSION_FULL_TARGETS, RAVEN_EXPLOSION_TARGET_DIMINISH)
	for enemy in TARGET_QUERY.in_radius(self, impact_position, raven_explosion_radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var away := enemy_node.global_position - impact_position
		if away.length_squared() > 0.001:
			_push_enemy(enemy_node, away.normalized())
	var support_seconds := float(raven.get_meta("constellation_support_seconds", 0.0))
	if support_seconds > 0.0 and current_owner != null and current_owner.has_method("constellation_set_timed_absorb"):
		current_owner.call("constellation_set_timed_absorb", "raven_support_%d" % get_instance_id(), 2.0, support_seconds)
	_release_effect(raven)


# SCRUM-913 «Охотничий капкан»: ПЕРМАНЕНТНЫЙ контрольный капкан.
const HUNTER_TRAP_ACTIVE_CAP := 6


func _fire_trap(owner_node: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "deploy", 0.6, direction, {"check_interval": pool_tick_interval})
	# FAN-1893: дополнительные капканы одним броском (веером поперёк направления)
	# даёт только семантический мета-ключ trap_extra_count («Капканщик»);
	# generic extra_projectile здесь инертен (real_projectile_count 0), поэтому
	# _extra_projectiles() возвращает лишь семантическую добавку.
	var extra_traps := maxi(_extra_projectiles(), 0)
	var center := owner_node.global_position + direction * minf(attack_range, 180.0)
	var side := direction.orthogonal().normalized()
	for trap_index in range(1 + extra_traps):
		# 0, +70, -70, +140, ... — веер поперёк направления броска.
		var lateral := float((trap_index + 1) / 2) * 70.0 * (1.0 if trap_index % 2 == 1 else -1.0)
		if trap_index == 0:
			lateral = 0.0
		_deploy_hunter_trap(owner_node, center + side * lateral)


func _deploy_hunter_trap(owner_node: Node2D, trap_position: Vector2) -> void:
	var trap := Node2D.new()
	trap.name = "WeaponTrapNode"
	_register_effect(trap)
	trap.z_index = 5
	var trap_visual := Sprite2D.new()
	trap_visual.texture = _weapon_visual_texture()
	trap_visual.scale = Vector2(0.34, 0.34)
	trap.add_child(trap_visual)
	_projectile_parent().add_child(trap)
	trap.global_position = trap_position
	trap.set_meta("hunter_trap", true)
	# Снапшот заряда стойки: капкан, поставленный из полной стойки, хлопает
	# сильнее (identity «терпеливого охотника»); сам ролл — на момент триггера.
	trap.set_meta("charge_snapshot", _current_charge_multiplier)
	_retire_excess_hunter_traps(trap)

	var state := {"triggered": false}
	var check_interval := maxf(pool_tick_interval, 0.15)
	var instant_arm := false
	if owner_node.has_method("meta_trap_instant_arm"):
		instant_arm = bool(owner_node.call("meta_trap_instant_arm", _meta_context()))
	var check_callable := Callable(self, "_hunter_trap_check").bind(trap.get_instance_id(), owner_node.get_instance_id(), state)
	# Вечный цикл проверки: интервал → проверка; живёт, пока жив узел капкана.
	var trap_tween := trap.create_tween()
	trap_tween.set_loops()
	trap_tween.tween_interval(check_interval)
	trap_tween.tween_callback(check_callable)
	if instant_arm:
		check_callable.call_deferred()


# Периодическая проверка капкана (Callable без лямбды — SCRUM-551): первый враг
# в радиусе захлопывает капкан. Игрок и союзные сущности проверку не проходят
# (только группа enemies).
func _hunter_trap_check(trap_id: int, owner_id: int, state: Dictionary) -> void:
	var trap := instance_from_id(trap_id) as Node2D
	if trap == null or not is_instance_valid(trap) or bool(state.get("triggered", false)):
		return
	if not _has_enemy_in_circle(trap.global_position, aoe_radius):
		return
	state["triggered"] = true
	_trigger_hunter_trap(trap, instance_from_id(owner_id) as Node2D)


# Срабатывание: физический AoE-хлопок по всем врагам в радиусе + контроль
# (_apply_hunter_trap_control: паралич + кровотечение). Урон и статусы идут
# по ОДНОМУ набору целей — читаемая зона совпадает с фактической.
func _trigger_hunter_trap(trap: Node2D, owner_node: Node2D) -> void:
	var trap_damage := damage
	if owner_node != null and is_instance_valid(owner_node):
		trap_damage = _rolled_damage(owner_node)
	trap_damage *= maxf(float(trap.get_meta("charge_snapshot", 1.0)), 1.0)
	var center := trap.global_position
	AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, false)
	for enemy_raw in TARGET_QUERY.in_radius(self, center, aoe_radius):
		var enemy_node := enemy_raw as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		_damage_enemy(enemy_node, trap_damage)
		var prey_result := _constellation_event("trap_trigger", enemy_node, 0.0)
		if bool(prey_result.get("triggered", false)):
			var mechanic = owner_node.call("constellation_weapon_mechanic", weapon_id, "trap_prey_mark_distribution") if owner_node != null and owner_node.has_method("constellation_weapon_mechanic") else {}
			var params: Dictionary = (mechanic as Dictionary).get("params", {}) if mechanic is Dictionary else {}
			enemy_node.set_meta("constellation_prey_owner", owner_node.get_instance_id() if owner_node != null else 0)
			enemy_node.set_meta("constellation_prey_until", Time.get_ticks_msec() + int(maxf(float(params.get("prey_seconds", 4.0)), 0.0) * 1000.0))
			enemy_node.set_meta("constellation_prey_share", clampf(float(params.get("shared_damage_ratio", 0.22)), 0.0, 0.5))
			enemy_node.set_meta("constellation_prey_neighbors", maxi(int(params.get("neighbor_targets", 3)), 0))
		if is_instance_valid(enemy_node):
			_apply_hunter_trap_control(enemy_node, owner_node)
	_release_effect(trap)


# Контроль капкана (SCRUM-913):
func _apply_hunter_trap_control(enemy_node: Node2D, owner_node: Node2D) -> void:
	var paralyze_duration := (trap_paralyze_seconds + _owner_mod("trap_paralysis_bonus")) * _control_resist_factor(enemy_node)
	if paralyze_duration > 0.0:
		StatusEffects.apply_status(enemy_node, "hunter_trap_paralysis", {
			"duration": paralyze_duration,
			"movement_locked": true,
			"speed_multiplier": 0.0,
			"marker_color": Color(0.45, 0.90, 0.40, 1.0),
		})
	if dot_ticks <= 0:
		return
	var bleed_tick := 3.0
	if owner_node != null and is_instance_valid(owner_node):
		var parameters_raw = owner_node.get("derived_parameters")
		if parameters_raw is Dictionary:
			bleed_tick = maxf(float((parameters_raw as Dictionary).get("dot_damage", 3.0)), 1.0)
	var tick_interval := maxf(trap_bleed_tick_interval, 0.1)
	StatusEffects.apply_status_from(owner_node, enemy_node, "hunter_trap_bleed", {
		"duration": float(dot_ticks) * tick_interval,
		"dot_damage": bleed_tick,
		"dot_interval": tick_interval,
		"marker_color": Color(0.35, 0.85, 0.30, 1.0),
	})


# Кап живых капканов (перманентность без замусоривания поля): старейшие сверх
# капа тихо снимаются. Это КАП, а не таймер — одинокий капкан живёт вечно.
func _retire_excess_hunter_traps(new_trap: Node2D) -> void:
	var cap := maxi(HUNTER_TRAP_ACTIVE_CAP + int(_owner_mod("trap_cap_bonus")), 1)
	var alive_traps: Array[Node2D] = []
	for effect in _alive_effects():
		if effect is Node2D and effect.has_meta("hunter_trap") and effect != new_trap:
			alive_traps.append(effect as Node2D)
	while alive_traps.size() >= cap:
		var oldest := alive_traps.pop_front() as Node2D
		_release_effect(oldest)


# SCRUM-936 «Аркебуза»: одна быстрая взрывная пуля — видимый снаряд летит далеко
# в цель и взрывается малым AoE (полный урон в центре, falloff к краю зоны).
# Внутренний capability seam extra_projectile при injected value добавляет пули
# по следующим ближайшим целям. FAN-2247: player-facing source отсутствует —
# ни один active artifact/reward/config сейчас не выдаёт этот ключ. Trait
# «Двойное действие» даёт второй независимый выстрел через _maybe_fire_action_echo
# (без рекурсии).
func _fire_arquebus_shot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var count := maxi(1 + _extra_projectiles(), 1)
	var targets := _find_closest_enemies(owner_node, count)
	if targets.is_empty():
		if target != null and is_instance_valid(target):
			targets = [target]  # цель вне базового радиуса поиска (передана _attack)
		else:
			_launch_arquebus_bullet(owner_node, null, direction)
			return
	for target_index in range(mini(count, targets.size())):
		var target_node := targets[target_index] as Node2D
		var aim := direction
		if target_node != null:
			var to_target: Vector2 = target_node.global_position - owner_node.global_position
			if to_target.length_squared() > 0.001:
				aim = to_target.normalized()
		_launch_arquebus_bullet(owner_node, target_node, aim)


func _launch_arquebus_bullet(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var start := owner_node.global_position + direction * 28.0
	var target_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 560.0)
	if target != null:
		target_position = target.global_position
	# Короткая вспышка у дула — читаемое начало выстрела (важно для эха: два дула).
	var muzzle := AttackVfx.beam(_projectile_parent(), start, start + direction * 46.0, beam_width, Color(visual_color.r, visual_color.g, visual_color.b, 0.55))
	_register_effect(muzzle)
	var bullet := _spawn_projectile_visual(start, target_position - start)
	_register_effect(bullet)
	var travel_time: float = clampf(start.distance_to(target_position) / maxf(projectile_speed, 1.0), 0.05, 0.60)
	var tween := create_tween()
	tween.tween_property(bullet, "global_position", target_position, travel_time).set_trans(Tween.TRANS_LINEAR)
	# SCRUM-551: Callable + примитивные bind-аргументы вместо лямбды с захватом узлов.
	tween.tween_callback(Callable(self, "_explode_arquebus_bullet").bind(bullet.get_instance_id(), owner_node.get_instance_id(), target_position, direction))


func _explode_arquebus_bullet(bullet_id: int, owner_id: int, center: Vector2, direction: Vector2) -> void:
	var bullet := instance_from_id(bullet_id) as Node
	if _effects_shutdown:
		if bullet != null and is_instance_valid(bullet):
			bullet.queue_free()
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var explosion_damage := damage
	if current_owner != null and is_instance_valid(current_owner):
		explosion_damage = _rolled_damage(current_owner)
	# SCRUM-961 «Шрапнель аркебузы» (rework SCRUM-936): осколочная зона шире (+25%)
	# и злее к соседям (falloff-пол 0.45→0.59); центр без изменений.
	var shrapnel := _owner_mod("arquebus_shrapnel_bonus") > 0.0
	var blast_radius := aoe_radius * (1.25 if shrapnel else 1.0)
	var edge_falloff := clampf(damage_falloff + (0.14 if shrapnel else 0.0), 0.0, 0.9)
	_damage_enemies_in_circle_falloff(center, blast_radius, explosion_damage, edge_falloff)
	for enemy_node in TARGET_QUERY.in_radius(self, center, blast_radius):
		_push_enemy(enemy_node, direction)
	AttackVfx.orb_burst(_projectile_parent(), center, blast_radius, _projectile_impact_color())
	if bullet != null and is_instance_valid(bullet):
		_release_effect(bullet)


# SCRUM-937 «Граната с фитилем»: медленный снаряд долго летит в телеграфированную
const GRENADE_MAX_FLIGHT_SPEED := 460.0


func _fire_grenade_fuse(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# SCRUM-961 «Длинный фитиль»: фитиль горит дольше (+0.35с телеграф), взрыв
	# окупается (+long_fuse_bonus урона, +10% радиуса).
	var fuse_bonus := _owner_mod("long_fuse_bonus")
	var fuse_delay := maxf(grenade_delay, 0.20) + (0.35 if fuse_bonus > 0.0 else 0.0)
	var blast_radius := aoe_radius * (1.10 if fuse_bonus > 0.0 else 1.0)
	var blast_damage_mult := 1.0 + fuse_bonus
	var target_position: Vector2 = owner_node.global_position + direction * minf(attack_range, 440.0)
	if target != null:
		target_position = target.global_position
	var start := owner_node.global_position + direction * 26.0
	var flight_speed := clampf(projectile_speed, 60.0, GRENADE_MAX_FLIGHT_SPEED)
	var travel_time := maxf(start.distance_to(target_position) / flight_speed, 0.25)
	_emit_weapon_animation_event(owner_node, "windup", travel_time + fuse_delay, direction, {"delayed": true})
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), target_position, blast_radius, visual_color, true)
	_register_effect(telegraph)
	var grenade := _spawn_projectile_visual(start, target_position - start)
	_register_effect(grenade)
	var tween := create_tween()
	tween.tween_property(grenade, "global_position", target_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Посадка: отдельный «armed»-пульс фитиля — читаемая фаза между полётом и взрывом.
	tween.tween_callback(Callable(self, "_arm_grenade_fuse").bind(owner_node.get_instance_id(), target_position, blast_radius, direction, fuse_delay))
	tween.tween_interval(fuse_delay)
	tween.tween_callback(Callable(self, "_explode_grenade_fuse").bind(grenade.get_instance_id(), telegraph.get_instance_id(), owner_node.get_instance_id(), target_position, blast_radius, blast_damage_mult, direction))


func _arm_grenade_fuse(owner_id: int, center: Vector2, blast_radius: float, direction: Vector2, fuse_delay: float) -> void:
	if _effects_shutdown:
		return
	var fuse_ring := AttackVfx.ring_pulse(_projectile_parent(), center, blast_radius * 0.45, Color(1.0, 0.82, 0.30, 0.55), false)
	if fuse_ring != null:
		_register_effect(fuse_ring)
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner != null and is_instance_valid(current_owner):
		_emit_weapon_animation_event(current_owner, "pulse", fuse_delay, direction, {"fuse": true})


func _explode_grenade_fuse(grenade_id: int, telegraph_id: int, owner_id: int, center: Vector2, blast_radius: float, blast_damage_mult: float, direction: Vector2) -> void:
	var current_grenade := instance_from_id(grenade_id) as Node
	var current_telegraph := instance_from_id(telegraph_id) as Node
	if _effects_shutdown:
		if current_grenade != null and is_instance_valid(current_grenade):
			current_grenade.queue_free()
		if current_telegraph != null and is_instance_valid(current_telegraph):
			current_telegraph.queue_free()
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var explosion_damage := damage
	if current_owner != null and is_instance_valid(current_owner):
		explosion_damage = _rolled_damage(current_owner)
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	explosion_damage *= blast_damage_mult
	_damage_enemies_in_circle_falloff(center, blast_radius, explosion_damage, damage_falloff)
	var shrapnel_result := _constellation_event("explosion", null, explosion_damage)
	if bool(shrapnel_result.get("triggered", false)):
		var shrapnel_ratio := maxf(float(shrapnel_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
		var shrapnel_tween := create_tween()
		shrapnel_tween.tween_interval(0.18)
		shrapnel_tween.tween_callback(Callable(self, "_constellation_grenade_second_wave").bind(center, explosion_damage * shrapnel_ratio, blast_radius))
	AttackVfx.orb_burst(_projectile_parent(), center, blast_radius, _projectile_impact_color())
	if current_grenade != null and is_instance_valid(current_grenade):
		_release_effect(current_grenade)
	if current_telegraph != null and is_instance_valid(current_telegraph):
		_release_effect(current_telegraph)


func _constellation_grenade_second_wave(center: Vector2, shard_damage: float, blast_radius: float) -> void:
	if _effects_shutdown or shard_damage <= 0.0:
		return
	var hit_counts := {}
	for shard_index in range(8):
		var shard_direction := Vector2.RIGHT.rotated(TAU * float(shard_index) / 8.0)
		var finish := center + shard_direction * blast_radius * 1.25
		_register_effect(AttackVfx.beam(_projectile_parent(), center, finish, maxf(beam_width * 0.35, 10.0), visual_color))
		for enemy_raw in TARGET_QUERY.in_segment(self, center, finish, maxf(beam_width, 28.0)):
			var enemy := enemy_raw as Node2D
			if enemy == null or not is_instance_valid(enemy):
				continue
			var enemy_id := enemy.get_instance_id()
			if int(hit_counts.get(enemy_id, 0)) >= 2:
				continue
			hit_counts[enemy_id] = int(hit_counts.get(enemy_id, 0)) + 1
			_call_take_damage(enemy, shard_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "grenade_shrapnel_second_wave"})


# SCRUM-938 «Штык-конус»: активный ближний сектор (cone_degrees) в направлении
# атаки — каждый враг в конусе получает укол и отброс за один взмах; вплотную к
# ногам мёртвой зоны нет (contact-rescue радиус). Поверх укола — редкий
# авто-выстрел винтовки по цели ЗА конусом (bayonet_auto_shot_chance + артефакт
# «Спуск штыка»). Выстрел — бонус-акцент, не превращает штык в вторую аркебузу.
const BAYONET_CONTACT_RESCUE_RADIUS := 52.0


func _fire_bayonet_cone(owner_node: Node2D, direction: Vector2) -> void:
	var cone_visual := AttackVfx.slash(owner_node, direction, attack_range, visual_color)
	_register_effect(cone_visual)
	var damage_value := _rolled_damage(owner_node)
	var origin := owner_node.global_position
	var brace_profile := _constellation_profile("bayonet_brace_countershot")
	var brace_params: Dictionary = brace_profile.get("params", {}) if not brace_profile.is_empty() else {}
	var brace_seconds := maxf(float(brace_params.get("brace_window_seconds", 0.5)), 0.0)
	var brace_candidate_id := 0
	for enemy_node in TARGET_QUERY.enemies(self):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not _is_enemy_inside_bayonet_cone(origin, enemy_node.global_position, direction):
			continue
		_damage_enemy(enemy_node, damage_value)
		var push_direction := (enemy_node.global_position - origin)
		_push_enemy(enemy_node, push_direction.normalized() if push_direction.length_squared() > 0.001 else direction)
		if brace_candidate_id == 0:
			brace_candidate_id = enemy_node.get_instance_id()
	if brace_candidate_id != 0 and brace_seconds > 0.0:
		var brace_token := int(_constellation_local_state.get("bayonet_brace_token", 0)) + 1
		var brace_until_msec := Time.get_ticks_msec() + int(brace_seconds * 1000.0)
		_constellation_local_state["bayonet_brace_token"] = brace_token
		_constellation_local_state["bayonet_brace_until_msec"] = brace_until_msec
		_constellation_local_state["bayonet_brace_used"] = false
		var brace_tween := create_tween()
		brace_tween.tween_interval(0.10)
		brace_tween.tween_callback(Callable(self, "_resolve_bayonet_brace_countershot").bind(brace_token, origin, brace_candidate_id, damage_value))
	# Редкий выстрел: встроенный шанс оружия + артефакт SCRUM-961 «Спуск штыка».
	var shot_chance := clampf(bayonet_auto_shot_chance + _owner_mod("bayonet_shot_chance"), 0.0, 1.0)
	if randf() < shot_chance:
		_fire_bayonet_auto_shot(owner_node, direction)


func _resolve_bayonet_brace_countershot(brace_token: int, origin: Vector2, target_id: int, base_damage: float) -> void:
	if _effects_shutdown or int(_constellation_local_state.get("bayonet_brace_token", 0)) != brace_token:
		return
	if bool(_constellation_local_state.get("bayonet_brace_used", false)):
		return
	var brace_until_msec := int(_constellation_local_state.get("bayonet_brace_until_msec", 0))
	if Time.get_ticks_msec() >= brace_until_msec:
		return
	var target := instance_from_id(target_id) as Node2D
	if target == null or not is_instance_valid(target):
		return
	var counter_result := _constellation_event("brace_hit", target, 0.0, {"brace_until_msec": brace_until_msec})
	if not bool(counter_result.get("triggered", false)):
		return
	_constellation_local_state["bayonet_brace_used"] = true
	var ratio := _constellation_result_param(counter_result, "countershot_damage_ratio", 0.55)
	_fire_bayonet_countershot_line(origin, target.global_position, base_damage * ratio)


func _fire_bayonet_countershot_line(origin: Vector2, through_position: Vector2, counter_damage: float) -> void:
	var line_direction := (through_position - origin).normalized()
	if line_direction.length_squared() <= 0.001 or counter_damage <= 0.0:
		return
	var line_end := origin + line_direction * maxf(bayonet_shot_range, attack_range)
	_register_effect(AttackVfx.beam(_projectile_parent(), origin, line_end, maxf(beam_width * 0.55, 10.0), visual_color))
	var half_width := maxf(beam_width * 0.75, 14.0)
	for target in TARGET_QUERY.enemies(self):
		if not is_instance_valid(target):
			continue
		var enemy := target as Node2D
		if enemy == null:
			continue
		var relative := enemy.global_position - origin
		var forward := relative.dot(line_direction)
		if forward < 0.0 or forward > maxf(bayonet_shot_range, attack_range):
			continue
		if absf(relative.cross(line_direction)) > half_width:
			continue
		_call_take_damage(enemy, counter_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "bayonet_brace_countershot"})


func _is_enemy_inside_bayonet_cone(origin: Vector2, enemy_position: Vector2, direction: Vector2) -> bool:
	var to_enemy := enemy_position - origin
	var distance := to_enemy.length()
	# Анти-deadzone: враг у самых ног (включая застрявшего на игроке) всегда в зоне.
	if distance <= BAYONET_CONTACT_RESCUE_RADIUS:
		return true
	if distance > attack_range:
		return false
	return absf(direction.angle_to(to_enemy)) <= deg_to_rad(clampf(cone_degrees, 1.0, 360.0) * 0.5)


# Авто-выстрел штыка: цель — ближайший враг ВНЕ конуса (дальше досягаемости укола),
# в пределах bayonet_shot_range; без такой цели пуля уходит по направлению укола.
# Урон bayonet_shot_damage_multiplier от укола первому врагу на траектории.
func _fire_bayonet_auto_shot(owner_node: Node2D, direction: Vector2) -> void:
	var shot_direction := direction
	var beyond_target := _find_bayonet_shot_target(owner_node)
	if beyond_target != null:
		var to_target := beyond_target.global_position - owner_node.global_position
		if to_target.length_squared() > 0.001:
			shot_direction = to_target.normalized()
	var start := owner_node.global_position + shot_direction * 22.0
	var tracer := AttackVfx.beam(_projectile_parent(), start, owner_node.global_position + shot_direction * bayonet_shot_range, beam_width * 0.6, Color(visual_color.r, visual_color.g, visual_color.b, 0.50))
	_register_effect(tracer)
	_emit_weapon_animation_event(owner_node, "pulse", 0.0, shot_direction, {"bayonet_shot": true})
	var hits := _enemies_in_corridor(start, shot_direction, maxf(beam_width, 40.0), bayonet_shot_range)
	if hits.is_empty():
		return
	_damage_enemy(hits[0]["node"], _rolled_damage(owner_node) * bayonet_shot_damage_multiplier)


func _find_bayonet_shot_target(owner_node: Node2D) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	var origin := owner_node.global_position
	for enemy_node in TARGET_QUERY.enemies(self):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var distance := origin.distance_to(enemy_node.global_position)
		if distance <= attack_range or distance > bayonet_shot_range:
			continue
		if distance < best_distance:
			best_distance = distance
			best = enemy_node
	return best


# === SCRUM-897: кит Вора (редизайн поверх trait «Воровская хватка») ===
# Ниши: экономический рикошет по толпе / контроль-кинжал с backstab-пейоффом /
# защитная дым-зона с разовым AoE-взрывом. Константы ниже — единственный источник
# истины по капам/долям; бюджетная модель (_budget_hit_model в progression_data.gd)
# зеркалит эти же числа в комментариях.

# «Кошель Рикошета»: жёсткий кап длины цепи. База 6 прыжков (projectile_count),
# артефакт «Счастливая монета» (coin_extra_bounces) добирает до 8; FAN-1893:
# generic extra_projectile цепь не удлиняет. Цепь конечна и не становится
# лучшим полнокартным клиром (полоса AC 5..8).
const COIN_CHAIN_HARD_CAP := 8

# «Отравленный Кинжал»: базовый удар фантома в долях ролла и позиционный пейофф.
const BACKSTAB_STRIKE_MULTIPLIER := 1.22       # базовый удар фантома
const BACKSTAB_POSITIONAL_MULTIPLIER := 1.35   # доп. множитель удара В СПИНУ (цель смотрит прочь от фантома)
const BACKSTAB_NEIGHBOR_SHARE := 0.35          # доля ролла соседям у точки удара
const BACKSTAB_FACING_DOT_THRESHOLD := 0.25    # порог «спина отдана фантому» (dot facing · фантом→цель)
const POISON_PARALYSIS_SPEED := 0.12           # целевой множитель скорости яда (StatusEffects клампит группу на 0.25)
const POISON_PARALYSIS_CAP := 1.8              # кап суммарного окна паралича (база + артефакт), сек
const POISON_PARALYSIS_BOSS_FACTOR := 0.25     # боссы/элиты: срезанное окно (~0.21с база; на скейле темпа аптайм <60%)


func _fire_coin_ricochet(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var current_target := target
	if current_target == null:
		current_target = _find_closest_enemy(owner_node, INF)
	if current_target == null:
		var miss := _spawn_projectile_visual(owner_node.global_position + direction * 24.0, direction)
		_register_effect(miss)
		var miss_tween := create_tween()
		miss_tween.tween_property(miss, "global_position", owner_node.global_position + direction * min(attack_range, 280.0), 0.18)
		# SCRUM-551: резолвим miss/self по instance_id (захват Node в lambda «освобождался» в CSV).
		var miss_id := miss.get_instance_id()
		var weapon_miss_self_id := get_instance_id()
		miss_tween.tween_callback(func() -> void:
			var w := instance_from_id(weapon_miss_self_id) as Node
			var m := instance_from_id(miss_id) as Node
			if w != null and is_instance_valid(w) and m != null and is_instance_valid(m):
				w.call("_release_effect", m)
		)
		return

	var chain_targets := [current_target]
	var used := {current_target.get_instance_id(): true}
	var search_origin := current_target.global_position
	# FAN-1893: прыжки рикошета — не снаряды; цепь удлиняет только классовый
	# артефакт coin_extra_bounces (SCRUM-961 «Счастливая монета»), generic
	# extra_projectile инертен. SCRUM-897 капит длину COIN_CHAIN_HARD_CAP —
	# рикошет конечен по AC.
	var chain_count := clampi(projectile_count + int(_owner_mod("coin_extra_bounces")), 1, COIN_CHAIN_HARD_CAP)
	for chain_index in range(chain_count - 1):
		var next_target := _find_nearest_enemy_from(search_origin, attack_range * 0.65, used)
		if next_target == null:
			break
		chain_targets.append(next_target)
		used[next_target.get_instance_id()] = true
		search_origin = next_target.global_position

	var damage_value := _rolled_damage(owner_node)
	var origin := owner_node.global_position + direction * 24.0
	# SCRUM-897: монотонный спад до damage_falloff-доли (0.5) на ПОСЛЕДНЕМ
	# ЗАДУМАННОМ прыжке: hit_i = ролл × tail^(i/(n-1)). Экспонента считается от
	# полной длины цепи, поэтому спад читаем при любом числе реально найденных целей.
	var chain_tail := clampf(damage_falloff, 0.1, 1.0)
	var chain_span := maxf(float(chain_count - 1), 1.0)
	for hit_index in range(chain_targets.size()):
		var enemy_node := chain_targets[hit_index] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var segment := AttackVfx.beam(_projectile_parent(), origin, enemy_node.global_position, beam_width, visual_color)
		_register_effect(segment)
		_register_effect(AttackVfx.projectile_trace(_projectile_parent(), origin, enemy_node.global_position, visual_color, _projectile_visual_profile(), 0.10))
		var hit_damage := damage_value * pow(chain_tail, float(hit_index) / chain_span)
		_damage_enemy(enemy_node, hit_damage)
		_try_steal_money(owner_node, hit_index)
		origin = enemy_node.global_position
	if chain_targets.size() >= 4:
		_constellation_event("return", chain_targets[0] as Node2D, damage_value, {"unique_targets": chain_targets.size()})


# SCRUM-897 «Отравленный Кинжал»: фантомный удар из тени ЗА ближайшей целью.
# Герой НЕ двигается и НЕ телепортируется (позиционный пейофф в духе Dead Cells
# Assassin's Dagger): кинжал материализуется за спиной цели, паралич-яд даёт окно
# на побег или добивание, удар в спину бьёт больнее.
func _fire_shadow_backstab(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var backstab_target := target
	if backstab_target == null:
		backstab_target = _find_closest_enemy(owner_node, INF)
	if backstab_target == null:
		_fire_stab_flurry(owner_node, direction)
		return
	var approach := (backstab_target.global_position - owner_node.global_position).normalized()
	if approach.length_squared() <= 0.001:
		approach = direction
	var start_position := owner_node.global_position
	var back_position := backstab_target.global_position + approach * 46.0
	var shadow_distance := start_position.distance_to(back_position)
	var max_shadow_reach := minf(attack_range, 360.0)
	if shadow_distance > max_shadow_reach:
		back_position = start_position + (back_position - start_position).normalized() * max_shadow_reach
	var strike_direction := (backstab_target.global_position - back_position).normalized()
	if strike_direction.length_squared() <= 0.001:
		strike_direction = -approach
	var slash := AttackVfx.slash(_projectile_parent(), strike_direction, aoe_radius, visual_color)
	_register_effect(slash)
	slash.global_position = back_position
	var damage_value := _rolled_damage(owner_node)
	var strike_damage := damage_value * BACKSTAB_STRIKE_MULTIPLIER
	# Позиционный backstab: цель отдаёт спину фантому (смотрит/движется прочь) —
	# чейзеры, идущие на героя, наказываются; враг, глядящий на фантом, видит удар.
	var positional_backstab := _is_backstab_hit(backstab_target, back_position, owner_node.global_position)
	if positional_backstab:
		strike_damage *= BACKSTAB_POSITIONAL_MULTIPLIER
	_damage_enemy(backstab_target, strike_damage)
	if positional_backstab and is_instance_valid(backstab_target):
		var mark_result := _constellation_event("hit", backstab_target, 0.0, {"constellation_consumer_event": true})
		if bool(mark_result.get("triggered", false)):
			_arm_constellation_target_mark(backstab_target, "backstab", _constellation_result_param(mark_result, "mark_duration_seconds", 2.5), _constellation_result_param(mark_result, "followup_damage_cap", 0.28), _constellation_result_param(mark_result, "execute_threshold", 0.30))
	# Встроенный контроль SCRUM-897: короткое окно паралича-яда (кап, босс-резист);
	# SCRUM-961 «Парализующее лезвие» (backstab_root_duration) продлевает окно.
	var paralysis_window := clampf(poison_paralysis_duration + _owner_mod("backstab_root_duration"), 0.0, POISON_PARALYSIS_CAP)
	_apply_poison_paralysis(backstab_target, paralysis_window)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or enemy_node == backstab_target or not is_instance_valid(enemy_node):
			continue
		if back_position.distance_squared_to(enemy_node.global_position) <= pow(aoe_radius * 0.55, 2.0):
			_damage_enemy(enemy_node, damage_value * BACKSTAB_NEIGHBOR_SHARE)
			_apply_poison_paralysis(enemy_node, paralysis_window)
	var vanish := AttackVfx.ring_pulse(_projectile_parent(), back_position, 62.0, visual_color, false)
	_register_effect(vanish)


# SCRUM-897: условие удара в спину — цель смотрит ПРОЧЬ от фантома. Направление
# взгляда: живая скорость врага (движение), иначе фоллбэк «чейзер смотрит на
# героя». Фантом появляется за спиной цели относительно героя, поэтому идущий на
# героя враг отдаёт спину, а убегающий/идущий на фантом — видит кинжал.
func _is_backstab_hit(enemy_node: Node2D, phantom_position: Vector2, owner_position: Vector2) -> bool:
	var away_from_phantom := enemy_node.global_position - phantom_position
	if away_from_phantom.length_squared() <= 0.001:
		return true
	var facing := Vector2.ZERO
	var velocity_raw = enemy_node.get("velocity")
	if velocity_raw is Vector2 and (velocity_raw as Vector2).length_squared() > 4.0:
		facing = (velocity_raw as Vector2).normalized()
	else:
		facing = (owner_position - enemy_node.global_position).normalized()
	if facing.length_squared() <= 0.001:
		return true
	return facing.dot(away_from_phantom.normalized()) >= BACKSTAB_FACING_DOT_THRESHOLD


# SCRUM-897: боссы и элиты сопротивляются контролю — окно паралича срезано
# (POISON_PARALYSIS_BOSS_FACTOR), пермалок невозможен (кап + короткая база).
# SCRUM-909/913: тот же общий резист режет и trait-отброс лука, и паралич капкана.
func _control_resist_factor(enemy_node: Node2D) -> float:
	if enemy_node.is_in_group("bosses") or enemy_node.is_in_group("elite_enemies"):
		return POISON_PARALYSIS_BOSS_FACTOR
	return 1.0


# SCRUM-909 «Сторожевой лук» (CLASS_TRAITS.ranger, data-driven): каждый прямой
func _apply_ranger_bow_knockback(enemy: Node) -> void:
	if not bow_knockback_trait:
		return
	var enemy_node := enemy as Node2D
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	var owner_node := _owner_node()
	if owner_node == null or not owner_node.has_method("class_trait_value"):
		return
	var trait_scale := float(owner_node.call("class_trait_value", "bow_hit_knockback"))
	if trait_scale <= 0.0:
		return
	var away := enemy_node.global_position - owner_node.global_position
	if away.length_squared() <= 0.001:
		return
	_push_enemy_scaled(enemy_node, away.normalized(), trait_scale * _control_resist_factor(enemy_node))


func _apply_poison_paralysis(enemy_node: Node2D, duration: float) -> void:
	var effective_duration := duration * _control_resist_factor(enemy_node)
	if effective_duration <= 0.0:
		return
	# Паралич-лайт: StatusEffects.speed_multiplier клампит группу статусов на 0.25 —
	# жертва почти стоит, но контроль не абсолютен и всегда конечен.
	StatusEffects.apply_status(enemy_node, "poison_paralysis", {
		"duration": effective_duration,
		"speed_multiplier": POISON_PARALYSIS_SPEED,
		"marker_color": Color(0.50, 0.95, 0.45, 1.0),
	})


# SCRUM-897 «Дымовая Бомба»: брошенный снаряд с отложенной детонацией. Шашка
func _fire_smoke_bomb(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.10), direction, {"delayed": true})
	var target_position: Vector2 = owner_node.global_position + direction * min(attack_range, 240.0)
	if target != null:
		target_position = target.global_position
	var bomb := _spawn_projectile_visual(owner_node.global_position + direction * 20.0, target_position - owner_node.global_position)
	_register_effect(bomb)
	var fuse := maxf(grenade_delay, 0.10)
	var travel_tween := create_tween()
	travel_tween.tween_property(bomb, "global_position", target_position, fuse)
	# SCRUM-551: без захвата узлов в лямбду — Callable.bind по instance_id
	# (tween умирает вместе с оружием, бесхозная детонация невозможна).
	var detonation_tween := create_tween()
	detonation_tween.tween_interval(fuse)
	detonation_tween.tween_callback(Callable(self, "_detonate_smoke_bomb").bind(owner_node.get_instance_id(), bomb.get_instance_id(), target_position, direction))


func _detonate_smoke_bomb(owner_instance_id: int, bomb_instance_id: int, target_position: Vector2, direction: Vector2) -> void:
	var bomb := instance_from_id(bomb_instance_id) as Node
	if bomb != null and is_instance_valid(bomb):
		_release_effect(bomb)
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_instance_id) as Node2D
	if current_owner != null and not is_instance_valid(current_owner):
		current_owner = null
	var damage_value := damage if current_owner == null else _rolled_damage(current_owner)
	# Единственное дамажащее событие дыма — сам взрыв.
	_damage_enemies_in_circle(target_position, aoe_radius, damage_value)
	AttackVfx.orb_burst(_projectile_parent(), target_position, aoe_radius, _projectile_impact_color())
	# Облако после взрыва урона НЕ наносит — только позиционное уклонение.
	var cloud := AttackVfx.ring_pulse(_projectile_parent(), target_position, aoe_radius, visual_color, true)
	_register_effect(cloud)
	var cloud_duration := maxf(_effective_smoke_duration(), 0.2)
	if current_owner != null:
		_emit_weapon_animation_event(current_owner, "release", cloud_duration, direction, {"delayed": true})
		# SCRUM-961 «Дымный тайник»: облако плотнее (+smoke_dodge_bonus) и дольше
		# (_effective_smoke_duration); бонус живёт только внутри зоны облака.
		var cloud_dodge := dodge_bonus + _owner_mod("smoke_dodge_bonus")
		if current_owner.has_method("register_smoke_cloud"):
			current_owner.call("register_smoke_cloud", target_position, aoe_radius, cloud_duration, cloud_dodge)
	var cloud_tween := create_tween()
	cloud_tween.tween_interval(cloud_duration)
	cloud_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(cloud.get_instance_id()))


# === SCRUM-947..950: кит Элементалиста (редизайн поверх trait «Проводник стихий») ===
# Ниши: постоянный квадрат-ореол (кольцо) / редкий полнокартный X (призма) /
# сверхредкий нюк с догорающей зоной (метеор). Константы ниже — единственный
# источник истины по долям/геометрии; бюджетная модель (_budget_hit_model в
# progression_data.gd) зеркалит эти же числа в комментариях.

# SCRUM-948 «Кольцо Четырёх Стихий»: квадратная зона в точке каста.
const SQUARE_HALF_RATIO := 0.72          # половина стороны квадрата = aoe_radius * ratio
const SQUARE_PHYSICAL_SHARE := 0.45      # доля канала damage (ось силы) на КАСТ
const SQUARE_DOT_TICK_SHARE := 0.70      # доля dot_damage владельца на тик ожога
const SQUARE_EARTH_CORE_PHYS_BONUS := 0.60  # артефакт «Четвертое кольцо»: +60% физ.доли
const SQUARE_EXTRA_TICK_CAP := 2         # кап доп. тиков от extra-рун («Монолит»)
const SQUARE_ELEMENT_COLORS := [
	Color(1.0, 0.42, 0.16, 0.85),  # огонь
	Color(0.26, 0.76, 1.0, 0.85),  # вода
	Color(0.64, 1.0, 0.28, 0.85),  # природа
	Color(0.72, 0.52, 0.24, 0.85), # земля — четвёртая стихия
]

# SCRUM-949 «Призматический Фокус»: полнокартный X-разлом.
# PRISM_FULL_MAP_REACH — документированный практический предел «во всю карту»:
# длина плеча луча от центра. Диагональ арены 4096×2304 ≈ 4700px, значит 4800px
# достигает любой точки арены из любого центра каста (тест держит этот инвариант).
const PRISM_FULL_MAP_REACH := 4800.0
const PRISM_BEAM_DAMAGE_SHARE := 0.72    # один луч-хит на врага за каст (без дублей)
const PRISM_CENTER_BONUS_SHARE := 0.55   # бонус-хит центра пересечения (стакается с лучом)
const PRISM_CROSS_EXTRA_SHARE := 0.60    # артефакт «Призматический крест»: доп. крест «+»

# SCRUM-950 «Ядро Метеора»: grenade_delay = ПОЛНАЯ задержка до удара.
const METEOR_TELEGRAPH_RATIO := 0.42     # доля задержки на чистый телеграф до падения
const METEOR_FALL_HEIGHT := 540.0        # высота, с которой метеор летит в зону
const METEOR_ZONE_RADIUS_RATIO := 0.78   # радиус догорающей зоны от aoe_radius
const METEOR_ZONE_FULL_TARGETS := 2      # полные тики зоны ближайшим к ядру
const METEOR_ZONE_TARGET_DIMINISH := 1.2 # спад по рангу удалённости в зоне
const METEOR_HEART_CENTER_BONUS := 0.55  # артефакт «Сердце метеора»: +55% центра
const METEOR_HEART_EXTRA_ZONE_TICKS := 2 # и догорание на 2 тика дольше


# SCRUM-948: враги внутри КВАДРАТА (углы поражаются — вписанный круг их не берёт,
# за пределами стороны — нет). Сбор через окружающий радиус + осевой фильтр.
func _enemies_in_square(center: Vector2, half_size: float) -> Array:
	var result := []
	for enemy in TARGET_QUERY.in_radius(self, center, half_size * 1.4143):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var offset := enemy_node.global_position - center
		if absf(offset.x) <= half_size and absf(offset.y) <= half_size:
			result.append(enemy_node)
	return result


# SCRUM-948 «Кольцо Четырёх Стихий»: квадратная AoE четырёх стихий в точке каста
func _fire_elemental_orbit(owner_node: Node2D, direction: Vector2) -> void:
	# «Монолит»/extra-руны: дополнительные тики поля (кап SQUARE_EXTRA_TICK_CAP).
	var ticks := maxi(storm_ticks, 1) + clampi(_extra_projectiles(), 0, SQUARE_EXTRA_TICK_CAP)
	_emit_weapon_animation_event(owner_node, "channel", orbit_duration, direction, {"ticks": ticks})
	var center: Vector2 = owner_node.global_position
	var half_size: float = aoe_radius * SQUARE_HALF_RATIO
	var field_root := Node2D.new()
	field_root.name = "ElementalSquareField"
	field_root.z_index = 3
	_projectile_parent().add_child(field_root)
	_register_effect(field_root)
	field_root.global_position = center
	_draw_square_field(field_root, half_size)
	_elemental_square_tick(owner_node, center, half_size, ticks, 0)
	var tick_interval := maxf(orbit_duration / float(ticks), 0.08)
	var owner_id := owner_node.get_instance_id()
	var field_id := field_root.get_instance_id()
	var field_tween := create_tween()
	for tick_index in range(1, ticks):
		field_tween.tween_interval(tick_interval)
		field_tween.tween_callback(Callable(self, "_elemental_square_scheduled_tick").bind(owner_id, center, half_size, ticks, tick_index, direction))
	field_tween.tween_interval(tick_interval)
	field_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(field_id))


# FAN-2981: квадрат читается только текстурными рунами четырёх стихий по углам
# (под врагами, z_index поля 3). Линейная разметка граней удаллена — зона
# унифицирована по образцу меча: нарисованный спрайт, без Line2D-схем.
func _draw_square_field(field_root: Node2D, half_size: float) -> void:
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for corner_index in range(4):
		var rune := Sprite2D.new()
		rune.name = "ElementRune%d" % corner_index
		rune.texture = _weapon_visual_texture()
		rune.modulate = SQUARE_ELEMENT_COLORS[corner_index % SQUARE_ELEMENT_COLORS.size()]
		rune.scale = Vector2.ONE * 0.16
		rune.position = (corners[corner_index] as Vector2) * half_size
		field_root.add_child(rune)


func _elemental_square_scheduled_tick(owner_id: int, center: Vector2, half_size: float, ticks: int, tick_index: int, direction: Vector2) -> void:
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	_emit_weapon_animation_event(current_owner, "pulse", 0.0, direction, {"index": tick_index, "count": ticks})
	_elemental_square_tick(current_owner, center, half_size, ticks, tick_index)


# Один тик квадрата: три канала + отброс от ЦЕНТРА КВАДРАТА (не от героя — зона
# автономна после каста). Элиты/боссы получают тот же apply_knockback-импульс,
# что и у прочих отбросов оружий (их устойчивость решает enemy-сторона).
func _elemental_square_tick(owner_node: Node2D, center: Vector2, half_size: float, ticks: int, phase_index := 0) -> void:
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var tick_divisor := float(maxi(ticks, 1))
	var magic_tick := _rolled_damage(owner_node) / tick_divisor
	var physical_total := float(parameters.get("damage", 0.0)) * SQUARE_PHYSICAL_SHARE
	if _owner_mod("earth_orb_mode") > 0.0:
		# «Четвертое кольцо»: земляное ядро укрепляет физический канал квадрата.
		physical_total *= 1.0 + SQUARE_EARTH_CORE_PHYS_BONUS
	var physical_tick := physical_total / tick_divisor
	var dot_tick_damage := maxf(float(parameters.get("dot_damage", 2.0)) * SQUARE_DOT_TICK_SHARE, 0.5)
	var dot_interval := 1.0 / maxf(float(parameters.get("dot_speed", 1.0)), 0.2)
	var burn_ticks := maxi(dot_ticks, 1)
	var phase_target: Node2D = null
	# FAN-1031 3c(b2): крауд-кап тика квадрата. Ранг по дистанции к центру каста
	# берётся из отдельной карты — порядок итерации и phase_target (вход constellation
	# «hit») НЕ трогаем (zero-collateral). Сентинел (без orbit_*-override) → factor 1.0
	# всем → magic/phys/ожог побайтово прежние; оффендер (orb_ring) душит хвост толпы.
	var square_enemies := _enemies_in_square(center, half_size)
	var orbit_ranks := {}
	var orbit_ordered := _status_fanout_order(center, square_enemies)
	for order_rank in range(orbit_ordered.size()):
		orbit_ranks[(orbit_ordered[order_rank] as Node2D).get_instance_id()] = order_rank
	for enemy in square_enemies:
		var enemy_node := enemy as Node2D
		if phase_target == null:
			phase_target = enemy_node
		var orbit_factor := _orbit_fanout_factor(int(orbit_ranks.get(enemy_node.get_instance_id(), 0)))
		# FAN-1031 3c-final fix (peer review MAJOR): жёсткий кап ШИРИНЫ = SKIP, не ×0. Цель за
		# orbit_max_targets (factor==0) НЕ должна получать ни он-хит пайплайн `_damage_enemy`
		# (hit-фидбек / on_weapon_hit / constellation-хуки / он-хит статусы), ни refresh ожога
		# нулём (затирал живой four_elements_burn от предыдущего in-cap тика), ни пуш — как в
		# bio/pool/aoe-ветках (break/skip). Диминиш (factor>0) по-прежнему масштабирует урон.
		if orbit_factor <= 0.0:
			continue
		_damage_enemy(enemy_node, magic_tick * orbit_factor)
		if physical_tick > 0.0:
			_damage_enemy(enemy_node, physical_tick * orbit_factor, false, "physical", false)
		StatusEffects.apply_status(enemy_node, "four_elements_burn", {
			"duration": dot_interval * float(burn_ticks),
			"dot_damage": dot_tick_damage * orbit_factor,
			"dot_interval": dot_interval,
			"marker_color": Color(0.40, 0.82, 1.0, 1.0),
		})
		var away := enemy_node.global_position - center
		if away.length_squared() > 0.001:
			_push_enemy(enemy_node, away.normalized())
	if phase_target != null:
		var phase_name: String = ["fire", "water", "air", "earth"][phase_index % 4]
		var resonance := _constellation_event("hit", phase_target, 0.0, {"phase": phase_name, "constellation_consumer_event": true})
		if bool(resonance.get("triggered", false)):
			_damage_enemies_in_circle(center, half_size * 1.4143, _rolled_damage(owner_node) * _constellation_result_param(resonance, "resonance_damage_ratio", 0.48))
	# SCRUM-961 «Стихийный отдачник»: дополнительный радиальный пуш от кастера.
	_apply_elemental_repulse(owner_node, center, half_size * 1.4143)


func _release_effect_by_id(effect_id: int) -> void:
	var effect := instance_from_id(effect_id) as Node
	if effect != null:
		_release_effect(effect)


# SCRUM-961 «Стихийный отдачник»: радиальный пуш от кастера по врагам в зоне.
func _apply_elemental_repulse(owner_node: Node2D, center: Vector2, radius: float) -> void:
	var repulse_power := _owner_mod("elemental_repulse_power")
	if repulse_power <= 0.0 or owner_node == null or not is_instance_valid(owner_node):
		return
	for enemy in TARGET_QUERY.in_radius(self, center, radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var away := enemy_node.global_position - owner_node.global_position
		if away.length_squared() <= 0.001:
			continue
		if enemy_node.has_method("apply_knockback"):
			enemy_node.apply_knockback(away.normalized() * repulse_power * 3.0)
		else:
			enemy_node.global_position += away.normalized() * repulse_power * 0.10


# SCRUM-949 «Призматический Фокус»: полнокартный X-разлом через точку фокуса
func _fire_prism_rift(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.12), direction, {"delayed": true})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 360.0)
	if target != null:
		center = target.global_position
	var axis_a := direction.rotated(PI / 4.0)
	if axis_a.length_squared() <= 0.001:
		axis_a = Vector2(1, -1)
	axis_a = axis_a.normalized()
	var axis_b := axis_a.rotated(PI / 2.0)
	var telegraph_ids: Array = []
	for axis in [axis_a, axis_b]:
		var axis_vector: Vector2 = axis
		var tele_beam := AttackVfx.beam(_projectile_parent(), center - axis_vector * PRISM_FULL_MAP_REACH, center + axis_vector * PRISM_FULL_MAP_REACH, maxf(beam_width * 0.35, 12.0), Color(visual_color.r, visual_color.g, visual_color.b, 0.20))
		_register_effect(tele_beam)
		telegraph_ids.append(tele_beam.get_instance_id())
	var telegraph_ring := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(telegraph_ring)
	telegraph_ids.append(telegraph_ring.get_instance_id())
	var rift_tween := create_tween()
	rift_tween.tween_interval(maxf(grenade_delay, 0.12))
	rift_tween.tween_callback(Callable(self, "_resolve_prism_rift").bind(owner_node.get_instance_id(), center, axis_a, axis_b, direction, telegraph_ids))


func _resolve_prism_rift(owner_id: int, center: Vector2, axis_a: Vector2, axis_b: Vector2, direction: Vector2, telegraph_ids: Array) -> void:
	for telegraph_id in telegraph_ids:
		_release_effect_by_id(int(telegraph_id))
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner != null and is_instance_valid(current_owner):
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	var damage_value := damage
	if current_owner != null and is_instance_valid(current_owner):
		damage_value = _rolled_damage(current_owner)
	# Оси урона: главные диагонали X, при артефакте «Призматический крест» — ещё
	# крест «+» (горизонталь/вертикаль относительно атаки) со сниженной долей.
	var beam_axes := [[axis_a, PRISM_BEAM_DAMAGE_SHARE], [axis_b, PRISM_BEAM_DAMAGE_SHARE]]
	if _owner_mod("prism_cross_pierce") > 0.0:
		var cross_axis := direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
		beam_axes.append([cross_axis, PRISM_BEAM_DAMAGE_SHARE * PRISM_CROSS_EXTRA_SHARE])
		beam_axes.append([cross_axis.rotated(PI / 2.0), PRISM_BEAM_DAMAGE_SHARE * PRISM_CROSS_EXTRA_SHARE])
	var color_cycle := [Color(0.26, 0.78, 1.0, 0.50), Color(1.0, 0.46, 0.20, 0.50), Color(0.76, 0.42, 1.0, 0.42), Color(0.64, 1.0, 0.28, 0.42)]
	var struck := {}
	for axis_index in range(beam_axes.size()):
		var axis_vector: Vector2 = beam_axes[axis_index][0]
		var axis_share: float = beam_axes[axis_index][1]
		var beam_start := center - axis_vector * PRISM_FULL_MAP_REACH
		var beam_end := center + axis_vector * PRISM_FULL_MAP_REACH
		var beam_visual := AttackVfx.beam(_projectile_parent(), beam_start, beam_end, beam_width, color_cycle[axis_index % color_cycle.size()])
		_register_effect(beam_visual)
		for enemy in TARGET_QUERY.in_segment(self, beam_start, beam_end, beam_width):
			var enemy_node := enemy as Node2D
			if enemy_node == null or not is_instance_valid(enemy_node):
				continue
			var enemy_key := enemy_node.get_instance_id()
			if struck.has(enemy_key):
				continue
			struck[enemy_key] = true
			_damage_enemy(enemy_node, damage_value * axis_share)
	for enemy in TARGET_QUERY.in_radius(self, center, aoe_radius):
		_damage_enemy(enemy as Node2D, damage_value * PRISM_CENTER_BONUS_SHARE)
	var rift_result := _constellation_event("intersection", null, damage_value)
	if bool(rift_result.get("triggered", false)):
		var tick_ratio := _constellation_result_param(rift_result, "tick_damage_ratio", 0.18)
		var rift_seconds := _constellation_result_param(rift_result, "rift_seconds", 1.2)
		var boss_pin_factor := _constellation_result_param(rift_result, "boss_pin_factor", 0.0)
		for rift_target_raw in TARGET_QUERY.in_radius(self, center, aoe_radius * 0.72):
			var rift_target := rift_target_raw as Node2D
			var pin_duration := rift_seconds * (boss_pin_factor if TARGET_QUERY.is_epic_displacement_immune(rift_target) else 1.0)
			if pin_duration > 0.0:
				StatusEffects.apply_status(rift_target, "constellation_prism_pin", {"duration": pin_duration, "movement_locked": true})
		var rift_tween := create_tween()
		for tick_index in range(3):
			rift_tween.tween_interval(0.4)
			rift_tween.tween_callback(Callable(self, "_constellation_prism_rift_tick").bind(center, damage_value * tick_ratio))
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius, visual_color)
	# SCRUM-961 «Стихийный отдачник»: центр разлома толкает монстров от кастера.
	if current_owner != null and is_instance_valid(current_owner):
		_apply_elemental_repulse(current_owner, center, aoe_radius)


func _constellation_prism_rift_tick(center: Vector2, tick_damage: float) -> void:
	if _effects_shutdown or tick_damage <= 0.0:
		return
	AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius * 0.72, visual_color, false)
	for enemy_raw in TARGET_QUERY.in_radius(self, center, aoe_radius * 0.72):
		_call_take_damage(enemy_raw as Node2D, tick_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "prism_intersection_rift"})


# SCRUM-950 «Ядро Метеора»: самое медленное оружие игрока. grenade_delay — полная
func _fire_meteor_shards(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var total_delay := maxf(grenade_delay, 0.30)
	_emit_weapon_animation_event(owner_node, "windup", total_delay, direction, {"delayed": true})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 430.0)
	if target != null:
		center = target.global_position
	var telegraph_holder := Node2D.new()
	telegraph_holder.name = "MeteorTelegraph"
	_projectile_parent().add_child(telegraph_holder)
	telegraph_holder.global_position = center
	_register_effect(telegraph_holder)
	HazardVfx.telegraph(telegraph_holder, aoe_radius, Color(1.0, 0.45, 0.15, 1.0), total_delay)
	var meteor_start := center + Vector2(200.0, -METEOR_FALL_HEIGHT)
	var meteor := _spawn_projectile_visual(meteor_start, center - meteor_start)
	_register_effect(meteor)
	var fall_time := maxf(total_delay * (1.0 - METEOR_TELEGRAPH_RATIO), 0.15)
	var meteor_tween := create_tween()
	meteor_tween.tween_interval(total_delay - fall_time)
	meteor_tween.tween_property(meteor, "global_position", center, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	meteor_tween.tween_callback(Callable(self, "_resolve_meteor_impact").bind(owner_node.get_instance_id(), center, direction, meteor.get_instance_id(), telegraph_holder.get_instance_id()))


func _resolve_meteor_impact(owner_id: int, center: Vector2, direction: Vector2, meteor_id: int, telegraph_id: int) -> void:
	_release_effect_by_id(meteor_id)
	_release_effect_by_id(telegraph_id)
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var owner_alive := current_owner != null and is_instance_valid(current_owner)
	if owner_alive:
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	var damage_value := damage
	if owner_alive:
		damage_value = _rolled_damage(current_owner)
	var heart_mode := _owner_mod("meteor_heart_mode") > 0.0
	# «Сердце метеора»: реже (интервал ×1.45 в _fire_interval_artifact_factor),
	# но центральный удар жирнее и зона догорает дольше.
	var center_multiplier := 1.0 + (METEOR_HEART_CENTER_BONUS if heart_mode else 0.0)
	_damage_enemies_in_circle_falloff(center, aoe_radius, damage_value * center_multiplier, 0.55)
	var recall_result := _constellation_event("return", null, damage_value)
	if bool(recall_result.get("triggered", false)):
		var recall_ratio := maxf(float(recall_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
		var recall_tween := create_tween()
		recall_tween.tween_interval(0.20)
		recall_tween.tween_callback(Callable(self, "_constellation_meteor_recall").bind(center, damage_value * recall_ratio))
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius, _projectile_impact_color())
	if owner_alive:
		# SCRUM-961 «Стихийный отдачник»: удар метеора толкает монстров от кастера.
		_apply_elemental_repulse(current_owner, center, aoe_radius)
	var zone_ticks := maxi(dot_ticks, 1) + (METEOR_HEART_EXTRA_ZONE_TICKS if heart_mode else 0)
	var tick_interval := maxf(pool_tick_interval, 0.18)
	var zone_radius := aoe_radius * METEOR_ZONE_RADIUS_RATIO
	var zone_tween := create_tween()
	for tick_index in range(zone_ticks):
		zone_tween.tween_interval(tick_interval)
		zone_tween.tween_callback(Callable(self, "_meteor_zone_tick").bind(owner_id, center, zone_radius))


# Тик догорающей зоны метеора: периодический канал (тип "dot", ось знания),
# полные тики — ближайшим к ядру, дальше спад по рангу (анти-раздувание толпой).
func _meteor_zone_tick(owner_id: int, center: Vector2, zone_radius: float) -> void:
	if _effects_shutdown:
		return
	var tick_damage := 2.0
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner != null and is_instance_valid(current_owner):
		var parameters_raw = current_owner.get("derived_parameters")
		if parameters_raw is Dictionary:
			tick_damage = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)), 1.0)
	AttackVfx.ring_pulse(_projectile_parent(), center, zone_radius, Color(1.0, 0.45, 0.15, 0.22), false)
	var enemies: Array = TARGET_QUERY.in_radius(self, center, zone_radius)
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return center.distance_squared_to(a.global_position) < center.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		var factor := 1.0
		if index >= METEOR_ZONE_FULL_TARGETS:
			factor = 1.0 / (1.0 + float(index - METEOR_ZONE_FULL_TARGETS + 1) * METEOR_ZONE_TARGET_DIMINISH)
		_damage_enemy(enemies[index] as Node2D, tick_damage * factor, false, "dot", false)


func _constellation_meteor_recall(center: Vector2, shard_damage: float) -> void:
	if _effects_shutdown or shard_damage <= 0.0:
		return
	var hit_counts := {}
	for shard_index in range(6):
		var outer := center + Vector2.RIGHT.rotated(TAU * float(shard_index) / 6.0) * aoe_radius
		_register_effect(AttackVfx.beam(_projectile_parent(), outer, center, maxf(beam_width * 0.4, 12.0), visual_color))
		for enemy_raw in TARGET_QUERY.in_segment(self, outer, center, maxf(beam_width, 30.0)):
			var enemy := enemy_raw as Node2D
			if enemy == null or not is_instance_valid(enemy):
				continue
			var enemy_id := enemy.get_instance_id()
			if int(hit_counts.get(enemy_id, 0)) >= 2:
				continue
			hit_counts[enemy_id] = int(hit_counts.get(enemy_id, 0)) + 1
			_call_take_damage(enemy, shard_damage, {"damage_type": _weapon_damage_type(), "constellation_final": "meteor_shard_recall"})


# SCRUM-931 «Винтовка Мертвого Глаза» (PREFERRED-вариант, зафиксирован): всегда
const DEADEYE_LOCK_MAIN_MULT := 1.34        # тяжёлый прямой хит по дальней цели
const DEADEYE_ENDPOINT_BLAST_RATIO := 0.42  # FAN-1031 v7: 0.35→0.42 — deadeye-специфичный буст снайпера (терминальный взрыв на конце линии; вне budget-компенсации, лендится напрямую). Артефакт «Патрон мертвого глаза» добавляет сверху.
const SHATTER_VOLLEY_HIT_LIMIT := 2         # макс пуль в одного врага за залп


func _fire_sniper_lockshot(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# Всегда самая дальняя валидная цель; переданная цель — резервный aim.
	var locked_target := _find_farthest_enemy(owner_node, attack_range)
	if locked_target == null:
		locked_target = target
	var aim := direction
	if locked_target != null and is_instance_valid(locked_target):
		var to_target := locked_target.global_position - owner_node.global_position
		if to_target.length_squared() > 0.001:
			aim = to_target.normalized()
	var endpoint := owner_node.global_position + aim * attack_range
	if locked_target != null and is_instance_valid(locked_target):
		endpoint = locked_target.global_position
	var start := owner_node.global_position + aim * 30.0
	var telegraph := AttackVfx.beam(_projectile_parent(), start, endpoint, maxf(beam_width * 0.65, 18.0), Color(visual_color.r, visual_color.g, visual_color.b, 0.26))
	_register_effect(telegraph)
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.08), aim, {"delayed": true})
	var target_id := locked_target.get_instance_id() if (locked_target != null and is_instance_valid(locked_target)) else 0
	var lock_tween := create_tween()
	lock_tween.tween_interval(maxf(grenade_delay, 0.08))
	lock_tween.tween_callback(Callable(self, "_resolve_sniper_lockshot").bind(owner_node.get_instance_id(), target_id, aim, telegraph.get_instance_id()))


# SCRUM-931: разрешение выстрела винтовки — тяжёлый хит по дальней цели +
# overpenetration-коридор по попутчикам (кроме первичной цели, чтобы соло-выход
# совпадал с budget-моделью 1.34 + endpoint) + терминальный взрыв на конце линии
# + ближний самоподрыв. Trait «Дальний расчёт» скейлит каждый _damage_enemy по
# дистанции владелец→жертва в этот момент (AC: отложенная атака честна).
func _resolve_sniper_lockshot(owner_id: int, target_id: int, aim: Vector2, telegraph_id: int) -> void:
	var current_owner := instance_from_id(owner_id) as Node2D
	if _effects_shutdown or current_owner == null or not is_instance_valid(current_owner):
		_release_effect_by_id(telegraph_id)
		return
	var shot_aim := aim
	var locked := instance_from_id(target_id) as Node2D
	var endpoint := current_owner.global_position + shot_aim * attack_range
	if locked != null and is_instance_valid(locked):
		var to_target := locked.global_position - current_owner.global_position
		if to_target.length_squared() > 0.001:
			shot_aim = to_target.normalized()
		endpoint = locked.global_position
	var start := current_owner.global_position + shot_aim * 30.0
	var damage_value := _rolled_damage(current_owner)
	var tracer := AttackVfx.beam(_projectile_parent(), start, endpoint, beam_width, visual_color)
	_register_effect(tracer)
	_emit_weapon_animation_event(current_owner, "release", 0.0, shot_aim, {"delayed": true})
	var rifle_hit := damage_value * DEADEYE_LOCK_MAIN_MULT
	var pierced := {}
	if locked != null and is_instance_valid(locked):
		pierced[locked.get_instance_id()] = true
		rifle_hit *= _consume_constellation_target_mark(locked, "weakpoint", 1.0)
		_damage_enemy(locked, rifle_hit)
		var weakpoint := _constellation_event("hit", locked, 0.0, {"constellation_consumer_event": true})
		if bool(weakpoint.get("triggered", false)):
			_arm_constellation_target_mark(locked, "weakpoint", _constellation_result_param(weakpoint, "weakpoint_seconds", 4.0), _constellation_result_param(weakpoint, "bonus_damage_cap", 0.30))
	# Overpenetration: попутчики на линии (не первичная цель) ловят falloff-долю.
	for hit in _enemies_in_corridor(start, shot_aim, beam_width * 0.72, start.distance_to(endpoint)):
		var pierce_node := hit["node"] as Node2D
		if pierce_node == null or not is_instance_valid(pierce_node) or pierced.has(pierce_node.get_instance_id()):
			continue
		pierced[pierce_node.get_instance_id()] = true
		_damage_enemy(pierce_node, damage_value * damage_falloff)
	# Терминальный взрыв на конце линии (артефакт «Патрон мертвого глаза» усиливает).
	var endpoint_ratio := DEADEYE_ENDPOINT_BLAST_RATIO + _owner_mod("deadeye_terminal_blast")
	var blast_radius := maxf(beam_width * 2.2, aoe_radius * 0.28)
	AttackVfx.orb_burst(_projectile_parent(), endpoint, blast_radius, visual_color)
	_damage_enemies_in_circle_falloff(endpoint, blast_radius, damage_value * endpoint_ratio, 0.5)
	# Ближний самоподрыв у ног — ~80% урона выстрела по врагам вплотную.
	if close_burst_ratio > 0.0 and close_burst_radius > 0.0:
		AttackVfx.orb_burst(_projectile_parent(), current_owner.global_position, close_burst_radius, Color(visual_color.r, visual_color.g, visual_color.b, 0.30))
		_damage_enemies_in_circle_falloff(current_owner.global_position, close_burst_radius, rifle_hit * close_burst_ratio, 0.6)
	_release_effect_by_id(telegraph_id)


# SCRUM-961 «Патрон мертвого глаза»: самая дальняя цель в пределах дальности.
func _find_farthest_enemy(owner_node: Node2D, range_limit: float) -> Node2D:
	var best: Node2D = null
	var best_distance := -1.0
	var range_squared := range_limit * range_limit
	for enemy_node in TARGET_QUERY.enemies(self):
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var distance := owner_node.global_position.distance_squared_to(enemy_node.global_position)
		if distance <= range_squared and distance > best_distance:
			best_distance = distance
			best = enemy_node
	return best


# SCRUM-932 «Прицел Наводчика»: отложенный артиллерийский AoE. Красный
func _fire_sniper_kill_zone(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var center: Vector2 = owner_node.global_position + direction * minf(attack_range, 620.0)
	if target != null and is_instance_valid(target):
		center = target.global_position
	# Артефакт «Метка наводчика»: зона ложится быстрее и добивает сильнее.
	var fast_mark := _owner_mod("spotter_fast_mark") > 0.0
	var mark_delay := maxf(grenade_delay * (0.65 if fast_mark else 1.0), 0.12)
	var zone_radius := aoe_radius
	# Красный полупрозрачный телеграф (AC: semi-transparent red circle).
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), center, zone_radius, Color(0.95, 0.15, 0.12, 0.32), true)
	_register_effect(telegraph)
	_emit_weapon_animation_event(owner_node, "windup", mark_delay, direction, {"delayed": true})
	var zone_tween := create_tween()
	zone_tween.tween_interval(mark_delay)
	zone_tween.tween_callback(Callable(self, "_land_spotter_shell").bind(owner_node.get_instance_id(), center, zone_radius, telegraph.get_instance_id(), direction))


# SCRUM-932: падение снаряда Наводчика в конце задержки — тяжёлый AoE по всей
# зоне (falloff к краю), урон каждого попадания скейлит trait по дистанции
# владелец→жертва. Артефакт «Метка наводчика» добавляет добивающий множитель
# взамен снятого серийного удара старого дизайна.
func _land_spotter_shell(owner_id: int, center: Vector2, zone_radius: float, telegraph_id: int, direction: Vector2) -> void:
	if _effects_shutdown:
		_release_effect_by_id(telegraph_id)
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var damage_value := damage
	if current_owner != null and is_instance_valid(current_owner):
		damage_value = _rolled_damage(current_owner)
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	if _owner_mod("spotter_fast_mark") > 0.0:
		damage_value *= 1.15
	AttackVfx.orb_burst(_projectile_parent(), center, zone_radius, visual_color)
	_damage_enemies_in_circle_falloff(center, zone_radius, damage_value, damage_falloff)
	var priority_target: Node2D = null
	var priority_health := -1.0
	for candidate_raw in TARGET_QUERY.in_radius(self, center, zone_radius):
		var candidate := candidate_raw as Node2D
		var candidate_health = candidate.get("health")
		var score := float(candidate_health) if candidate_health != null else 0.0
		if score > priority_health:
			priority_health = score
			priority_target = candidate
	if priority_target != null:
		var priority := _constellation_event("target_acquired", priority_target, 0.0)
		if bool(priority.get("triggered", false)):
			var mark_until := Time.get_ticks_msec() + int(_constellation_result_param(priority, "mark_seconds", 3.0) * 1000.0)
			priority_target.set_meta(_constellation_mark_key("spotter"), {"until_msec": mark_until})
			var reserved := create_tween()
			reserved.tween_interval(0.08)
			reserved.tween_callback(Callable(self, "_constellation_spotter_reserved_beam").bind(priority_target.get_instance_id(), center, damage_value, mark_until, _constellation_result_param(priority, "priority_bonus_cap", 0.26)))
	_release_effect_by_id(telegraph_id)


func _constellation_spotter_reserved_beam(target_id: int, origin: Vector2, base_damage: float, mark_until: int, bonus_cap: float) -> void:
	if _effects_shutdown or Time.get_ticks_msec() > mark_until:
		return
	var target := instance_from_id(target_id) as Node2D
	if target == null or not is_instance_valid(target):
		return
	var mark_raw = target.get_meta(_constellation_mark_key("spotter"), {})
	if not mark_raw is Dictionary or int((mark_raw as Dictionary).get("until_msec", 0)) != mark_until:
		return
	target.remove_meta(_constellation_mark_key("spotter"))
	_register_effect(AttackVfx.beam(_projectile_parent(), origin, target.global_position, maxf(beam_width * 0.55, 12.0), visual_color))
	_call_take_damage(target, base_damage * clampf(bonus_cap, 0.0, 0.30), {"damage_type": _weapon_damage_type(), "constellation_final": "spotter_highest_hp_priority"})


# SCRUM-933 «Осколочные Патроны»: скорострельный круговой веер пуль по ближним
func _fire_sniper_split_round(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_constellation_shatter_volley_token += 1
	var volley_token := _constellation_shatter_volley_token
	_constellation_shatter_volleys[volley_token] = {}
	while _constellation_shatter_volleys.size() > 8:
		var oldest_token: int = int(_constellation_shatter_volleys.keys().min())
		_constellation_shatter_volleys.erase(oldest_token)
	var origin := owner_node.global_position
	var bullet_count := maxi(projectile_count + _extra_projectiles() + int(_owner_mod("shatter_extra_splits")), 1)
	var spray_radius := maxf(aoe_radius, 160.0)
	var candidates := _nearest_enemies_from(origin, spray_radius, bullet_count)
	if candidates.is_empty() and target != null and is_instance_valid(target):
		if origin.distance_to(target.global_position) <= spray_radius:
			candidates = [target]
	# Round-robin слоты: каждый ближний враг получает до SHATTER_VOLLEY_HIT_LIMIT
	# пуль, ближайшие — первыми (проходы по отсортированному списку).
	var target_slots: Array = []
	for volley_pass in range(SHATTER_VOLLEY_HIT_LIMIT):
		for candidate in candidates:
			if target_slots.size() >= bullet_count:
				break
			target_slots.append(candidate)
		if target_slots.size() >= bullet_count:
			break
	var damage_value := _rolled_damage(owner_node)
	var base_angle := direction.angle() if direction.length_squared() > 0.001 else 0.0
	for bullet_index in range(bullet_count):
		var aimed_target: Node2D = (target_slots[bullet_index] as Node2D) if bullet_index < target_slots.size() else null
		var bullet_aim: Vector2
		var bullet_finish: Vector2
		if aimed_target != null and is_instance_valid(aimed_target):
			var to_target: Vector2 = aimed_target.global_position - origin
			bullet_aim = to_target.normalized() if to_target.length_squared() > 0.001 else Vector2.RIGHT.rotated(base_angle)
			bullet_finish = aimed_target.global_position
		else:
			# Пустое направление: ровный радиальный веер, урона нет.
			var fan_angle := base_angle + TAU * float(bullet_index) / float(bullet_count)
			bullet_aim = Vector2.RIGHT.rotated(fan_angle)
			bullet_finish = origin + bullet_aim * spray_radius
		var bullet_start := origin + bullet_aim * 24.0
		var bullet := _spawn_projectile_visual(bullet_start, bullet_aim)
		_register_effect(bullet)
		var travel_time := clampf(bullet_start.distance_to(bullet_finish) / maxf(projectile_speed, 1.0), 0.04, 0.6)
		var aimed_id := aimed_target.get_instance_id() if (aimed_target != null and is_instance_valid(aimed_target)) else 0
		var bullet_tween := create_tween()
		bullet_tween.tween_property(bullet, "global_position", bullet_finish, travel_time).set_trans(Tween.TRANS_LINEAR)
		bullet_tween.tween_callback(Callable(self, "_impact_shatter_bullet").bind(bullet.get_instance_id(), aimed_id, damage_value, volley_token))
	_emit_weapon_animation_event(owner_node, "release", 0.0, direction, {})


# SCRUM-933: импакт одиночной пули веера — одиночный физический хит по своей
# цели (trait «Дальний расчёт» скейлит по дистанции), пули без цели просто
# гаснут. Разрешение через Callable + примитивы (SCRUM-551, без захвата узлов).
func _impact_shatter_bullet(bullet_id: int, target_id: int, damage_value: float, volley_token := 0) -> void:
	var bullet := instance_from_id(bullet_id) as Node
	if _effects_shutdown:
		if bullet != null and is_instance_valid(bullet):
			bullet.queue_free()
		return
	var enemy := instance_from_id(target_id) as Node2D
	if enemy != null and is_instance_valid(enemy):
		var enemy_id := enemy.get_instance_id()
		var state_key := volley_token
		if state_key <= 0:
			_constellation_shatter_volley_token += 1
			state_key = _constellation_shatter_volley_token
		var hit_counts_raw = _constellation_shatter_volleys.get(state_key, {})
		var hit_counts: Dictionary = hit_counts_raw if hit_counts_raw is Dictionary else {}
		if int(hit_counts.get(enemy_id, 0)) < 2:
			hit_counts[enemy_id] = int(hit_counts.get(enemy_id, 0)) + 1
			_constellation_shatter_volleys[state_key] = hit_counts
			AttackVfx.orb_burst(_projectile_parent(), enemy.global_position, maxf(beam_width, 18.0), _projectile_impact_color())
			_damage_enemy(enemy, damage_value)
			var pierce_result := _constellation_event("pierce", enemy, 0.0)
			if bool(pierce_result.get("triggered", false)):
				var excluded := {enemy_id: true}
				for counted_id in hit_counts.keys():
					if int(hit_counts.get(counted_id, 0)) >= 2:
						excluded[int(counted_id)] = true
				var next_target := TARGET_QUERY.nearest(self, enemy.global_position, maxf(aoe_radius, 160.0), excluded)
				if next_target != null:
					var repeat_ratio := maxf(float(pierce_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
					_register_effect(AttackVfx.beam(_projectile_parent(), enemy.global_position, next_target.global_position, maxf(beam_width * 0.45, 10.0), visual_color))
					_call_take_damage(next_target, damage_value * repeat_ratio, {"damage_type": _weapon_damage_type(), "constellation_final": "shatter_extra_pierce_falloff"})
					hit_counts[next_target.get_instance_id()] = int(hit_counts.get(next_target.get_instance_id(), 0)) + 1
					_constellation_shatter_volleys[state_key] = hit_counts
	if bullet != null and is_instance_valid(bullet):
		_release_effect(bullet)


# SCRUM-927: Реликварий — быстрый дальний бурст «тик-тик-тик» БЕЗ лечения
func _fire_priest_sanctify(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "windup", maxf(grenade_delay, 0.08), direction, {"delayed": true})
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 480.0)
	var target_id := 0
	if target != null:
		center = target.global_position
		target_id = target.get_instance_id()
	var mark := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(mark)
	# SCRUM-961 «Реликварный залп»: вспышки сильнее (+20%); темп — в
	# _fire_interval_artifact_factor (лечения у реликвария больше нет, SCRUM-927).
	var barrage_blast_mult := 1.2 if _owner_mod("reliquary_barrage_mode") > 0.0 else 1.0
	var tick_damage: float = _rolled_damage(owner_node) * clampf(sanctify_tick_ratio, 0.05, 1.0) * barrage_blast_mult
	var pulse_count: int = maxi(storm_ticks, 1)
	if target != null and is_instance_valid(target):
		target.set_meta(_constellation_mark_key("reliquary"), true)
		target.set_meta(_constellation_mark_key("reliquary_base"), tick_damage * float(pulse_count))
	for tick_index in range(pulse_count):
		var burst_tween := create_tween()
		burst_tween.tween_interval(maxf(grenade_delay, 0.08) + float(tick_index) * maxf(burst_interval, 0.06))
		# SCRUM-551: bound-метод вместо лямбды (анти use-after-free в tween).
		burst_tween.tween_callback(Callable(self, "_sanctify_burst_tick").bind(owner_node.get_instance_id(), target_id, center, direction, tick_index, pulse_count, tick_damage))
	# Снятие знака после последнего тика (mark по id — анти use-after-free).
	var release_tween := create_tween()
	var expiry_delay := maxf(grenade_delay, 0.08) + float(pulse_count) * maxf(burst_interval, 0.06) + 0.18
	release_tween.tween_interval(expiry_delay)
	release_tween.tween_callback(Callable(self, "_constellation_reliquary_expire_by_id").bind(owner_node.get_instance_id(), target_id, center, tick_damage * float(pulse_count)))
	release_tween.tween_callback(Callable(self, "_release_effect_by_id").bind(mark.get_instance_id()))


# Один тик бурста реликвария: вспышка малого радиуса по живой позиции цели.
func _sanctify_burst_tick(owner_id: int, target_id: int, stored_center: Vector2, direction: Vector2, tick_index: int, tick_count: int, tick_damage: float) -> void:
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	var impact_center := stored_center
	var current_target := instance_from_id(target_id) as Node2D
	if current_target != null and is_instance_valid(current_target):
		impact_center = current_target.global_position
	if tick_index == 0:
		_emit_weapon_animation_event(current_owner, "release", 0.0, direction, {"delayed": true})
	else:
		_emit_weapon_animation_event(current_owner, "pulse", maxf(burst_interval, 0.06), direction, {"index": tick_index, "count": tick_count})
	AttackVfx.orb_burst(_projectile_parent(), impact_center, aoe_radius * 0.72, visual_color)
	_damage_enemies_in_circle_falloff(impact_center, aoe_radius, tick_damage, damage_falloff)


# SCRUM-928: Кадило — большой БЛИЗКИЙ AoE с долгим кулдауном. Редкие тяжёлые
func _fire_priest_ward(owner_node: Node2D) -> void:
	var weapon_id := get_instance_id()
	var owner_id := owner_node.get_instance_id()
	var pulse_count: int = maxi(storm_ticks, 1)
	# SCRUM-961 «Обет кадила»: пульс реже (fire_interval-фактор), но шире (+45%
	# радиуса) и больнее (+35%) — DPS ≈ паритет, пейсинг-переработка.
	var vow_mode := _owner_mod("censer_vow_mode") > 0.0
	var vow_radius_mult := 1.45 if vow_mode else 1.0
	var vow_damage_mult := 1.35 if vow_mode else 1.0
	_emit_weapon_animation_event(owner_node, "burst", maxf(burst_interval, 0.06) * float(maxi(pulse_count - 1, 1)), Vector2.RIGHT, {"count": pulse_count})
	var ward_duration := maxf(burst_interval, 0.06) * float(pulse_count) + 0.35
	if owner_node.has_method("meta_apply_priest_ward"):
		owner_node.call("meta_apply_priest_ward", ward_duration)
	var censer_profile := _constellation_profile("censer_absorb_retaliation")
	if not censer_profile.is_empty() and owner_node.has_method("constellation_set_single_hit_ward"):
		var censer_params: Dictionary = censer_profile.get("params", {})
		owner_node.call("constellation_set_single_hit_ward", "censer_%d" % get_instance_id(), clampf(float(censer_params.get("absorb_ratio", 0.18)), 0.0, 0.80), ward_duration)
	var damage_value: float = _rolled_damage(owner_node) * vow_damage_mult
	# FAN-1031 v8-микротрим: крауд-добор Жреца перенесён с каденции реликвария (смягчена выше)
	var ward_full := aoe_full_targets if aoe_full_targets >= 0 else 9999
	var ward_diminish := aoe_target_diminish if aoe_target_diminish >= 0.0 else 0.0
	for pulse_index in range(pulse_count):
		var ward_tween := create_tween()
		ward_tween.tween_interval(float(pulse_index) * maxf(burst_interval, 0.06))
		ward_tween.tween_callback(func() -> void:
			var current_weapon := instance_from_id(weapon_id) as Node
			var current_owner := instance_from_id(owner_id) as Node2D
			if current_weapon == null or current_owner == null:
				return
			current_weapon.call("_emit_weapon_animation_event", current_owner, "pulse", maxf(float(current_weapon.get("burst_interval")), 0.06), Vector2.RIGHT, {"index": pulse_index, "count": pulse_count})
			# SCRUM-928: волны раскрываются от 0.80 до ПОЛНОГО aoe_radius —
			# «большой близкий AoE», заявленный радиус реально достигается.
			var pulse_progress := 1.0 if pulse_count <= 1 else float(pulse_index) / float(pulse_count - 1)
			var radius: float = float(current_weapon.get("aoe_radius")) * lerpf(0.80, 1.0, pulse_progress) * vow_radius_mult
			AttackVfx.ring_pulse(current_weapon.call("_projectile_parent"), current_owner.global_position, radius, current_weapon.get("visual_color"), false)
			current_weapon.call("_damage_enemies_in_circle_capped", current_owner.global_position, radius, damage_value, ward_full, ward_diminish)
		)


# SCRUM-929: Колокол Молитвы — dual toll. Каждый удар создаёт РОВНО два центра
func _fire_priest_dual_toll(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var bell_target: Node2D = target
	if bell_target == null:
		bell_target = _find_closest_enemy(owner_node, INF)
	var target_center: Vector2 = owner_node.global_position + direction * minf(attack_range, 480.0)
	if bell_target != null and is_instance_valid(bell_target):
		target_center = bell_target.global_position
	_emit_weapon_animation_event(owner_node, "release", 0.14, direction, {"dual": true})
	var damage_value: float = _rolled_damage(owner_node)
	# Резонанс-линия между центрами — читаемость связи двух взрывов (AC SCRUM-929).
	AttackVfx.beam(_projectile_parent(), owner_node.global_position, target_center, beam_width * 0.5, Color(visual_color.r, visual_color.g, visual_color.b, 0.26))
	var toll_hit := {}
	_fire_bell_toll_blast(target_center, damage_value, toll_hit)
	_fire_bell_toll_blast(owner_node.global_position, damage_value, toll_hit)
	if toll_hit.size() >= 3:
		var return_result := _constellation_event("return", null, 0.0, {"unique_targets": toll_hit.size()})
		if bool(return_result.get("triggered", false)) and owner_node.has_method("constellation_set_timed_absorb"):
			var mechanic = owner_node.call("constellation_weapon_mechanic", weapon_id, "chime_owner_return_shield") if owner_node.has_method("constellation_weapon_mechanic") else {}
			var params: Dictionary = (mechanic as Dictionary).get("params", {}) if mechanic is Dictionary else {}
			var shield := minf(float(owner_node.get("max_health")) * clampf(float(params.get("return_shield_ratio", 0.12)), 0.0, 1.0), maxf(float(params.get("shield_cap", 18.0)), 0.0))
			owner_node.call("constellation_set_timed_absorb", "chime_%d" % get_instance_id(), shield, 4.0)
	# SCRUM-961 «Двойной колокол» (rework под dual-toll базу SCRUM-929): эхо-звон —
	# оба взрыва повторяются через 0.45с на 45% урона (свой дедуп на эхо-волну).
	if _owner_mod("chime_twin_toll") > 0.0:
		var echo_tween := create_tween()
		echo_tween.tween_interval(0.45)
		# SCRUM-551: bound-метод вместо лямбды (анти use-after-free в tween).
		echo_tween.tween_callback(Callable(self, "_fire_bell_echo_toll").bind(owner_node.get_instance_id(), target_center, damage_value * 0.45))


# Эхо-волна «Двойного колокола»: повторный dual toll со своим дедупом.
func _fire_bell_echo_toll(owner_id: int, target_center: Vector2, amount: float) -> void:
	if _effects_shutdown:
		return
	var echo_hit := {}
	_fire_bell_toll_blast(target_center, amount, echo_hit)
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner != null and is_instance_valid(current_owner):
		_fire_bell_toll_blast(current_owner.global_position, amount, echo_hit)


# Одиночный взрыв колокола с общим дедупом волны: враг в перекрытии двух
# центров ловит урон ровно один раз (per-enemy max-hit, SCRUM-929).
func _fire_bell_toll_blast(center: Vector2, amount: float, toll_hit: Dictionary) -> void:
	AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, false)
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius * 0.55, visual_color)
	for enemy in TARGET_QUERY.in_radius(self, center, aoe_radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var enemy_id := enemy_node.get_instance_id()
		if toll_hit.has(enemy_id):
			continue
		toll_hit[enemy_id] = true
		_damage_enemy(enemy_node, amount)


# SCRUM-896: Споровая Линза — ЛОКАЛЬНЫЙ AoE у персонажа. Стартовый attack_range
# резко срезан данными (через экран не стреляет), «нравящийся» радиус колец
# сохранён. Три расширяющихся кольца бьют с falloff; КАЖДЫЙ задетый кольцом враг
# получает замедление (_apply_bio_spore_slow, AC SCRUM-896) и биоинфекцию
# (_apply_bio_infection — топливо trait'а «Разбор образцов», SCRUM-1005).
func _fire_bio_spore_bloom(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	_emit_weapon_animation_event(owner_node, "burst", maxf(burst_interval, 0.08) * float(maxi(storm_ticks - 1, 1)), direction, {"count": maxi(storm_ticks, 1)})
	var center: Vector2 = owner_node.global_position + direction * minf(attack_range, 420.0)
	var target_id := 0
	if target != null:
		center = target.global_position
		target_id = target.get_instance_id()
	var damage_value: float = _rolled_damage(owner_node)
	# SCRUM-961 «Расщепленный анализ»: первый задетый враг делится спорами с соседями.
	_apply_bio_split_analysis(TARGET_QUERY.nearest(self, center, aoe_radius), damage_value)
	var pulse_count: int = maxi(storm_ticks, 1)
	for pulse_index in range(pulse_count):
		var bloom_tween := create_tween()
		bloom_tween.tween_interval(float(pulse_index) * maxf(burst_interval, 0.08))
		# SCRUM-551: bound-метод вместо лямбды (анти use-after-free в tween).
		bloom_tween.tween_callback(Callable(self, "_bio_spore_pulse").bind(owner_node.get_instance_id(), target_id, center, direction, pulse_index, pulse_count, damage_value))


# Одно кольцо линзы: урон с диминишингом по дистанции, затем замедление и
# инфекция ВСЕХ задетых (порядок «урон → статусы»: бонус trait'а по заражённым
# окупается со следующего кольца/каста, не в момент заражения).
func _bio_spore_pulse(owner_id: int, target_id: int, stored_center: Vector2, direction: Vector2, pulse_index: int, pulse_count: int, damage_value: float) -> void:
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	_emit_weapon_animation_event(current_owner, "pulse", maxf(burst_interval, 0.08), direction, {"index": pulse_index, "count": pulse_count})
	var impact_center := stored_center
	var current_target := instance_from_id(target_id) as Node2D
	if current_target != null and is_instance_valid(current_target):
		impact_center = current_target.global_position
	var radius: float = aoe_radius * (0.44 + 0.24 * float(pulse_index + 1))
	var factor: float = pow(damage_falloff, float(pulse_index))
	AttackVfx.ring_pulse(_projectile_parent(), impact_center, radius, visual_color, pulse_index == 0)
	_damage_enemies_in_circle_falloff(impact_center, radius, damage_value * factor, damage_falloff)
	_apply_bio_spore_slow(current_owner, impact_center, radius)
	var ring_targets := TARGET_QUERY.in_radius(self, impact_center, radius)
	# FAN-1031 3c(b): крауд-инфекция — ближние status_full_targets получают полный
	# DoT, дальний хвост толпы диминишится (порядок ring_targets для constellation
	# ниже НЕ трогаем — ранжируем в дубликате).
	var infect_order := _status_fanout_order(impact_center, ring_targets)
	for rank in range(infect_order.size()):
		var infect_factor := _status_fanout_factor(rank)
		# FAN-1031 3c(final): жёсткий кап ШИРИНЫ — за status_max_targets factor==0 → дальний
		# хвост толпы вообще не заражается (order отсортирован по дистанции → break). Без
		# override factor>0 всегда → цикл не прерывается (нулевое изменение поведения).
		if infect_factor <= 0.0:
			break
		_apply_bio_infection(infect_order[rank] as Node2D, current_owner, infect_factor)
	if pulse_index == pulse_count - 1 and not ring_targets.is_empty():
		var bloom_result := _constellation_event("final_ring", ring_targets[0] as Node2D, 0.0)
		if bool(bloom_result.get("triggered", false)):
			var bloom_cap := maxi(int(_constellation_result_param(bloom_result, "secondary_blooms", 4.0)), 0)
			var bloom_ratio := _constellation_result_param(bloom_result, "bloom_damage_ratio", 0.30)
			for bloom_index in range(mini(ring_targets.size(), bloom_cap)):
				var bloom_target := ring_targets[bloom_index] as Node2D
				AttackVfx.orb_burst(_projectile_parent(), bloom_target.global_position, maxf(aoe_radius * 0.18, 24.0), visual_color)
				_call_take_damage(bloom_target, damage_value * factor * bloom_ratio, {"damage_type": _weapon_damage_type(), "constellation_final": "spore_final_ring_blooms"})


# SCRUM-896: Инъектор Образцов — длинный пирсинг-луч Биолога. Урон получают ВСЕ
func _fire_bio_sample_dart(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var beam_direction := direction
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - owner_node.global_position
		if to_target.length_squared() > 0.001:
			beam_direction = to_target.normalized()
	if beam_direction.length_squared() <= 0.001:
		beam_direction = Vector2.RIGHT
	var start: Vector2 = owner_node.global_position + beam_direction * 26.0
	var beam_length: float = maxf(attack_range - 26.0, 60.0)
	var tip_center: Vector2 = start + beam_direction * beam_length
	if target != null and is_instance_valid(target):
		tip_center = target.global_position
	var tracer := AttackVfx.beam(_projectile_parent(), start, start + beam_direction * beam_length, beam_width, visual_color)
	_register_effect(tracer)
	_register_effect(AttackVfx.projectile_trace(_projectile_parent(), start, tip_center, visual_color, _projectile_visual_profile(), 0.14))
	_emit_weapon_animation_event(owner_node, "burst", maxf(burst_interval, 0.08), direction, {"count": 1})
	var damage_value: float = _rolled_damage(owner_node)
	var chain_artifact := _owner_mod("sample_beam_full_damage") > 0.0
	var line_multiplier := 1.3 if chain_artifact else 1.0
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var physical_bonus := maxf(float(parameters.get("damage", 0.0)), 0.0) * INJECTOR_PHYSICAL_SHARE * line_multiplier
	var injected: Node2D = null
	var injected_forward := INF
	for hit in _enemies_in_corridor(start, beam_direction, beam_width, beam_length):
		var line_enemy := hit["node"] as Node2D
		if line_enemy == null or not is_instance_valid(line_enemy):
			continue
		var sample_multiplier := 1.0
		if not _constellation_profile("injector_sample_analysis_ramp").is_empty():
			var sample_event := _constellation_event("hit", line_enemy, 0.0, {"constellation_consumer_event": true})
			var sample_stacks := _advance_constellation_target_stack(line_enemy, "sample", 4, _constellation_result_param(sample_event, "duration_seconds", 5.0))
			var sample_bonus := 0.08 * float(sample_stacks)
			if TARGET_QUERY.is_epic_displacement_immune(line_enemy):
				sample_bonus = minf(sample_bonus, 0.28)
			sample_multiplier += sample_bonus
		_damage_enemy(line_enemy, damage_value * line_multiplier * sample_multiplier)
		if physical_bonus > 0.0:
			_damage_enemy(line_enemy, physical_bonus, false, "physical", false)
		var forward := float(hit.get("forward", INF))
		if forward < injected_forward:
			injected_forward = forward
			injected = line_enemy
	var tip_radius := aoe_radius * (1.25 if chain_artifact else 1.0)
	AttackVfx.orb_burst(_projectile_parent(), tip_center, tip_radius * 0.42, _projectile_impact_color())
	_damage_enemies_in_circle_falloff(tip_center, tip_radius, damage_value * tip_burst_ratio, damage_falloff)
	if injected != null:
		_apply_bio_infection(injected, owner_node)
		# SCRUM-961 «Расщепленный анализ»: взятый образец делится с соседями.
		_apply_bio_split_analysis(injected, damage_value)


# SCRUM-896: Семя Симбионта — самое дальнобойное оружие кита с ТЕМПОРАЛЬНОЙ
func _fire_bio_symbiote_web(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	var germination_center: Vector2 = owner_node.global_position + direction * minf(attack_range, 720.0)
	if target != null and is_instance_valid(target):
		germination_center = target.global_position
	_emit_weapon_animation_event(owner_node, "channel", maxf(grenade_delay, 0.16), direction, {"seed": true})
	var seed_flight := AttackVfx.beam(_projectile_parent(), owner_node.global_position + direction * 24.0, germination_center, beam_width * 0.5, Color(visual_color.r, visual_color.g, visual_color.b, 0.30))
	_register_effect(seed_flight)
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), germination_center, aoe_radius, Color(visual_color.r, visual_color.g, visual_color.b, 0.22), false)
	_register_effect(telegraph)
	var damage_value: float = _rolled_damage(owner_node)
	var seed_tween := create_tween()
	seed_tween.tween_interval(maxf(grenade_delay, 0.08))
	# SCRUM-551: bound-метод вместо лямбды (анти use-after-free в tween).
	seed_tween.tween_callback(Callable(self, "_germinate_symbiote_seed").bind(owner_node.get_instance_id(), germination_center, damage_value))


# Прорастание семени: стартовый маг.хит по области, затем инфекция всех задетых
# (порядок «урон → статусы»: trait-бонус окупается со следующего каста).
func _germinate_symbiote_seed(owner_id: int, center: Vector2, damage_value: float) -> void:
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	var impact_damage := damage_value * maxf(seed_impact_ratio, 0.0) * (1.0 + _owner_mod("symbiote_impact_bonus"))
	_damage_enemies_in_circle_falloff(center, aoe_radius, impact_damage, damage_falloff)
	var ring_targets: Array = TARGET_QUERY.in_radius(self, center, aoe_radius)
	# FAN-1031 3c(b): крауд-инфекция ранжируется по дистанции (диминиш хвоста);
	# linked_targets (constellation) сохраняют ИСХОДНЫЙ порядок выборки — zero-collateral.
	var linked_targets: Array = []
	for enemy_node in ring_targets:
		if linked_targets.size() < 5:
			linked_targets.append(enemy_node)
	var infect_order := _status_fanout_order(center, ring_targets)
	for rank in range(infect_order.size()):
		var seed_infect_factor := _status_fanout_factor(rank)
		# FAN-1031 3c(final): жёсткий кап ШИРИНЫ заражения (см. _bio_spore_pulse). linked_targets
		# (constellation, кап 5) взяты ВЫШЕ из исходного порядка — их break не трогает.
		if seed_infect_factor <= 0.0:
			break
		_apply_bio_infection(infect_order[rank] as Node2D, current_owner, seed_infect_factor)
	if not linked_targets.is_empty():
		var host := linked_targets[0] as Node2D
		var link_result := _constellation_event("link", host, 0.0, {"linked_targets": linked_targets.size()})
		if bool(link_result.get("triggered", false)):
			var profile: Dictionary = current_owner.call("constellation_weapon_mechanic", weapon_id, "symbiote_link_transfer") as Dictionary if current_owner.has_method("constellation_weapon_mechanic") else {}
			var params: Dictionary = (profile as Dictionary).get("params", {}) if profile is Dictionary else {}
			var linked_ids := linked_targets.map(func(target): return (target as Node).get_instance_id())
			for linked_raw in linked_targets:
				var linked := linked_raw as Node2D
				linked.set_meta("constellation_symbiote_owner", current_owner.get_instance_id())
				linked.set_meta("constellation_symbiote_ids", linked_ids.duplicate())
				linked.set_meta("constellation_symbiote_share", clampf(float(params.get("shared_damage_ratio", 0.22)), 0.0, 0.5))
				linked.set_meta("constellation_symbiote_transfers", maxi(int(params.get("transfers_per_cast", 2)), 0))
	# SCRUM-961 «Расщепленный анализ»: ближайший к центру делится с соседями.
	_apply_bio_split_analysis(TARGET_QUERY.nearest(self, center, aoe_radius), impact_damage)


# SCRUM-896: базовое замедление Споровой Линзы (AC). Каждый задетый кольцом
func _apply_bio_spore_slow(owner_node: Node2D, center: Vector2, radius: float) -> void:
	var slow_power := _spore_slow_power(owner_node) + maxf(_owner_mod("spore_slow_power"), 0.0)
	if slow_power <= 0.0:
		return
	for enemy_node in TARGET_QUERY.in_radius(self, center, radius):
		StatusEffects.apply_status(enemy_node, "bio_spore_slow", {
			"duration": 1.6,
			"speed_multiplier": maxf(1.0 - slow_power, 0.25),
			"max_stacks": 1,
			"stack_mode": "refresh",
			"marker_color": Color(0.55, 0.95, 0.35, 1.0),
		})


# SCRUM-896: сила замедления линзы от прогрессии. spore_slow_base (5%) на
# старте, линейный рост к spore_slow_max (20%) к ~×3 эффективного magic_damage
# владельца от lvl1-базы класса; кламп с обеих сторон (AC: 5% мин, 20% макс) —
# сырой ростом урона потолок не пробивается.
func _spore_slow_power(owner_node: Node2D) -> float:
	if spore_slow_max <= 0.0:
		return 0.0
	if owner_node == null or not is_instance_valid(owner_node):
		return spore_slow_base
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var current_magic := maxf(float(parameters.get("magic_damage", 0.0)), 0.0)
	if _bio_magic_baseline <= 0.0:
		var raw_character = owner_node.get("character_id")
		var owner_class := str(raw_character) if raw_character != null and str(raw_character) != "" else "biologist"
		var baseline: Dictionary = ProgressionData.derived_parameters(ProgressionData.base_stats(owner_class), {}, ProgressionData.weapon(owner_class, weapon_id))
		_bio_magic_baseline = maxf(float(baseline.get("magic_damage", 1.0)), 0.001)
	var progress := clampf((current_magic / _bio_magic_baseline - 1.0) * 0.5, 0.0, 1.0)
	return clampf(spore_slow_base + (spore_slow_max - spore_slow_base) * progress, spore_slow_base, spore_slow_max)


# SCRUM-896/1005: биоинфекция — status-based DoT Биолога с атрибуцией владельца.
func _apply_bio_infection(enemy: Node, owner_node: Node2D, fanout_factor := 1.0) -> void:
	if dot_ticks <= 0 or enemy == null or not is_instance_valid(enemy):
		return
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var tick_damage := maxf(float(parameters.get("dot_damage", 1.0)), 1.0) * maxf(curse_tick_multiplier, 0.0) * clampf(fanout_factor, 0.0, 1.0)
	if tick_damage <= 0.0:
		return
	var tick_speed := maxf(float(parameters.get("dot_speed", 1.0)), 0.2) * maxf(curse_tick_rate, 0.2)
	var tick_interval := maxf(1.0 / tick_speed, 0.1)
	var total_ticks := dot_ticks
	if attack_mode == "bio_symbiote_web":
		total_ticks += int(_owner_mod("symbiote_dot_extra_ticks"))
	# SCRUM-942 паритет: классовый периодический множитель источника (у Биолога
	# 1.0) запекается в dot_damage на моменте применения — как у Химика.
	StatusEffects.apply_status_from(owner_node, enemy, "bio_infection", {
		"duration": (float(maxi(total_ticks, 1)) + 0.99) * tick_interval,
		"dot_damage": tick_damage,
		"dot_interval": tick_interval,
		"max_stacks": 1,
		"stack_mode": "refresh",
		"source_id": owner_node.get_instance_id(),
		"marker_color": Color(0.55, 0.95, 0.35, 1.0),
		"tick_feedback": {"damage_type": "dot", "player_owned": true, "bio_infection": true},
	})
	if enemy is Node2D:
		HazardVfx.dot_tick(enemy as Node2D, Color(visual_color.r, visual_color.g, visual_color.b, 1.0))


# SCRUM-961 «Расщепленный анализ»: первичная цель каста сплэшит долю урона на
# 2 ближайших врагов. Сплэш бьёт напрямую (без _damage_enemy) — без каскада.
func _apply_bio_split_analysis(primary: Node2D, amount: float) -> void:
	var split_ratio := _owner_mod("analysis_split_ratio")
	if split_ratio <= 0.0 or primary == null or not is_instance_valid(primary):
		return
	var excluded := {primary.get_instance_id(): true}
	for neighbor in TARGET_QUERY.nearest_many(self, primary.global_position, maxf(aoe_radius, 160.0), 2, excluded):
		if neighbor == null or not is_instance_valid(neighbor) or not neighbor.has_method("take_damage"):
			continue
		var spore := AttackVfx.beam(_projectile_parent(), primary.global_position, neighbor.global_position, beam_width * 0.5, Color(visual_color.r, visual_color.g, visual_color.b, 0.30))
		_register_effect(spore)
		_call_take_damage(neighbor, amount * split_ratio, {"damage_type": _weapon_damage_type()})


# SCRUM-961: он-хит статусы классовых артефактов. Только прямые хиты
# (apply_unique_melee_effects) — DoT/пул-тики стаки не накручивают.
func _apply_class_on_hit_statuses(enemy: Node) -> void:
	if not (enemy is Node2D) or not is_instance_valid(enemy):
		return
	if attack_mode.begins_with("bio_"):
		# «Колония торможения»: стакающееся замедление, кап 3 (−24% < кламп движка).
		var contact_slow := _owner_mod("bio_contact_slow")
		if contact_slow > 0.0:
			StatusEffects.apply_status(enemy, "bio_inhibitor_slow", {
				"duration": 2.0,
				"speed_multiplier": 1.0 - contact_slow,
				"stack_mode": "add",
				"max_stacks": 3,
				"marker_color": Color(0.40, 0.85, 0.30, 1.0),
			})
	elif attack_mode == "amp":
		# «Петля фидбэка»: пульсы усилителей стакают резонанс-уязвимость, кап 3 (+15%).
		var resonance := _owner_mod("amp_resonance_vuln")
		if resonance > 0.0:
			StatusEffects.apply_status(enemy, "amp_resonance_vuln", {
				"duration": 2.5,
				"damage_taken_multiplier": 1.0 + resonance,
				"stack_mode": "add",
				"max_stacks": 3,
				"marker_color": Color(0.30, 0.80, 1.0, 1.0),
			})


# SCRUM-961 «Второй залп»/«Боевой устав»: шанс повторить попадание ослабленным
# дублем (50% урона). duplicate_hit_chance сам по себе работает на аркебузе;
# duplicate_hit_universal распространяет дубль на гранату и штык. Суммарный шанс
# жёстко капится 0.65; дубль бьёт напрямую и дублей не порождает (§8.4).
func _maybe_duplicate_hit(enemy: Node, amount: float, hit_type: String) -> void:
	if hit_type == "dot":
		return
	var duplicate_chance := minf(_owner_mod("duplicate_hit_chance"), 0.65)
	if duplicate_chance <= 0.0:
		return
	var universal := _owner_mod("duplicate_hit_universal") > 0.0
	if attack_mode != "arquebus_shot" and not (universal and attack_mode in ["grenade_fuse", "bayonet_cone"]):
		return
	if randf() >= duplicate_chance:
		return
	if enemy is Node2D:
		AttackVfx.ring_pulse(_projectile_parent(), (enemy as Node2D).global_position, 46.0, Color(1.0, 0.85, 0.35, 0.40), false)
	_call_take_damage(enemy, amount * 0.5, {"damage_type": hit_type})


func _fire_robot_magnetic_anchor(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# SCRUM-915: редкий ТЯЖЁЛЫЙ AoE-пулл. Центр = точка якоря (цель/направление),
	var center: Vector2 = owner_node.global_position + direction * min(attack_range, 360.0)
	if target != null:
		center = target.global_position
	var telegraph := AttackVfx.ring_pulse(_projectile_parent(), center, aoe_radius, visual_color, true)
	_register_effect(telegraph)
	var tether := AttackVfx.beam(_projectile_parent(), owner_node.global_position + direction * 24.0, center, beam_width, Color(visual_color.r, visual_color.g, visual_color.b, 0.26))
	_register_effect(tether)
	var owner_id := owner_node.get_instance_id()
	var stored_center := center
	# SCRUM-1034: удар отложен на grenade_delay. Раньше колбэк был лямбдой с
	# ПРЯМЫМ захватом Node-ов telegraph/tether; эти VFX само-освобождаются раньше
	# удара, и Godot писал engine-ERROR «Lambda capture at index N was freed».
	# Канон SCRUM-551: Callable+bind по instance id, VFX/владелец — через id.
	var telegraph_id := telegraph.get_instance_id()
	var tether_id := tether.get_instance_id()
	var anchor_tween := create_tween()
	anchor_tween.tween_interval(maxf(grenade_delay, 0.08))
	anchor_tween.tween_callback(Callable(self, "_resolve_robot_anchor").bind(owner_id, stored_center, telegraph_id, tether_id))


func _resolve_robot_anchor(owner_id: int, center: Vector2, telegraph_id: int, tether_id: int) -> void:
	# Отложенный удар Магнитного Якоря. Твин принадлежит оружию (умирает вместе с
	# ним); владелец и VFX перепроверяются по instance id, поэтому освобождённый
	# телеграф/тезер даёт null без engine-ERROR (SCRUM-1034/551).
	if _effects_shutdown:
		_release_effect_by_id(telegraph_id)
		_release_effect_by_id(tether_id)
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var damage_value: float = _rolled_damage(current_owner) if (current_owner != null and is_instance_valid(current_owner)) else damage
	# Контракт SCRUM-915 не меняется: полный ролл с falloff от ЦЕНТРА якоря + пулл.
	_damage_enemies_in_circle_falloff(center, aoe_radius, damage_value, damage_falloff)
	_pull_enemies_toward(center, aoe_radius, knockback)
	for enemy_raw in TARGET_QUERY.in_radius(self, center, aoe_radius):
		var enemy := enemy_raw as Node2D
		if enemy == null or TARGET_QUERY.is_epic_displacement_immune(enemy):
			continue
		var setup := _constellation_event("hit", enemy, 0.0, {"constellation_consumer_event": true})
		if bool(setup.get("triggered", false)):
			_arm_constellation_target_mark(enemy, "anchor", _constellation_result_param(setup, "mark_seconds", 2.0), _constellation_result_param(setup, "bonus_damage_cap", 0.25))
	AttackVfx.orb_burst(_projectile_parent(), center, aoe_radius * 0.62, visual_color)
	_release_effect_by_id(telegraph_id)
	_release_effect_by_id(tether_id)


func _fire_robot_compression_line(owner_node: Node2D, target: Node2D, direction: Vector2) -> void:
	# SCRUM-916: широкий коридор компрессии. Урон наносится по ВСЕЙ ширине
	var center: Vector2 = owner_node.global_position + direction * min(attack_range * 0.58, 260.0)
	if target != null:
		var to_target := target.global_position - owner_node.global_position
		if to_target.length_squared() > 0.001:
			center = owner_node.global_position + to_target.normalized() * minf(to_target.length(), attack_range * 0.58)
	var start := owner_node.global_position + direction * 28.0
	var finish := owner_node.global_position + direction * attack_range
	var perpendicular := Vector2(-direction.y, direction.x).normalized()
	# SCRUM-961 «Калибратор пресса»: коридор компрессии шире (+30%), урон не растёт.
	var corridor_width := suppression_width
	if _owner_mod("press_corridor_bonus") > 0.0:
		corridor_width *= 1.30
	var left_start := start + perpendicular * corridor_width * 0.5
	var left_finish := finish + perpendicular * corridor_width * 0.5
	var right_start := start - perpendicular * corridor_width * 0.5
	var right_finish := finish - perpendicular * corridor_width * 0.5
	var left := AttackVfx.beam(_projectile_parent(), left_start, left_finish, beam_width * 0.42, Color(visual_color.r, visual_color.g, visual_color.b, 0.28))
	var right := AttackVfx.beam(_projectile_parent(), right_start, right_finish, beam_width * 0.42, Color(visual_color.r, visual_color.g, visual_color.b, 0.28))
	_register_effect(left)
	_register_effect(right)
	var owner_id := owner_node.get_instance_id()
	var line_start := start
	var line_finish := finish
	var line_direction := direction
	var line_perpendicular := perpendicular
	var clamp_center := center
	# SCRUM-1034: как и якорь — раньше колбэк был лямбдой с прямым захватом боковых
	# телеграфов left/right, которые само-освобождаются до удара (engine-ERROR
	# «Lambda capture was freed»). Канон SCRUM-551: Callable+bind по instance id.
	var left_id := left.get_instance_id()
	var right_id := right.get_instance_id()
	var press_tween := create_tween()
	press_tween.tween_interval(maxf(grenade_delay, 0.08))
	press_tween.tween_callback(Callable(self, "_resolve_robot_press").bind(owner_id, line_start, line_finish, line_direction, line_perpendicular, clamp_center, corridor_width, left_id, right_id))


func _resolve_robot_press(owner_id: int, line_start: Vector2, line_finish: Vector2, line_direction: Vector2, line_perpendicular: Vector2, clamp_center: Vector2, corridor_width: float, left_id: int, right_id: int) -> void:
	# Отложенная компрессия Гидравлического Пресса. Твин принадлежит оружию;
	# владелец и боковые VFX перепроверяются по instance id (SCRUM-1034/551).
	if _effects_shutdown:
		_release_effect_by_id(left_id)
		_release_effect_by_id(right_id)
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	var damage_value: float = _rolled_damage(current_owner) if (current_owner != null and is_instance_valid(current_owner)) else damage
	var impact := AttackVfx.beam(_projectile_parent(), line_start, line_finish, beam_width, visual_color)
	_register_effect(impact)
	# SCRUM-916: урон по полной ширине коридора, затем компрессия к оси (контракт не меняется).
	_damage_enemies_in_corridor(line_start, line_direction, damage_value, corridor_width)
	_compress_enemies_to_axis(line_start, line_direction, line_perpendicular, corridor_width, attack_range, knockback)
	AttackVfx.ring_pulse(_projectile_parent(), clamp_center, aoe_radius * 0.42, visual_color, false)
	_release_effect_by_id(left_id)
	_release_effect_by_id(right_id)


func _fire_robot_reactor_vent(owner_node: Node2D, _direction: Vector2) -> void:
	# SCRUM-918: Реакторное Ядро — вращающийся четырёхнаправленный веер.
	var damage_value := _rolled_damage(owner_node) * REACTOR_VENT_DAMAGE_RATIO
	var cycle_resolution := _constellation_event("cast", null, damage_value)
	if bool(cycle_resolution.get("triggered", false)):
		var pulse_ratio := _constellation_result_param(cycle_resolution, "pulse_damage_ratio", 0.40)
		var pulse_knockback := _constellation_result_param(cycle_resolution, "pulse_knockback", 110.0)
		for pulse_target in TARGET_QUERY.in_radius(self, owner_node.global_position, aoe_radius):
			var pulse_enemy := pulse_target as Node2D
			if pulse_enemy == null or not is_instance_valid(pulse_enemy):
				continue
			_call_take_damage(pulse_enemy, damage_value * pulse_ratio, {"damage_type": _weapon_damage_type(), "constellation_final": "reactor_vent_cycle_pulse"})
			var away := pulse_enemy.global_position - owner_node.global_position
			_push_enemy_scaled(pulse_enemy, away.normalized() if away.length_squared() > 0.001 else Vector2.RIGHT, pulse_knockback / maxf(knockback, 1.0))
	# FAN-1893: ширина лопасти — не число снарядов; generic «+1 снаряд» вентили
	# не расширяет (перегруженная width-интерпретация удалена), направлений
	# всегда ровно REACTOR_VENT_COUNT.
	var vent_width := beam_width
	var base_phase := _reactor_vent_phase
	_reactor_vent_phase = fmod(_reactor_vent_phase + deg_to_rad(REACTOR_ROTATION_STEP_DEG), TAU)
	AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, aoe_radius * 0.62, visual_color, true)
	# SCRUM-961 «Реакторный хронометр»: вентили этого каста идут последовательной
	# волной внутри интервала (без мёртвых пауз); канонический шаг паттерна
	# остаётся +6°/атака — артефакт меняет только развёртку внутри каста.
	if _owner_mod("reactor_smooth_rotation") > 0.0:
		var step := maxf(fire_interval, 0.2) * 0.85 / float(REACTOR_VENT_COUNT)
		var owner_id := owner_node.get_instance_id()
		var rotation_tween := create_tween()
		for vent_index in range(REACTOR_VENT_COUNT):
			var vent_direction := Vector2.RIGHT.rotated(base_phase + TAU * float(vent_index) / float(REACTOR_VENT_COUNT))
			if vent_index > 0:
				rotation_tween.tween_interval(step)
			# SCRUM-551: Callable+bind вместо лямбды с захватом узлов.
			rotation_tween.tween_callback(Callable(self, "_fire_reactor_vent_step").bind(owner_id, vent_direction, damage_value, vent_width))
		return
	for vent_index in range(REACTOR_VENT_COUNT):
		var vent_direction := Vector2.RIGHT.rotated(base_phase + TAU * float(vent_index) / float(REACTOR_VENT_COUNT))
		_fire_reactor_single_vent(owner_node, vent_direction, damage_value, vent_width)


func _fire_reactor_vent_step(owner_id: int, vent_direction: Vector2, damage_value: float, vent_width: float) -> void:
	# Отложенный вентиль «Реакторного хронометра». Твин принадлежит оружию
	# (умирает вместе с ним), владелец перепроверяется по instance id (SCRUM-551).
	if _effects_shutdown:
		return
	var current_owner := instance_from_id(owner_id) as Node2D
	if current_owner == null or not is_instance_valid(current_owner):
		return
	_fire_reactor_single_vent(current_owner, vent_direction, damage_value, vent_width)


func _fire_reactor_single_vent(owner_node: Node2D, vent_direction: Vector2, damage_value: float, vent_width := -1.0) -> void:
	var effective_width := vent_width if vent_width > 0.0 else beam_width
	var start := owner_node.global_position + vent_direction * 22.0
	var finish := owner_node.global_position + vent_direction * attack_range
	var beam := AttackVfx.beam(_projectile_parent(), start, finish, effective_width, visual_color)
	_register_effect(beam)
	_damage_enemies_in_segment(start, finish, effective_width, damage_value)
	for enemy in _enemies_in_corridor(start, vent_direction, effective_width, attack_range):
		var enemy_node := enemy["node"] as Node2D
		if enemy_node == null:
			continue
		_push_enemy(enemy_node, vent_direction)


func _fire_engineer_sentry_link(owner_node: Node2D, direction: Vector2) -> void:
	# SCRUM-905: «Часовая турель» = развёртка турелей С БОЕЗАПАСОМ.
	var alive_turrets: Array[Node] = []
	for device in _deployed_amps:
		if device != null and is_instance_valid(device):
			alive_turrets.append(device)
	_deployed_amps = alive_turrets
	var turret_limit := _engineer_turret_limit(owner_node)
	if _deployed_amps.size() >= turret_limit:
		return
	_emit_weapon_animation_event(owner_node, "deploy", 0.62, direction, {"pulse_interval": amp_pulse_interval})
	var turret_scene := SENTRY_TURRET_SCENE as PackedScene
	if turret_scene == null:
		return
	var turret := turret_scene.instantiate() as Node2D
	if turret == null:
		return
	if turret.has_method("setup"):
		turret.call("setup", self, owner_node)
	_projectile_parent().add_child(turret)
	_register_effect(turret)
	turret.global_position = owner_node.global_position + direction * 92.0
	_deployed_amps.append(turret)
	AttackVfx.ring_pulse(_projectile_parent(), turret.global_position, aoe_radius * 0.45, visual_color, false)
	# Мгновенное включение: турель сразу обстреливает ближайшего врага.
	if turret.has_method("try_fire"):
		turret.call("try_fire", self)


func _engineer_turret_limit(owner_node: Node2D) -> int:
	# SCRUM-905: предел парка = max_summons + floor(summon_amount/4)
	# (зеркало summon_count бюджет-модели), жёсткий рельс max_summons_cap;
	# бонус «Полевого чертежа» (+1 за каждые 6 Лидерства) добавляется ПОВЕРХ
	# рельса — иначе артефакт мёртв на раскачанном Лидерстве.
	var summon_amount := 0.0
	if owner_node != null and is_instance_valid(owner_node):
		var params = owner_node.get("derived_parameters")
		if params is Dictionary:
			summon_amount = maxf(float((params as Dictionary).get("summon_amount", 0.0)), 0.0)
	var limit := maxi(max_summons, 1) + int(floor(summon_amount / 4.0))
	if max_summons_cap > 0:
		limit = mini(limit, max_summons_cap)
	return maxi(limit + _blueprint_device_cap_bonus(owner_node), 1)


func _engineer_turret_projectile_hit(target_instance_id: int, shot_damage: float) -> void:
	# Прилёт снаряда турели (колбэк твина полёта; цель — по instance id,
	# см. SCRUM-551: без захвата узлов в лямбдах).
	if _effects_shutdown:
		return
	var target := instance_from_id(target_instance_id) as Node2D
	if target == null or not is_instance_valid(target):
		return
	_damage_enemy(target, shot_damage)
	_damage_engineer_sentry_splash(target, shot_damage)


func _damage_engineer_sentry_splash(primary_target: Node2D, shot_damage: float) -> void:
	if primary_target == null or not is_instance_valid(primary_target):
		return
	if sentry_splash_radius <= 0.0 or sentry_splash_damage_multiplier <= 0.0 or sentry_splash_target_cap <= 0:
		return
	var excluded := {primary_target.get_instance_id(): true}
	var splash_targets := TARGET_QUERY.nearest_many(self, primary_target.global_position, sentry_splash_radius, sentry_splash_target_cap, excluded)
	for index in range(splash_targets.size()):
		var splash_target := splash_targets[index] as Node2D
		if splash_target == null or not is_instance_valid(splash_target):
			continue
		var factor := sentry_splash_damage_multiplier / (1.0 + float(index) * 0.75)
		_damage_enemy(splash_target, shot_damage * factor, false, _weapon_damage_type(), false)


func _fire_engineer_orbit_drone(owner_node: Node2D, direction: Vector2) -> void:
	# SCRUM-906: «Орбитальный Дрон» — обслуживание ПОСТОЯННОГО парка орбитальных
	var alive_drones := _alive_orbit_drones()
	var target_count := _engineer_drone_target_count(owner_node)
	if alive_drones.size() >= target_count:
		return
	_emit_weapon_animation_event(owner_node, "deploy", 0.30, direction, {"drones": target_count})
	while alive_drones.size() < target_count:
		var drone := Node2D.new()
		drone.name = "EngineerOrbitDrone"
		drone.set_script(ENGINEER_ORBIT_DRONE_SCRIPT)
		var visual := Sprite2D.new()
		visual.texture = _weapon_visual_texture()
		visual.scale = Vector2.ONE * maxf(drone_visual_scale, 0.01)
		visual.modulate = Color(1.0, 1.0, 1.0, 0.92)
		drone.add_child(visual)
		_projectile_parent().add_child(drone)
		_register_effect(drone)
		if drone.has_method("setup"):
			drone.call("setup", self, owner_node, alive_drones.size(), target_count)
		alive_drones.append(drone)
	# Перераспределение фаз: спираль читается при любом числе дронов.
	for slot_index in range(alive_drones.size()):
		var slot_drone := alive_drones[slot_index]
		if slot_drone != null and is_instance_valid(slot_drone) and slot_drone.has_method("set_slot"):
			slot_drone.call("set_slot", slot_index, alive_drones.size())
	AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, drone_orbit_radius, visual_color, false)


func _engineer_drone_target_count(owner_node: Node2D) -> int:
	# SCRUM-906, FAN-1075: 2 дрона на базовом профиле Инженера; +1 за каждые
	# drone_count_step summon_amount сверх drone_count_threshold (порог ~
	# базовый summon_amount класса), рельс max_summons_cap. Задокументированные
	# пороги (threshold 12, step 4): 16 → 3, 20 → 4, 24 → 5, 28 → 6.
	var summon_amount := 0.0
	if owner_node != null and is_instance_valid(owner_node):
		var params = owner_node.get("derived_parameters")
		if params is Dictionary:
			summon_amount = maxf(float((params as Dictionary).get("summon_amount", 0.0)), 0.0)
	var extra := int(floor(maxf(summon_amount - drone_count_threshold, 0.0) / maxf(drone_count_step, 0.5)))
	var count := maxi(max_summons, 1) + extra
	if max_summons_cap > 0:
		count = mini(count, max_summons_cap)
	return maxi(count, 1)


func _alive_orbit_drones() -> Array[Node2D]:
	var drones: Array[Node2D] = []
	for effect in _alive_effects():
		if effect is Node2D and effect.has_meta("orbit_drone"):
			drones.append(effect as Node2D)
	return drones


func _fire_engineer_pressure_mines(owner_node: Node2D, direction: Vector2) -> void:
	# SCRUM-907: каждый деплой — 2 персистентные мины (projectile_count; extra-
	var mine_count := maxi(projectile_count + _extra_projectiles(), 1)
	_emit_weapon_animation_event(owner_node, "deploy", 0.40, direction, {"count": mine_count})
	var mine_cap := _engineer_mine_cap(owner_node)
	var alive_count := _alive_persistent_mines().size()
	var placement_min := maxf(mine_place_min_distance, 24.0)
	var placement_max := maxf(mine_place_max_distance, placement_min + 1.0)
	for mine_index in range(mine_count):
		if alive_count >= mine_cap:
			return
		var mine_direction := Vector2.RIGHT.rotated(randf() * TAU)
		var distance := randf_range(placement_min, placement_max)
		_spawn_engineer_pressure_mine(owner_node, owner_node.global_position + mine_direction * distance, mine_index)
		alive_count += 1


func _spawn_engineer_pressure_mine(owner_node: Node2D, mine_position: Vector2, mine_index: int) -> void:
	var mine := Node2D.new()
	mine.name = "EngineerPressureMine"
	mine.set_script(ENGINEER_MINE_SCRIPT)
	var visual := Sprite2D.new()
	visual.texture = _weapon_visual_texture()
	visual.scale = Vector2.ONE * 0.18
	visual.modulate = Color(1.0, 1.0, 1.0, 0.86)
	mine.add_child(visual)
	_projectile_parent().add_child(mine)
	_register_effect(mine)
	mine.global_position = mine_position
	if mine.has_method("setup"):
		mine.call("setup", self, owner_node, mine_index)
	AttackVfx.ring_pulse(_projectile_parent(), mine_position, aoe_radius * 0.52, visual_color, true)


# SCRUM-907: подрыв персистентной мины (зовёт scripts/engineer_mine.gd по
# триггеру врага/игрока). Урон по области с damage_falloff от эпицентра;
# «Ядро утилизации» возвращает долю перезарядки.
func _detonate_engineer_mine(mine_instance_id: int, owner_instance_id: int, mine_index: int, chain_depth := 0, chain_scale := 1.0, chain_hit_counts := {}) -> void:
	var mine := instance_from_id(mine_instance_id) as Node2D
	if mine == null or not is_instance_valid(mine):
		return
	var current_owner := instance_from_id(owner_instance_id) as Node2D
	var owner_alive := current_owner != null and is_instance_valid(current_owner)
	if owner_alive:
		_emit_weapon_animation_event(current_owner, "release", 0.0, Vector2.RIGHT, {"mine_index": mine_index})
	var mine_damage := (_rolled_damage(current_owner) if owner_alive else damage) * clampf(chain_scale, 0.0, 1.0)
	var hit_counts: Dictionary = chain_hit_counts if chain_hit_counts is Dictionary else {}
	for enemy_raw in TARGET_QUERY.in_radius(self, mine.global_position, aoe_radius):
		var enemy := enemy_raw as Node2D
		var enemy_id := enemy.get_instance_id()
		if int(hit_counts.get(enemy_id, 0)) >= 2:
			continue
		hit_counts[enemy_id] = int(hit_counts.get(enemy_id, 0)) + 1
		var distance := mine.global_position.distance_to(enemy.global_position)
		var factor := lerpf(1.0, clampf(damage_falloff, 0.0, 1.0), distance / maxf(aoe_radius, 1.0))
		_damage_enemy(enemy, mine_damage * factor)
	var chain_result := _constellation_event("mine_explosion", null, 0.0, {"chain_depth": chain_depth})
	if bool(chain_result.get("triggered", false)) and chain_depth < 2:
		var adjacent_mines := _alive_persistent_mines(mine)
		adjacent_mines.sort_custom(func(a: Node2D, b: Node2D) -> bool:
			return mine.global_position.distance_squared_to(a.global_position) < mine.global_position.distance_squared_to(b.global_position)
		)
		if not adjacent_mines.is_empty():
			var adjacent := adjacent_mines[0]
			var ratio := maxf(float(chain_result.get("damage_multiplier", 1.0)) - 1.0, 0.0)
			var chain_tween := create_tween()
			chain_tween.tween_interval(0.12)
			chain_tween.tween_callback(Callable(self, "_detonate_engineer_mine").bind(adjacent.get_instance_id(), owner_instance_id, mine_index, chain_depth + 1, ratio, hit_counts))
	AttackVfx.orb_burst(_projectile_parent(), mine.global_position, aoe_radius * 0.72, visual_color)
	_release_effect(mine)
	_salvage_device_refund()  # SCRUM-961 «Ядро утилизации»


func _engineer_mine_cap(owner_node: Node2D) -> int:
	# SCRUM-907: кап живых мин = mine_active_cap (база 6) + «Минная сумка»
	# (mine_cap_bonus) + «Полевой чертеж» (+1 за каждые 6 Лидерства).
	var cap := maxi(mine_active_cap, 1) + int(_owner_mod("mine_cap_bonus")) + _blueprint_device_cap_bonus(owner_node)
	return maxi(cap, 1)


# SCRUM-961 «Полевой чертеж» (SCRUM-905/907 rework): +1 к пределу устройств
# (турели и мины) за каждые 6 Лидерства. Прежний lifetime-бонус мин умер вместе
# с таймером жизни (мины теперь персистентные, SCRUM-907).
func _blueprint_device_cap_bonus(owner_node: Node2D) -> int:
	if _owner_mod("blueprint_leadership_scaling") <= 0.0:
		return 0
	var reference: Node2D = owner_node if owner_node != null and is_instance_valid(owner_node) else _owner_node()
	if reference == null:
		return 0
	var stats = reference.get("stats")
	if not (stats is Dictionary):
		return 0
	return int(floor(float((stats as Dictionary).get("leadership", 0.0)) / 6.0))


# SCRUM-961 «Корневой капкан»: сработавший капкан укореняет жертв (кламп движка


func _alive_persistent_mines(exclude: Node2D = null) -> Array[Node2D]:
	var alive_mines: Array[Node2D] = []
	for effect in _alive_effects():
		if effect is Node2D and effect.has_meta("persistent_mine") and effect != exclude:
			alive_mines.append(effect as Node2D)
	return alive_mines


# SCRUM-961 «Ядро утилизации»: отжившее/подорванное устройство возвращает
# долю перезарядки текущего deploy-оружия.
func _salvage_device_refund() -> void:
	var refund_ratio := _owner_mod("salvage_refund_ratio")
	if refund_ratio <= 0.0:
		return
	_cooldown = maxf(_cooldown - fire_interval * refund_ratio, 0.0)


# SCRUM-961 «Полевой чертеж»: Лидерство продлевает жизнь ловушек (+12% за 6 LDR).
# SCRUM-907: мины инженера персистентны и этот множитель больше НЕ используют —
# остаётся только generic trap-путь; для устройств см. _blueprint_device_cap_bonus.
func _blueprint_lifetime_multiplier() -> float:
	if _owner_mod("blueprint_leadership_scaling") <= 0.0:
		return 1.0
	var owner_node := _owner_node()
	if owner_node == null:
		return 1.0
	var stats = owner_node.get("stats")
	if not (stats is Dictionary):
		return 1.0
	return 1.0 + 0.12 * floor(float((stats as Dictionary).get("leadership", 0.0)) / 6.0)


func _pull_enemies_toward(center: Vector2, radius: float, force: float) -> void:
	# SCRUM-915: тяжёлый пулл Магнитного Якоря. Рядовые враги стягиваются К
	var anchor_bonus := _owner_mod("anchor_pull_power") if attack_mode == "robot_magnetic_anchor" else 0.0
	var convergence := clampf(
		ANCHOR_PULL_CONVERGENCE * (force / ANCHOR_PULL_FORCE_NORM) * (1.0 + maxf(anchor_bonus, 0.0)),
		0.10, ANCHOR_PULL_CONVERGENCE_CAP)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if not _is_non_elite_target(enemy_node):
			continue
		var to_center := center - enemy_node.global_position
		var distance := to_center.length()
		if distance <= 0.001 or distance > radius:
			continue
		var travel := distance * convergence
		if enemy_node.has_method("apply_knockback"):
			var impulse := minf(sqrt(KNOCKBACK_IMPULSE_TRAVEL_FACTOR * travel), ANCHOR_PULL_IMPULSE_CAP)
			enemy_node.apply_knockback(to_center.normalized() * impulse)
		else:
			enemy_node.global_position += to_center.normalized() * travel


# SCRUM-961: рядовой враг (не элитка/босс) — для эффектов, которые по контракту
# «элитки/боссы прямо исключены» (ядро якоря и т.п.).
func _is_non_elite_target(enemy_node: Node2D) -> bool:
	if enemy_node.is_in_group("elite_enemies") or enemy_node.is_in_group("bosses"):
		return false
	if enemy_node.has_meta("elite_behavior") or enemy_node.has_meta("boss_id"):
		return false
	return true


func _compress_enemies_to_axis(origin: Vector2, direction: Vector2, perpendicular: Vector2, width: float, range_limit: float, force: float) -> void:
	# SCRUM-916: компрессия Гидравлического Пресса. Врагов в коридоре прижимает
	var force_scale := clampf(force / PRESS_COMPRESSION_FORCE_NORM, 0.25, 1.6)
	var convergence := clampf(PRESS_COMPRESSION_CONVERGENCE * force_scale, 0.10, 0.95)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var to_enemy := enemy_node.global_position - origin
		var forward := to_enemy.dot(direction)
		if forward < -CONTACT_STUCK_HIT_BACK_ALLOWANCE or forward > range_limit:
			continue
		var side := to_enemy.dot(perpendicular)
		if absf(side) > width * 0.5 or absf(side) <= 0.001:
			continue
		var resist := 1.0 if _is_non_elite_target(enemy_node) else PRESS_ELITE_BOSS_COMPRESSION_FACTOR
		var travel := absf(side) * convergence * resist
		if travel <= 0.001:
			continue
		var push_direction := (-perpendicular if side > 0.0 else perpendicular).normalized()
		if push_direction.length_squared() <= 0.001:
			continue
		if enemy_node.has_method("apply_knockback"):
			var impulse := minf(sqrt(KNOCKBACK_IMPULSE_TRAVEL_FACTOR * travel), PRESS_COMPRESSION_IMPULSE_CAP)
			enemy_node.apply_knockback(push_direction * impulse)
		else:
			enemy_node.global_position += push_direction * travel


func _try_steal_money(owner_node: Node2D, hit_index: int) -> void:
	# SCRUM-897: золото начисляется МГНОВЕННО в кошель забега (gain_money) — без
	# спавна и сбора money-пикапа — и ДЕТЕРМИНИРОВАННО с первых steal_hits целей
	# цепи (читаемая экономика вместо прежнего 42%-ролла по хвосту).
	# SCRUM-961 «Счастливая монета»: coin_steal_bonus добавляет краденое золото.
	var effective_steal := steal_money + int(_owner_mod("coin_steal_bonus")) if steal_money > 0 else steal_money
	if effective_steal <= 0 or owner_node == null or not owner_node.has_method("gain_money"):
		return
	if hit_index >= maxi(steal_hits, 1):
		return
	owner_node.gain_money(effective_steal)


# SCRUM-897: прежний глобальный временный dodge (_apply_temporary_dodge через
# run_modifiers) удалён — уклонение дыма стало ПОЗИЦИОННЫМ (только внутри облака,
# см. _detonate_smoke_bomb + Player.smoke_cloud_dodge_bonus).
# SCRUM-961 «Дымный тайник»: длительность завесы с бонусом артефакта.
func _effective_smoke_duration() -> float:
	return smoke_duration * (1.0 + _owner_mod("smoke_duration_mult"))


func _extra_projectiles() -> int:
	var owner_node := _owner_node()
	if owner_node == null:
		return 0
	# FAN-1893: generic-ось «+1 снаряд» потребляется ТОЛЬКО оружием с явной
	# capability real_projectile_count > 0 — тогда каждый пункт добавляет ровно
	# один реальный снаряд боевого пути. У обычного оружия это его выстрел;
	# engineer_sentry_link читает шов из try_fire каждой активной турели, поэтому
	# один пункт добавляет по снаряду к каждому её залпу, но не меняет парк,
	# cadence, damage или summon scaling. Для остальных оружий generic-ключ
	# инертен (перегруженные интерпретации «лишняя ловушка/тик/звено/ширина»
	# удалены); семантические мета-ключи (trap_extra_count и т.п.) остаются.
	# FAN-2247: player-facing source отсутствует; direct probes и injected/future
	# values проверяют runtime seam, но не означают доступную игроку награду.
	var generic_extra := 0
	if real_projectile_count > 0:
		var mods = owner_node.get("run_modifiers")
		if mods is Dictionary:
			generic_extra = maxi(int((mods as Dictionary).get("extra_projectile", 0.0)), 0)
	var semantic_extra := 0
	if owner_node.has_method("meta_extra_projectiles"):
		semantic_extra = int(owner_node.call("meta_extra_projectiles", _meta_context()))
	return generic_extra + semantic_extra


func _effective_pierce_count() -> int:
	var owner_node := _owner_node()
	var extra := 0
	if owner_node != null and owner_node.has_method("meta_extra_pierce"):
		extra = int(owner_node.call("meta_extra_pierce", _meta_context({"charge_seconds": charge_seconds})))
	return maxi(pierce_count + extra, 1)


func _meta_context(extra := {}) -> Dictionary:
	var owner_node := _owner_node()
	var payload: Dictionary = extra.duplicate(true) if extra is Dictionary else {}
	payload["pool_element"] = pool_element
	payload["leaves_pool"] = leaves_pool
	payload["summon_role"] = summon_role
	payload["charge_seconds"] = charge_seconds
	if owner_node != null and owner_node.has_method("meta_context_for_weapon"):
		return owner_node.call("meta_context_for_weapon", self, payload)
	payload["weapon_id"] = weapon_id
	payload["attack_mode"] = attack_mode
	payload["damage_parameter"] = damage_parameter
	payload["damage_type"] = str(payload.get("damage_type", _weapon_damage_type()))
	return payload


func _constellation_event(event: String, enemy: Node2D = null, base_damage := 0.0, extra := {}) -> Dictionary:
	var owner_node := _owner_node()
	if owner_node == null or not owner_node.has_method("constellation_weapon_event"):
		return {"valid": true, "triggered": false}
	var context := _meta_context(extra)
	var resolution: Dictionary = owner_node.call("constellation_weapon_event", weapon_id, event, context, enemy)
	if not bool(resolution.get("valid", false)) or not bool(resolution.get("triggered", false)):
		return resolution
	var bonus_ratio := maxf(float(resolution.get("damage_multiplier", 1.0)) - 1.0, 0.0)
	if enemy != null and is_instance_valid(enemy) and base_damage > 0.0 and bonus_ratio > 0.0:
		_call_take_damage(enemy, base_damage * bonus_ratio, {"damage_type": _weapon_damage_type()})
	return resolution


func _constellation_result_param(result: Dictionary, key: String, fallback: float) -> float:
	var params = result.get("params", {})
	return float((params as Dictionary).get(key, fallback)) if params is Dictionary else fallback


func _constellation_profile(mechanic_id: String) -> Dictionary:
	var owner_node := _owner_node()
	if owner_node == null or not owner_node.has_method("constellation_weapon_mechanic"):
		return {}
	var raw = owner_node.call("constellation_weapon_mechanic", weapon_id, mechanic_id)
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func _constellation_mark_key(label: String) -> String:
	var owner_node := _owner_node()
	var owner_id := owner_node.get_instance_id() if owner_node != null else 0
	return "constellation_%s_%d" % [label, owner_id]


func _arm_constellation_target_mark(enemy: Node, label: String, duration: float, bonus: float, threshold := 1.0) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	enemy.set_meta(_constellation_mark_key(label), {
		"until_msec": Time.get_ticks_msec() + int(maxf(duration, 0.0) * 1000.0),
		"bonus": clampf(bonus, 0.0, 0.55),
		"threshold": clampf(threshold, 0.0, 1.0),
	})


func _consume_constellation_target_mark(enemy: Node, label: String, fallback_multiplier := 1.0) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return fallback_multiplier
	var key := _constellation_mark_key(label)
	var raw = enemy.get_meta(key, {})
	if not raw is Dictionary or (raw as Dictionary).is_empty():
		return fallback_multiplier
	var mark: Dictionary = raw
	if Time.get_ticks_msec() > int(mark.get("until_msec", 0)):
		enemy.remove_meta(key)
		return fallback_multiplier
	var max_hp_value = enemy.get("max_health")
	var hp_value = enemy.get("health")
	var threshold := float(mark.get("threshold", 1.0))
	if max_hp_value != null and hp_value != null and float(max_hp_value) > 0.0 and float(hp_value) / float(max_hp_value) > threshold:
		return fallback_multiplier
	enemy.remove_meta(key)
	return fallback_multiplier + clampf(float(mark.get("bonus", 0.0)), 0.0, 0.55)


func _advance_constellation_target_stack(enemy: Node, label: String, cap: int, duration: float) -> int:
	if enemy == null or not is_instance_valid(enemy):
		return 0
	var key := _constellation_mark_key(label)
	var raw = enemy.get_meta(key, {})
	var entry: Dictionary = raw if raw is Dictionary else {}
	var now_msec := Time.get_ticks_msec()
	var count := int(entry.get("count", 0)) if now_msec <= int(entry.get("until_msec", 0)) else 0
	count = mini(count + 1, maxi(cap, 1))
	enemy.set_meta(key, {"count": count, "until_msec": now_msec + int(maxf(duration, 0.0) * 1000.0)})
	return count


func constellation_owner_event(event: String, context := {}, enemy: Node2D = null) -> Dictionary:
	var payload: Dictionary = context if context is Dictionary else {}
	var base_damage := float(payload.get("dealt_damage", damage))
	var owner_node := _owner_node()
	if event == "dodge" and weapon_id == "thief_smoke_bomb" and bool(payload.get("smoke_zone", false)) and owner_node != null:
		var cloud_id := int(payload.get("smoke_cloud_id", 0))
		if cloud_id <= 0 or not owner_node.has_method("consume_smoke_cloud_constellation_burst") or not bool(owner_node.call("consume_smoke_cloud_constellation_burst", cloud_id)):
			return {"valid": true, "triggered": false}
		var center: Vector2 = payload.get("smoke_center", owner_node.global_position)
		var target := TARGET_QUERY.nearest(self, center, aoe_radius)
		var smoke_result := _constellation_event("dodge", target, 0.0, payload)
		if bool(smoke_result.get("triggered", false)):
			var burst_damage := _rolled_damage(owner_node) * _constellation_result_param(smoke_result, "burst_damage_ratio", 0.40)
			_damage_enemies_in_circle(center, aoe_radius, burst_damage)
			for affected in TARGET_QUERY.in_radius(self, center, aoe_radius):
				StatusEffects.apply_status(affected, "constellation_smoke_slow", {"duration": _constellation_result_param(smoke_result, "slow_seconds", 1.4), "speed_multiplier": 0.60})
		return smoke_result
	if event == "damage_absorbed" and weapon_id == "priest_censer" and owner_node != null:
		if str(payload.get("constellation_ward_source", "")) != ("censer_%d" % get_instance_id()):
			return {"valid": true, "triggered": false}
		var now_msec := Time.get_ticks_msec()
		if now_msec < int(_constellation_local_state.get("censer_ready_msec", 0)):
			return {"valid": true, "triggered": false}
		var target := TARGET_QUERY.nearest(self, owner_node.global_position, aoe_radius)
		if target == null:
			return {"valid": true, "triggered": false}
		var retaliation := _constellation_event("damage_absorbed", target, 0.0, payload)
		if bool(retaliation.get("triggered", false)):
			_constellation_local_state["censer_ready_msec"] = now_msec + int(_constellation_result_param(retaliation, "cooldown_seconds", 1.5) * 1000.0)
			_damage_enemies_in_circle(target.global_position, aoe_radius, _rolled_damage(owner_node) * _constellation_result_param(retaliation, "retaliation_damage_ratio", 0.45))
		return retaliation
	if event == "execute" and weapon_id == "shadow_daggers" and owner_node != null and enemy != null and not TARGET_QUERY.is_epic_displacement_immune(enemy):
		var now_msec := Time.get_ticks_msec()
		if now_msec < int(_constellation_local_state.get("shadow_window_ready_msec", 0)):
			return {"valid": true, "triggered": false}
		var window := _constellation_event("execute", enemy, 0.0, payload)
		if bool(window.get("triggered", false)) and owner_node.has_method("constellation_set_timed_dodge"):
			owner_node.call("constellation_set_timed_dodge", "shadow_window_%d" % get_instance_id(), _constellation_result_param(window, "dodge_bonus", 0.18), _constellation_result_param(window, "window_seconds", 0.75))
			_constellation_local_state["shadow_window_ready_msec"] = now_msec + int(_constellation_result_param(window, "cooldown_seconds", 3.0) * 1000.0)
		return window
	if event == "kill" and weapon_id == "cursed_skull" and enemy != null:
		return _constellation_transfer_skull_curse(enemy, payload)
	if event == "kill" and weapon_id == "biologist_symbiote_seed" and enemy != null and owner_node != null:
		var transferred := _constellation_transfer_symbiote_host(enemy, owner_node)
		return {"valid": true, "triggered": transferred}
	if event == "expiry" and weapon_id == "priest_reliquary":
		if enemy != null and bool(enemy.get_meta(_constellation_mark_key("reliquary"), false)):
			return _constellation_reliquary_expire(owner_node, enemy, enemy.global_position, base_damage)
		return {"valid": true, "triggered": false}
	match event:
		"block": return _constellation_event("block", enemy, base_damage, payload)
		"dodge": return _constellation_event("dodge", enemy, base_damage, payload)
		"damage_absorbed": return _constellation_event("damage_absorbed", enemy, base_damage, payload)
		"kill": return _constellation_event("kill", enemy, base_damage, payload)
		"execute": return _constellation_event("execute", enemy, base_damage, payload)
		"expiry": return _constellation_event("expiry", enemy, base_damage, payload)
	return {"valid": true, "triggered": false}


func _constellation_transfer_skull_curse(dead_host: Node2D, payload: Dictionary) -> Dictionary:
	var key := _constellation_mark_key("skull_curse")
	var raw = dead_host.get_meta(key, {})
	if not raw is Dictionary or int((raw as Dictionary).get("depth", 1)) >= 1:
		return {"valid": true, "triggered": false}
	dead_host.remove_meta(key)
	var transfer := _constellation_event("kill", dead_host, 0.0, payload)
	if not bool(transfer.get("triggered", false)):
		return transfer
	var status_raw = (raw as Dictionary).get("status", {})
	if not status_raw is Dictionary:
		return transfer
	var status: Dictionary = (status_raw as Dictionary).duplicate(true)
	status["duration"] = maxf(float(status.get("duration", 0.0)) * _constellation_result_param(transfer, "transfer_duration_ratio", 0.55), 0.0)
	var excluded := {dead_host.get_instance_id(): true}
	var target_cap := maxi(int(_constellation_result_param(transfer, "transfer_targets", 3.0)), 0)
	for target_raw in TARGET_QUERY.nearest_many(self, dead_host.global_position, aoe_radius * 1.5, target_cap, excluded):
		var target := target_raw as Node2D
		if target == null or not is_instance_valid(target):
			continue
		StatusEffects.apply_status(target, "skull_curse", status)
		target.set_meta(key, {"status": status.duplicate(true), "depth": 1})
	return transfer


func _constellation_reliquary_expire_by_id(owner_id: int, target_id: int, fallback_center: Vector2, burst_base: float) -> void:
	if _effects_shutdown:
		return
	var owner_node := instance_from_id(owner_id) as Node2D
	var target := instance_from_id(target_id) as Node2D
	if target == null or not is_instance_valid(target):
		return
	_constellation_reliquary_expire(owner_node, target, target.global_position if is_instance_valid(target) else fallback_center, burst_base)


func _constellation_reliquary_expire(owner_node: Node2D, target: Node2D, center: Vector2, burst_base: float) -> Dictionary:
	if owner_node == null or target == null or not is_instance_valid(target):
		return {"valid": true, "triggered": false}
	var mark_key := _constellation_mark_key("reliquary")
	if not bool(target.get_meta(mark_key, false)):
		return {"valid": true, "triggered": false}
	target.remove_meta(mark_key)
	var stored_base := float(target.get_meta(_constellation_mark_key("reliquary_base"), burst_base))
	target.remove_meta(_constellation_mark_key("reliquary_base"))
	var expiry := _constellation_event("expiry", target, 0.0, {"constellation_consumer_event": true})
	if not bool(expiry.get("triggered", false)):
		return expiry
	var wave_damage := maxf(stored_base, 0.0) * _constellation_result_param(expiry, "damage_ratio", 0.40)
	_damage_enemies_in_circle(center, aoe_radius, wave_damage)
	var now_msec := Time.get_ticks_msec()
	var window_start := int(_constellation_local_state.get("reliquary_heal_window_msec", 0))
	if now_msec - window_start >= 1000:
		window_start = now_msec
		_constellation_local_state["reliquary_healed"] = 0.0
	_constellation_local_state["reliquary_heal_window_msec"] = window_start
	var cap := _constellation_result_param(expiry, "heal_per_second_cap", 1.6)
	var already := float(_constellation_local_state.get("reliquary_healed", 0.0))
	var heal_amount := minf(wave_damage * _constellation_result_param(expiry, "heal_ratio", 0.08), maxf(cap - already, 0.0))
	if heal_amount > 0.0:
		var previous_health := float(owner_node.get("health"))
		var maximum := float(owner_node.get("max_health"))
		var actual := minf(heal_amount, maxf(maximum - previous_health, 0.0))
		owner_node.set("health", previous_health + actual)
		_constellation_local_state["reliquary_healed"] = already + actual
	return expiry


func _find_closest_enemy(owner_node: Node2D, range_limit := -1.0) -> Node2D:
	var max_distance := attack_range if range_limit < 0.0 else range_limit
	return TARGET_QUERY.nearest(self, owner_node.global_position, max_distance)


func _owner_uses_cursor_aim(owner_node: Node) -> bool:
	return owner_node != null and owner_node.has_method("attack_aim_mode") and str(owner_node.call("attack_aim_mode")) == "cursor"


func _enemies_in_corridor(origin: Vector2, direction: Vector2, width: float, range_limit: float) -> Array:
	return TARGET_QUERY.in_corridor(self, origin, direction, width, range_limit, _line_back_allowance(origin))


func _line_back_allowance(origin: Vector2) -> float:
	var owner_node := _owner_node()
	if owner_node == null:
		return 0.0
	if origin.distance_squared_to(owner_node.global_position) <= CONTACT_STUCK_HIT_BACK_ALLOWANCE * CONTACT_STUCK_HIT_BACK_ALLOWANCE:
		return CONTACT_STUCK_HIT_BACK_ALLOWANCE
	return 0.0


func _find_nearest_enemy_from(origin: Vector2, range_limit: float, excluded_ids: Dictionary) -> Node2D:
	return TARGET_QUERY.nearest(self, origin, range_limit, excluded_ids)


func _nearest_enemies_from(origin: Vector2, range_limit: float, count: int, excluded_ids: Dictionary = {}) -> Array:
	return TARGET_QUERY.nearest_many(self, origin, range_limit, count, excluded_ids)


func _enemies_in_circle_sorted(origin: Vector2, radius: float, count: int) -> Array:
	return _nearest_enemies_from(origin, radius, count)


func _is_enemy_inside_wave(origin: Vector2, enemy_position: Vector2, direction: Vector2) -> bool:
	var perpendicular := Vector2(-direction.y, direction.x)
	var to_enemy := enemy_position - origin
	var forward := to_enemy.dot(direction)
	if forward < -CONTACT_STUCK_HIT_BACK_ALLOWANCE or forward > attack_range:
		return false
	var width_ratio: float = clamp(forward / max(attack_range, 1.0), 0.0, 1.0)
	# SCRUM-961 «Зубья костяной пилы»: веер пилы шире (+saw_arc_width_mult).
	var effective_wave_width := wave_width
	if attack_mode == "stab_flurry":
		effective_wave_width *= 1.0 + _owner_mod("saw_arc_width_mult")
	var half_width := lerpf(58.0, effective_wave_width * 0.5, width_ratio)
	return abs(to_enemy.dot(perpendicular)) <= half_width


# SCRUM-523: КАНАЛ урона оружия → строковый тип для палитры боевых цифр.
func _weapon_damage_type() -> String:
	match damage_parameter:
		"magic_damage":
			return "magic"
		_:
			return "physical"


func _damage_enemy(enemy: Node, amount: float, apply_unique_melee_effects := true, damage_type := "", notify_owner_hit := true) -> void:
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("take_damage"):
		var hit_type := damage_type if damage_type != "" else _weapon_damage_type()
		var owner_node := _owner_node()
		var hit_context := _meta_context({"damage_type": hit_type})
		if owner_node != null and owner_node.has_method("telemetry_context_for_hit"):
			hit_context = owner_node.call("telemetry_context_for_hit", hit_context)
		var is_critical := _last_attack_crit and apply_unique_melee_effects
		hit_context["critical"] = is_critical
		var final_amount := amount
		if owner_node != null and owner_node.has_method("meta_damage_multiplier"):
			final_amount *= float(owner_node.call("meta_damage_multiplier", hit_context, enemy))
		if hit_type != "dot":
			match weapon_id:
				"thief_shadow_cloak": final_amount *= _consume_constellation_target_mark(enemy, "backstab")
				"robot_magnetic_anchor": final_amount *= _consume_constellation_target_mark(enemy, "anchor")
				"moon_crossbow": final_amount *= _consume_constellation_target_mark(enemy, "moon")
		# SCRUM-1005 «Разбор образцов»: ПРЯМЫЕ хиты владельца по цели под ЕГО
		if hit_type != "dot" and owner_node != null and owner_node.has_method("class_trait_value"):
			var infected_multiplier := maxf(float(owner_node.call("class_trait_value", "infected_direct_hit_multiplier", 1.0)), 1.0)
			if infected_multiplier > 1.0 and StatusEffects.has_dot_from_source(enemy, owner_node.get_instance_id()):
				final_amount *= infected_multiplier
			# SCRUM-930 «Дальний расчёт»: урон оружия Снайпера растёт с дистанцией
			final_amount *= _class_distance_trait_multiplier(owner_node, enemy as Node2D)
		var hit_feedback := {"critical": is_critical, "damage_type": hit_type}
		if owner_node != null and owner_node.has_method("telemetry_feedback_for_hit"):
			hit_feedback = owner_node.call("telemetry_feedback_for_hit", hit_context, hit_feedback)
		_call_take_damage(enemy, final_amount, hit_feedback)
		_apply_constellation_symbiote_share(enemy, owner_node, final_amount, hit_type)
		_apply_constellation_prey_distribution(enemy, owner_node, final_amount, hit_type)
		# SCRUM-961: он-хит статусы и дубль-выстрел солдата (только прямые хиты).
		if apply_unique_melee_effects:
			_apply_class_on_hit_statuses(enemy)
			_apply_ranger_bow_knockback(enemy)  # SCRUM-909 «Сторожевой лук»
			_maybe_duplicate_hit(enemy, final_amount, hit_type)
		if notify_owner_hit and owner_node != null and owner_node.has_method("on_weapon_hit"):
			owner_node.on_weapon_hit(enemy, final_amount, _last_attack_crit, hit_context)  # SCRUM-500/SCRUM-835: крит + semantic hit context
		_heal_owner_from_damage(owner_node, final_amount)
		if _last_attack_crit and crit_shadow_burst_radius > 0.0 and owner_node != null and owner_node.has_method("trigger_assassin_crit_shadow"):
			owner_node.trigger_assassin_crit_shadow(enemy, crit_shadow_burst_radius)
		if apply_unique_melee_effects and owner_node != null:
			_apply_unique_melee_hit_effects(owner_node, enemy, final_amount)


func _apply_constellation_symbiote_share(enemy: Node, owner_node: Node, amount: float, hit_type: String) -> void:
	if enemy == null or owner_node == null or not enemy.has_meta("constellation_symbiote_owner"):
		return
	if int(enemy.get_meta("constellation_symbiote_owner", 0)) != owner_node.get_instance_id():
		return
	var ratio := clampf(float(enemy.get_meta("constellation_symbiote_share", 0.0)), 0.0, 0.5)
	var linked_ids = enemy.get_meta("constellation_symbiote_ids", [])
	if ratio > 0.0 and linked_ids is Array:
		for linked_id in linked_ids:
			var linked := instance_from_id(int(linked_id)) as Node
			if linked == null or not is_instance_valid(linked) or linked == enemy or not linked.has_method("take_damage"):
				continue
			_call_take_damage(linked, amount * ratio, {"damage_type": hit_type, "constellation_final": "symbiote_link_transfer"})
	var health_value = enemy.get("health")
	if health_value == null or float(health_value) > 0.0:
		return
	_constellation_transfer_symbiote_host(enemy, owner_node)


func _constellation_transfer_symbiote_host(enemy: Node, owner_node: Node) -> bool:
	if enemy == null or owner_node == null or not enemy.has_meta("constellation_symbiote_owner"):
		return false
	if int(enemy.get_meta("constellation_symbiote_owner", 0)) != owner_node.get_instance_id():
		return false
	var ratio := clampf(float(enemy.get_meta("constellation_symbiote_share", 0.0)), 0.0, 0.5)
	var linked_ids = enemy.get_meta("constellation_symbiote_ids", [])
	var transfers := maxi(int(enemy.get_meta("constellation_symbiote_transfers", 0)), 0)
	if transfers <= 0 or not linked_ids is Array:
		return false
	var excluded := {}
	for linked_id in linked_ids:
		excluded[int(linked_id)] = true
	var enemy_position := (enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO
	var replacement := TARGET_QUERY.nearest(self, enemy_position, aoe_radius, excluded)
	if replacement == null:
		return false
	var next_ids: Array = (linked_ids as Array).duplicate()
	next_ids.erase(enemy.get_instance_id())
	next_ids.append(replacement.get_instance_id())
	enemy.remove_meta("constellation_symbiote_owner")
	enemy.remove_meta("constellation_symbiote_ids")
	enemy.remove_meta("constellation_symbiote_share")
	enemy.remove_meta("constellation_symbiote_transfers")
	for linked_id in next_ids:
		var linked := instance_from_id(int(linked_id)) as Node
		if linked == null or not is_instance_valid(linked):
			continue
		linked.set_meta("constellation_symbiote_owner", owner_node.get_instance_id())
		linked.set_meta("constellation_symbiote_ids", next_ids.duplicate())
		linked.set_meta("constellation_symbiote_share", ratio)
		linked.set_meta("constellation_symbiote_transfers", transfers - 1)
	return true


func _apply_constellation_prey_distribution(enemy: Node, owner_node: Node, amount: float, hit_type: String) -> void:
	if enemy == null or owner_node == null or not enemy.has_meta("constellation_prey_owner"):
		return
	if int(enemy.get_meta("constellation_prey_owner", 0)) != owner_node.get_instance_id() or Time.get_ticks_msec() > int(enemy.get_meta("constellation_prey_until", 0)):
		return
	if str(owner_node.get("character_id")) != "ranger":
		return
	var ratio := clampf(float(enemy.get_meta("constellation_prey_share", 0.0)), 0.0, 0.5)
	var count := maxi(int(enemy.get_meta("constellation_prey_neighbors", 0)), 0)
	if ratio <= 0.0 or count <= 0 or not enemy is Node2D:
		return
	var candidates := []
	for neighbor_raw in TARGET_QUERY.in_radius(self, (enemy as Node2D).global_position, aoe_radius):
		var neighbor := neighbor_raw as Node2D
		if neighbor == null or neighbor == enemy:
			continue
		if int(neighbor.get_meta("constellation_prey_owner", 0)) != owner_node.get_instance_id() or Time.get_ticks_msec() > int(neighbor.get_meta("constellation_prey_until", 0)):
			continue
		candidates.append(neighbor)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return (enemy as Node2D).global_position.distance_squared_to(a.global_position) < (enemy as Node2D).global_position.distance_squared_to(b.global_position)
	)
	for neighbor_index in range(mini(candidates.size(), count)):
		_call_take_damage(candidates[neighbor_index] as Node, amount * ratio, {"damage_type": hit_type, "constellation_final": "trap_prey_mark_distribution"})


# SCRUM-930 «Дальний расчёт»: множитель дистанции для прямого хита владельца.
func _class_distance_trait_multiplier(owner_node: Node2D, enemy_node: Node2D) -> float:
	if owner_node == null or enemy_node == null or not is_instance_valid(enemy_node):
		return 1.0
	var per_100 := float(owner_node.call("class_trait_value", "distance_damage_per_100px", 0.0))
	if per_100 <= 0.0:
		return 1.0
	var cap_bonus := float(owner_node.call("class_trait_value", "distance_damage_cap_bonus", 0.0))
	var free_range := float(owner_node.call("class_trait_value", "distance_damage_free_range", 0.0))
	var distance := owner_node.global_position.distance_to(enemy_node.global_position)
	return ProgressionData.distance_trait_multiplier(per_100, cap_bonus, free_range, distance)


func _apply_unique_melee_hit_effects(owner_node: Node2D, enemy: Node, amount: float) -> void:
	var enemy_node := enemy as Node2D
	if enemy_node == null or not is_instance_valid(enemy_node):
		return
	var direction := enemy_node.global_position - owner_node.global_position
	var distance := direction.length()
	# SCRUM-523: добивания/осколки красим тем же каналом, что основное попадание.
	var hit_type := _weapon_damage_type()
	if melee_close_bonus_radius > 0.0 and melee_close_damage_multiplier > 1.0 and distance <= melee_close_bonus_radius:
		_call_take_damage(enemy_node, amount * (melee_close_damage_multiplier - 1.0), {"damage_type": hit_type})
	if melee_execute_threshold > 0.0 and melee_execute_multiplier > 1.0:
		var max_hp := float(enemy_node.get("max_health")) if enemy_node.get("max_health") != null else 0.0
		var health := float(enemy_node.get("health")) if enemy_node.get("health") != null else max_hp
		if max_hp > 0.0 and health / max_hp <= melee_execute_threshold:
			_call_take_damage(enemy_node, amount * (melee_execute_multiplier - 1.0), {"damage_type": hit_type})
	if melee_stagger_knockback_multiplier > 0.0 and direction.length_squared() > 0.001:
		_push_enemy_scaled(enemy_node, direction.normalized(), melee_stagger_knockback_multiplier)
	if melee_arc_followup_radius > 0.0 and melee_arc_followup_multiplier > 0.0:
		var splash_damage := amount * melee_arc_followup_multiplier
		for nearby in TARGET_QUERY.in_radius(self, enemy_node.global_position, melee_arc_followup_radius):
			if nearby == enemy_node:
				continue
			if nearby.has_method("take_damage"):
				_call_take_damage(nearby, splash_damage, {"damage_type": hit_type})
	# SCRUM-603: мили лечение-при-ударе тоже через per-second бюджет (capped).
	if melee_heal_percent_on_hit > 0.0 and owner_node.has_method("heal_percent_capped"):
		owner_node.heal_percent_capped(melee_heal_percent_on_hit)
	elif melee_heal_percent_on_hit > 0.0 and owner_node.has_method("heal_percent"):
		owner_node.heal_percent(melee_heal_percent_on_hit)


func _damage_enemy_with_dot(enemy: Node, direct_damage: float, owner_node: Node2D) -> void:
	var wire_damage := direct_damage
	if not _constellation_profile("wire_poison_ramp_snap").is_empty():
		var wire_stacks := _advance_constellation_target_stack(enemy, "wire_poison", 5, 3.0)
		var wire_event := _constellation_event("hit", enemy as Node2D, 0.0, {"wire_stacks": wire_stacks, "constellation_consumer_event": true})
		wire_damage *= 1.0 + 0.06 * float(wire_stacks)
		if bool(wire_event.get("triggered", false)):
			_call_take_damage(enemy, direct_damage * _constellation_result_param(wire_event, "snap_damage_ratio", 0.55), {"damage_type": _weapon_damage_type(), "constellation_final": "wire_poison_ramp_snap"})
	_damage_enemy(enemy, wire_damage)
	var parameters_raw = owner_node.get("derived_parameters")
	var parameters: Dictionary = parameters_raw if parameters_raw is Dictionary else {}
	var tick_damage := float(parameters.get("dot_damage", max(1.0, direct_damage * 0.22)))
	# SCRUM-894: крит-снапшот яда (dot_crit_snapshot_ratio > 0, Ядовитая струна) —
	# критовый прямой удар усиливает тики долей крит-множителя, зафиксированного
	# на момент каста (_last_attack_crit из _rolled_damage). Выше raw 2.75
	# множитель использует убывающий sqrt-tail без верхнего потолка.
	if dot_crit_snapshot_ratio > 0.0 and _last_attack_crit:
		tick_damage *= 1.0 + maxf(float(parameters.get("crit_damage_multiplier", 1.0)) - 1.0, 0.0) * clampf(dot_crit_snapshot_ratio, 0.0, 1.0)
	var tick_speed: float = max(float(parameters.get("dot_speed", 1.0)), 0.2)
	if dot_ticks <= 0:
		return
	# SCRUM-961: классовые артефакты продлевают DoT-идентичность конкретных линий
	# («Ядовитая катушка» — Ядовитая струна). SCRUM-896: биологические оружия
	# сюда больше не ходят — их периодика живёт статусом bio_infection
	# (_apply_bio_infection, symbiote_dot_extra_ticks учитывается там).
	var extra_ticks := 0
	if attack_mode == "dot_beam":
		extra_ticks = int(_owner_mod("venom_dot_extra_ticks"))
	# Tween на оружии замораживается паузой, в отличие от SceneTreeTimer.
	var dot_color := Color(visual_color.r, visual_color.g, visual_color.b, 1.0)
	var dot_tween := create_tween()
	for tick_index in range(dot_ticks + extra_ticks):
		dot_tween.tween_interval(1.0 / tick_speed)
		# SCRUM-551: bound-метод вместо лямбды с захватом локала `enemy` (Node). Захват
		# узла в lambda-callable интермиттентно «освобождался» под быстрым create/free
		# оружия и врагов в balance-CSV (ERROR: Lambda capture at index 1 was freed,
		# gdscript_lambda_callable.cpp:110) и валил прогон. Callable.bind держит self
		# (живёт пока жив tween) + value-args; гвард is_instance_valid внутри метода.
		dot_tween.tween_callback(Callable(self, "_apply_weapon_dot_tick").bind(enemy, tick_damage, dot_color))


func _apply_weapon_dot_tick(enemy: Node, tick_damage: float, dot_color: Color) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	_damage_enemy(enemy, tick_damage, false, "dot", false)
	if enemy is Node2D:
		HazardVfx.dot_tick(enemy, dot_color)


func _damage_enemies_in_circle(origin: Vector2, radius: float, amount: float) -> void:
	for enemy_node in TARGET_QUERY.in_radius(self, origin, radius):
		_damage_enemy(enemy_node, amount)


func _damage_aoe_projectile_explosion(origin: Vector2, radius: float, amount: float) -> void:
	# FAN-1031 S1: per-weapon override прямого AoE-капа (сентинел <0 → общий default).
	var full_targets := aoe_full_targets if aoe_full_targets >= 0 else AOE_PROJECTILE_FULL_TARGETS
	var target_diminish := aoe_target_diminish if aoe_target_diminish >= 0.0 else AOE_PROJECTILE_TARGET_DIMINISH
	# SCRUM-961 «Летучая пыль»: без облака взрыв прямой (+25%, каппинг обычного AoE).
	if _volatile_powder_active():
		_damage_enemies_in_circle_capped(origin, radius, amount * 1.25, full_targets, target_diminish)
		return
	if leaves_pool:
		# FAN-1031 3c(a): прямая leaves_pool-ветка тоже уважает per-weapon override
		# (сентинел <0 → общий POOL_PROJECTILE_* default).
		var pool_full := pool_full_targets if pool_full_targets >= 0 else POOL_PROJECTILE_FULL_TARGETS
		var pool_diminish := pool_target_diminish if pool_target_diminish >= 0.0 else POOL_PROJECTILE_TARGET_DIMINISH
		_damage_enemies_in_circle_capped(origin, radius, amount * POOL_PROJECTILE_DAMAGE_MULTIPLIER * pool_direct_damage_multiplier, pool_full, pool_diminish)
		return
	_damage_enemies_in_circle_capped(origin, radius, amount, full_targets, target_diminish)


# SCRUM-961 «Летучая пыль»: blast_powder переведён в режим быстрого AoE без облака.
func _volatile_powder_active() -> bool:
	return weapon_id == "blast_powder" and _owner_mod("volatile_powder_mode") > 0.0


# SCRUM-533: тик ЛУЖИ (DoT-облако) с диминишингом по числу целей. Раньше каждый
const POOL_FULL_TARGETS := 1
const POOL_TARGET_DIMINISH := 1.5
const MAX_ACTIVE_DAMAGE_POOLS := 6
const AOE_PROJECTILE_FULL_TARGETS := 5
const AOE_PROJECTILE_TARGET_DIMINISH := 2.0
const POOL_PROJECTILE_FULL_TARGETS := 1
const POOL_PROJECTILE_TARGET_DIMINISH := 3.0
const POOL_TICK_DAMAGE_MULTIPLIER := 0.55
const POOL_PROJECTILE_DAMAGE_MULTIPLIER := 0.55
# FAN-1031 3c(b): дефолт STATUS fan-out — БЕЗ диминиша (diminish 0 → factor==1 для
# всех рангов), чтобы оружия без override не меняли поведение (нулевой A/B-контроль).
# Оффендеры опт-инятся полями status_full_targets/status_target_diminish в конфиге.
const STATUS_FANOUT_FULL_TARGETS := 4
const STATUS_FANOUT_TARGET_DIMINISH := 0.0
# FAN-1031 3c(b2): дефолт FALLOFF/ORBIT fan-out — БЕЗ диминиша (diminish 0 → factor==1
# для всех рангов), чтобы оружия без override не меняли поведение (нулевой A/B-контроль).
# Оффендер опт-инится полями falloff_*/orbit_* в конфиге.
const FALLOFF_FANOUT_FULL_TARGETS := 4
const FALLOFF_FANOUT_TARGET_DIMINISH := 0.0
const ORBIT_FANOUT_FULL_TARGETS := 4
const ORBIT_FANOUT_TARGET_DIMINISH := 0.0


# FAN-1031 3c: диминиш-факторы крауд-fan-out каналов (STATUS/FALLOFF/ORBIT) — обёртки над
# WeaponCrowdCaps.fanout_factor с per-weapon полями + сентинел-дефолтами. Канон и профиль
# каждого канала: docs/design/systems/progression_balance.md. Ранг = дистанция от центра.
func _status_fanout_factor(rank: int) -> float:
	return WEAPON_CROWD_CAPS.fanout_factor(rank, status_full_targets, status_target_diminish, status_max_targets, STATUS_FANOUT_FULL_TARGETS, STATUS_FANOUT_TARGET_DIMINISH)


func _falloff_fanout_factor(rank: int) -> float:
	return WEAPON_CROWD_CAPS.fanout_factor(rank, falloff_full_targets, falloff_target_diminish, -1, FALLOFF_FANOUT_FULL_TARGETS, FALLOFF_FANOUT_TARGET_DIMINISH)


func _orbit_fanout_factor(rank: int) -> float:
	return WEAPON_CROWD_CAPS.fanout_factor(rank, orbit_full_targets, orbit_target_diminish, orbit_max_targets, ORBIT_FANOUT_FULL_TARGETS, ORBIT_FANOUT_TARGET_DIMINISH)


# FAN-1031 3c(b): дистанционно-отсортированный список врагов в радиусе — ранг
# определяет диминиш крауд-DoT (_status_fanout_factor). Дубликат исходной выборки,
# чтобы не тревожить порядок вызывающего (constellation-логика читает свой порядок).
func _status_fanout_order(origin: Vector2, enemies: Array) -> Array:
	var ordered := enemies.duplicate()
	ordered.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return ordered


func _retire_excess_damage_pools(new_pool: Node2D) -> void:
	var active_pools: Array[Node2D] = []
	for cloud_node in get_tree().get_nodes_in_group("chemist_clouds"):
		if not (cloud_node is Node2D):
			continue
		if int(cloud_node.get_meta("pool_weapon_owner", 0)) != get_instance_id():
			continue
		active_pools.append(cloud_node as Node2D)
	active_pools.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		if a == new_pool:
			return false
		if b == new_pool:
			return true
		return int(a.get_instance_id()) < int(b.get_instance_id())
	)
	while active_pools.size() > MAX_ACTIVE_DAMAGE_POOLS:
		var stale_pool := active_pools.pop_front() as Node2D
		if stale_pool == new_pool:
			active_pools.append(stale_pool)
			continue
		stale_pool.remove_from_group("chemist_clouds")
		_release_effect(stale_pool)
		stale_pool.queue_free()

func _damage_enemies_in_pool(origin: Vector2, radius: float, amount: float, source_pool: Node2D = null) -> void:
	var enemies: Array = TARGET_QUERY.in_radius(self, origin, radius)
	_apply_pool_contact_statuses(enemies, source_pool)
	# FAN-1031 3c(a): per-weapon override пул-тика (сентинел <0 → общий default).
	var full_targets := pool_full_targets if pool_full_targets >= 0 else POOL_FULL_TARGETS
	var target_diminish := pool_target_diminish if pool_target_diminish >= 0.0 else POOL_TARGET_DIMINISH
	# FAN-1031 3c-final fix (peer review MINOR): fast-path берём только когда жёсткий кап ШИРИНЫ
	# не режет глубже full_targets — иначе малый пак (size ≤ full, но > pool_max) обходил бы кап
	# (немонотонность; pool_max=0 не мог «выключить» канал). effective_cap = min(full, max).
	var fast_cap := full_targets if pool_max_targets < 0 else mini(full_targets, pool_max_targets)
	if enemies.size() <= fast_cap:
		for enemy_node in enemies:
			# SCRUM-942: тик лужи — периодический канал и на одиночной цели тоже:
			# тип "dot" (единая покраска цифр + trait-множитель периодики), без
			# он-хит статусов/дублей — зеркально ветке толпы ниже.
			_damage_enemy(enemy_node, amount, false, "dot", false)
		return
	# Сортировка по близости к центру лужи — полный урон достаётся «ядру» пака.
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		# FAN-1031 3c(final): жёсткий кап ШИРИНЫ тика лужи — дальше pool_max_targets НОЛЬ.
		if pool_max_targets >= 0 and index >= pool_max_targets:
			break
		var factor := 1.0
		if index >= full_targets:
			factor = 1.0 / (1.0 + float(index - full_targets + 1) * target_diminish)
		_damage_enemy(enemies[index] as Node2D, amount * factor, false, "dot", false)


# SCRUM-944: базовый префикс id вечных кислотных зарядов (+ instance id лужи).
const ACID_CHARGE_STATUS_PREFIX := "acid_charge"
# SCRUM-944: «вечность» заряда — живёт до смерти носителя (раунды много короче).
const ACID_CHARGE_PERSIST_SECONDS := 999999.0
# SCRUM-961 «Кислотный катализатор»: артефакт поднимает кап зарядов на цель.
const ACID_CHARGE_ARTIFACT_CAP_BONUS := 3


# Existing acid charges outlive their pools, so weapon cadence changes must
# retime their stored intervals in place instead of re-applying/resetting them.
func refresh_persistent_status_cadence() -> void:
	if not pool_contact_charges or not is_inside_tree():
		return
	var owner_node := _owner_node()
	if owner_node == null or not is_instance_valid(owner_node):
		return
	var owner_id := owner_node.get_instance_id()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node and is_instance_valid(enemy):
			StatusEffects.retime_dot_statuses(enemy as Node, ACID_CHARGE_STATUS_PREFIX, owner_id, pool_charge_tick_interval)

# SCRUM-944: контактные статусы луж. Кислотная колба (pool_contact_charges):
func _apply_pool_contact_statuses(enemies: Array, source_pool: Node2D = null) -> void:
	var acid_charges := pool_contact_charges and source_pool != null and is_instance_valid(source_pool)
	if not acid_charges:
		return
	var owner_node := _owner_node()
	var charge_cap := pool_charge_cap
	var charge_status_id := "%s_p%d" % [ACID_CHARGE_STATUS_PREFIX, source_pool.get_instance_id()]
	if _owner_mod("acid_charge_stacks") > 0.0:
		charge_cap += ACID_CHARGE_ARTIFACT_CAP_BONUS
	var parameters_raw = owner_node.get("derived_parameters") if owner_node != null else null
	var dot_damage := 2.0
	if parameters_raw is Dictionary:
		dot_damage = maxf(float((parameters_raw as Dictionary).get("dot_damage", 2.0)), 1.0)
	var charge_tick := maxf(dot_damage * pool_charge_tick_multiplier, 0.30)
	# FAN-1031 3c(b): крауд-заряды ранжируются по дистанции к центру лужи — ближние
	var charge_order := _status_fanout_order(source_pool.global_position, enemies)
	for rank in range(charge_order.size()):
		var enemy_node := charge_order[rank] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var per_target_tick := charge_tick * _status_fanout_factor(rank)
		# FAN-1031 3c-final fix (peer review MINOR): жёсткий кап ШИРИНЫ = skip. За status_max_targets
		# (factor==0) НЕ вешаем вечный acid_charge с dot_damage 0 (занимал бы слот charge_cap и
		# считался в 5-стаковой детонации нулём). order отсортирован по дистанции → break. Без
		# override status_max factor>0 всегда → break не срабатывает (нулевое изменение поведения).
		if per_target_tick <= 0.0:
			break
		var owner_id := owner_node.get_instance_id() if owner_node != null else 0
		var previous_stack_count := StatusEffects.count_status_prefix(enemy_node, ACID_CHARGE_STATUS_PREFIX)
		if previous_stack_count < 5 and int(enemy_node.get_meta("constellation_acid_detonated_owner", 0)) == owner_id:
			enemy_node.remove_meta("constellation_acid_detonated_owner")
		if not StatusEffects.has_status(enemy_node, charge_status_id) \
				and previous_stack_count < charge_cap:
			StatusEffects.apply_status_from(owner_node, enemy_node, charge_status_id, {
				"source_id": owner_id,
				"duration": ACID_CHARGE_PERSIST_SECONDS,
				"dot_damage": per_target_tick,
				"dot_interval": pool_charge_tick_interval,
				"max_stacks": 1,
				"marker_color": Color(0.62, 0.95, 0.25, 1.0),
			})
		var acid_stack_count := StatusEffects.count_status_prefix(enemy_node, ACID_CHARGE_STATUS_PREFIX)
		if acid_stack_count >= 5 \
				and int(enemy_node.get_meta("constellation_acid_detonated_owner", 0)) != owner_id:
			var detonation := _constellation_event("pool_stack", enemy_node, 0.0, {"stacks": acid_stack_count})
			if bool(detonation.get("triggered", false)):
				enemy_node.set_meta("constellation_acid_detonated_owner", owner_id)
				var detonation_radius := maxf(aoe_radius * 0.60, 48.0)
				AttackVfx.orb_burst(_projectile_parent(), enemy_node.global_position, detonation_radius, visual_color)
				_damage_enemies_in_circle_capped(enemy_node.global_position, detonation_radius, per_target_tick * 5.0 * _constellation_result_param(detonation, "detonation_damage_ratio", 0.46), 2, 0.65)


# SCRUM-903: тик терновой зоны — контракт повторных ФИЗИЧЕСКИХ хитов:
func _briar_zone_tick(pool: Node2D) -> void:
	if pool == null or not is_instance_valid(pool):
		return
	var origin := pool.global_position
	var zone_radius := aoe_radius * 0.7
	var hit_counts: Dictionary = pool.get_meta("briar_hit_counts", {})
	var dwell: Dictionary = pool.get_meta("constellation_briar_dwell", {})
	var matured: Dictionary = pool.get_meta("constellation_briar_matured", {})
	var previous_inside: Dictionary = pool.get_meta("constellation_briar_inside", {})
	var last_positions: Dictionary = pool.get_meta("constellation_briar_positions", {})
	var current_inside := {}
	var slow_multiplier := briar_slow_multiplier
	var seal_power := _owner_mod("briar_slow_power")
	if seal_power > 0.0:
		slow_multiplier = minf(slow_multiplier, maxf(1.0 - seal_power, 0.25))
	var hit_damage := damage * briar_hit_multiplier
	for enemy in TARGET_QUERY.in_radius(self, origin, zone_radius):
		var enemy_node := enemy as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		StatusEffects.apply_status(enemy_node, "briar_zone_slow", {
			"duration": maxf(pool_tick_interval * 1.6, 0.7),
			"speed_multiplier": slow_multiplier,
			"marker_color": Color(0.35, 0.70, 0.25, 1.0),
		})
		var enemy_id := enemy_node.get_instance_id()
		current_inside[enemy_id] = true
		last_positions[enemy_id] = enemy_node.global_position
		dwell[enemy_id] = float(dwell.get(enemy_id, 0.0)) + pool_tick_interval
		if float(dwell[enemy_id]) >= 1.2 and not bool(matured.get(enemy_id, false)):
			var root_result := _constellation_event("root_matured", enemy_node, 0.0)
			if bool(root_result.get("triggered", false)):
				matured[enemy_id] = true
				StatusEffects.apply_status(enemy_node, "constellation_briar_root", {"duration": 0.75, "speed_multiplier": 0.0, "movement_locked": true})
		var hits := int(hit_counts.get(enemy_id, 0))
		if hits >= briar_hit_cap:
			continue
		hit_counts[enemy_id] = hits + 1
		_damage_enemy(enemy_node, hit_damage, false, "physical", false)
	for previous_id in previous_inside.keys():
		if current_inside.has(previous_id):
			continue
		if bool(matured.get(previous_id, false)):
			var burst_center: Vector2 = last_positions.get(previous_id, origin)
			AttackVfx.orb_burst(_projectile_parent(), burst_center, zone_radius * 0.55, visual_color)
			for burst_target in TARGET_QUERY.in_radius(self, burst_center, zone_radius * 0.55):
				_call_take_damage(burst_target as Node, hit_damage * 0.38, {"damage_type": "physical", "constellation_final": "briar_sustained_root_burst"})
		matured.erase(previous_id)
		dwell.erase(previous_id)
		last_positions.erase(previous_id)
	pool.set_meta("briar_hit_counts", hit_counts)
	pool.set_meta("constellation_briar_dwell", dwell)
	pool.set_meta("constellation_briar_matured", matured)
	pool.set_meta("constellation_briar_inside", current_inside)
	pool.set_meta("constellation_briar_positions", last_positions)


func _damage_enemies_in_circle_capped(origin: Vector2, radius: float, amount: float, full_targets: int, diminish: float) -> void:
	var enemies: Array = TARGET_QUERY.in_radius(self, origin, radius)
	# FAN-1031 3c-final fix (peer review MINOR): fast-path берём только когда жёсткий кап ШИРИНЫ
	# (aoe_max_targets) не режет глубже full_targets — иначе малый пак обходил бы кап
	# (немонотонность; aoe_max=0 не мог «выключить» канал). effective_cap = min(full, max).
	var fast_cap := full_targets if aoe_max_targets < 0 else mini(full_targets, aoe_max_targets)
	if enemies.size() <= fast_cap:
		for enemy_node in enemies:
			_damage_enemy(enemy_node, amount)
		return
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	for index in range(enemies.size()):
		# FAN-1031 3c(final): жёсткий кап ШИРИНЫ прямого AoE — дальше aoe_max_targets НОЛЬ.
		if aoe_max_targets >= 0 and index >= aoe_max_targets:
			break
		var factor := 1.0
		if index >= full_targets:
			factor = 1.0 / (1.0 + float(index - full_targets + 1) * diminish)
		_damage_enemy(enemies[index] as Node2D, amount * factor, index < full_targets)


func _damage_enemies_in_circle_falloff(origin: Vector2, radius: float, amount: float, minimum_factor: float) -> void:
	# FAN-1031 3c(b2): к радиальному спаду (per-target, по дистанции) добавлен крауд-кап
	# ХВОСТА по ЧИСЛУ целей (_falloff_fanout_factor). Ранг = дистанция от центра; сентинел
	# (без override) → factor 1.0 для всех рангов → урон побайтово прежний (A/B-контроль).
	var ordered := _status_fanout_order(origin, TARGET_QUERY.in_radius(self, origin, radius))
	for rank in range(ordered.size()):
		var enemy_node := ordered[rank] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var distance := origin.distance_to(enemy_node.global_position)
		var factor := lerpf(1.0, clampf(minimum_factor, 0.0, 1.0), distance / maxf(radius, 1.0))
		_damage_enemy(enemy_node, amount * factor * _falloff_fanout_factor(rank))


func _damage_enemies_in_segment(start: Vector2, finish: Vector2, width: float, amount: float) -> void:
	var segment := finish - start
	var length := segment.length()
	if length <= 0.001:
		_damage_enemies_in_circle(start, width * 0.5, amount)
		return
	for enemy_node in TARGET_QUERY.in_segment(self, start, finish, width, _line_back_allowance(start)):
		_damage_enemy(enemy_node, amount)


func _damage_split_shard_corridor(origin: Vector2, direction: Vector2, width: float, range_limit: float, amount: float, excluded_ids: Dictionary, hit_limit: int) -> int:
	var hit_count := 0
	for hit in _enemies_in_corridor(origin, direction, width, range_limit):
		if hit_count >= hit_limit:
			break
		var enemy_node := hit["node"] as Node2D
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var enemy_id := enemy_node.get_instance_id()
		if excluded_ids.has(enemy_id):
			continue
		excluded_ids[enemy_id] = true
		_damage_enemy(enemy_node, amount * pow(0.72, float(hit_count)))
		hit_count += 1
	return hit_count


func _has_enemy_in_circle(origin: Vector2, radius: float) -> bool:
	return TARGET_QUERY.has_in_radius(self, origin, radius)


func _call_take_damage(enemy: Node, amount: float, feedback := {}) -> void:
	if _take_damage_accepts_feedback(enemy):
		var tagged: Dictionary = feedback if feedback is Dictionary else {}
		var owner_node := _owner_node()
		if str(tagged.get("telemetry_provenance_id", "")) == "" and owner_node != null and owner_node.has_method("telemetry_context_for_hit") and owner_node.has_method("telemetry_feedback_for_hit"):
			var telemetry_context: Dictionary = owner_node.call("telemetry_context_for_hit", {"weapon_id": weapon_id, "attack_mode": attack_mode, "damage_type": str(tagged.get("damage_type", _weapon_damage_type()))})
			tagged = owner_node.call("telemetry_feedback_for_hit", telemetry_context, tagged)
		# SCRUM-1007: весь урон классового оружия — урон ИГРОКА. Метка едет в
		# feedback убившего хита (enemy._record_kill_attribution) и служит
		# атрибуцией он-килл trait'ов; лишний ключ для остальных читателей шумом
		# не является (enemy читает только известные поля).
		tagged["player_owned"] = true
		enemy.call("take_damage", amount, tagged)
	else:
		enemy.call("take_damage", amount)


func _take_damage_accepts_feedback(enemy: Node) -> bool:
	for method in enemy.get_method_list():
		if str(method.get("name", "")) == "take_damage":
			var args: Array = method.get("args", [])
			if args.size() < 2:
				return false
			var script: Script = enemy.get_script()
			if script != null and str(script.resource_path) in ["res://scripts/enemy.gd", "res://scripts/boss.gd"]:
				return true
			return enemy.is_in_group("enemies") and enemy.has_method("_show_combat_feedback")
	return false


func _push_enemy(enemy: Node2D, direction: Vector2) -> void:
	_push_enemy_scaled(enemy, direction, 1.0)


func _push_enemy_scaled(enemy: Node2D, direction: Vector2, multiplier: float) -> void:
	if direction.length_squared() <= 0.001:
		return
	var push_strength := knockback * maxf(multiplier, 0.0)
	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(direction.normalized() * push_strength * 3.6)
	else:
		enemy.global_position += direction.normalized() * push_strength * 0.12


func _rolled_damage(owner_node: Node2D) -> float:
	var raw_parameters = owner_node.get("derived_parameters")
	if not (raw_parameters is Dictionary):
		return damage

	var parameters: Dictionary = raw_parameters
	var result := float(parameters.get(damage_parameter, damage))
	_last_attack_crit = false
	if randf() < float(parameters.get("crit_chance", 0.0)):
		result *= float(parameters.get("crit_damage_multiplier", 1.0))
		_last_attack_crit = true
	if charge_seconds > 0.0:
		result *= _current_charge_multiplier
	if not summon_role.is_empty():
		result *= _summon_role_damage_factor(parameters)
	# SCRUM-908 «Сеть мастерской»: живые устройства инженера усиливают урон
	# устройств (data-driven через CLASS_TRAITS; для прочих классов фактор 1.0).
	result *= _workshop_network_factor(owner_node)
	# SCRUM-961 «Счетчик ритма»: ослабленный повтор каста (эхо активно только
	# внутри _maybe_fire_rhythm_echo, обычные касты не задевает).
	result *= _rhythm_echo_scale
	return result


func _summon_role_damage_factor(parameters: Dictionary) -> float:
	# SCRUM-546: deploy/sentry-саммоны (turret/totem/drone) масштабируются от
	# Лидерства так же, как pure-саммоны (summoner_weapon._summon_profile) и
	# бюджетная модель (progression_data._budget_summon_role_damage_factor).
	var summon_amount := float(parameters.get("summon_amount", 0.0))
	var leadership := float(parameters.get("leadership", 0.0))
	return summon_role_damage_multiplier * (1.0 + minf(leadership * 0.060 + summon_amount * 0.016, 1.15))


# SCRUM-899: Лидерство = uptime деплой-ампа — продлевает жизнь усилителя на
# amp_leadership_lifetime_per_point за очко (кап amp_leadership_lifetime_cap).
# Opt-in через конфиг оружия (sound_amp); у неподписанных амп-оружий
# per_point = 0 → бонус нулевой.
func _amp_leadership_lifetime_bonus(owner_node: Node2D) -> float:
	if amp_leadership_lifetime_per_point <= 0.0 or owner_node == null:
		return 0.0
	var owner_stats = owner_node.get("stats")
	if not (owner_stats is Dictionary):
		return 0.0
	var leadership := float((owner_stats as Dictionary).get("leadership", 0.0))
	return minf(leadership * amp_leadership_lifetime_per_point, maxf(amp_leadership_lifetime_cap, 0.0))


# SCRUM-899: «сила» ампа от summon_amount — учащение пульса по КАНОНУ
# саммон-хейста (summoner_weapon._summon_profile: min(summon_amount*0.014 +
# leadership*0.006, 0.30)). Урон отдельного пульса остаётся чистой magic_damage
# осью — никакой «лидерской» оси урона (политика SCRUM-899).
func _amp_summon_haste_value(owner_node: Node2D) -> float:
	if owner_node == null:
		return 0.0
	var raw_parameters = owner_node.get("derived_parameters")
	if not (raw_parameters is Dictionary):
		return 0.0
	var parameters: Dictionary = raw_parameters
	var summon_amount := float(parameters.get("summon_amount", 0.0))
	var leadership := float(parameters.get("leadership", 0.0))
	return minf(summon_amount * 0.014 + leadership * 0.006, 0.30)


# SCRUM-908 «Сеть мастерской» (workshop_network): активные устройства инженера
func _workshop_network_factor(owner_node: Node2D) -> float:
	if owner_node == null or not is_instance_valid(owner_node) or not owner_node.has_method("class_trait_value"):
		return 1.0
	var per_stack := float(owner_node.call("class_trait_value", "network_damage_per_stack", 0.0))
	if per_stack <= 0.0:
		return 1.0
	var stacks := _workshop_network_stacks(owner_node)
	if stacks <= 0.0:
		return 1.0
	return 1.0 + stacks * per_stack


func _workshop_network_stacks(owner_node: Node2D) -> float:
	var weight_sum := 0.0
	for effect in _alive_effects():
		if effect is Node2D and effect.has_meta("network_weight"):
			weight_sum += maxf(float(effect.get_meta("network_weight")), 0.0)
	var cap_base := float(owner_node.call("class_trait_value", "network_stack_cap_base", 3.0))
	var cap_step := maxf(float(owner_node.call("class_trait_value", "network_cap_leadership_step", 6.0)), 1.0)
	var leadership := 0.0
	var stats = owner_node.get("stats")
	if stats is Dictionary:
		leadership = maxf(float((stats as Dictionary).get("leadership", 0.0)), 0.0)
	var cap := maxf(cap_base + floor(leadership / cap_step), 0.0)
	var stacks := minf(weight_sum, cap)
	_maybe_pulse_network_cue(owner_node, stacks)
	return stacks


# Лёгкий фидбек сети (AC SCRUM-908): при смене ЦЕЛОГО числа стеков — короткий
# ринг-пульс вокруг инженера (существующий VFX-паттерн, без новых UI-файлов).
func _maybe_pulse_network_cue(owner_node: Node2D, stacks: float) -> void:
	var tier := floorf(stacks)
	if is_equal_approx(tier, _network_cue_tier):
		return
	_network_cue_tier = tier
	if tier <= 0.0 or _effects_shutdown or not is_inside_tree():
		return
	AttackVfx.ring_pulse(_projectile_parent(), owner_node.global_position, 54.0 + 8.0 * tier, Color(0.98, 0.82, 0.30, 0.30), false)


func _update_charge(delta: float) -> void:
	if charge_seconds <= 0.0:
		return
	var owner_node := _owner_node()
	if owner_node == null:
		return
	var energy := 0.0
	var owner_stats = owner_node.get("stats")
	if owner_stats is Dictionary:
		energy = float((owner_stats as Dictionary).get("energy", 0.0))
	var effective_charge_seconds := maxf(charge_seconds / (1.0 + energy * 0.025), 0.25)
	var owner_velocity := Vector2.ZERO
	var raw_velocity = owner_node.get("velocity")
	if raw_velocity is Vector2:
		owner_velocity = raw_velocity
	if owner_velocity.length_squared() <= 4.0:
		_charge_time = minf(_charge_time + delta, effective_charge_seconds)
	else:
		_charge_time = maxf(_charge_time - delta * 2.5, 0.0)


func _charge_multiplier() -> float:
	if charge_seconds <= 0.0:
		return 1.0
	var owner_node := _owner_node()
	var energy := 0.0
	if owner_node != null:
		var owner_stats = owner_node.get("stats")
		if owner_stats is Dictionary:
			energy = float((owner_stats as Dictionary).get("energy", 0.0))
	var effective_charge_seconds := maxf(charge_seconds / (1.0 + energy * 0.025), 0.25)
	var charge_ratio := clampf(_charge_time / maxf(effective_charge_seconds, 0.01), 0.0, 1.0)
	return lerpf(1.0, maxf(charge_max_multiplier, 1.0), charge_ratio)


func _owner_node() -> CharacterBody2D:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node is CharacterBody2D:
			return parent_node
		parent_node = parent_node.get_parent()
	return null


func _emit_weapon_animation_event(owner_node: Node2D, phase: String, duration: float, direction: Vector2, metadata := {}) -> void:
	if owner_node == null or not is_instance_valid(owner_node) or not owner_node.has_method("play_action_animation"):
		return
	var event_metadata: Dictionary = metadata if metadata is Dictionary else {}
	var payload := event_metadata.duplicate(true)
	payload["attack_mode"] = attack_mode
	payload["weapon_id"] = weapon_id
	payload["display_name"] = display_name
	payload["phase_source"] = "class_weapon"
	var action_id := _event_action_animation_for_mode()
	owner_node.call("play_action_animation", action_id, direction, phase, maxf(duration, 0.0), payload)


func _estimated_windup_duration() -> float:
	match attack_mode:
		"grenade_fuse", "smoke_bomb", "prism_rift", "meteor_shards", "priest_sanctify", "robot_magnetic_anchor", "robot_compression_line", "sniper_lockshot", "sniper_kill_zone":
			return maxf(grenade_delay, 0.08)
		"priest_ward", "bio_spore_bloom", "bio_sample_dart":
			return maxf(burst_interval, 0.06)
		"amp", "trap", "engineer_sentry_link", "engineer_orbit_drone", "engineer_pressure_mines":
			return 0.10
		"beam", "dot_beam", "drain_link", "priest_dual_toll", "bio_symbiote_web", "moon_split_shot", "storm_pierce_cone":
			return 0.12
		# SCRUM-939..941: касты кита Тёмного мага — короткий читаемый замах.
		"dark_chain_burst", "skull_curse_burn", "dark_mirror_blast":
			return 0.12
	return 0.08


func _projectile_parent() -> Node:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	return parent


func _projectile_visual_profile() -> Dictionary:
	return PROJECTILE_VISUALS.profile_for_weapon(weapon_id)


func _spawn_projectile_visual(start: Vector2, travel_direction := Vector2.RIGHT) -> Node2D:
	return AttackVfx.orb_projectile(_projectile_parent(), start, visual_color, _projectile_visual_profile(), travel_direction)


func _projectile_impact_color() -> Color:
	var profile := _projectile_visual_profile()
	var palette = profile.get("impact_palette", [])
	return palette[0] if palette is Array and not palette.is_empty() else visual_color


func _weapon_visual_texture() -> Texture2D:
	var visual := get_node_or_null("WeaponVisual") as Sprite2D
	if visual != null and visual.texture != null:
		return visual.texture
	return SOUND_AMP_TEXTURE


func _deploy_visual_texture() -> Texture2D:
	if not deploy_texture_path.is_empty():
		var texture := load(deploy_texture_path) as Texture2D
		if texture != null:
			return texture
	return _weapon_visual_texture()


func _register_effect(effect: Node) -> void:
	if effect == null:
		return
	effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	_effects_shutdown = false
	effect.set_meta("weapon_owner_id", get_instance_id())
	effect.add_to_group("player_weapon_effects")
	_spawned_effects = _alive_effects()
	_spawned_effects.append(effect)


func _alive_effects() -> Array[Node]:
	var alive: Array[Node] = []
	for tracked in _spawned_effects:
		if tracked != null and is_instance_valid(tracked):
			alive.append(tracked)
	return alive


func _release_effect(effect: Node) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	effect.remove_from_group("player_weapon_effects")
	_spawned_effects.erase(effect)
	effect.queue_free()


func _capture_base_values() -> void:
	if not has_meta("base_damage"):
		set_meta("base_damage", damage)
	if not has_meta("base_fire_interval"):
		set_meta("base_fire_interval", fire_interval)
	if not has_meta("base_attack_range"):
		set_meta("base_attack_range", attack_range)
	if not has_meta("base_aoe_radius"):
		set_meta("base_aoe_radius", aoe_radius)
	if not has_meta("base_projectile_speed"):
		set_meta("base_projectile_speed", projectile_speed)
	if not has_meta("base_beam_width"):
		set_meta("base_beam_width", beam_width)
	if not has_meta("base_wave_width"):
		set_meta("base_wave_width", wave_width)
	if not has_meta("base_suppression_width"):
		set_meta("base_suppression_width", suppression_width)
	if not has_meta("base_knockback"):
		set_meta("base_knockback", knockback)
