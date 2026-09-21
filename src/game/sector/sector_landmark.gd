extends StaticBody2D
class_name SectorLandmark

@onready var sprite: Sprite2D = %Sprite
@onready var marker: SectorLandmarkMarker = %Marker
@onready var collision_shape: CollisionShape2D = %CollisionShape

var _definition: Dictionary = {}
var _spin_speed := 0.0
var _motion_phase := 0.0
var _visual_rotation := 0.0

func configure(definition: Dictionary, spin_speed: float = 0.0, motion_phase: float = 0.0) -> void:
	assert(not definition.is_empty(), "SectorLandmark requires definition.")
	_definition = definition.duplicate(true)
	_spin_speed = spin_speed
	_motion_phase = motion_phase

func _ready() -> void:
	assert(not _definition.is_empty(), "SectorLandmark must be configured before entering the tree.")
	add_to_group("landmark")
	add_to_group("structure")
	var texture_path := String(_definition["sprite"])
	sprite.texture = load(texture_path) as Texture2D
	assert(sprite.texture != null, "SectorLandmark texture must load: %s" % texture_path)
	var visual_scale := float(_definition.get("scale", 1.0))
	sprite.scale = Vector2.ONE * visual_scale
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)
	_configure_collision()
	var texture_size := sprite.texture.get_size() * visual_scale
	var reserved_radius := float(_definition.get("reserved_radius", 0.0))
	var visual_radius := maxf(texture_size.x, texture_size.y) * 0.34
	marker.configure(minf(maxf(visual_radius, reserved_radius * 0.64), 420.0))

func _configure_collision() -> void:
	var collision := _definition.get("collision", {}) as Dictionary
	assert(not collision.is_empty(), "SectorLandmark requires collision data.")
	match String(collision.get("shape", "")):
		"circle":
			var shape := CircleShape2D.new()
			shape.radius = float(collision["radius"])
			collision_shape.shape = shape
		"box":
			var size_data := collision["size"] as Array
			assert(size_data.size() == 2, "Landmark box collision requires two size values.")
			var shape := RectangleShape2D.new()
			shape.size = Vector2(float(size_data[0]), float(size_data[1]))
			collision_shape.shape = shape
		_:
			assert(false, "Unsupported landmark collision shape.")

func _process(delta: float) -> void:
	_motion_phase = fmod(_motion_phase + delta, TAU * 100.0)
	_visual_rotation = wrapf(_visual_rotation + _spin_speed * delta, -PI, PI)
	var drift := float(_definition.get("drift_amplitude", 0.0))
	var local_offset := Vector2(cos(_motion_phase * 0.23), sin(_motion_phase * 0.31)) * drift
	# Presentation may breathe/drift, but gameplay collision remains anchored to the
	# structure's deterministic world transform. This keeps routing stable and
	# prevents a static landmark from becoming a moving collision target.
	sprite.rotation = _visual_rotation
	sprite.position = local_offset
