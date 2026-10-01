extends RefCounted
class_name CollisionGeometry2D

const BUILD_MODE := CollisionPolygon2D.BUILD_SOLIDS
const GENERATED_META := &"occ_alpha_collision_part"
const DEFAULT_ALPHA_THRESHOLD := 0.10
const DEFAULT_TRACE_EPSILON := 0.0

static var _source_polygon_cache: Dictionary = {}

static func build_from_sprite(
	body: CollisionObject2D,
	sprite: Sprite2D,
	alpha_threshold: float = DEFAULT_ALPHA_THRESHOLD,
	trace_epsilon: float = DEFAULT_TRACE_EPSILON
) -> float:
	assert(body != null, "Alpha collision requires a CollisionObject2D owner.")
	assert(sprite != null and sprite.texture != null, "Alpha collision requires a rendered Sprite2D texture.")
	assert(sprite.region_enabled == false, "Alpha collision currently expects a full texture, not a Sprite2D region.")

	_clear_generated_parts(body)
	var source_polygons := _trace_texture_alpha(sprite.texture, alpha_threshold, trace_epsilon)
	assert(not source_polygons.is_empty(), "Visible texture alpha must generate collision polygons.")

	var texture_size := sprite.texture.get_size()
	var origin := texture_size * 0.5 if sprite.centered else Vector2.ZERO
	var max_radius := 0.0

	for index in range(source_polygons.size()):
		var source_polygon := source_polygons[index] as PackedVector2Array
		if source_polygon.size() < 3:
			continue

		var polygon := PackedVector2Array()
		for source_point in source_polygon:
			var local := source_point - origin + sprite.offset
			if sprite.flip_h:
				local.x = -local.x
			if sprite.flip_v:
				local.y = -local.y
			local *= sprite.scale
			polygon.append(local)
			max_radius = maxf(max_radius, local.length())

		var collision := CollisionPolygon2D.new()
		collision.name = "AlphaCollisionPart%02d" % index
		collision.build_mode = BUILD_MODE
		collision.polygon = polygon
		collision.set_meta(GENERATED_META, true)
		# CollisionPolygon2D only contributes to physics when it is a direct
		# child of CollisionObject2D.
		body.add_child(collision)

	assert(_generated_parts(body).size() > 0, "Alpha collision must register at least one polygon.")
	return max_radius

static func alpha_bounds_radius(
	texture: Texture2D,
	sprite_scale: Vector2,
	alpha_threshold: float = DEFAULT_ALPHA_THRESHOLD,
	trace_epsilon: float = DEFAULT_TRACE_EPSILON
) -> float:
	assert(texture != null, "Alpha collision bounds require a texture.")
	var source_polygons := _trace_texture_alpha(texture, alpha_threshold, trace_epsilon)
	var origin := texture.get_size() * 0.5
	var max_radius := 0.0
	for polygon_value in source_polygons:
		var polygon := polygon_value as PackedVector2Array
		for source_point in polygon:
			var local := (source_point - origin) * sprite_scale
			max_radius = maxf(max_radius, local.length())
	assert(max_radius > 0.0, "Alpha collision bounds require visible pixels.")
	return max_radius

static func set_generated_rotation(body: CollisionObject2D, rotation_radians: float) -> void:
	for part in _generated_parts(body):
		part.rotation = rotation_radians

static func generated_part_count(body: CollisionObject2D) -> int:
	return _generated_parts(body).size()

static func _trace_texture_alpha(
	texture: Texture2D,
	alpha_threshold: float,
	trace_epsilon: float
) -> Array:
	assert(texture != null, "Cannot trace an empty texture.")
	var threshold := clampf(alpha_threshold, 0.0, 1.0)
	var epsilon := maxf(trace_epsilon, 0.0)
	var path_key := texture.resource_path
	var texture_key := path_key if not path_key.is_empty() else str(texture.get_instance_id())
	var cache_key := "%s|%.4f|%.4f" % [texture_key, threshold, epsilon]
	if _source_polygon_cache.has(cache_key):
		return _source_polygon_cache[cache_key] as Array

	# get_image() can be expensive because it may read texture data back from
	# the GPU. This path runs once per unique texture/threshold/epsilon and is
	# cached for every later instance.
	var image := texture.get_image()
	assert(image != null and not image.is_empty(), "Collision texture must expose image data.")
	if image.is_compressed():
		var error := image.decompress()
		assert(error == OK, "Collision texture image must be decompressible: %s" % texture.resource_path)
	assert(
		image.detect_alpha() != Image.ALPHA_NONE,
		"Collision source must preserve transparent alpha in the imported image: %s" % texture.resource_path
	)

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, threshold)
	var polygons := bitmap.opaque_to_polygons(
		Rect2i(Vector2i.ZERO, bitmap.get_size()),
		epsilon
	)
	assert(not polygons.is_empty(), "Texture alpha contains no collision silhouette.")
	_source_polygon_cache[cache_key] = polygons
	return polygons

static func _generated_parts(body: CollisionObject2D) -> Array[CollisionPolygon2D]:
	var parts: Array[CollisionPolygon2D] = []
	for child in body.get_children():
		if child is CollisionPolygon2D and bool(child.get_meta(GENERATED_META, false)):
			parts.append(child as CollisionPolygon2D)
	return parts

static func _clear_generated_parts(body: CollisionObject2D) -> void:
	for child in _generated_parts(body):
		body.remove_child(child)
		child.free()
