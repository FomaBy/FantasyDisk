class_name ContactSheetBeatsContract
extends RefCounted

## Frame-local evidence declarations for ultimate contact sheets.
##
## This contract is presentation evidence only. It does not instantiate scenes,
## change the runtime presentation bridge, or own class mechanics.

const REQUIRED_PHASES: Array[String] = ["release", "active", "recovery"]

## Ranger and Thief build their effect sprites at begin(), so Godot assigns
## generated names. This semantic anchor requires a real visible CanvasItem
## without coupling evidence to an engine-generated node name.
const VISIBLE_EFFECT_NODE := "@visible_effect"

# This list only shrinks as class packages adopt FRAMES_BY_CLASS. The target is
# an empty list; a complete declaration left here fails the shared invariant.
const MIGRATION_ALLOWLIST: Array[String] = []

# Source documents are immutable presentation evidence. Their paths let the
# focused gate prove a declaration remains tied to the live visual timeline.
const EVIDENCE_BY_CLASS := {
	"chemist": {"source_kind": "class_manifest", "path": "res://docs/design/references/weapon_ultimates/chemist/manifest.json"},
	"knight": {"source_kind": "class_manifest", "path": "res://docs/design/references/weapon_ultimates/knight/manifest.json"},
	"priest": {"source_kind": "class_manifest", "path": "res://docs/design/references/weapon_ultimates/priest/manifest.json"},
	"ranger": {"source_kind": "class_manifest", "path": "res://docs/design/references/weapon_ultimates/ranger/manifest.json", "frame_evidence": true},
	"robot": {"source_kind": "class_manifest", "path": "res://docs/design/references/weapon_ultimates/robot/manifest.json"},
	"sniper": {
		"source_kind": "weapon_timelines",
		"paths_by_weapon": {
			"sniper_deadeye_rifle": "res://scenes/vfx/ultimates/sniper/sniper_deadeye_rifle.timeline.json",
			"sniper_spotter_scope": "res://scenes/vfx/ultimates/sniper/sniper_spotter_scope.timeline.json",
			"sniper_shatter_rounds": "res://scenes/vfx/ultimates/sniper/sniper_shatter_rounds.timeline.json",
		},
	},
	"soldier": {"source_kind": "class_manifest", "path": "res://docs/design/references/weapon_ultimates/soldier/manifest.json"},
	"thief": {"source_kind": "class_manifest", "path": "res://docs/design/references/weapon_ultimates/thief/manifest.json", "frame_evidence": true},
}

const FRAMES_BY_CLASS := {
	"assassin": {
		"chakrams": [
			{"phase": "release", "time": 0.9, "required_nodes": ["BackdropLayer/BackdropVeil", "ImpactFlash", "Orbit/MoonOne", "Orbit/MoonEight"]},
			{"phase": "active", "time": 2.4, "required_nodes": ["BackdropLayer/BackdropVeil", "Orbit/MoonFour", "ReturnCrescents"]},
			{"phase": "recovery", "time": 3.2, "required_nodes": ["Orbit/MoonOne", "ReturnCrescents"]},
		],
		"shadow_daggers": [
			{"phase": "release", "time": 0.9, "required_nodes": ["BackdropLayer/BackdropVeil", "FreezeMarks", "Afterimages/BackstabOne"]},
			{"phase": "active", "time": 2.05, "required_nodes": ["Afterimages/BackstabOne", "FinalReveal"]},
			{"phase": "recovery", "time": 3.0, "required_nodes": ["FreezeMarks", "FinalReveal"]},
		],
		"venom_wire": [
			{"phase": "release", "time": 0.8, "required_nodes": ["BackdropLayer/BackdropVeil", "Anchors/NeedleOne", "HexWeb"]},
			{"phase": "active", "time": 2.8, "required_nodes": ["HexWeb", "SnapCollapse"]},
			{"phase": "recovery", "time": 3.25, "required_nodes": ["Anchors/NeedleOne", "SnapCollapse"]},
		],
	},
	"berserk": {
		"sword": [
			{"phase": "release", "time": 0.75, "required_nodes": ["BackdropVeil", "CastFlash", "WhirlwindCore"]},
			{"phase": "active", "time": 1.80, "required_nodes": ["WhirlwindCore", "BladeGhostOne", "BladeGhostThree"]},
			{"phase": "recovery", "time": 3.15, "required_nodes": ["WhirlwindCore", "CollapseFlare"]},
		],
		"axe": [
			{"phase": "release", "time": 0.65, "required_nodes": ["BackdropVeil", "CastFlash", "AxeGhost"]},
			{"phase": "active", "time": 1.70, "required_nodes": ["AxeGhost", "TurnBurst"]},
			{"phase": "recovery", "time": 2.90, "required_nodes": ["AxeGhost", "TurnBurst"]},
		],
		"hammer": [
			{"phase": "release", "time": 0.60, "required_nodes": ["BackdropVeil", "CastFlash", "HammerGhost"]},
			{"phase": "active", "time": 1.35, "required_nodes": ["HammerGhost", "RiftBeatOne", "RiftBeatTwo", "CentralQuake"]},
			{"phase": "recovery", "time": 2.50, "required_nodes": ["HammerGhost", "CentralQuake"]},
		],
	},
	"biologist": {
		"biologist_spore_lens": [
			{"phase": "release", "time": 0.70, "required_nodes": ["Mycelium"]},
			{"phase": "active", "time": 1.70, "required_nodes": ["Mycelium"]},
			{"phase": "recovery", "time": 2.80, "required_nodes": ["Mycelium"]},
		],
		"biologist_sample_injector": [
			{"phase": "release", "time": 0.55, "required_nodes": ["PerfectSample"]},
			{"phase": "active", "time": 1.35, "required_nodes": ["PerfectSample"]},
			{"phase": "recovery", "time": 2.35, "required_nodes": ["PerfectSample"]},
		],
		"biologist_symbiote_seed": [
			{"phase": "release", "time": 0.80, "required_nodes": ["Matriarch"]},
			{"phase": "active", "time": 1.90, "required_nodes": ["Matriarch"]},
			{"phase": "recovery", "time": 3.10, "required_nodes": ["Matriarch"]},
		],
	},
	"chemist": {
		"blast_powder": [
			{"phase": "release", "time": 0.95, "required_nodes": ["PhilosophersRitual"]},
			{"phase": "active", "time": 1.30, "required_nodes": ["PhilosophersRitual"]},
			{"phase": "recovery", "time": 2.90, "required_nodes": ["PhilosophersRitual"]},
		],
		"acid_flask": [
			{"phase": "release", "time": 0.85, "required_nodes": ["TsarFlask", "LakeRing"]},
			{"phase": "active", "time": 1.00, "required_nodes": ["TsarFlask", "LakeRing"]},
			{"phase": "recovery", "time": 3.35, "required_nodes": ["TsarFlask", "LakeRing", "EvaporationSmoke"]},
		],
		"homunculus_vial": [
			{"phase": "release", "time": 0.90, "required_nodes": ["AlchemicalCircle"]},
			{"phase": "active", "time": 1.75, "required_nodes": ["AlchemicalCircle", "Avatar", "StompWave"]},
			{"phase": "recovery", "time": 3.60, "required_nodes": ["AlchemicalCircle", "TauntHalo", "ToxicCascade"]},
		],
	},
	"dark_mage": {
		"dark_book": [
			{"phase": "release", "time": 0.7, "required_nodes": ["BookGhost", "MirrorPlane", "OriginalShadow"]},
			{"phase": "active", "time": 1.95, "required_nodes": ["MirrorPlane", "AbyssEnergy", "PairedDetonation"]},
			{"phase": "recovery", "time": 2.5, "required_nodes": ["BookGhost", "MirrorPlane", "PairedDetonation"]},
		],
		"cursed_skull": [
			{"phase": "release", "time": 0.85, "required_nodes": ["SkullCrown", "CrownHalo"]},
			{"phase": "active", "time": 1.8, "required_nodes": ["SkullCrown", "CurseChains", "SoulWispLeft"]},
			{"phase": "recovery", "time": 2.55, "required_nodes": ["SkullCrown", "HarvestBite", "CurseAura"]},
		],
		"dark_wand": [
			{"phase": "release", "time": 0.95, "required_nodes": ["WandGhost", "OuterThread"]},
			{"phase": "active", "time": 1.8, "required_nodes": ["WandGhost", "Branches", "NodeMarks"]},
			{"phase": "recovery", "time": 2.5, "required_nodes": ["OuterThread", "NodeMarks", "CollapseAfterimage"]},
		],
	},
	"druid": {
		"summon_amulet": [
			{"phase": "release", "time": 1.0, "required_nodes": ["BackdropLayer/BackdropVeil", "WildHunt"]},
			{"phase": "active", "time": 1.95, "required_nodes": ["WildHunt"]},
			{"phase": "recovery", "time": 3.1, "required_nodes": ["WildHunt"]},
		],
		"briar_staff": [
			{"phase": "release", "time": 1.1, "required_nodes": ["BackdropLayer/BackdropVeil", "BriarLattice"]},
			{"phase": "active", "time": 2.0, "required_nodes": ["BriarLattice"]},
			{"phase": "recovery", "time": 3.2, "required_nodes": ["BriarLattice"]},
		],
		"raven_totem": [
			{"phase": "release", "time": 0.75, "required_nodes": ["BackdropLayer/BackdropVeil", "RavenVortex"]},
			{"phase": "active", "time": 1.65, "required_nodes": ["RavenVortex"]},
			{"phase": "recovery", "time": 2.9, "required_nodes": ["RavenVortex"]},
		],
	},
	"elementalist": {
		"elementalist_orb_ring": [
			{"phase": "release", "time": 1.70, "required_nodes": ["Conclave"]},
			{"phase": "active", "time": 4.10, "required_nodes": ["Conclave"]},
			{"phase": "recovery", "time": 6.70, "required_nodes": ["Conclave"]},
		],
		"elementalist_prism_focus": [
			{"phase": "release", "time": 1.40, "required_nodes": ["PrismLattice"]},
			{"phase": "active", "time": 3.50, "required_nodes": ["PrismLattice"]},
			{"phase": "recovery", "time": 5.90, "required_nodes": ["PrismLattice"]},
		],
		"elementalist_meteor_core": [
			{"phase": "release", "time": 1.80, "required_nodes": ["Starfall"]},
			{"phase": "active", "time": 4.30, "required_nodes": ["Starfall"]},
			{"phase": "recovery", "time": 7.20, "required_nodes": ["Starfall"]},
		],
	},
	"engineer": {
		"engineer_sentry_wrench": [
			{"phase": "release", "time": 0.95, "required_nodes": ["BackdropDim", "WrenchSigil", "Pylon0"]},
			{"phase": "active", "time": 2.20, "required_nodes": ["BackdropDim", "WrenchSigil", "CrossfireChord0", "Pylon0"]},
			{"phase": "recovery", "time": 3.40, "required_nodes": ["BackdropDim", "WrenchSigil", "Pylon0"]},
		],
		"engineer_repair_drone": [
			{"phase": "release", "time": 0.70, "required_nodes": ["DroneSwarm"]},
			{"phase": "active", "time": 1.80, "required_nodes": ["DroneSwarm"]},
			{"phase": "recovery", "time": 3.40, "required_nodes": ["DroneSwarm"]},
		],
		"engineer_pressure_mines": [
			{"phase": "release", "time": 0.90, "required_nodes": ["MineField"]},
			{"phase": "active", "time": 1.70, "required_nodes": ["MineField"]},
			{"phase": "recovery", "time": 3.10, "required_nodes": ["MineField"]},
		],
	},
	"guitarist": {
		"electric_guitar": [
			{"phase": "release", "time": 0.90, "required_nodes": ["LastChord"]},
			{"phase": "active", "time": 2.70, "required_nodes": ["LastChord"]},
			{"phase": "recovery", "time": 4.40, "required_nodes": ["LastChord"]},
		],
		"bass_guitar": [
			{"phase": "release", "time": 1.00, "required_nodes": ["Subwoofer"]},
			{"phase": "active", "time": 2.90, "required_nodes": ["Subwoofer"]},
			{"phase": "recovery", "time": 4.70, "required_nodes": ["Subwoofer"]},
		],
		"sound_amp": [
			{"phase": "release", "time": 1.10, "required_nodes": ["WallOfSound"]},
			{"phase": "active", "time": 3.00, "required_nodes": ["WallOfSound"]},
			{"phase": "recovery", "time": 4.90, "required_nodes": ["WallOfSound"]},
		],
	},
	"knight": {
		"long_spear": [
			{"phase": "release", "time": 0.60, "required_nodes": ["SpearPlant", "CorridorGuide"]},
			{"phase": "active", "time": 0.90, "required_nodes": ["CorridorGuide", "Phalanx/RankOne"]},
			{"phase": "recovery", "time": 5.20, "required_nodes": ["CorridorGuide", "Phalanx/RankOne", "BannerLine"]},
		],
		"tower_shield": [
			{"phase": "release", "time": 0.90, "required_nodes": ["GuardStance", "ShieldWall/WallCore", "ShieldWall/Rampart"]},
			{"phase": "active", "time": 1.30, "required_nodes": ["GuardStance", "ShieldWall/WallCore", "ShieldWall/Rampart"]},
			{"phase": "recovery", "time": 7.60, "required_nodes": ["GuardStance", "ShieldWall/WallCore", "ShieldWall/Rampart"]},
		],
		"holy_flail": [
			{"phase": "release", "time": 1.20, "required_nodes": ["ChainRise", "FlailHead", "SpiralPath"]},
			{"phase": "active", "time": 1.60, "required_nodes": ["ChainRise", "FlailHead", "SpiralPath"]},
			{"phase": "recovery", "time": 6.60, "required_nodes": ["ChainRise", "FlailHead", "SpiralPath"]},
		],
	},
	"priest": {
		"priest_reliquary": [
			{"phase": "release", "time": 0.90, "required_nodes": ["Shrine", "ShrineRays"]},
			{"phase": "active", "time": 1.25, "required_nodes": ["Shrine", "ShrineRays", "RingJudgment"]},
			{"phase": "recovery", "time": 7.80, "required_nodes": ["Shrine", "RingJudgment", "Pillar", "Halo"]},
		],
		"priest_censer": [
			{"phase": "release", "time": 0.60, "required_nodes": ["Orbit/Censer", "Orbit/Chain"]},
			{"phase": "active", "time": 0.95, "required_nodes": ["Orbit/Censer", "Orbit/Chain"]},
			{"phase": "recovery", "time": 6.90, "required_nodes": ["Orbit/Censer", "Orbit/Chain", "SlamWave"]},
		],
		"priest_chime": [
			{"phase": "release", "time": 0.50, "required_nodes": ["Bell", "TollSilver"]},
			{"phase": "active", "time": 0.80, "required_nodes": ["Bell", "TollSilver"]},
			{"phase": "recovery", "time": 5.60, "required_nodes": ["Bell", "TollDawn", "DawnGuard"]},
			],
		},
	"ranger": {
		"moon_crossbow": [
			{"phase": "release", "time": 0.70, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "active", "time": 1.05, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "recovery", "time": 2.60, "required_nodes": [VISIBLE_EFFECT_NODE]},
		],
		"storm_longbow": [
			{"phase": "release", "time": 0.60, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "active", "time": 0.95, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "recovery", "time": 2.85, "required_nodes": [VISIBLE_EFFECT_NODE]},
		],
		"hunter_trap": [
			{"phase": "release", "time": 0.95, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "active", "time": 1.40, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "recovery", "time": 2.70, "required_nodes": [VISIBLE_EFFECT_NODE]},
		],
	},
	"robot": {
		"robot_magnetic_anchor": [
			{"phase": "release", "time": 0.45, "required_nodes": ["RobotMagneticAnchorSingularity"]},
			{"phase": "active", "time": 1.05, "required_nodes": ["RobotMagneticAnchorSingularity"]},
			{"phase": "recovery", "time": 4.25, "required_nodes": ["RobotMagneticAnchorSingularity"]},
		],
		"robot_hydraulic_press": [
			{"phase": "release", "time": 0.72, "required_nodes": ["RobotHydraulicPressProtocol"]},
			{"phase": "active", "time": 1.32, "required_nodes": ["RobotHydraulicPressProtocol"]},
			{"phase": "recovery", "time": 3.48, "required_nodes": ["RobotHydraulicPressProtocol"]},
		],
		"robot_reactor_core": [
			{"phase": "release", "time": 0.56, "required_nodes": ["RobotReactorCoreRedZone"]},
			{"phase": "active", "time": 1.08, "required_nodes": ["RobotReactorCoreRedZone"]},
			{"phase": "recovery", "time": 5.42, "required_nodes": ["RobotReactorCoreRedZone"]},
		],
	},
	"sniper": {
		"sniper_deadeye_rifle": [
			{"phase": "release", "time": 0.75, "required_nodes": ["PhaseNodes/Release/ArenaTracer", "PhaseNodes/Release/MuzzleTracer"]},
			{"phase": "active", "time": 1.25, "required_nodes": ["PhaseNodes/Active/EndpointFlash", "PhaseNodes/Active/SonicCrack"]},
			{"phase": "recovery", "time": 2.05, "required_nodes": ["PhaseNodes/Recovery/CasingDrop"]},
		],
		"sniper_spotter_scope": [
			{"phase": "release", "time": 0.85, "required_nodes": ["PhaseNodes/Release/SkyGridCrown", "PhaseNodes/Release/SkyGridRelease"]},
			{"phase": "active", "time": 1.55, "required_nodes": ["PhaseNodes/Active/BarrageColumnEast", "PhaseNodes/Active/ArenaImpactCore"]},
			{"phase": "recovery", "time": 2.60, "required_nodes": ["PhaseNodes/Recovery/CollapsePoint"]},
		],
		"sniper_shatter_rounds": [
			{"phase": "release", "time": 0.65, "required_nodes": ["PhaseNodes/Release/MuzzleFlash", "PhaseNodes/Release/FanTrajectory3"]},
			{"phase": "active", "time": 1.30, "required_nodes": ["PhaseNodes/Active/WaveEchoCore", "PhaseNodes/Active/CrystalWaveCore"]},
			{"phase": "recovery", "time": 2.20, "required_nodes": ["PhaseNodes/Recovery/CenterReturn"]},
		],
	},
	"soldier": {
		"soldier_rifle": [
			{"phase": "release", "time": 0.60, "required_nodes": ["FiringLine", "VolleyLane"]},
			{"phase": "active", "time": 0.90, "required_nodes": ["RifleGhostCenter", "VolleyLane", "MuzzleFlashWave"]},
			{"phase": "recovery", "time": 2.60, "required_nodes": ["RifleGhostCenter", "VolleyLane", "MuzzleFlashWave"]},
		],
		"soldier_grenade": [
			{"phase": "release", "time": 0.70, "required_nodes": ["LobArc", "GrenadeOne"]},
			{"phase": "active", "time": 1.00, "required_nodes": ["FuseRing", "GrenadeOne", "GrenadeThree"]},
			{"phase": "recovery", "time": 2.90, "required_nodes": ["FuseRing", "GrenadeOne", "GrenadeFive"]},
		],
		"soldier_bayonet": [
			{"phase": "release", "time": 0.80, "required_nodes": ["ChargeCorridor", "RankOne", "FrontalGuard"]},
			{"phase": "active", "time": 1.10, "required_nodes": ["ChargeCorridor", "RankOne", "FrontalGuard"]},
			{"phase": "recovery", "time": 3.20, "required_nodes": ["ChargeCorridor", "RankOne", "RankThree"]},
			],
		},
	"thief": {
		"thief_coin_pouch": [
			{"phase": "release", "time": 0.70, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "active", "time": 1.10, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "recovery", "time": 2.30, "required_nodes": [VISIBLE_EFFECT_NODE]},
		],
		"thief_shadow_cloak": [
			{"phase": "release", "time": 0.82, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "active", "time": 1.22, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "recovery", "time": 2.57, "required_nodes": [VISIBLE_EFFECT_NODE]},
		],
		"thief_smoke_bomb": [
			{"phase": "release", "time": 0.94, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "active", "time": 1.34, "required_nodes": [VISIBLE_EFFECT_NODE]},
			{"phase": "recovery", "time": 2.84, "required_nodes": [VISIBLE_EFFECT_NODE]},
		],
	},
	"doctor": {
		"restore_potion": [
			{"phase": "release", "time": 1.10, "required_nodes": ["GiantFlask", "GlassImpact"]},
			{"phase": "active", "time": 2.10, "required_nodes": ["GiantFlask", "OuterPoisonPool", "InnerHealingSpiral", "ShieldCrystal"]},
			{"phase": "recovery", "time": 3.05, "required_nodes": ["OuterPoisonPool", "InnerHealingSpiral", "ShieldCrystal"]},
		],
		"plague_syringe": [
			{"phase": "release", "time": 1.00, "required_nodes": ["OversizedSyringe", "PatientZero"]},
			{"phase": "active", "time": 2.60, "required_nodes": ["OversizedSyringe", "PatientZero", "PlagueVeinsA", "PlagueWaveThree"]},
			{"phase": "recovery", "time": 3.55, "required_nodes": ["MaskVaporBurst", "PlagueVeinsA"]},
		],
		"bone_saw": [
			{"phase": "release", "time": 0.85, "required_nodes": ["OrbitSaw1", "OrbitSaw2", "OrbitSaw3", "SurgicalOrbitArc"]},
			{"phase": "active", "time": 1.70, "required_nodes": ["OrbitSaw1", "OrbitSaw2", "SurgicalOrbitArc", "MetalSparks", "DrainRibbonGreen"]},
			{"phase": "recovery", "time": 2.55, "required_nodes": ["OrbitSaw1", "OrbitSaw2", "OrbitSaw3", "ShieldStitches"]},
		],
	},
}


static func frames_for_class(class_id: String) -> Dictionary:
	var frames = FRAMES_BY_CLASS.get(class_id, {})
	return (frames as Dictionary).duplicate(true) if frames is Dictionary else {}


static func evidence_for_class(class_id: String) -> Dictionary:
	var evidence = EVIDENCE_BY_CLASS.get(class_id, {})
	return (evidence as Dictionary).duplicate(true) if evidence is Dictionary else {}
