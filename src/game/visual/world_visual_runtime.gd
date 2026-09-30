extends Node
class_name WorldVisualRuntime

var _post_process: WorldPostProcess
var _environment_vfx: EnvironmentalVfxLayer
var _space_environment: SpaceEnvironmentLayer
var _environment_runtime: EnvironmentRuntime

func configure(
	play_bounds: Rect2,
	palette: Dictionary,
	visual_profile: Dictionary,
	post_process: WorldPostProcess,
	environment_vfx: EnvironmentalVfxLayer,
	space_environment: SpaceEnvironmentLayer
) -> void:
	assert(post_process != null, "WorldVisualRuntime requires WorldPostProcess.")
	assert(environment_vfx != null, "WorldVisualRuntime requires EnvironmentalVfxLayer.")
	assert(space_environment != null, "WorldVisualRuntime requires SpaceEnvironmentLayer.")
	_post_process = post_process
	_environment_vfx = environment_vfx
	_space_environment = space_environment

	_post_process.configure(palette, visual_profile)
	_environment_vfx.configure(play_bounds, palette, visual_profile)
	_space_environment.configure(play_bounds, palette, visual_profile)
	print(
		"[Visual] READY profile=%s intensity=%.2f quality=%s screen_post=%s"
		% [
			WorldVisualLanguage.environment_effect_profile(visual_profile),
			WorldVisualLanguage.environment_effect_intensity(visual_profile),
			RuntimeQuality.visual_effects_level_name(),
			str(RuntimeQuality.use_screen_texture_post_process()),
		]
	)

func bind(environment_runtime: EnvironmentRuntime) -> void:
	assert(environment_runtime != null, "WorldVisualRuntime requires EnvironmentRuntime.")
	if _environment_runtime != null and is_instance_valid(_environment_runtime):
		if _environment_runtime.environment_visual_state_changed.is_connected(_on_environment_visual_state_changed):
			_environment_runtime.environment_visual_state_changed.disconnect(_on_environment_visual_state_changed)

	_environment_runtime = environment_runtime
	if not _environment_runtime.environment_visual_state_changed.is_connected(_on_environment_visual_state_changed):
		_environment_runtime.environment_visual_state_changed.connect(_on_environment_visual_state_changed)

func _on_environment_visual_state_changed(
	visibility: float,
	environment_color: Color,
	distortion: float,
	label_key: String,
	intensity: float
) -> void:
	if _post_process != null:
		_post_process.set_environment_state(visibility, environment_color, distortion)
	if _environment_vfx != null:
		_environment_vfx.set_environment_state(label_key, intensity, environment_color, distortion)
