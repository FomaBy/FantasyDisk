class_name UltimateVisualDirectionContract
extends RefCounted

## Objective quality bar shared by all 51 weapon-ultimate presentations.
##
## The contract reads class reference manifests and their committed capture
## files. It never instantiates a presentation scene: live budget enforcement
## stays in WeaponUltimatePresentationRuntime, phase/pivot/asset binding stays
## in WeaponUltimatePresentationSchema, and timing parity stays in the contact
## sheet beats and timing distinctness gates. This module adds the visual
## direction, live-capture, provenance and accessibility gates none of them own.
##
## Every violation is reported as "<gate>.<code>: <detail>", so a caller can
## group findings by gate through gate_of().

const Schema := preload("res://scripts/ultimates/presentation/weapon_ultimate_presentation_schema.gd")

const MANIFEST_ROOT := "res://docs/design/references/weapon_ultimates"

## The five presentation phases, in the order a cast plays them. `cancel` is the
## cleanup phase: it also runs on pause-abort, death and interrupt.
const PHASE_ORDER: Array[String] = ["windup", "release", "active", "recovery", "cancel"]

## Phase name → the frozen registry cast-phase suffix it must bind.
const PHASE_ID_SUFFIXES := {
	"windup": "windup",
	"release": "execute",
	"active": "active",
	"recovery": "recover",
	"cancel": "cleanup",
}

## Matches the presentation schema's own timeline ceiling.
const MAX_TIMELINE_SECONDS := 10.0

## The supported live-capture viewport set. A class package commits one contact
## sheet per entry, rendered from the running scene at exactly that size, so
## crowd and HUD readability are reviewable at the smallest and largest viewport.
const REQUIRED_CAPTURES := {
	"648p": Vector2i(1152, 648),
	"720p": Vector2i(1280, 720),
	"1080p": Vector2i(1920, 1080),
	"2k": Vector2i(2560, 1440),
}

## Declared-budget ceilings. The live roster peaks at 26 drawn nodes, so the
## ceiling keeps working headroom while still bounding what one activation may
## add on top of a crowd. Runtime counts the real nodes against the same numbers.
const MAX_VISUAL_NODES_CEILING := 32
const CROWD_CAP_CEILING := 32

## The material half of the same budget: distinct materials/shaders one
## activation may carry, and how many of those may cover the full viewport (the
## backdrop darken/flash layers). Enforced only for a pair that has left
## Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST, so a v1 package is never forced
## to declare materials and the rule arrives exactly when a package goes v2.
const MAX_UNIQUE_MATERIALS_CEILING := 16
const MAX_FULLSCREEN_MATERIALS_CEILING := 2

## Readability: the fraction of the viewport one activation may cover opaquely.
## Above this the HUD and the crowd stop being readable at 1152x648.
const MAX_VIEWPORT_COVERAGE_RATIO := 0.35

## Photosensitivity: WCAG 2.3.1 general flash threshold, and the coverage above
## which a repeating flash is not allowed at all.
const MAX_FLASH_HZ := 3.0
const MAX_REPEAT_FLASH_COVERAGE_RATIO := 0.25

## Free-text direction fields that must exist and stay distinct inside a trio.
const DIRECTION_FIELDS: Array[String] = ["silhouette", "motion_path", "impact_language"]

## Classes that do not satisfy a gate yet. This map is a ratchet like
## ContactSheetBeatsContract.MIGRATION_ALLOWLIST: it only shrinks, and an entry
## whose class already passes its gate fails as stale. Roster-wide adoption
## belongs to the per-class animation cards, not to this contract.
const ADOPTION_GAPS := {
	"phases": {
		"engineer": "legacy asset-pipeline manifest: declares no per-weapon phase_ids",
		"sniper": "legacy source manifest: declares no per-weapon phase_ids",
		"thief": "legacy asset-pipeline manifest: declares no per-weapon phase_ids",
	},
	"cleanup": {
		"soldier": "soldier_grenade declares cancel == recovery (8.40s): no cleanup window",
	},
	"direction": {
		"engineer": "legacy asset-pipeline manifest: no silhouette/motion/impact language",
		"sniper": "legacy source manifest: no silhouette/motion/impact language",
		"thief": "legacy asset-pipeline manifest: no silhouette/motion/impact language",
	},
	"capture": {
		"ranger": "single 4680x594 strip instead of the four live-capture viewports",
		"sniper": "single 768x256 strip instead of the four live-capture viewports",
		"thief": "single 3600x552 strip instead of the four live-capture viewports",
	},
	"provenance": {
		"sniper": "legacy source manifest: no generator_provenance block",
		"thief": "legacy asset-pipeline manifest: no generator_provenance block",
	},
	"quality": {
		"assassin": "awaiting the readability/accessibility declaration",
		"berserk": "awaiting the readability/accessibility declaration",
		"biologist": "awaiting the readability/accessibility declaration",
		"dark_mage": "awaiting the readability/accessibility declaration",
		"druid": "awaiting the readability/accessibility declaration",
		"elementalist": "awaiting the readability/accessibility declaration",
		"engineer": "awaiting the readability/accessibility declaration",
		"guitarist": "awaiting the readability/accessibility declaration",
		"knight": "awaiting the readability/accessibility declaration",
		"priest": "awaiting the readability/accessibility declaration",
		"ranger": "awaiting the readability/accessibility declaration",
		"robot": "awaiting the readability/accessibility declaration",
		"sniper": "awaiting the readability/accessibility declaration",
		"soldier": "awaiting the readability/accessibility declaration",
		"thief": "awaiting the readability/accessibility declaration",
	},
}

const GATES: Array[String] = ["phases", "cleanup", "budget", "direction", "capture", "provenance", "quality"]


static func class_ids() -> Array[String]:
	var ids: Array[String] = []
	for name in DirAccess.get_directories_at(MANIFEST_ROOT):
		ids.append(str(name))
	ids.sort()
	return ids


static func load_manifest(class_id: String) -> Dictionary:
	var path := "%s/%s/manifest.json" % [MANIFEST_ROOT, class_id]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## Every gate for one class, as "<gate>.<code>: <detail>" entries.
static func violations(
	class_id: String,
	manifest: Dictionary,
	allowlist: Dictionary = Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST
) -> Array[String]:
	var errors: Array[String] = []
	if manifest.is_empty():
		errors.append("phases.manifest_missing: %s" % class_id)
		return errors
	var weapons := _weapons(manifest)
	if weapons.size() != 3:
		errors.append("phases.trio: %s declares %d weapons" % [class_id, weapons.size()])
	for weapon in weapons:
		var key := "%s/%s" % [class_id, str(weapon.get("weapon_id", ""))]
		_check_phases(weapon, key, errors)
		_check_cleanup(weapon, key, errors)
		_check_budget(weapon, key, allowlist, errors)
		_check_quality(weapon, key, errors)
	_check_direction(weapons, class_id, errors)
	_check_capture(manifest, class_id, errors)
	_check_provenance(manifest, weapons, class_id, errors)
	return errors


static func gate_of(violation: String) -> String:
	return violation.get_slice(".", 0)


## The five phases are declared, start at zero, never run backwards, stay inside
## the timeline ceiling, and bind their frozen registry cast-phase ids.
static func _check_phases(weapon: Dictionary, key: String, errors: Array[String]) -> void:
	var timing: Variant = weapon.get("timing_seconds")
	if not timing is Dictionary:
		errors.append("phases.timing_missing: %s" % key)
		return
	var previous := -1.0
	for phase in PHASE_ORDER:
		var value: Variant = (timing as Dictionary).get(phase)
		if not _is_number(value):
			errors.append("phases.timing_type: %s/%s" % [key, phase])
			continue
		var seconds := float(value)
		if not is_finite(seconds) or seconds < 0.0 or seconds > MAX_TIMELINE_SECONDS:
			errors.append("phases.timing_range: %s/%s is %.2fs" % [key, phase, seconds])
		elif seconds < previous:
			errors.append("phases.timing_order: %s/%s runs backwards" % [key, phase])
		previous = seconds
	if _is_number((timing as Dictionary).get("windup")) and not is_zero_approx(float((timing as Dictionary)["windup"])):
		errors.append("phases.windup_origin: %s must start its timeline at 0.00s" % key)

	var phase_ids: Variant = weapon.get("phase_ids")
	if not phase_ids is Dictionary:
		errors.append("phases.phase_ids_missing: %s" % key)
		return
	for phase in PHASE_ORDER:
		var phase_id := str((phase_ids as Dictionary).get(phase, ""))
		if phase_id.is_empty():
			errors.append("phases.phase_id_empty: %s/%s" % [key, phase])
		elif not phase_id.ends_with(".%s" % PHASE_ID_SUFFIXES[phase]):
			errors.append("phases.phase_id_binding: %s/%s is %s" % [key, phase, phase_id])


## The cancel phase is the cleanup window; it must be a real window, not a
## timestamp shared with recovery, or nothing can tear down on interrupt.
static func _check_cleanup(weapon: Dictionary, key: String, errors: Array[String]) -> void:
	var timing: Variant = weapon.get("timing_seconds")
	if not timing is Dictionary:
		return
	var recovery: Variant = (timing as Dictionary).get("recovery")
	var cancel: Variant = (timing as Dictionary).get("cancel")
	if not _is_number(recovery) or not _is_number(cancel):
		return
	if float(cancel) <= float(recovery):
		errors.append(
			"cleanup.window: %s declares cancel %.2fs at or before recovery %.2fs"
			% [key, float(cancel), float(recovery)]
		)


## Declared visual budgets bound what one activation adds on top of a crowd.
static func _check_budget(
	weapon: Dictionary,
	key: String,
	allowlist: Dictionary,
	errors: Array[String]
) -> void:
	var performance: Variant = weapon.get("performance")
	if not performance is Dictionary:
		errors.append("budget.missing: %s" % key)
		return
	if not allowlist.has(key):
		_check_material_budget(performance as Dictionary, key, errors)
	var max_visual_nodes: Variant = (performance as Dictionary).get("max_visual_nodes")
	var crowd_cap: Variant = (performance as Dictionary).get("crowd_cap")
	if not _is_whole_number(max_visual_nodes) or int(max_visual_nodes) <= 0:
		errors.append("budget.max_visual_nodes: %s declares %s" % [key, str(max_visual_nodes)])
		return
	if not _is_whole_number(crowd_cap) or int(crowd_cap) <= 0:
		errors.append("budget.crowd_cap: %s declares %s" % [key, str(crowd_cap)])
		return
	if int(max_visual_nodes) > int(crowd_cap):
		errors.append(
			"budget.relation: %s max_visual_nodes %d exceeds crowd_cap %d"
			% [key, int(max_visual_nodes), int(crowd_cap)]
		)
	if int(max_visual_nodes) > MAX_VISUAL_NODES_CEILING:
		errors.append(
			"budget.max_visual_nodes_ceiling: %s declares %d over %d"
			% [key, int(max_visual_nodes), MAX_VISUAL_NODES_CEILING]
		)
	if int(crowd_cap) > CROWD_CAP_CEILING:
		errors.append(
			"budget.crowd_cap_ceiling: %s declares %d over %d"
			% [key, int(crowd_cap), CROWD_CAP_CEILING]
		)


## The declared material budget, validated exactly like max_visual_nodes: a
## missing, non-positive or above-ceiling number fails closed, and so does a
## full-screen count larger than the unique count it is drawn from. The same
## declaration arrives from a manifest `performance` block and from the scene
## metadata of an instantiated activation, so both read one validator.
static func _check_material_budget(declaration: Dictionary, key: String, errors: Array[String]) -> void:
	var unique: Variant = declaration.get("max_unique_materials")
	var fullscreen: Variant = declaration.get("max_fullscreen_materials")
	if not _is_whole_number(unique) or int(unique) <= 0:
		errors.append("budget.max_unique_materials: %s declares %s" % [key, str(unique)])
		return
	if not _is_whole_number(fullscreen) or int(fullscreen) <= 0:
		errors.append("budget.max_fullscreen_materials: %s declares %s" % [key, str(fullscreen)])
		return
	if int(unique) > MAX_UNIQUE_MATERIALS_CEILING:
		errors.append(
			"budget.max_unique_materials_ceiling: %s declares %d over %d"
			% [key, int(unique), MAX_UNIQUE_MATERIALS_CEILING]
		)
	if int(fullscreen) > MAX_FULLSCREEN_MATERIALS_CEILING:
		errors.append(
			"budget.max_fullscreen_materials_ceiling: %s declares %d over %d"
			% [key, int(fullscreen), MAX_FULLSCREEN_MATERIALS_CEILING]
		)
	if int(fullscreen) > int(unique):
		errors.append(
			"budget.material_relation: %s max_fullscreen_materials %d exceeds max_unique_materials %d"
			% [key, int(fullscreen), int(unique)]
		)


## The actual material counts of an instantiated activation against the budget
## its scene metadata declares. The caller owns the instance: this contract
## still instantiates nothing, it only walks the tree it is handed. A pair
## inside the migration allowlist is v1 and reports nothing.
static func scene_material_violations(
	scene: Node,
	key: String,
	allowlist: Dictionary = Schema.PRESENTATION_V2_MIGRATION_ALLOWLIST
) -> Array[String]:
	var errors: Array[String] = []
	if allowlist.has(key):
		return errors
	if scene == null or not is_instance_valid(scene):
		errors.append("budget.scene_missing: %s" % key)
		return errors
	var declared_unique: Variant = _declared_meta(scene, "max_unique_materials")
	var declared_fullscreen: Variant = _declared_meta(scene, "max_fullscreen_materials")
	_check_material_budget(
		{"max_unique_materials": declared_unique, "max_fullscreen_materials": declared_fullscreen},
		key,
		errors
	)
	if not errors.is_empty():
		return errors
	var counts := material_counts(scene)
	if int(counts["unique"]) > int(declared_unique):
		errors.append(
			"budget.unique_materials_actual: %s carries %d over its declared %d"
			% [key, int(counts["unique"]), int(declared_unique)]
		)
	if int(counts["fullscreen"]) > int(declared_fullscreen):
		errors.append(
			"budget.fullscreen_materials_actual: %s carries %d over its declared %d"
			% [key, int(counts["fullscreen"]), int(declared_fullscreen)]
		)
	return errors


## A missing scene declaration reads as null, the same "not declared" value the
## manifest path produces, without Object.get_meta pushing its own error.
static func _declared_meta(scene: Node, key: String) -> Variant:
	return scene.get_meta(key) if scene.has_meta(key) else null


## Materials an instantiated activation actually carries, as
## {"unique": int, "fullscreen": int}.
##
## "Covers the full viewport" is read as screen space: a CanvasItem under a
## CanvasLayer inside the activation draws in viewport coordinates regardless of
## camera, which is the one full-viewport property readable off a scene without
## rendering it. The rule over-counts a small screen-space overlay and does not
## see a world-space node stretched over the viewport, so it is deliberately
## strict on what it does count and silent on what it cannot; the remainder
## stays review-gated. Materials created during begin() are not visible here
## either: this counts the authored tree.
static func material_counts(root: Node) -> Dictionary:
	var unique := {}
	var fullscreen := {}
	_collect_materials(root, false, unique, fullscreen)
	return {"unique": unique.size(), "fullscreen": fullscreen.size()}


static func _collect_materials(
	node: Node,
	screen_space: bool,
	unique: Dictionary,
	fullscreen: Dictionary
) -> void:
	var in_screen_space := screen_space or node is CanvasLayer
	for material in _node_materials(node):
		unique[material.get_instance_id()] = true
		if in_screen_space:
			fullscreen[material.get_instance_id()] = true
	for child in node.get_children():
		_collect_materials(child, in_screen_space, unique, fullscreen)


## Every material resource one node contributes: its canvas material, plus the
## particle process shader, which is a distinct program on the same activation.
static func _node_materials(node: Node) -> Array[Material]:
	var materials: Array[Material] = []
	if node is CanvasItem and (node as CanvasItem).material != null:
		materials.append((node as CanvasItem).material)
	if node is GPUParticles2D and (node as GPUParticles2D).process_material != null:
		materials.append((node as GPUParticles2D).process_material)
	return materials


## Sibling distinctness: the three weapons of a class read differently on
## silhouette, motion and impact, so a player can name the ultimate on sight.
static func _check_direction(weapons: Array[Dictionary], class_id: String, errors: Array[String]) -> void:
	for field in DIRECTION_FIELDS:
		var seen := {}
		for weapon in weapons:
			var key := "%s/%s" % [class_id, str(weapon.get("weapon_id", ""))]
			var value := str(weapon.get(field, "")).strip_edges()
			if value.is_empty():
				errors.append("direction.%s_missing: %s" % [field, key])
				continue
			var normalized := value.to_lower()
			if seen.has(normalized):
				errors.append("direction.%s_duplicate: %s repeats %s" % [field, key, seen[normalized]])
			else:
				seen[normalized] = key


## Live captures: one reproducible contact sheet per supported viewport, each
## file committed at exactly that size.
static func _check_capture(manifest: Dictionary, class_id: String, errors: Array[String]) -> void:
	var evidence: Variant = manifest.get("evidence")
	if not evidence is Dictionary:
		errors.append("capture.evidence_missing: %s" % class_id)
		return
	var capture_script := str((evidence as Dictionary).get("capture_script", ""))
	if capture_script.is_empty():
		errors.append("capture.script_missing: %s" % class_id)
	elif not FileAccess.file_exists(_resource_path(capture_script)):
		errors.append("capture.script_absent: %s" % capture_script)

	var sheets: Variant = (evidence as Dictionary).get("contact_sheets")
	if not sheets is Array:
		errors.append("capture.sheets_missing: %s" % class_id)
		return
	var listed := sheets as Array
	if listed.size() != REQUIRED_CAPTURES.size():
		errors.append("capture.sheet_count: %s lists %d of %d" % [class_id, listed.size(), REQUIRED_CAPTURES.size()])
	for suffix in REQUIRED_CAPTURES:
		var expected_size: Vector2i = REQUIRED_CAPTURES[suffix]
		var matches: Array[String] = []
		for raw_path in listed:
			if str(raw_path).ends_with("_%s.png" % suffix):
				matches.append(str(raw_path))
		if matches.size() != 1:
			errors.append("capture.viewport_missing: %s/%s listed %d times" % [class_id, suffix, matches.size()])
			continue
		var path := _resource_path(matches[0])
		var actual_size := png_size(path)
		if actual_size == Vector2i.ZERO:
			errors.append("capture.file_absent: %s" % matches[0])
		elif actual_size != expected_size:
			errors.append(
				"capture.viewport_size: %s is %dx%d, expected %dx%d"
				% [matches[0], actual_size.x, actual_size.y, expected_size.x, expected_size.y]
			)


## Source provenance. PixelLab is the required source for new isolated frames;
## the built-in Image Generator is admitted only through the declared
## full-canvas exception, which may never claim transparent frames.
static func _check_provenance(
	manifest: Dictionary,
	weapons: Array[Dictionary],
	class_id: String,
	errors: Array[String]
) -> void:
	var provenance: Variant = manifest.get("generator_provenance")
	if not provenance is Dictionary:
		errors.append("provenance.missing: %s" % class_id)
		return
	var record := provenance as Dictionary
	var route := str(record.get("route", "")).strip_edges().to_lower()
	if route.is_empty():
		errors.append("provenance.route_missing: %s" % class_id)
	var new_assets: Variant = record.get("new_pixellab_assets")
	if not new_assets is Array:
		errors.append("provenance.new_pixellab_assets: %s must declare an Array" % class_id)
		return
	if (new_assets as Array).is_empty():
		var reused: Variant = record.get("reused_sources")
		if not reused is Dictionary or (reused as Dictionary).is_empty():
			errors.append("provenance.reuse_unevidenced: %s generated nothing and reuses nothing" % class_id)
		if not route.contains("reused"):
			errors.append("provenance.route_reuse: %s generated no asset but its route is %s" % [class_id, route])
	elif not route.contains("pixellab"):
		errors.append("provenance.route_pixellab: %s ships new frames on route %s" % [class_id, route])

	if not record.has("full_canvas_exception"):
		return
	var exception: Variant = record["full_canvas_exception"]
	if not exception is Dictionary:
		errors.append("provenance.exception_type: %s" % class_id)
		return
	var exception_record := exception as Dictionary
	if str(exception_record.get("reason", "")).strip_edges().is_empty():
		errors.append("provenance.exception_reason: %s" % class_id)
	if exception_record.get("full_canvas") != true:
		errors.append("provenance.exception_scope: %s must declare full_canvas true" % class_id)
	if exception_record.get("transparent_frames") != false:
		errors.append("provenance.exception_transparency: %s may not supply transparent frames" % class_id)
	var weapon_id := str(exception_record.get("weapon_id", ""))
	var known := false
	for weapon in weapons:
		if str(weapon.get("weapon_id", "")) == weapon_id:
			known = true
	if not known:
		errors.append("provenance.exception_weapon: %s/%s is not a class weapon" % [class_id, weapon_id])


## Crowd/HUD readability plus the reduced-motion and photosensitivity variants.
static func _check_quality(weapon: Dictionary, key: String, errors: Array[String]) -> void:
	var quality: Variant = weapon.get("quality")
	if not quality is Dictionary:
		errors.append("quality.missing: %s" % key)
		return
	var record := quality as Dictionary

	var coverage: Variant = record.get("max_viewport_coverage_ratio")
	if not _is_number(coverage) or float(coverage) <= 0.0 or float(coverage) > MAX_VIEWPORT_COVERAGE_RATIO:
		errors.append("quality.coverage: %s declares %s over %.2f" % [key, str(coverage), MAX_VIEWPORT_COVERAGE_RATIO])
	if record.get("hud_bands_clear") != true:
		errors.append("quality.hud_bands: %s must keep the HUD bands clear" % key)
	if str(record.get("reduced_motion_substitute", "")).strip_edges().is_empty():
		errors.append("quality.reduced_motion_substitute: %s" % key)
	if record.get("reduced_motion_preserves_timing") != true:
		errors.append("quality.reduced_motion_timing: %s variant must keep its phase timing" % key)

	var flash_hz: Variant = record.get("full_screen_flash_hz")
	var flash_coverage: Variant = record.get("max_flash_coverage_ratio")
	if not _is_number(flash_hz) or float(flash_hz) < 0.0 or float(flash_hz) > MAX_FLASH_HZ:
		errors.append("quality.flash_hz: %s declares %s over %.1f Hz" % [key, str(flash_hz), MAX_FLASH_HZ])
		return
	if not _is_number(flash_coverage) or float(flash_coverage) < 0.0 or float(flash_coverage) > 1.0:
		errors.append("quality.flash_coverage: %s declares %s" % [key, str(flash_coverage)])
		return
	if float(flash_hz) > 0.0 and float(flash_coverage) > MAX_REPEAT_FLASH_COVERAGE_RATIO:
		errors.append(
			"quality.flash_repeat: %s repeats a %.2f-coverage flash at %.2f Hz"
			% [key, float(flash_coverage), float(flash_hz)]
		)


## Width/height straight from the PNG IHDR header, or ZERO when the file is
## missing or is not a PNG. Reading 24 bytes avoids decoding 2K sheets.
static func png_size(path: String) -> Vector2i:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Vector2i.ZERO
	var header := file.get_buffer(24)
	file.close()
	if header.size() != 24 or header.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return Vector2i.ZERO
	return Vector2i(_big_endian_u32(header, 16), _big_endian_u32(header, 20))


static func _big_endian_u32(bytes: PackedByteArray, offset: int) -> int:
	return (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3]


static func _weapons(manifest: Dictionary) -> Array[Dictionary]:
	var weapons: Array[Dictionary] = []
	var raw: Variant = manifest.get("weapons", [])
	if not raw is Array:
		return weapons
	for entry in raw as Array:
		if entry is Dictionary:
			weapons.append(entry as Dictionary)
	return weapons


## Manifests record repository-relative paths; an already-qualified path passes
## through so a fixture can point at user:// without being rewritten.
static func _resource_path(path: String) -> String:
	return path if path.contains("://") else "res://%s" % path


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and not value is bool


## JSON parses every number as a float, so a declared node count arrives as 12.0.
static func _is_whole_number(value: Variant) -> bool:
	if not _is_number(value):
		return false
	var numeric := float(value)
	return is_finite(numeric) and is_equal_approx(numeric, floorf(numeric))
