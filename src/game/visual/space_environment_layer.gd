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
static var _shared_noise_a: NoiseTexture2D
static var _shared_noise_b: NoiseTexture2D

var _noise_a: Texture2D
var _noise_b: Texture2D
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
	if _shared_noise_a == null:
		_shared_noise_a = _build_noise_texture(1487, 0.030)
	if _shared_noise_b == null:
		_shared_noise_b = _build_noise_texture(9743, 0.071)
	_noise_a = _shared_noise_a
	_noise_b = _shared_noise_b

func _build_noise_texture(seed_value: int, frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency

	var texture := NoiseTexture2D.new()
	texture.width = NOISE_SIZE
	texture.height = NOISE_SIZE
	texture.noise = noise
	texture.normalize = true
	texture.seamless = true
	texture.seamless_blend_skirt = 0.18
	texture.generate_mipmaps = false
	return texture

func _apply_configuration() -> void:
	if not _configured or _palette.is_empty() or _background_material == null:
		return

	var background := Color.from_string(String(_palette.get("background", "#040b13")), Color("#040b13"))
	var nebula := Color.from_string(String(_palette.get("nebula", "#183b72")), Color("#183b72"))
	var accent := Color.from_string(String(_palette.get("accent", "#55e6ff")), Color("#55e6ff"))
	var profile_mode := WorldVisualLanguage.environment_space_mode(_visual_profile)
	var intensity := WorldVisualLanguage.environment_effect_intensity(_visual_profile)
	var focal := Vector2(0.5, 0.5)
	var anchor_value: Variant = _visual_profile.get("primary_anchor", [0.5, 0.5])
	if anchor_value is Array and (anchor_value as Array).size() >= 2:
		var anchor: Array = anchor_value as Array
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
