extends SceneTree

## SCRUM-791 fairness gate: the secret boss's directional cone/beam damage zones
## must match the orientation of their rotated telegraph PNG. directional_hit is
## the single source of truth for damage geometry and is fed the SAME `dir` that
## rotates the telegraph — this test proves orientation == geometry (a point on
## the attack axis is hit, a point behind / outside the cone arc / outside the
## beam lane / beyond the length is NOT), and that directional_telegraph actually
## rotates a textured sprite to that angle.

const BossScript := preload("res://scripts/boss.gd")
const HazardVfxScript := preload("res://scripts/hazard_vfx.gd")


func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)


func _initialize() -> void:
	await process_frame
	var origin := Vector2(1000.0, 800.0)

	# --- CONE (sector) ---
	var dir := Vector2.RIGHT.rotated(0.7)
	var length := BossScript.SECRET_CONE_LENGTH_PX
	var half_angle: float = BossScript.SECRET_CONE_HALF_ANGLE
	if not BossScript.directional_hit("cone", origin, dir, length, half_angle, origin + dir * 300.0):
		_fail("cone: точка на оси внутри длины должна попадать")
	if BossScript.directional_hit("cone", origin, dir, length, half_angle, origin - dir * 200.0):
		_fail("cone: точка ПОЗАДИ не должна попадать (ориентация телеграфа == зоны)")
	if BossScript.directional_hit("cone", origin, dir, length, half_angle, origin + dir.rotated(half_angle + 0.2) * 300.0):
		_fail("cone: точка ВНЕ раствора не должна попадать")
	if BossScript.directional_hit("cone", origin, dir, length, half_angle, origin + dir * (length + 60.0)):
		_fail("cone: точка ДАЛЬШЕ длины не должна попадать")

	# --- BEAM (lane) ---
	var bdir := Vector2.RIGHT.rotated(-1.2)
	var blen: float = BossScript.SECRET_BEAM_LENGTH_PX * 1.15
	var bhw: float = BossScript.SECRET_BEAM_HALF_WIDTH_PX * 1.15
	var perp := Vector2(-bdir.y, bdir.x)
	if not BossScript.directional_hit("beam", origin, bdir, blen, bhw, origin + bdir * 300.0):
		_fail("beam: точка на оси внутри длины должна попадать")
	if not BossScript.directional_hit("beam", origin, bdir, blen, bhw, origin + bdir * 300.0 + perp * (bhw - 10.0)):
		_fail("beam: точка внутри полуширины должна попадать")
	if BossScript.directional_hit("beam", origin, bdir, blen, bhw, origin + bdir * 300.0 + perp * (bhw + 20.0)):
		_fail("beam: точка ВНЕ полуширины не должна попадать")
	if BossScript.directional_hit("beam", origin, bdir, blen, bhw, origin - bdir * 50.0):
		_fail("beam: точка ПОЗАДИ устья не должна попадать")
	if BossScript.directional_hit("beam", origin, bdir, blen, bhw, origin + bdir * (blen + 60.0)):
		_fail("beam: точка ДАЛЬШЕ длины не должна попадать")

	# --- telegraph rotation + textured sprite ---
	var host := Node2D.new()
	root.add_child(host)
	host.global_position = origin
	var tele := HazardVfxScript.directional_telegraph(
		host, BossScript.SECRET_CONE_TELEGRAPH, BossScript.SECRET_CONE_ANCHOR_PX,
		1.0, dir.angle(), Color(0.8, 0.4, 1.0, 1.0), 0.6)
	if tele == null or not is_instance_valid(tele):
		_fail("directional_telegraph должен вернуть живой узел")
	if not is_equal_approx(tele.rotation, dir.angle()):
		_fail("directional_telegraph должен повернуть телеграф под направление атаки (fairness)")
	var has_tex_sprite := false
	for child in tele.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			has_tex_sprite = true
	if not has_tex_sprite:
		_fail("directional_telegraph должен использовать текстурный спрайт, не голый примитив")

	HazardVfxScript.directional_detonate(tele, Color(0.8, 0.4, 1.0, 1.0))
	await process_frame
	print("Boss directional telegraph/zone fairness gate passed.")
	quit()
