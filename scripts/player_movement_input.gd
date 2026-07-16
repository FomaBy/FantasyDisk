extends RefCounted

## FAN-1107: neutral-rearm support for Player movement. This deliberately
## measures action activity before opposing directions are subtracted.


static func all_actions_neutral(deadzone: float) -> bool:
	# A zero resultant vector is not neutral when opposing physical inputs remain
	# held. Preserve Input.get_vector's circular deadzone while retaining the
	# strongest raw contributor on each axis before left/right or up/down cancel.
	var uncancelled_activity := Vector2(
		maxf(
			Input.get_action_raw_strength(&"move_left"),
			Input.get_action_raw_strength(&"move_right")
		),
		maxf(
			Input.get_action_raw_strength(&"move_up"),
			Input.get_action_raw_strength(&"move_down")
		)
	)
	return uncancelled_activity.length_squared() <= deadzone * deadzone
