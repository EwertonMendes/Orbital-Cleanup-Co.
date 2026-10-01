extends AnimatableBody2D
class_name SectorLandmark

@onready var sprite: Sprite2D = %Sprite
@onready var marker: SectorLandmarkMarker = %Marker

var _definition: Dictionary = {}
var _spin_speed := 0.0
var _motion_phase := 0.0
var _base_position := Vector2.ZERO
var _registry := ContentRegistry.new()

func configure(definition: Dictionary, spin_speed: float = 0.0, motion_phase: float = 0.0) -> void:
	assert(not definition.is_empty(), "SectorLandmark requires definition.")
	_definition = definition.duplicate(true)
	_spin_speed = spin_speed
	_motion_phase = motion_phase

func _ready() -> void:
	_base_position = position
	assert(not _definition.is_empty(), "SectorLandmark must be configured before entering the tree.")
	add_to_group("landmark")
	add_to_group("structure")
	var texture_path := String(_definition["sprite"])
	sprite.texture = load(texture_path) as Texture2D
	assert(sprite.texture != null, "SectorLandmark texture must load: %s" % texture_path)

	var visual_scale := float(_definition.get("scale", 1.0))
	var texture_scale := 1.0
	var reference_size := float(_definition.get("texture_reference_size", 0.0))
	if reference_size > 0.0:
		var max_texture_size := maxf(float(sprite.texture.get_width()), float(sprite.texture.get_height()))
		texture_scale = reference_size / maxf(max_texture_size, 1.0)
	sprite.scale = Vector2.ONE * visual_scale * texture_scale
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)

	var collision_radius := CollisionGeometry2D.build_static_boundary(
		self,
		sprite
	)
	var reserved_radius := float(_definition.get("reserved_radius", 0.0))
	marker.configure(minf(maxf(collision_radius, reserved_radius * 0.64), 420.0))

func get_landmark_id() -> String:
	return String(_definition.get("id", ""))

func get_reserved_radius() -> float:
	return float(_definition.get("reserved_radius", 0.0))

func _physics_process(delta: float) -> void:
	_motion_phase = fmod(_motion_phase + delta, TAU * 100.0)
	# Structural spin belongs to the AnimatableBody2D so the polygon collision
	# cannot drift out of alignment with dishes, panels, hulls or station arms.
	rotation = wrapf(rotation + _spin_speed * delta, -PI, PI)

	var drift := float(_definition.get("drift_amplitude", 0.0))
	# Landmark drift belongs to the physics body. Keeping it on Sprite2D alone
	# would make the visible alpha and collision diverge.
	position = _base_position + Vector2(cos(_motion_phase * 0.23), sin(_motion_phase * 0.31)) * drift
	sprite.position = Vector2.ZERO
