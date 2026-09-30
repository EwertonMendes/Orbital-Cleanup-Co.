extends Node2D
class_name SpaceEnvironmentLayer

const SPACE_SHADER := preload("res://src/game/visual/space_environment.gdshader")
const NOISE_SIZE := 192

var _play_bounds := Rect2(-4800.0, -3000.0, 9600.0, 6000.0)
var _palette: Dictionary = {}
var _visual_profile: Dictionary = {}
var _background_mesh: MeshInstance2D
var _foreground_mesh: MeshInstance2D
var _background_material: ShaderMaterial
var _foreground_material: ShaderMaterial
var _noise_a: ImageTexture
var _noise_b: ImageTexture
var _last_viewport_size := Vector2.ZERO
var _configured := false

func _ready() -> void:
	_ensure_runtime_nodes()
	_ensure_noise_textures()
	_apply_configuration()
	_update_camera_state(true)

func configure(
	play_bounds: Rect2,
	palette: Dictionary,
	visual_profile: Dictionary
) -> void:
	assert(play_bounds.size.x > 0.0 and play_bounds.size.y > 0.0, "SpaceEnvironmentLayer requires valid play bounds.")
	_play_bounds = play_bounds
	_palette = palette.duplicate(true)
	_visual_profile = visual_profile.duplicate(true)
	_configured = true
	if is_node_ready():
		_ensure_runtime_nodes()
		_ensure_noise_textures()
		_apply_configuration()
		_update_camera_state(true)

func _process(_delta: float) -> void:
	_update_camera_state(false)

func _ensure_runtime_nodes() -> void:
	if _background_mesh == null:
		_background_mesh = MeshInstance2D.new()
		_background_mesh.name = "BackgroundAtmosphere"
		_background_mesh.z_index = 0
		add_child(_background_mesh)

	if _foreground_mesh == null:
		_foreground_mesh = MeshInstance2D.new()
		_foreground_mesh.name = "ForegroundAtmosphere"
		_foreground_mesh.z_as_relative = false
		_foreground_mesh.z_index = 18
		add_child(_foreground_mesh)

	if _background_material == null:
		_background_material = ShaderMaterial.new()
		_background_material.shader = SPACE_SHADER
		_background_mesh.material = _background_material

	if _foreground_material == null:
		_foreground_material = ShaderMaterial.new()
		_foreground_material.shader = SPACE_SHADER
		_foreground_mesh.material = _foreground_material

func _ensure_noise_textures() -> void:
	if _noise_a == null:
		_noise_a = _build_noise_texture(1487, 0.030)
	if _noise_b == null:
		_noise_b = _build_noise_texture(9743, 0.071)

func _build_noise_texture(seed_value: int, frequency: float) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency

	var bytes := PackedByteArray()
	bytes.resize(NOISE_SIZE * NOISE_SIZE)
	for y in range(NOISE_SIZE):
		for x in range(NOISE_SIZE):
			var value := noise.get_noise_2d(float(x), float(y))
			bytes[y * NOISE_SIZE + x] = int(clampf((value + 1.0) * 127.5, 0.0, 255.0))

	var image := Image.create_from_data(
		NOISE_SIZE,
		NOISE_SIZE,
		false,
		Image.FORMAT_L8,
		bytes
	)
	return ImageTexture.create_from_image(image)

func _apply_configuration() -> void:
	if not _configured or _palette.is_empty() or _background_material == null:
		return

	var background := Color.from_string(String(_palette.get("background", "#040b13")), Color("#040b13"))
	var nebula := Color.from_string(String(_palette.get("nebula", "#183b72")), Color("#183b72"))
	var accent := Color.from_string(String(_palette.get("accent", "#55e6ff")), Color("#55e6ff"))
	var profile_mode := WorldVisualLanguage.environment_effect_mode(_visual_profile)
	var intensity := WorldVisualLanguage.environment_effect_intensity(_visual_profile)
	var focal := Vector2(0.5, 0.5)
	var anchor_value := _visual_profile.get("primary_anchor", [0.5, 0.5])
	if anchor_value is Array and (anchor_value as Array).size() >= 2:
		var anchor := anchor_value as Array
		focal = Vector2(float(anchor[0]), float(anchor[1]))

	for material in [_background_material, _foreground_material]:
		material.set_shader_parameter("noise_a", _noise_a)
		material.set_shader_parameter("noise_b", _noise_b)
		material.set_shader_parameter("background_color", background)
		material.set_shader_parameter("nebula_color", nebula)
		material.set_shader_parameter("accent_color", accent)
		material.set_shader_parameter("profile_mode", profile_mode)
		material.set_shader_parameter("intensity", intensity)
		material.set_shader_parameter("quality_factor", RuntimeQuality.visual_effects_factor())
		material.set_shader_parameter("focal_point", focal)

	_background_material.set_shader_parameter("foreground_mix", 0.0)
	_foreground_material.set_shader_parameter("foreground_mix", 1.0)

func _update_camera_state(force_geometry: bool) -> void:
	if _background_mesh == null or _foreground_mesh == null:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return

	global_position = camera.global_position
	var viewport_size := get_viewport_rect().size
	var zoom := Vector2(
		maxf(absf(camera.zoom.x), 0.01),
		maxf(absf(camera.zoom.y), 0.01)
	)
	var visible_world_size := Vector2(
		viewport_size.x / zoom.x,
		viewport_size.y / zoom.y
	)
	if force_geometry or not viewport_size.is_equal_approx(_last_viewport_size):
		_last_viewport_size = viewport_size
		_set_quad_size(_background_mesh, visible_world_size * 1.14)
		_set_quad_size(_foreground_mesh, visible_world_size * 1.14)
		_background_material.set_shader_parameter("viewport_size", viewport_size)
		_foreground_material.set_shader_parameter("viewport_size", viewport_size)

	var bounds_size := Vector2(
		maxf(_play_bounds.size.x, 1.0),
		maxf(_play_bounds.size.y, 1.0)
	)
	var offset := Vector2(
		camera.global_position.x / bounds_size.x,
		camera.global_position.y / bounds_size.y
	)
	_background_material.set_shader_parameter("camera_offset", offset)
	_foreground_material.set_shader_parameter("camera_offset", offset)

func _set_quad_size(instance: MeshInstance2D, size: Vector2) -> void:
	var quad := instance.mesh as QuadMesh
	if quad == null:
		quad = QuadMesh.new()
		instance.mesh = quad
	quad.size = size
