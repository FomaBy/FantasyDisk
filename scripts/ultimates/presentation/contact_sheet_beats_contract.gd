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
	"assassin",
	"berserk",
	"biologist",
	"chemist",
	"dark_mage",
	"druid",
	"elementalist",
	"engineer",
	"guitarist",
	"knight",
	"priest",
	"ranger",
	"robot",
	"sniper",
	"soldier",
	"thief",
]

const FRAMES_BY_CLASS := {
	"doctor": {
		"restore_potion": [
			{"phase": "release", "time": 1.35, "required_nodes": ["GiantFlask", "GlassImpact"]},
			{"phase": "active", "time": 3.10, "required_nodes": ["GiantFlask", "OuterPoisonPool", "InnerHealingSpiral", "ShieldCrystal"]},
			{"phase": "recovery", "time": 5.45, "required_nodes": ["OuterPoisonPool", "InnerHealingSpiral", "ShieldCrystal"]},
		],
		"plague_syringe": [
			{"phase": "release", "time": 0.62, "required_nodes": ["OversizedSyringe", "PatientZero"]},
			{"phase": "active", "time": 4.35, "required_nodes": ["OversizedSyringe", "PatientZero", "PlagueVeinsA", "PlagueWaveThree"]},
			{"phase": "recovery", "time": 6.50, "required_nodes": ["MaskVaporBurst", "PlagueVeinsA"]},
		],
		"bone_saw": [
			{"phase": "release", "time": 0.37, "required_nodes": ["OrbitSaw1", "OrbitSaw2", "OrbitSaw3", "SurgicalOrbitArc"]},
			{"phase": "active", "time": 1.95, "required_nodes": ["OrbitSaw1", "OrbitSaw2", "SurgicalOrbitArc", "MetalSparks", "DrainRibbonGreen"]},
			{"phase": "recovery", "time": 3.40, "required_nodes": ["OrbitSaw1", "OrbitSaw2", "OrbitSaw3", "ShieldStitches"]},
		],
	},
}


static func frames_for_class(class_id: String) -> Dictionary:
	var frames = FRAMES_BY_CLASS.get(class_id, {})
	return (frames as Dictionary).duplicate(true) if frames is Dictionary else {}
