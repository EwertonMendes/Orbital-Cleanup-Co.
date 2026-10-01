extends AnimatableBody2D
class_name SectorObstacle

@onready var sprite: Sprite2D = %Sprite
@onready var marker: SectorObstacleMarker = %Marker

var _definition: Dictionary = {}
var _visual_scale := 1.0
var _spin_speed := 0.0
var _motion_phase := 0.0
var _registry := ContentRegistry.new()

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

	var texture_scale := 1.0
	var reference_size := float(_definition.get("texture_reference_size", 0.0))
	if reference_size > 0.0:
		var max_texture_size := maxf(float(sprite.texture.get_width()), float(sprite.texture.get_height()))
		texture_scale = reference_size / maxf(max_texture_size, 1.0)
	sprite.scale = Vector2.ONE * _visual_scale * texture_scale

	var tint_text := String(_definition.get("sprite_modulate", "#949ea8f5"))
	sprite.modulate = Color.from_string(tint_text, Color(0.58, 0.62, 0.66, 0.96))

	var profile := _registry.get_collision_profile(String(_definition["id"]))
	var collision_radius := CollisionGeometry2D.build_profile(
		self,
		profile,
		sprite.texture,
		sprite.scale
	)
	marker.configure(collision_radius)

func _physics_process(delta: float) -> void:
	_motion_phase = fmod(_motion_phase + delta, TAU * 100.0)
	# AnimatableBody2D owns the authored spin so the rendered silhouette and
	# polygon collision rotate as one physical object.
	rotation = wrapf(rotation + _spin_speed * delta, -PI, PI)

	# Tiny presentation drift remains cosmetic; it never changes navigable space.
	sprite.position = Vector2(
		cos(_motion_phase * 0.47),
		sin(_motion_phase * 0.61)
	) * 1.4
