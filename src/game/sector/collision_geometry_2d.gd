extends RefCounted
class_name CollisionGeometry2D

const GENERATED_OWNER_META := &"occ_alpha_collision_owner"
const DEFAULT_ALPHA_THRESHOLD := 0.10

static var _source_mask_cache: Dictionary = {}
static var _source_rect_cache: Dictionary = {}
static var _source_boundary_cache: Dictionary = {}
static var _dynamic_shape_cache: Dictionary = {}

static func build_static_boundary(
	body: StaticBody2D,
	sprite: Sprite2D,
	alpha_threshold: float = DEFAULT_ALPHA_THRESHOLD
) -> float:
	assert(body != null, "Static alpha collision requires a StaticBody2D owner.")
	assert(sprite != null and sprite.texture != null, "Static alpha collision requires a rendered Sprite2D texture.")
	assert(not sprite.region_enabled, "Static alpha collision currently expects a full texture, not a Sprite2D region.")

	_clear_generated_shapes(body)
	var source_segments := _alpha_boundary_segments(sprite.texture, alpha_threshold)
	assert(source_segments.size() >= 6 and source_segments.size() % 2 == 0, "Visible texture alpha must generate boundary segments.")

	var owner_id := body.create_shape_owner(body)
	body.set_meta(GENERATED_OWNER_META, owner_id)

	var mask := _alpha_mask(sprite.texture, alpha_threshold)
	var source_size := Vector2(float(mask["width"]), float(mask["height"]))
	var texture_size := sprite.texture.get_size()
	var local_segments := PackedVector2Array()
	var max_radius := 0.0

	for source_point: Vector2 in source_segments:
		var local := _sprite_local_point(source_point, source_size, texture_size, sprite)
		local_segments.append(local)
		max_radius = maxf(max_radius, local.length())

	var shape := ConcavePolygonShape2D.new()
	shape.segments = local_segments
	body.shape_owner_add_shape(owner_id, shape)

	assert(generated_part_count(body) == 1, "Static alpha collision should use one concave boundary shape.")
	return max_radius

static func build_dynamic_solid(
	body: CollisionObject2D,
	sprite: Sprite2D,
	alpha_threshold: float = DEFAULT_ALPHA_THRESHOLD
) -> float:
	assert(body != null, "Dynamic alpha collision requires a CollisionObject2D owner.")
	assert(sprite != null and sprite.texture != null, "Dynamic alpha collision requires a rendered Sprite2D texture.")
	assert(not sprite.region_enabled, "Dynamic alpha collision currently expects a full texture, not a Sprite2D region.")

	_clear_generated_shapes(body)
	var transformed_cache_key := _dynamic_shape_cache_key(sprite, alpha_threshold)
	var owner_id := body.create_shape_owner(body)
	body.set_meta(GENERATED_OWNER_META, owner_id)

	if _dynamic_shape_cache.has(transformed_cache_key):
		var cached := _dynamic_shape_cache[transformed_cache_key] as Dictionary
		for shape_value in cached["shapes"] as Array:
			body.shape_owner_add_shape(owner_id, shape_value as Shape2D)
		assert(generated_part_count(body) > 0, "Cached dynamic alpha collision must register convex shapes.")
		return float(cached["max_radius"])

	var source_rects := _alpha_rectangles(sprite.texture, alpha_threshold)
	assert(not source_rects.is_empty(), "Visible texture alpha must generate solid collision geometry.")
	var mask := _alpha_mask(sprite.texture, alpha_threshold)
	var source_size := Vector2(float(mask["width"]), float(mask["height"]))
	var texture_size := sprite.texture.get_size()
	var max_radius := 0.0
	var cached_shapes: Array[Shape2D] = []

	for rect_value in source_rects:
		var rect := rect_value as Rect2i
		var source_points := PackedVector2Array([
			Vector2(rect.position),
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end),
			Vector2(rect.position.x, rect.end.y),
		])
		var local_points := PackedVector2Array()
		for source_point: Vector2 in source_points:
			var local := _sprite_local_point(source_point, source_size, texture_size, sprite)
			local_points.append(local)
			max_radius = maxf(max_radius, local.length())

		var shape := ConvexPolygonShape2D.new()
		shape.points = local_points
		cached_shapes.append(shape)
		body.shape_owner_add_shape(owner_id, shape)

	_dynamic_shape_cache[transformed_cache_key] = {
		"shapes": cached_shapes,
		"max_radius": max_radius,
	}
	assert(generated_part_count(body) > 0, "Dynamic alpha collision must register convex shapes.")
	return max_radius

static func alpha_bounds_radius(
	texture: Texture2D,
	sprite_scale: Vector2,
	alpha_threshold: float = DEFAULT_ALPHA_THRESHOLD
) -> float:
	assert(texture != null, "Alpha collision bounds require a texture.")
	var mask := _alpha_mask(texture, alpha_threshold)
	var source_size := Vector2(float(mask["width"]), float(mask["height"]))
	var texture_size := texture.get_size()
	var source_segments := _alpha_boundary_segments(texture, alpha_threshold)
	var origin := texture_size * 0.5
	var source_to_texture := Vector2(
		texture_size.x / maxf(source_size.x, 1.0),
		texture_size.y / maxf(source_size.y, 1.0)
	)
	var max_radius := 0.0

	for source_point: Vector2 in source_segments:
		var texture_point := source_point * source_to_texture
		var local: Vector2 = (texture_point - origin) * sprite_scale
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

static func generated_boundary_segment_count(body: CollisionObject2D) -> int:
	var owner_id := _generated_owner_id(body)
	if owner_id < 0 or body.shape_owner_get_shape_count(owner_id) != 1:
		return 0
	var shape := body.shape_owner_get_shape(owner_id, 0)
	if shape is not ConcavePolygonShape2D:
		return 0
	return (shape as ConcavePolygonShape2D).segments.size() / 2

static func _alpha_mask(texture: Texture2D, alpha_threshold: float) -> Dictionary:
	assert(texture != null, "Cannot trace an empty texture.")
	var threshold := clampf(alpha_threshold, 0.0, 1.0)
	var cache_key := _cache_key(texture, threshold)
	if _source_mask_cache.has(cache_key):
		return _source_mask_cache[cache_key] as Dictionary

	# Texture readback happens once per unique source texture and threshold.
	# Every collision representation for that asset reuses this authoritative mask.
	var image := texture.get_image()
	assert(image != null and not image.is_empty(), "Collision texture must expose image data.")
	if image.is_compressed():
		var error := image.decompress()
		assert(error == OK, "Collision texture image must be decompressible: %s" % texture.resource_path)
	assert(
		image.detect_alpha() != Image.ALPHA_NONE,
		"Collision source must preserve transparent alpha in the imported image: %s" % texture.resource_path
	)

	var width := image.get_width()
	var height := image.get_height()
	assert(width > 0 and height > 0, "Collision alpha image must have positive dimensions.")

	var bits := PackedByteArray()
	bits.resize(width * height)
	for y in range(height):
		var row_offset := y * width
		for x in range(width):
			if image.get_pixel(x, y).a > threshold:
				bits[row_offset + x] = 1

	var mask := {
		"width": width,
		"height": height,
		"bits": bits,
	}
	_source_mask_cache[cache_key] = mask
	return mask

static func _alpha_boundary_segments(texture: Texture2D, alpha_threshold: float) -> PackedVector2Array:
	var threshold := clampf(alpha_threshold, 0.0, 1.0)
	var cache_key := _cache_key(texture, threshold)
	if _source_boundary_cache.has(cache_key):
		return _source_boundary_cache[cache_key] as PackedVector2Array

	var mask := _alpha_mask(texture, threshold)
	var width := int(mask["width"])
	var height := int(mask["height"])
	var bits := mask["bits"] as PackedByteArray
	var segments := PackedVector2Array()

	# Horizontal boundaries. Keep opposite transition directions separate at
	# diagonal contacts so disconnected opaque islands never become linked.
	for boundary_y in range(height + 1):
		var x := 0
		while x < width:
			var above := boundary_y > 0 and bits[(boundary_y - 1) * width + x] != 0
			var below := boundary_y < height and bits[boundary_y * width + x] != 0
			if above == below:
				x += 1
				continue
			var start_x := x
			var transition_above := above
			var transition_below := below
			x += 1
			while x < width:
				var next_above := boundary_y > 0 and bits[(boundary_y - 1) * width + x] != 0
				var next_below := boundary_y < height and bits[boundary_y * width + x] != 0
				if next_above != transition_above or next_below != transition_below:
					break
				x += 1
			segments.append(Vector2(start_x, boundary_y))
			segments.append(Vector2(x, boundary_y))

	# Vertical boundaries.
	for boundary_x in range(width + 1):
		var y := 0
		while y < height:
			var left := boundary_x > 0 and bits[y * width + boundary_x - 1] != 0
			var right := boundary_x < width and bits[y * width + boundary_x] != 0
			if left == right:
				y += 1
				continue
			var start_y := y
			var transition_left := left
			var transition_right := right
			y += 1
			while y < height:
				var next_left := boundary_x > 0 and bits[y * width + boundary_x - 1] != 0
				var next_right := boundary_x < width and bits[y * width + boundary_x] != 0
				if next_left != transition_left or next_right != transition_right:
					break
				y += 1
			segments.append(Vector2(boundary_x, start_y))
			segments.append(Vector2(boundary_x, y))

	assert(segments.size() >= 6, "Texture alpha contains no collision boundary.")
	_source_boundary_cache[cache_key] = segments
	return segments

static func _alpha_rectangles(texture: Texture2D, alpha_threshold: float) -> Array:
	var threshold := clampf(alpha_threshold, 0.0, 1.0)
	var cache_key := _cache_key(texture, threshold)
	if _source_rect_cache.has(cache_key):
		return _source_rect_cache[cache_key] as Array

	var mask := _alpha_mask(texture, threshold)
	var width := int(mask["width"])
	var height := int(mask["height"])
	var remaining := (mask["bits"] as PackedByteArray).duplicate()
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

	assert(not rectangles.is_empty(), "Texture alpha contains no solid collision silhouette.")
	_source_rect_cache[cache_key] = rectangles
	return rectangles

static func _sprite_local_point(
	source_point: Vector2,
	source_size: Vector2,
	texture_size: Vector2,
	sprite: Sprite2D
) -> Vector2:
	var source_to_texture := Vector2(
		texture_size.x / maxf(source_size.x, 1.0),
		texture_size.y / maxf(source_size.y, 1.0)
	)
	var texture_point := source_point * source_to_texture
	var origin := texture_size * 0.5 if sprite.centered else Vector2.ZERO
	var local := texture_point - origin + sprite.offset
	if sprite.flip_h:
		local.x = -local.x
	if sprite.flip_v:
		local.y = -local.y
	return local * sprite.scale

static func _cache_key(texture: Texture2D, threshold: float) -> String:
	var path_key := texture.resource_path
	var texture_key := path_key if not path_key.is_empty() else str(texture.get_instance_id())
	return "%s|%.4f" % [texture_key, threshold]

static func _dynamic_shape_cache_key(sprite: Sprite2D, alpha_threshold: float) -> String:
	var source_key := _cache_key(sprite.texture, clampf(alpha_threshold, 0.0, 1.0))
	return "%s|scale=%.5f,%.5f|offset=%.3f,%.3f|centered=%s|flip=%s,%s" % [
		source_key,
		sprite.scale.x,
		sprite.scale.y,
		sprite.offset.x,
		sprite.offset.y,
		str(sprite.centered),
		str(sprite.flip_h),
		str(sprite.flip_v),
	]

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
