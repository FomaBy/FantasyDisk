class_name ContactSheetBeatsContract
extends RefCounted

## Frame-local evidence declarations for ultimate contact sheets.
##
## This contract is presentation evidence only. It does not instantiate scenes,
## change the runtime presentation bridge, or own class mechanics.

const REQUIRED_PHASES: Array[String] = ["release", "active", "recovery"]

# This list only shrinks as class packages adopt FRAMES_BY_CLASS. The target is
# an empty list; a complete declaration left here fails the shared invariant.
const MIGRATION_ALLOWLIST: Array[String] = [
	"chemist",
	"knight",
	"priest",
	"ranger",
	"robot",
	"sniper",
	"soldier",
	"thief",
]

const FRAMES_BY_CLASS := {
	"assassin": {
		"chakrams": [
			{"phase": "release", "time": 0.9, "required_nodes": ["BackdropDarken", "ImpactFlash", "Orbit/MoonOne", "Orbit/MoonEight"]},
			{"phase": "active", "time": 2.4, "required_nodes": ["BackdropDarken", "Orbit/MoonFour", "ReturnCrescents"]},
			{"phase": "recovery", "time": 3.2, "required_nodes": ["Orbit/MoonOne", "ReturnCrescents"]},
		],
		"shadow_daggers": [
			{"phase": "release", "time": 0.5, "required_nodes": ["FreezeMarks", "Afterimages/BackstabOne"]},
			{"phase": "active", "time": 2.0, "required_nodes": ["Afterimages/BackstabOne", "FinalReveal"]},
			{"phase": "recovery", "time": 5.2, "required_nodes": ["FreezeMarks", "FinalReveal"]},
		],
		"venom_wire": [
			{"phase": "release", "time": 0.7, "required_nodes": ["Anchors/NeedleOne", "HexWeb"]},
			{"phase": "active", "time": 2.4, "required_nodes": ["HexWeb", "SnapCollapse"]},
			{"phase": "recovery", "time": 5.5, "required_nodes": ["Anchors/NeedleOne", "SnapCollapse"]},
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
			{"phase": "release", "time": 1.50, "required_nodes": ["WildHunt"]},
			{"phase": "active", "time": 3.50, "required_nodes": ["WildHunt"]},
			{"phase": "recovery", "time": 6.20, "required_nodes": ["WildHunt"]},
		],
		"briar_staff": [
			{"phase": "release", "time": 1.70, "required_nodes": ["BriarLattice"]},
			{"phase": "active", "time": 4.20, "required_nodes": ["BriarLattice"]},
			{"phase": "recovery", "time": 7.30, "required_nodes": ["BriarLattice"]},
		],
		"raven_totem": [
			{"phase": "release", "time": 1.80, "required_nodes": ["RavenVortex"]},
			{"phase": "active", "time": 4.50, "required_nodes": ["RavenVortex"]},
			{"phase": "recovery", "time": 7.80, "required_nodes": ["RavenVortex"]},
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
