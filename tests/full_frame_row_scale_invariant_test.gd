extends SceneTree

# FAN-2914: full-frame builders must use one scale for every source frame in
# a rendered animation row. The old reports remain the negative control until
# a rebuilt runtime pack publishes its replacement report.

const PACKS := [
	{"id": "rift_cutter", "runtime": "res://assets/sprites/enemies/full_frame/rift_cutter", "source_report": ""},
	{"id": "ash_marksman", "runtime": "res://assets/sprites/enemies/full_frame/ash_marksman_8dir", "source_report": "res://assets/sprites/enemies/pixellab/ash_marksman/alpha_bbox_report.json"},
	{"id": "spark_runner", "runtime": "res://assets/sprites/enemies/full_frame/spark_runner_8dir", "source_report": "res://assets/sprites/enemies/pixellab/spark_runner/alpha_bbox_report.json"},
	{"id": "stone_bruiser", "runtime": "res://assets/sprites/enemies/full_frame/stone_bruiser_8dir", "source_report": "res://assets/sprites/enemies/pixellab/stone_bruiser/alpha_bbox_report.json"},
	{"id": "bone_caller", "runtime": "res://assets/sprites/enemies/full_frame/bone_caller", "source_report": "res://assets/sprites/enemies/pixellab/bone_caller/alpha_bbox_report.json"},
	{"id": "void_mage", "runtime": "res://assets/sprites/enemies/full_frame/void_mage_8dir", "source_report": "res://assets/sprites/enemies/pixellab/void_mage/alpha_bbox_report.json"},
	{"id": "venom_spitter", "runtime": "res://assets/sprites/enemies/full_frame/venom_spitter_8dir", "source_report": "res://assets/sprites/enemies/pixellab/venom_spitter/alpha_bbox_report.json"},
	{"id": "rift_shieldbearer", "runtime": "res://assets/sprites/enemies/full_frame/rift_shieldbearer_8dir", "source_report": "res://assets/sprites/enemies/pixellab/rift_shieldbearer/alpha_bbox_report.json"},
	{"id": "small_biter", "runtime": "res://assets/sprites/enemies/full_frame/small_biter", "source_report": "res://assets/sprites/enemies/pixellab/small_biter/alpha_bbox_report.json"},
	{"id": "bone_shaman", "runtime": "res://assets/sprites/enemies/full_frame/bone_shaman", "source_report": "res://assets/sprites/enemies/pixellab/bone_shaman/alpha_bbox_report.json"},
	{"id": "winged_spark", "runtime": "res://assets/sprites/enemies/full_frame/winged_spark", "source_report": "res://assets/sprites/enemies/pixellab/winged_spark/alpha_bbox_report.json"},
	{"id": "plague_prophet", "runtime": "res://assets/sprites/elites/full_frame/plague_prophet", "source_report": "res://assets/sprites/elites/pixellab/plague_prophet/alpha_bbox_report.json"},
	{"id": "mini_rot_hound", "runtime": "res://assets/sprites/elites/full_frame/mini_rot_hound", "source_report": "res://assets/sprites/elites/pixellab/mini_rot_hound/alpha_bbox_report.json"},
	{"id": "disk_devourer", "runtime": "res://assets/sprites/bosses/disk_devourer_8dir/runtime", "source_report": "res://assets/sprites/bosses/disk_devourer_8dir/pixellab_source/alpha_bbox_report.json"},
	{"id": "homunculus_tank", "runtime": "res://assets/sprites/allies/homunculus_tank/runtime", "source_report": "res://assets/sprites/allies/homunculus_tank/pixellab_source/alpha_bbox_report.json"},
	{"id": "iron_bastion", "runtime": "res://assets/sprites/elites/full_frame/iron_bastion", "source_report": "res://assets/sprites/elites/pixellab/iron_bastion/alpha_bbox_report.json"},
]
const REPORT_NAME := "row_scale_report.json"
const SCALE_TOLERANCE := 0.000001
const EXPECTED_SIZE := Vector2i(512, 512)
const EXPECTED_ALPHA_BOTTOM := 480


func _initialize() -> void:
	var errors: Array[String] = []
	for pack_variant in PACKS:
		var pack := pack_variant as Dictionary
		_check_pack(pack, errors)
	if not errors.is_empty():
		for error in errors:
			push_error("FAN-2914 row-scale invariant: %s" % error)
		quit(1)
		return
	print("FAN-2914 row-scale invariant passed for %d rebuilt registry packs." % PACKS.size())
	quit(0)


func _check_pack(pack: Dictionary, errors: Array[String]) -> void:
	var pack_id := str(pack["id"])
	var runtime_dir := str(pack["runtime"])
	var report_path := runtime_dir.path_join(REPORT_NAME)
	var report := _load_report(report_path)
	if report.is_empty():
		var old_report_path := str(pack["source_report"])
		if old_report_path.is_empty():
			errors.append("%s: missing rebuilt report %s." % [pack_id, report_path])
			return
		report = _load_report(old_report_path)
		if report.is_empty():
			errors.append("%s: missing rebuilt report %s and legacy negative-control report %s." % [pack_id, report_path, old_report_path])
			return
		print("%s: using legacy report as the old-math negative control." % pack_id)
	for row_name_variant in report.keys():
		var row_name := str(row_name_variant)
		var frames := report[row_name] as Array
		if frames.is_empty():
			errors.append("%s/%s: row report is empty." % [pack_id, row_name])
			continue
		var row_scale := -1.0
		for frame_variant in frames:
			if not (frame_variant is Dictionary):
				errors.append("%s/%s: malformed frame report." % [pack_id, row_name])
				continue
			var frame := frame_variant as Dictionary
			var scale := float(frame.get("scale", -1.0))
			if scale <= 0.0:
				errors.append("%s/%s: missing positive scale." % [pack_id, row_name])
				continue
			if row_scale < 0.0:
				row_scale = scale
			elif absf(scale - row_scale) > SCALE_TOLERANCE:
				errors.append("%s/%s: per-frame scale %.6f differs from row scale %.6f." % [pack_id, row_name, scale, row_scale])
			_check_runtime_frame(pack_id, runtime_dir.path_join(str(frame.get("runtime", ""))), errors)


func _load_report(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _check_runtime_frame(pack_id: String, path: String, errors: Array[String]) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		errors.append("%s: missing runtime frame %s." % [pack_id, path])
		return
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		errors.append("%s: cannot decode runtime frame %s." % [pack_id, path])
		return
	if image.get_size() != EXPECTED_SIZE:
		errors.append("%s: %s is %s, expected %s." % [pack_id, path, image.get_size(), EXPECTED_SIZE])
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		errors.append("%s: %s is not RGBA8." % [pack_id, path])
		return
	var bbox := image.get_used_rect()
	if bbox.size == Vector2i.ZERO:
		errors.append("%s: %s has no alpha bbox." % [pack_id, path])
	elif bbox.end.y != EXPECTED_ALPHA_BOTTOM:
		errors.append("%s: %s alpha bottom %d, expected %d." % [pack_id, path, bbox.end.y, EXPECTED_ALPHA_BOTTOM])
