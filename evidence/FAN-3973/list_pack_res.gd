extends SceneTree

# FAN-3973: authoritative listing of an exported pack from inside Godot.
#
#   Godot --headless --main-pack <file.pck> --script <abs path to this file> -- <out.txt>
#
# Walks `res://` (hidden `.godot/` included) through DirAccess, which is backed
# by the PackedData tree when a main pack is mounted, and writes one
# "<size>\t<path>" line per file to the output path given after `--`.
# Then prints the file count, total bytes, a per-top-level summary and every
# path under a non-game location the 0.3.1 Setup shipped by mistake.

const FORBIDDEN_PREFIXES := [
	"res://evidence/", "res://skills/", "res://docs/", "res://tools/", "res://tests/",
	"res://references/", "res://source_docs/", "res://build/", "res://releases/",
]
const FORBIDDEN_FILES := [
	"res://before_berserk_648p.png", "res://before_berserk_648p.png.import",
	"res://after_berserk_648p.png", "res://after_berserk_648p.png.import",
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var entries: Array = []
	_walk("res://", entries)
	entries.sort_custom(func(a, b): return str(a[1]) < str(b[1]))
	if not args.is_empty():
		var out := FileAccess.open(str(args[0]), FileAccess.WRITE)
		if out == null:
			push_error("cannot write %s" % args[0])
		else:
			for entry in entries:
				out.store_line("%d\t%s" % [int(entry[0]), str(entry[1])])
			out.close()
	var total := 0
	var by_top := {}
	var by_top_bytes := {}
	var forbidden: Array = []
	var root_files: Array = []
	for entry in entries:
		var size := int(entry[0])
		var path := str(entry[1])
		total += size
		var rel := path.trim_prefix("res://")
		var top := rel.get_slice("/", 0) if rel.contains("/") else "<root>"
		by_top[top] = int(by_top.get(top, 0)) + 1
		by_top_bytes[top] = int(by_top_bytes.get(top, 0)) + size
		if not rel.contains("/"):
			root_files.append(path)
		for prefix in FORBIDDEN_PREFIXES:
			if path.begins_with(prefix):
				forbidden.append(path)
		if FORBIDDEN_FILES.has(path):
			forbidden.append(path)
	print("files: %d, payload: %d bytes (%.1f MiB)" % [entries.size(), total, float(total) / 1048576.0])
	print("| top-level | files | bytes |")
	print("|---|---|---|")
	var tops := by_top.keys()
	tops.sort_custom(func(a, b): return int(by_top_bytes[a]) > int(by_top_bytes[b]))
	for top in tops:
		print("| %s | %d | %d |" % [top, int(by_top[top]), int(by_top_bytes[top])])
	print("root files: %s" % ", ".join(root_files))
	print("forbidden paths present: %d" % forbidden.size())
	for path in forbidden.slice(0, 20):
		print("  FORBIDDEN %s" % path)
	quit(1 if not forbidden.is_empty() else 0)


func _walk(directory_path: String, entries: Array) -> void:
	var dir := DirAccess.open(directory_path)
	if dir == null:
		push_error("cannot open %s" % directory_path)
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var path := directory_path.path_join(name)
		if dir.current_is_dir():
			_walk(path, entries)
		else:
			var size := 0
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				size = file.get_length()
				file.close()
			entries.append([size, path])
		name = dir.get_next()
	dir.list_dir_end()
