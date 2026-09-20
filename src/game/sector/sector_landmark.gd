extends Node2D
class_name SectorLandmark

@onready var sprite: Sprite2D = %Sprite

var _definition: Dictionary = {}

func configure(definition: Dictionary) -> void:
	assert(not definition.is_empty(), "SectorLandmark requires definition.")
	_definition = definition.duplicate(true)

func _ready() -> void:
	assert(not _definition.is_empty(), "SectorLandmark must be configured before entering the tree.")
	var texture_path := String(_definition["sprite"])
	sprite.texture = load(texture_path) as Texture2D
	assert(sprite.texture != null, "SectorLandmark texture must load: %s" % texture_path)
	var visual_scale := float(_definition.get("scale", 1.0))
	sprite.scale = Vector2.ONE * visual_scale
	sprite.modulate = Color(0.70, 0.90, 1.0, 0.34)
