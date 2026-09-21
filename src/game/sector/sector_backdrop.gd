extends Node2D
class_name SectorBackdrop

const BACKGROUND_EXTENT := 18000.0
const STAR_EXTENT := 11500.0

var _play_bounds := Rect2(-4800.0, -3000.0, 9600.0, 6000.0)
var _background_color := Color("#040b13")
var _nebula_color := Color("#0b3d4d")
var _accent_color := Color("#53d7f1")
var _biome_id := ""
var _visual_profile: Dictionary = {}
var _star_field: MultiMeshInstance2D
var _primary_visual: Sprite2D
var _primary_material: ShaderMaterial
var _camera_origin := Vector2.ZERO
var _camera_origin_set := false
var _primary_rotation_speed := 0.0

func configure(
	play_bounds: Rect2,
	palette: Dictionary,
	biome_id: String = "",
	visual_profile: Dictionary = {}
) -> void:
	assert(play_bounds.size.x > 0.0 and play_bounds.size.y > 0.0, "SectorBackdrop requires valid bounds.")
	_play_bounds = play_bounds
	_background_color = Color(String(palette.get("background", "#040b13")))
	_nebula_color = Color(String(palette.get("nebula", "#0b3d4d")))
	_accent_color = Color(String(palette.get("accent", "#53d7f1")))
	_biome_id = biome_id
	_visual_profile = visual_profile.duplicate(true)
	RenderingServer.set_default_clear_color(_background_color)
	if is_inside_tree():
		_rebuild_primary_visual()
	queue_redraw()

func _ready() -> void:
	_build_star_multimesh()
	_rebuild_primary_visual()
	queue_redraw()

func _process(delta: float) -> void:
	_update_primary_parallax()
	if _primary_visual != null and is_instance_valid(_primary_visual):
		_primary_visual.rotation = wrapf(
			_primary_visual.rotation + _primary_rotation_speed * delta,
			-PI,
			PI
		)

func _draw() -> void:
	draw_rect(
		Rect2(-BACKGROUND_EXTENT, -BACKGROUND_EXTENT, BACKGROUND_EXTENT * 2.0, BACKGROUND_EXTENT * 2.0),
		_background_color
	)

	_draw_soft_cloud(Vector2(0, 80), 2650.0, _nebula_color, 0.16)
	_draw_soft_cloud(Vector2(3000, -1900), 1850.0, _nebula_color, 0.085)
	_draw_soft_cloud(Vector2(-3400, 2100), 2050.0, _nebula_color, 0.075)
	_draw_biome_horizon()

	draw_arc(Vector2(1150, -650), 1100.0, deg_to_rad(192.0), deg_to_rad(342.0), 96, Color(_accent_color, 0.16), 2.0, true)
	draw_arc(Vector2(-1800, 1300), 920.0, deg_to_rad(8.0), deg_to_rad(176.0), 84, Color(_accent_color, 0.09), 1.5, true)
	draw_arc(Vector2(450, 260), 3200.0, deg_to_rad(208.0), deg_to_rad(304.0), 120, Color(_accent_color, 0.045), 1.0, true)
	_draw_glint(Vector2(2200, 980), 10.0, Color(_accent_color, 0.5))
	_draw_glint(Vector2(-2850, -1250), 7.0, Color(1.0, 0.82, 0.5, 0.42))
	_draw_perimeter()

func _build_star_multimesh() -> void:
	if _star_field != null and is_instance_valid(_star_field):
		_star_field.queue_free()

	var texture := load("res://assets/third_party/kenney_simple_space/scenery/star_small.png") as Texture2D
	assert(texture != null, "SectorBackdrop requires the curated star texture.")

	var star_count := RuntimeQuality.star_count()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.instance_count = star_count

	var rng := RandomNumberGenerator.new()
	rng.seed = 31051999
	for index in range(star_count):
		var bright := rng.randf() > 0.82
		var position := Vector2(
			rng.randf_range(-STAR_EXTENT, STAR_EXTENT),
			rng.randf_range(-STAR_EXTENT, STAR_EXTENT)
		)
		var scale_value := rng.randf_range(0.020, 0.045) if not bright else rng.randf_range(0.040, 0.075)
		var transform := Transform2D(
			rng.randf_range(-PI, PI),
			Vector2.ONE * scale_value,
			0.0,
			position
		)
		multimesh.set_instance_transform_2d(index, transform)
		var alpha := rng.randf_range(0.12, 0.42) if not bright else rng.randf_range(0.48, 0.82)
		var color := Color(1.0, 0.86, 0.55, alpha) if bright and rng.randf() > 0.82 else Color(0.66, 0.90, 1.0, alpha)
		multimesh.set_instance_color(index, color)

	_star_field = MultiMeshInstance2D.new()
	_star_field.multimesh = multimesh
	_star_field.texture = texture
	_star_field.z_index = -2
	add_child(_star_field)

func _draw_biome_horizon() -> void:
	var style := String(_visual_profile.get("horizon_style", "clear"))
	var intensity := clampf(float(_visual_profile.get("horizon_intensity", 0.6)), 0.0, 1.0)
	match style:
		"orbit":
			_draw_soft_cloud(Vector2(1200.0, 820.0), 1750.0, _accent_color, 0.08 * intensity)
			draw_arc(Vector2(-900.0, 420.0), 1500.0, 3.3, 5.7, 90, Color(_accent_color, 0.06 * intensity), 1.2, true)
		"rings":
			for index in range(5):
				var radius := 680.0 + index * 260.0
				draw_arc(Vector2(-1200.0, 500.0), radius, 3.5, 5.6, 72, Color(_accent_color, (0.02 + index * 0.004) * intensity), 1.0, true)
		"dust":
			_draw_soft_cloud(Vector2(1300.0, 760.0), 2100.0, _nebula_color, 0.14 * intensity)
			for index in range(5):
				var y := -1200.0 + index * 620.0
				draw_line(Vector2(-5200.0, y), Vector2(5200.0, y + 520.0), Color(_accent_color, 0.03 * intensity), 18.0, true)
		"nebula":
			_draw_soft_cloud(Vector2(520.0, -180.0), 1550.0, _accent_color, 0.24 * intensity)
			_draw_soft_cloud(Vector2(-820.0, 580.0), 1250.0, _nebula_color, 0.16 * intensity)
			_draw_soft_cloud(Vector2(2300.0, -1300.0), 1650.0, _accent_color, 0.09 * intensity)
		"solar":
			_draw_soft_cloud(Vector2(1700.0, 250.0), 1900.0, _accent_color, 0.12 * intensity)
			for index in range(4):
				draw_arc(Vector2(900.0, 120.0), 900.0 + index * 290.0, 2.8, 5.9, 96, Color(_accent_color, 0.045 * intensity), 2.0, true)
		"gas":
			_draw_soft_cloud(Vector2(1500.0, 700.0), 2300.0, _nebula_color, 0.13 * intensity)
			for index in range(4):
				var y := -900.0 + index * 580.0
				draw_line(Vector2(-4400.0, y), Vector2(4500.0, y + 210.0), Color(_accent_color, 0.025 * intensity), 24.0, true)
		"ice":
			_draw_soft_cloud(Vector2(-1300.0, 400.0), 1800.0, _accent_color, 0.09 * intensity)
			for index in range(4):
				draw_arc(Vector2(1000.0, 500.0), 700.0 + index * 310.0, 3.1, 5.4, 72, Color(_accent_color, 0.035 * intensity), 1.5, true)
		"industrial":
			for index in range(7):
				var x := -4200.0 + index * 1400.0
				draw_line(Vector2(x, -2600.0), Vector2(x + 800.0, 2600.0), Color(_accent_color, 0.025 * intensity), 2.0, true)
			_draw_soft_cloud(Vector2(1800.0, -900.0), 1300.0, _nebula_color, 0.08 * intensity)
		"anomaly":
			_draw_soft_cloud(Vector2(0.0, 0.0), 1700.0, _nebula_color, 0.18 * intensity)
			for index in range(4):
				draw_arc(Vector2.ZERO, 900.0 + index * 430.0, 0.0, TAU, 96, Color(_accent_color, 0.025 * intensity), 1.5, true)
		_:
			pass

func _draw_primary_horizon(
	center: Vector2,
	radius: float,
	body_color: Color,
	atmosphere: Color,
	body_alpha: float
) -> void:
	for layer in range(7, 0, -1):
		var expansion := float(layer) * 14.0
		var alpha := 0.006 + float(8 - layer) * 0.006
		draw_circle(center, radius + expansion, Color(atmosphere, alpha))
	draw_circle(center, radius, Color(body_color, body_alpha))
	draw_arc(center, radius + 3.0, deg_to_rad(196.0), deg_to_rad(344.0), 120, Color(atmosphere, 0.22), 2.2, true)
	draw_arc(center, radius - 34.0, deg_to_rad(210.0), deg_to_rad(328.0), 100, Color(atmosphere, 0.055), 1.0, true)

func _draw_soft_cloud(center: Vector2, radius: float, color: Color, strength: float) -> void:
	var layer_count := RuntimeQuality.soft_cloud_layers()
	for layer in range(layer_count, 0, -1):
		var ratio := float(layer) / float(layer_count)
		var layer_radius := radius * (0.34 + ratio * 0.66)
		var alpha := strength * (0.030 + (1.0 - ratio) * 0.040)
		draw_circle(center, layer_radius, Color(color, alpha))

func _draw_glint(position: Vector2, size: float, color: Color) -> void:
	draw_line(position - Vector2(size, 0), position + Vector2(size, 0), color, 1.2, true)
	draw_line(position - Vector2(0, size), position + Vector2(0, size), color, 1.2, true)
	draw_circle(position, 2.0, Color(color, minf(color.a + 0.22, 1.0)))

func _rebuild_primary_visual() -> void:
	if _primary_visual != null and is_instance_valid(_primary_visual):
		_primary_visual.queue_free()
	_primary_visual = null
	_primary_material = null
	_camera_origin_set = false
	if _visual_profile.is_empty():
		return

	var asset_path := String(_visual_profile.get("primary_asset", ""))
	var texture := load(asset_path) as Texture2D
	assert(texture != null, "Biome primary asset must load: %s" % asset_path)

	_primary_visual = Sprite2D.new()
	_primary_visual.texture = texture
	_primary_visual.centered = true
	_primary_visual.z_index = 1
	_primary_rotation_speed = float(_visual_profile.get("primary_rotation_speed", 0.006))
	_primary_visual.material = null
	add_child(_primary_visual)
	_update_primary_parallax()

func _update_primary_parallax() -> void:
	if _primary_visual == null or not is_instance_valid(_primary_visual):
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if not _camera_origin_set:
		_camera_origin = camera.global_position
		_camera_origin_set = true

	var viewport_size := get_viewport_rect().size
	var anchor_data := _visual_profile.get("primary_anchor", [0.8, 0.75]) as Array
	var anchor := Vector2(float(anchor_data[0]), float(anchor_data[1]))
	var screen_offset := (anchor - Vector2(0.5, 0.5)) * viewport_size
	var parallax := float(_visual_profile.get("primary_parallax", 0.06))
	var camera_delta := camera.global_position - _camera_origin
	_primary_visual.global_position = camera.global_position + screen_offset - camera_delta * parallax

	var base_scale := float(_visual_profile.get("primary_scale", 2.0))
	var compact_scale := 0.72 if viewport_size.x < 700.0 else 1.0
	_primary_visual.scale = Vector2.ONE * base_scale * compact_scale

func _draw_perimeter() -> void:
	var outer := _play_bounds
	var inner := _play_bounds.grow(-180.0)

	draw_rect(outer, Color(_accent_color, 0.16), false, 3.0, true)
	draw_rect(inner, Color(_accent_color, 0.05), false, 1.0, true)

	var corner := 180.0
	var color := Color(1.0, 0.78, 0.28, 0.46)
	var left := outer.position.x
	var right := outer.end.x
	var top := outer.position.y
	var bottom := outer.end.y

	draw_line(Vector2(left, top), Vector2(left + corner, top), color, 4.0, true)
	draw_line(Vector2(left, top), Vector2(left, top + corner), color, 4.0, true)
	draw_line(Vector2(right, top), Vector2(right - corner, top), color, 4.0, true)
	draw_line(Vector2(right, top), Vector2(right, top + corner), color, 4.0, true)
	draw_line(Vector2(left, bottom), Vector2(left + corner, bottom), color, 4.0, true)
	draw_line(Vector2(left, bottom), Vector2(left, bottom - corner), color, 4.0, true)
	draw_line(Vector2(right, bottom), Vector2(right - corner, bottom), color, 4.0, true)
	draw_line(Vector2(right, bottom), Vector2(right, bottom - corner), color, 4.0, true)
