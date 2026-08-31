extends Node2D

# FAN-3840: модуль распределённого боевого класса ClassWeapon — разделяемое состояние: preload-константы, @export-конфиг, runtime-переменные и реестр ATTACK_MODE_EXECUTORS.
# Часть линейной extends-цепочки scripts/classes/** (сборка — фасад
# scripts/class_weapon.gd). Код перенесён из class_weapon.gd БЕЗ изменений;
# кросс-модульные вызовы разрешаются виртуально через forward-объявления
# в class_weapon_shared_api.gd.


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


# --- члены класса, поднятые из глубины монолита (лексическая область общих модулей) ---


# ==================== SCRUM-903: вороны тотема (raven_homing) ====================
const RAVEN_EXPLOSION_FULL_TARGETS := 3


const POISON_PARALYSIS_CAP := 1.8              # кап суммарного окна паралича (база + артефакт), сек


const POISON_PARALYSIS_BOSS_FACTOR := 0.25     # боссы/элиты: срезанное окно (~0.21с база; на скейле темпа аптайм <60%)


const SQUARE_PHYSICAL_SHARE := 0.45      # доля канала damage (ось силы) на КАСТ


const MAX_ACTIVE_DAMAGE_POOLS := 6
