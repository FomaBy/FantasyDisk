extends "res://tests/runtime_smoke_test.gd"

# FAN-3814 (ADR Фаза 2): балансовый smoke класса doctor.
# Домен владения: class/doctor (docs/process/ownership_map.md).


func _initialize() -> void:
	_check_doctor_identity_modes()
	await _check_doctor_identity()
	_finish("[balance/doctor] PASSED")


func _check_doctor_identity_modes() -> void:
	# SCRUM-900: кит Доктора — три уникальных режима weapon-only sustain
	# (зелье-бросок AoE / чумной дротик со спредом / melee-сектор пилы).
	var doctor_modes := {}
	for doctor_weapon_id in ProgressionData.weapon_ids("doctor"):
		var doctor_mode := str(ProgressionData.weapon("doctor", doctor_weapon_id).get("attack_mode", ""))
		if doctor_modes.has(doctor_mode):
			_fail("Expected Doctor weapons to use three distinct attack modes.")
			return
		doctor_modes[doctor_mode] = true
	for required_doctor_mode in ["aoe_projectile", "plague_dart", "saw_sector"]:
		if not doctor_modes.has(required_doctor_mode):
			_fail("Expected Doctor to include %s attack mode (SCRUM-900 kit)." % required_doctor_mode)
			return


func _check_doctor_identity() -> void:
	var holder := Node2D.new()
	holder.name = "DoctorIdentityScene"
	root.add_child(holder)
	current_scene = holder
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var doctor := player_scene.instantiate()
	holder.add_child(doctor)
	doctor.global_position = Vector2(900, 700)
	await process_frame
	# SCRUM-900: живой sustain-контракт — пила лечит от фактически нанесённого
	# урона (мгновенный melee-сектор; зелье/чума покрыты tests/doctor_kit_test.gd).
	doctor.call("configure_character", "doctor", "bone_saw")
	var doctor_weapon: Node = doctor.get("equipped_weapon")
	doctor_weapon.set_process(false)
	doctor.set("health", float(doctor.get("max_health")) * 0.5)
	doctor.set("_drain_heal_budget", 3.0)
	var doctor_enemy := enemy_scene.instantiate()
	holder.add_child(doctor_enemy)
	doctor_enemy.set("max_health", 100000.0)
	doctor_enemy.set("health", 100000.0)
	doctor_enemy.global_position = doctor.global_position + Vector2(170, 0)
	await process_frame
	var doctor_health_before := float(doctor.get("health"))
	doctor_weapon.call("_attack")
	await process_frame
	if float(doctor.get("health")) <= doctor_health_before:
		_fail("Expected Doctor bone saw sector to heal from dealt damage (weapon-only sustain).")
		return
	holder.queue_free()
	current_scene = null
	await process_frame
