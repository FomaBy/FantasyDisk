extends RefCounted
class_name BossSceneCatalog

# Boss id -> PackedScene. Extracted from combat_director.gd by FAN-3977 (the
# encounter roster needs the same resolution before combat starts, and the
# director is at its line ratchet). `game` supplies the Disk Devourer scene
# and the generic fallback boss scene it exports.
#
# SCRUM-794: Bloodthorn Lion resolves here and is ready to spawn; it is NOT
# in the random route pool (route_map_screen._random_boss_route_node) —
# rotation is a separate task after QA.

const BONE_ARCHON_BOSS_SCENE := preload("res://scenes/BossBoneArchon.tscn")
const BROOD_MOTHER_BOSS_SCENE := preload("res://scenes/BossBroodMother.tscn")
const ASHEN_COLOSSUS_BOSS_SCENE := preload("res://scenes/BossAshenColossus.tscn")
const SECRET_ASCENSION_BOSS_SCENE := preload("res://scenes/BossSecretAscension.tscn")
const BLOODTHORN_LION_BOSS_SCENE := preload("res://scenes/BossBloodthornLion.tscn")


static func scene_for_id(game, boss_id: String) -> PackedScene:
	match boss_id:
		"disk_devourer":
			return game.disk_devourer_boss_scene if game.disk_devourer_boss_scene != null else game.boss_scene
		"bone_archon":
			return BONE_ARCHON_BOSS_SCENE
		"brood_mother":
			return BROOD_MOTHER_BOSS_SCENE
		"ashen_colossus":
			return ASHEN_COLOSSUS_BOSS_SCENE
		"secret_ascension_boss":
			return SECRET_ASCENSION_BOSS_SCENE
		"bloodthorn_lion":
			return BLOODTHORN_LION_BOSS_SCENE
		_:
			return game.boss_scene
