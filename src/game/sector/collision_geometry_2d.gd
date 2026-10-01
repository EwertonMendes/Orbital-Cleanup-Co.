extends RefCounted
class_name CollisionGeometry2D

const BUILD_MODE := CollisionPolygon2D.BUILD_SOLIDS
const GENERATED_META := &"occ_collision_profile_part"

static func build_profile(
	body: CollisionObject2D,
	profile: Dictionary,
	texture: Texture2D,
	sprite_scale: Vector2
) -> float:
	assert(body != null, "CollisionGeometry2D requires a CollisionObject2D owner.")
	assert(not profile.is_empty(), "CollisionGeometry2D requires a profile.")
	assert(texture != null, "CollisionGeometry2D requires the rendered texture.")
	assert(is_equal_approx(sprite_scale.x, sprite_scale.y), "World collision profiles require uniform sprite scale.")

	_clear_generated_parts(body)

	var parts := profile.get("parts", []) as Array
	assert(not parts.is_empty(), "Collision profile requires at least one polygon part.")
	var texture_size := texture.get_size()
	var max_radius := 0.0

	for index in range(parts.size()):
		var source_points := parts[index] as Array
		assert(source_points.size() >= 3, "Collision polygon part requires at least three points.")
		var polygon := PackedVector2Array()
		for point_value in source_points:
			var point_data := point_value as Array
			assert(point_data.size() == 2, "Collision polygon points require x/y values.")
			var normalized := Vector2(float(point_data[0]), float(point_data[1]))
			var local := Vector2(
				normalized.x * texture_size.x * sprite_scale.x,
				normalized.y * texture_size.y * sprite_scale.y
			)
			polygon.append(local)
			max_radius = maxf(max_radius, local.length())

		var collision := CollisionPolygon2D.new()
		collision.name = "CollisionPart%02d" % index
		collision.build_mode = BUILD_MODE
		collision.polygon = polygon
		collision.set_meta(GENERATED_META, true)

		# CollisionPolygon2D must be a direct child of CollisionObject2D.
		# Nesting it under an intermediate Node2D leaves visible nodes in the
		# scene tree but does not register any shape with the physics body.
		body.add_child(collision)

	return max_radius

static func _clear_generated_parts(body: CollisionObject2D) -> void:
	for child in body.get_children():
		if child is CollisionPolygon2D and bool(child.get_meta(GENERATED_META, false)):
			body.remove_child(child)
			child.free()

static func reference_bounds_radius(profile: Dictionary, reference_size: float, visual_scale: float) -> float:
	assert(not profile.is_empty(), "Collision bounds require a profile.")
	assert(reference_size > 0.0, "Collision bounds require positive reference size.")
	assert(visual_scale > 0.0, "Collision bounds require positive visual scale.")
	var normalized_radius := float(profile.get("bounds_radius", 0.0))
	assert(normalized_radius > 0.0, "Collision profile requires bounds_radius.")
	return normalized_radius * reference_size * visual_scale
