extends StaticBody2D
class_name SectorObstacle

@onready var sprite: Sprite2D = %Sprite
@onready var marker: SectorObstacleMarker = %Marker
@onready var collision_shape: CollisionShape2D = %CollisionShape

var _definition: Dictionary = {}
var _visual_scale := 1.0
var _spin_speed := 0.0
var _motion_phase := 0.0

func configure(definition: Dictionary, visual_scale: float, spin_speed: float = 0.0, motion_phase: float = 0.0) -> void:
	assert(not definition.is_empty(), "SectorObstacle requires definition.")
	_definition = definition.duplicate(true)
	_visual_scale = visual_scale
	_spin_speed = spin_speed
	_motion_phase = motion_phase

func _ready() -> void:
	assert(not _definition.is_empty(), "SectorObstacle must be configured before entering the tree.")
	add_to_group("hazard")
	var texture_path := String(_definition["sprite"])
	sprite.texture = load(texture_path) as Texture2D
	assert(sprite.texture != null, "SectorObstacle texture must load: %s" % texture_path)
	sprite.scale = Vector2.ONE * _visual_scale
	sprite.modulate = Color(0.58, 0.62, 0.66, 0.96)

	var circle := collision_shape.shape as CircleShape2D
	assert(circle != null, "SectorObstacle requires CircleShape2D.")
	circle.radius = float(_definition["collision_radius"]) * _visual_scale
	marker.configure(circle.radius)

func _process(delta: float) -> void:
	_motion_phase = fmod(_motion_phase + delta, TAU * 100.0)
	sprite.rotation = wrapf(sprite.rotation + _spin_speed * delta, -PI, PI)
	sprite.position = Vector2(
		cos(_motion_phase * 0.47),
		sin(_motion_phase * 0.61)
	) * 1.4
