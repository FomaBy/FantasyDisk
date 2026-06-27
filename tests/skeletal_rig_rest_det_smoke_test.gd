extends SceneTree

# SCRUM-510: регресс-гард на нулевой рендер-спам скелетного рига (det==0 / bone-length).
#
# До SCRUM-509 (коммит 205fe13e) кости скелета (dark_mage/knight) собирались с нулевой
# length/углом → Skeleton2D строил вырожденный bone-rest (determinant == 0) при ригинге
# спрайтов, заваливая консоль ~360×`ERROR det==0` + bone-length WARNING. Smoke проходил
# зелёным несмотря на спам — ассертов на рендер не было. Этот тест ловит регрессию: он
# строит риг для dark_mage и knight, обходит все Bone2D и требует НЕнулевой детерминант
# rest/global-трансформа каждой кости (т.е. кость не вырождена в точку/линию), length
# >= MIN_BONE_LENGTH и мету `rest_det_safe`, которую проставляет фикс `_finalize_bone_setup`.
#
# Изолированный `extends SceneTree` (по образцу sliced_rig_manifest_smoke_test.gd): НЕ грузит
# Main.tscn и НЕ читает реальный dev мета-сейв (unlocks/death_save) → детерминирован, без
# ложных red'ов. Авто-подхватывается tools/run_focused_tests.sh по `^extends SceneTree`.
#
# Запуск: Godot --headless --path . --script res://tests/skeletal_rig_rest_det_smoke_test.gd

const RigScript := preload("res://scripts/skeleton_player_rig_2d.gd")
const DarkMageRigScene := preload("res://scenes/characters/DarkMageSkeletonRig.tscn")
const KnightRigScene := preload("res://scenes/characters/KnightSkeletonRig.tscn")

const DET_EPS := 0.0001
const MIN_BONES_PER_RIG := 8


func _initialize() -> void:
	var errors: Array = []
	var total_bones := 0

	var rigs := {
		"dark_mage": DarkMageRigScene,
		"knight": KnightRigScene,
	}

	for entity_id in rigs:
		var eid := str(entity_id)
		var rig: Node2D = rigs[entity_id].instantiate()
		root.add_child(rig)
		# Риг строится в _ready()/configure() — даём кадр, чтобы дерево/Skeleton2D собрались.
		await process_frame
		await process_frame

		var skeleton := rig.find_child("Skeleton2D", true, false)
		if skeleton == null:
			errors.append("риг '%s': нет Skeleton2D под ригом" % eid)
			rig.queue_free()
			continue

		var bones := skeleton.find_children("*", "Bone2D", true, false)
		if bones.size() < MIN_BONES_PER_RIG:
			errors.append("риг '%s': найдено %d Bone2D (< %d) — гард прошёл бы вакуумно" % [
				eid, bones.size(), MIN_BONES_PER_RIG])

		for bone in bones:
			total_bones += 1
			var bname := str(bone.name)

			# Главный сигнал: rest-трансформ (то, что set_rest() записал в _finalize_bone_setup)
			# и фактический рендер-трансформ кости после ригинга Skeleton2D — оба невырождены.
			var rest_det: float = bone.get_rest().determinant()
			if absf(rest_det) < DET_EPS:
				errors.append("риг '%s'/кость '%s': вырожденный rest (det=%.6f)" % [eid, bname, rest_det])
			var global_det: float = bone.get_global_transform().determinant()
			if absf(global_det) < DET_EPS:
				errors.append("риг '%s'/кость '%s': вырожденный global-трансформ (det=%.6f)" % [eid, bname, global_det])

			# Вторичный сигнал ближе к корню: именно нулевая length рождала вырожденный rest.
			var length: float = bone.get_length()
			if length < RigScript.MIN_BONE_LENGTH - DET_EPS:
				errors.append("риг '%s'/кость '%s': length %.3f < MIN_BONE_LENGTH %.1f" % [
					eid, bname, length, RigScript.MIN_BONE_LENGTH])

			# Привязка к источнику фикса: _finalize_bone_setup помечает каждую кость.
			if not bone.get_meta("rest_det_safe", false):
				errors.append("риг '%s'/кость '%s': нет меты rest_det_safe (фикс не отработал)" % [eid, bname])

		rig.queue_free()

	if total_bones < MIN_BONES_PER_RIG * rigs.size():
		errors.append("суммарно обойдено %d костей (< %d) — гард вакуумный" % [
			total_bones, MIN_BONES_PER_RIG * rigs.size()])

	if not errors.is_empty():
		for e in errors:
			push_error("Skeletal rig rest-det smoke: %s" % e)
		push_error("Skeletal rig rest-det smoke test: %d ошибок." % errors.size())
		quit(1)
		return
	print("Skeletal rig rest-det smoke passed (%d bones, %d rigs)." % [total_bones, rigs.size()])
	quit(0)
