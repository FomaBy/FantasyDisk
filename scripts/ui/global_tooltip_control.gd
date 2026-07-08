extends Control

const GlobalTooltip := preload("res://scripts/ui/global_tooltip.gd")


# SCRUM-890: контент тултипа — титул золотом + тело светлым; позиция попапа —
# 16px от курсора с клампом в вьюпорт (GlobalTooltip.reposition_tooltip_popup).
func _make_custom_tooltip(for_text: String) -> Object:
	return GlobalTooltip.make_tooltip_content(for_text, self)
