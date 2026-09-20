extends NinePatchRect
class_name OccPanelFrame

enum Variant {
	GLASS,
	METAL,
	GLASS_TAB,
}

const GLASS_TEXTURE := preload("res://assets/third_party/kenney_ui_sci_fi/ui/panel_glass_notches.png")
const METAL_TEXTURE := preload("res://assets/third_party/kenney_ui_sci_fi/ui/panel_rectangle_screws.png")
const GLASS_TAB_TEXTURE := preload("res://assets/third_party/kenney_ui_sci_fi/ui/panel_glass_tab_blade.png")

@export var variant: Variant = Variant.GLASS:
	set(value):
		variant = value
		_apply_variant()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_variant()

func _apply_variant() -> void:
	match variant:
		Variant.GLASS:
			texture = GLASS_TEXTURE
		Variant.METAL:
			texture = METAL_TEXTURE
		Variant.GLASS_TAB:
			texture = GLASS_TAB_TEXTURE
