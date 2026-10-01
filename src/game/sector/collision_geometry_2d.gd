extends RefCounted
class_name CollisionGeometry2D

const GENERATED_OWNER_META := &"occ_alpha_collision_owner"
const DEFAULT_ALPHA_THRESHOLD := 0.10

static var _source_rect_cache: Dictionary = {}

static func build_from_sprite(
	body: CollisionObject2D,
	sprite: Sprite2D,
	alpha_threshold: float = DEFAULT_ALPHA_THRESHOLD
) -> float:
	assert(body != null, "Alpha collision requires a CollisionObject2D owner.")
	assert(sprite != null and sprite.texture != null, "Alpha collision requires a rendered Sprite2D texture.")
	assert(not sprite.region_enabled, "Alpha collision currently expects a full texture, not a Sprite2D region.")

	_clear_generated_shapes(body)
	var source_rects := _alpha_rectangles(sprite.texture, alpha_threshold)
	assert(not source_rects.is_empty(), "Visible texture alpha must generate collision geometry.")

	var owner_id := body.create_shape_owner(body)
	body.set_meta(GENERATED_OWNER_META, owner_id)

	var texture_size := sprite.texture.get_size()
	var origin := texture_size * 0.5 if sprite.centered else Vector2.ZERO
	var max_radius := 0.0

	for rect_value in source_rects:
		var rect := rect_value as Rect2i
		var x0 := float(rect.position.x)
		var y0 := float(rect.position.y)
		var x1 := float(rect.end.x)
		var y1 := float(rect.end.y)
		var source_points := PackedVector2Array([
			Vector2(x0, y0),
			Vector2(x1, y0),
			Vector2(x1, y1),
			Vector2(x0, y1),
		])
		var local_points := PackedVector2Array()
		for source_point in source_points:
			var local := source_point - origin + sprite.offset
			if sprite.flip_h:
				local.x = -local.x
			if sprite.flip_v:
				local.y = -local.y
			local *= sprite.scale
			local_points.append(local)
			max_radius = maxf(max_radius, local.length())

		var shape := ConvexPolygonShape2D.new()
		shape.points = local_points
		body.shape_owner_add_shape(owner_id, shape)

	assert(generated_part_count(body) > 0, "Alpha collision must register at least one convex shape.")
	return max_radius

static func alpha_bounds_radius(
	texture: Texture2D,
	sprite_scale: Vector2,
	alpha_threshold: float = DEFAULT_ALPHA_THRESHOLD
) -> float:
	assert(texture != null, "Alpha collision bounds require a texture.")
	var source_rects := _alpha_rectangles(texture, alpha_threshold)
	var origin := texture.get_size() * 0.5
	var max_radius := 0.0
	for rect_value in source_rects:
		var rect := rect_value as Rect2i
		var corners := PackedVector2Array([
			Vector2(rect.position),
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end),
			Vector2(rect.position.x, rect.end.y),
		])
		for source_point: Vector2 in corners:
			var local: Vector2 = (source_point - origin) * sprite_scale
			max_radius = maxf(max_radius, local.length())
	assert(max_radius > 0.0, "Alpha collision bounds require visible pixels.")
	return max_radius

static func set_generated_rotation(body: CollisionObject2D, rotation_radians: float) -> void:
	var owner_id := _generated_owner_id(body)
	if owner_id < 0:
		return
	body.shape_owner_set_transform(owner_id, Transform2D(rotation_radians, Vector2.ZERO))

static func generated_part_count(body: CollisionObject2D) -> int:
	var owner_id := _generated_owner_id(body)
	if owner_id < 0:
		return 0
	return body.shape_owner_get_shape_count(owner_id)

static func _alpha_rectangles(texture: Texture2D, alpha_threshold: float) -> Array:
	assert(texture != null, "Cannot trace an empty texture.")
	var threshold := clampf(alpha_threshold, 0.0, 1.0)
	var path_key := texture.resource_path
	var texture_key := path_key if not path_key.is_empty() else str(texture.get_instance_id())
	var cache_key := "%s|%.4f" % [texture_key, threshold]
	if _source_rect_cache.has(cache_key):
		return _source_rect_cache[cache_key] as Array

	# Texture readback happens only once per unique source texture and threshold.
	# The resulting source-space convex partition is cached for every instance.
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
	var size := bitmap.get_size()
	var width := size.x
	var height := size.y
	assert(width > 0 and height > 0, "Collision bitmap must have positive dimensions.")

	var remaining := PackedByteArray()
	remaining.resize(width * height)
	for y in range(height):
		var row_offset := y * width
		for x in range(width):
			if bitmap.get_bit(x, y):
				remaining[row_offset + x] = 1

	var rectangles: Array = []
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			if remaining[index] == 0:
				continue

			var first_row_width := 0
			while x + first_row_width < width and remaining[index + first_row_width] != 0:
				first_row_width += 1

			var best_width := first_row_width
			var best_height := 1
			var best_area := first_row_width
			var current_width := first_row_width
			var scan_y := y + 1

			while scan_y < height and current_width > 0:
				var scan_width := 0
				var scan_offset := scan_y * width + x
				while scan_width < current_width and remaining[scan_offset + scan_width] != 0:
					scan_width += 1
				current_width = mini(current_width, scan_width)
				if current_width <= 0:
					break

				var candidate_height := scan_y - y + 1
				var candidate_area := current_width * candidate_height
				if candidate_area > best_area:
					best_area = candidate_area
					best_width = current_width
					best_height = candidate_height
				scan_y += 1

			var rect := Rect2i(x, y, best_width, best_height)
			rectangles.append(rect)
			for clear_y in range(y, y + best_height):
				var clear_offset := clear_y * width + x
				for clear_x in range(best_width):
					remaining[clear_offset + clear_x] = 0

	assert(not rectangles.is_empty(), "Texture alpha contains no collision silhouette.")
	_source_rect_cache[cache_key] = rectangles
	return rectangles

static func _generated_owner_id(body: CollisionObject2D) -> int:
	if not body.has_meta(GENERATED_OWNER_META):
		return -1
	var owner_id := int(body.get_meta(GENERATED_OWNER_META, -1))
	if owner_id < 0 or not body.get_shape_owners().has(owner_id):
		return -1
	return owner_id

static func _clear_generated_shapes(body: CollisionObject2D) -> void:
	var owner_id := _generated_owner_id(body)
	if owner_id >= 0:
		body.remove_shape_owner(owner_id)
	body.remove_meta(GENERATED_OWNER_META)
