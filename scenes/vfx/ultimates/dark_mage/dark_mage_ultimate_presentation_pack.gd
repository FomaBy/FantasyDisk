class_name DarkMageUltimatePresentationPack
extends RefCounted

## The non-scene timing source consumed by the roster-wide parity ratchet.
## Keep these cumulative beats identical to the class manifest; the runtime
## scenes own their visual interpolation, not a second mechanics timeline.

const CLASS_ID := "dark_mage"
const WEAPONS := {
	"dark_book": {
		"timing": {"windup": 0.0, "release": 0.7, "active": 1.2, "recovery": 2.5, "cancel": 3.1},
	},
	"cursed_skull": {
		"timing": {"windup": 0.0, "release": 0.85, "active": 1.3, "recovery": 2.9, "cancel": 3.6},
	},
	"dark_wand": {
		"timing": {"windup": 0.0, "release": 0.95, "active": 1.45, "recovery": 2.9, "cancel": 3.9},
	},
}
