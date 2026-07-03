extends Control

const GlobalTooltip := preload("res://scripts/ui/global_tooltip.gd")


func _make_custom_tooltip(for_text: String) -> Object:
	return GlobalTooltip.make_text_panel(for_text, GlobalTooltip.make_minimal_metal_style())
