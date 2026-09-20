extends StaticBody2D
class_name SectorObstacle

@onready var sprite: Sprite2D = %Sprite
@onready var collision_shape: CollisionShape2D = %CollisionShape

var _definition: Dictionary = {}
var _visual_scale := 1.0

func configure(definition: Dictionary, visual_scale: float) -> void:
	assert(not definition.is_empty(), "SectorObstacle requires definition.")
	_definition = definition.duplicate(true)
	_visual_scale = visual_scale

func _ready() -> void:
	assert(not _definition.is_empty(), "SectorObstacle must be configured before entering the tree.")
	var texture_path := String(_definition["sprite"])
	sprite.texture = load(texture_path) as Texture2D
	assert(sprite.texture != null, "SectorObstacle texture must load: %s" % texture_path)
	sprite.scale = Vector2.ONE * _visual_scale

	var circle := collision_shape.shape as CircleShape2D
	assert(circle != null, "SectorObstacle requires CircleShape2D.")
	circle.radius = float(_definition["collision_radius"]) * _visual_scale
