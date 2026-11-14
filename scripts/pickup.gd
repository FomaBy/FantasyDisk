extends Node2D

const MONEY_TEXTURE := preload("res://assets/sprites/ui/hud/hud_money.png")
const XP_TEXTURE := preload("res://assets/sprites/ui/hud/hud_xp.png")

var pickup_type := "xp"
## Total raw (pre-multiplier) value carried by this node.
var amount := 1
## FAN-4003: raw drop amount -> number of drops merged into this node. The run
## multiplier rounds per drop (at least 1 each), so collection grants every
## merged drop separately and the total equals the unmerged drops exactly.
var drops := {}


func _ready() -> void:
	add_to_group("pickups")
	_update_visual()


func setup(new_pickup_type: String, new_amount: int) -> void:
	pickup_type = new_pickup_type
	amount = new_amount
	drops = {new_amount: 1}
	_update_visual()


## FAN-4003: fold one more same-type drop into this node.
func absorb_drop(drop_amount: int) -> void:
	if drops.is_empty():
		drops = {amount: 1}
	drops[drop_amount] = int(drops.get(drop_amount, 0)) + 1
	amount += drop_amount


## Raw drop amount -> count; a node configured without setup() is one drop.
func drop_counts() -> Dictionary:
	return drops if not drops.is_empty() else {amount: 1}


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
