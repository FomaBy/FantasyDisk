extends SceneTree

## Combat primitive ratchet (Combat VFX Art Standard v1.2, FAN-3006).
##
## Visible naked primitives — ColorRect, Polygon2D, untextured Line2D and flat
## draw_* calls — are banned as combat effects, both as .tscn nodes and as
## runtime construction in combat GDScript. Existing violators live in the
## shrink-only allowlists below (same ratchet rules as
## ContactSheetBeatsContract.MIGRATION_ALLOWLIST); the target state is empty.
## Standard and combat-vs-UI boundary:
## docs/design/systems/weapon_ultimate_presentation.md.

# One shared root list for scenes and scripts: combat .tscn also live under
# scripts/ultimates/classes/, and two separate constants already drifted once
# into a fail-open hole (QA FAN-3007).
const SCAN_ROOTS: Array[String] = ["res://scripts", "res://scenes"]

# Non-combat presentation (UI screens, HUD overlays, character-rig ground
# shadows) is outside the standard by explicit design-review boundary, never
# via the allowlists. Extending these lists is a design decision recorded in
# the doc above; it is NOT the way to ship a new combat primitive.
const NON_COMBAT_EXEMPT_PREFIXES: Array[String] = [
	"res://scenes/ui/",
	"res://scripts/ui/",
]
const NON_COMBAT_EXEMPT_FILES: Array[String] = [
	"res://scenes/PauseStatsMenu.tscn",
	"res://scripts/ui_screens.gd",
	"res://scripts/route_map_screen.gd",
	"res://scripts/pause_stats_menu.gd",
	"res://scripts/enemy_health_bar.gd",
	"res://scripts/cutout_rig_2d.gd",
]

# Both allowlists only shrink as FAN-3002 retrofit cards redraw the violators.
# Values are exact violation counts measured on dev @ 13c0855d. Any unlisted
# violation fails; any count drift fails (up = new violation, down or gone =
# stale entry that must shrink with the fix that removed it).
const SCENE_ALLOWLIST := {
	"res://scenes/vfx/BerserkAxeCleaveVfx.tscn": 3,
	"res://scenes/vfx/BerserkHammerSlamVfx.tscn": 4,
	"res://scenes/vfx/HolyFlailSpiralVfx.tscn": 3,
	"res://scenes/vfx/RobotHydraulicPressCompressionVfx.tscn": 5,
	"res://scenes/vfx/ultimates/assassin/AssassinChakramsEightMoons.tscn": 5,
	"res://scenes/vfx/ultimates/assassin/AssassinShadowDaggersMomentBeforeDeath.tscn": 3,
	"res://scenes/vfx/ultimates/assassin/AssassinVenomWireBlackWeb.tscn": 3,
	"res://scenes/vfx/ultimates/berserk/BerserkAxeExecutionLoop.tscn": 4,
	"res://scenes/vfx/ultimates/berserk/BerserkHammerFourfoldRift.tscn": 5,
	"res://scenes/vfx/ultimates/berserk/BerserkSwordScarletWhirlwind.tscn": 3,
	"res://scenes/vfx/ultimates/chemist/ChemistAcidFlaskTsarFlask.tscn": 4,
	"res://scenes/vfx/ultimates/chemist/ChemistBlastPowderPhilosophersExplosion.tscn": 1,
	"res://scenes/vfx/ultimates/chemist/ChemistHomunculusVialPerfectHomunculus.tscn": 5,
	"res://scenes/vfx/ultimates/dark_mage/DarkMageBookAbyssMirror.tscn": 5,
	"res://scenes/vfx/ultimates/dark_mage/DarkMageSkullCursedCrown.tscn": 4,
	"res://scenes/vfx/ultimates/dark_mage/DarkMageWandVanishingThread.tscn": 5,
	"res://scenes/vfx/ultimates/druid/DruidBriarStaffForestInOneBreath.tscn": 9,
	"res://scenes/vfx/ultimates/druid/DruidRavenTotemNightOfThousandWings.tscn": 8,
	"res://scenes/vfx/ultimates/druid/DruidSummonAmuletWildHunt.tscn": 10,
	"res://scenes/vfx/ultimates/elementalist/ElementalistMeteorCoreStarfall.tscn": 5,
	"res://scenes/vfx/ultimates/elementalist/ElementalistOrbRingGrandConclave.tscn": 6,
	"res://scenes/vfx/ultimates/elementalist/ElementalistPrismFocusPrismaticVerdict.tscn": 8,
	"res://scenes/vfx/ultimates/guitarist/GuitaristBassGuitarHellSubwoofer.tscn": 4,
	"res://scenes/vfx/ultimates/guitarist/GuitaristElectricGuitarLastChord.tscn": 5,
	"res://scenes/vfx/ultimates/guitarist/GuitaristSoundAmpWallOfSound.tscn": 6,
	"res://scenes/vfx/ultimates/knight/KnightHolyFlailHeavenlySpiral.tscn": 6,
	"res://scenes/vfx/ultimates/knight/KnightLongSpearSpearWall.tscn": 4,
	"res://scenes/vfx/ultimates/knight/KnightTowerShieldImpassableLine.tscn": 4,
	"res://scenes/vfx/ultimates/priest/PriestCenserUnbreakableVow.tscn": 8,
	"res://scenes/vfx/ultimates/priest/PriestChimeThreeBellsOfDawn.tscn": 7,
	"res://scenes/vfx/ultimates/priest/PriestReliquarySanctumJudgment.tscn": 10,
	"res://scenes/vfx/ultimates/sniper/sniper_deadeye_rifle_ultimate.tscn": 4,
	"res://scenes/vfx/ultimates/sniper/sniper_shatter_rounds_ultimate.tscn": 11,
	"res://scenes/vfx/ultimates/sniper/sniper_spotter_scope_ultimate.tscn": 7,
	"res://scenes/vfx/ultimates/soldier/SoldierBayonetLastCharge.tscn": 5,
	"res://scenes/vfx/ultimates/soldier/SoldierGrenadeSevenSeconds.tscn": 4,
	"res://scenes/vfx/ultimates/soldier/SoldierRifleSuppressiveOrder.tscn": 5,
}
const SCRIPT_ALLOWLIST := {
	"res://scenes/vfx/ultimates/biologist/biologist_ultimate_scene.gd": 1,
	"res://scenes/vfx/ultimates/doctor/doctor_ultimate_timeline_scene.gd": 2,
	"res://scripts/class_weapon.gd": 1,
	"res://scripts/combat_director.gd": 1,
	"res://scripts/encounters/features/captains/captain_feature.gd": 1,
	"res://scripts/encounters/features/marked_target_feature.gd": 1,
	"res://scripts/enemy.gd": 1,
	"res://scripts/player.gd": 4,
	"res://scripts/projectile.gd": 1,
	"res://scripts/threat_indicators.gd": 1,
}

var _errors: Array[String] = []
var _construction_regex := RegEx.new()
var _node_header_regex := RegEx.new()


func _init() -> void:
	_construction_regex.compile("\\b(?:ColorRect|Polygon2D|Line2D)\\.new\\s*\\(|\\bdraw_(?:circle|rect|polygon|line|arc)\\s*\\(")
	_node_header_regex.compile("^\\[node .*\\btype=\"(ColorRect|Polygon2D|Line2D)\"")

	var scene_found := {}
	var scenes: Array[String] = []
	for root in SCAN_ROOTS:
		_collect_files(root, "tscn", scenes)
	for path in scenes:
		var count := _scene_primitive_count(path)
		if count > 0:
			scene_found[path] = count

	var script_found := {}
	var scripts: Array[String] = []
	for root in SCAN_ROOTS:
		_collect_files(root, "gd", scripts)
	for path in scripts:
		var count := _script_construction_count(path)
		if count > 0:
			script_found[path] = count

	_check_ratchet("scene", SCENE_ALLOWLIST, scene_found)
	_check_ratchet("script", SCRIPT_ALLOWLIST, script_found)

	if _errors.is_empty():
		print("Combat primitive ratchet passed: %d allowlisted scenes (%d primitive nodes), %d allowlisted scripts (%d construction sites), 0 violations outside the ratchet." % [
			scene_found.size(), _sum(scene_found), script_found.size(), _sum(script_found),
		])
		quit(0)
	else:
		for error in _errors:
			push_error("Combat primitive ratchet: %s" % error)
		quit(1)


func _check_ratchet(kind: String, allowlist: Dictionary, found: Dictionary) -> void:
	for path in found:
		if not allowlist.has(path):
			_errors.append("new combat primitive %s outside the ratchet: %s (%d). The standard requires a PixelLab flipbook; the allowlist never grows." % [kind, path, found[path]])
		elif found[path] > allowlist[path]:
			_errors.append("%s %s grew from %d to %d allowlisted primitives; new combat primitives are banned." % [kind, path, allowlist[path], found[path]])
		elif found[path] < allowlist[path]:
			_errors.append("stale ratchet entry: %s %s now has %d violations, entry says %d. Shrink the entry with the fix that removed them." % [kind, path, found[path], allowlist[path]])
	for path in allowlist:
		if not found.has(path):
			_errors.append("stale ratchet entry: %s %s has no violations left (or no longer exists). Remove its allowlist entry." % [kind, path])


func _scene_primitive_count(path: String) -> int:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var count := 0
	for i in lines.size():
		var found := _node_header_regex.search(lines[i].strip_edges())
		if found == null:
			continue
		if found.get_string(1) != "Line2D":
			count += 1
			continue
		# A textured Line2D is a legal textured stroke; only naked ones count.
		var textured := false
		for j in range(i + 1, lines.size()):
			var property := lines[j].strip_edges()
			if property.begins_with("["):
				break
			if property.begins_with("texture ") or property.begins_with("texture="):
				textured = true
				break
		if not textured:
			count += 1
	return count


func _script_construction_count(path: String) -> int:
	var count := 0
	for line in FileAccess.get_file_as_string(path).split("\n"):
		# ponytail: comment stripping ignores '#' inside string literals;
		# a draw_* call after such a '#' would be missed, none exist today.
		count += _construction_regex.search_all(line.get_slice("#", 0)).size()
	return count


func _collect_files(root: String, extension: String, out: Array[String]) -> void:
	if _is_exempt(root + "/"):
		return
	var dir := DirAccess.open(root)
	if dir == null:
		_errors.append("scan root cannot be opened (fail closed): %s" % root)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var path := root.path_join(entry)
			if dir.current_is_dir():
				_collect_files(path, extension, out)
			elif entry.get_extension() == extension and not _is_exempt(path) and not out.has(path):
				out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _is_exempt(path: String) -> bool:
	if path in NON_COMBAT_EXEMPT_FILES:
		return true
	for prefix in NON_COMBAT_EXEMPT_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false


func _sum(counts: Dictionary) -> int:
	var total := 0
	for path in counts:
		total += counts[path]
	return total
