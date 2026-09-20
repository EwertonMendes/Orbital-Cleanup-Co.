extends NinePatchRect
class_name OccPanelFrame

enum Variant {
	GLASS,
	METAL,
}

const GLASS_TEXTURE := preload("res://assets/third_party/kenney_ui_sci_fi/ui/panel_glass_notches.png")
const METAL_TEXTURE := preload("res://assets/third_party/kenney_ui_sci_fi/ui/panel_rectangle_screws.png")

@export var variant: Variant = Variant.GLASS:
	set(value):
		variant = value
		_apply_variant()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_variant()

func _apply_variant() -> void:
	texture = GLASS_TEXTURE if variant == Variant.GLASS else METAL_TEXTURE
