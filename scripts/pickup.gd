extends Node2D

const MONEY_TEXTURE := preload("res://assets/sprites/ui/hud/hud_money.png")
const XP_TEXTURE := preload("res://assets/sprites/ui/hud/hud_xp.png")

var pickup_type := "xp"
var amount := 1


func _ready() -> void:
	add_to_group("pickups")
	_update_visual()


func setup(new_pickup_type: String, new_amount: int) -> void:
	pickup_type = new_pickup_type
	amount = new_amount
	_update_visual()


func _update_visual() -> void:
	var body := get_node_or_null("Body") as Sprite2D
	if body == null:
		return

	if pickup_type == "money":
		body.texture = MONEY_TEXTURE
		body.modulate = Color(1.0, 0.94, 0.70, 1.0)
	else:
		body.texture = XP_TEXTURE
		body.modulate = Color(0.72, 0.92, 1.0, 1.0)
