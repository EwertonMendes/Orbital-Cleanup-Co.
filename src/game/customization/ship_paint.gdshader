shader_type canvas_item;

uniform vec4 paint_color : source_color = vec4(0.224, 0.714, 0.910, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.106, 0.200, 0.271, 1.0);
uniform vec4 accent_color : source_color = vec4(0.906, 0.973, 1.000, 1.0);
uniform float paint_strength : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D paint_mask : source_color, filter_nearest;
uniform bool use_rgb_mask = false;

vec3 preserve_luminance(vec3 source, vec3 target) {
	float luminance = dot(source, vec3(0.2126, 0.7152, 0.0722));
	return target * (0.42 + luminance * 0.92);
}

// Fleet source art uses cyan/teal glass and emissive service lights as a
// consistent non-hull material language. Some early RGB masks inherited thin
// reflective highlights from those regions. Paint must never recolor canopy
// glass or emissive hardware, even when a mask pixel was authored incorrectly.
float protected_non_hull_factor(vec3 source) {
	float cyan_bias = min(source.g, source.b) - source.r;
	return smoothstep(0.035, 0.115, cyan_bias);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb;

	if (use_rgb_mask) {
		vec4 mask = texture(paint_mask, UV);
		vec3 primary = preserve_luminance(tex.rgb, paint_color.rgb);
		vec3 secondary = preserve_luminance(tex.rgb, secondary_color.rgb);
		vec3 accent = preserve_luminance(tex.rgb, accent_color.rgb);
		float hull_material = 1.0 - protected_non_hull_factor(tex.rgb);
		float primary_weight = clamp(mask.r * paint_strength * hull_material, 0.0, 1.0);
		float secondary_weight = clamp(mask.g * paint_strength * hull_material, 0.0, 1.0);
		float accent_weight = clamp(mask.b * paint_strength * hull_material, 0.0, 1.0);
		rgb = mix(rgb, primary, primary_weight);
		rgb = mix(rgb, secondary, secondary_weight);
		rgb = mix(rgb, accent, accent_weight);
	} else {
		float max_rg = max(tex.r, tex.g);
		float blue_bias = max(tex.b - max_rg * 0.94, 0.0);
		float saturation = max(max(tex.r, tex.g), tex.b) - min(min(tex.r, tex.g), tex.b);
		float legacy_mask = smoothstep(0.025, 0.22, blue_bias + saturation * 0.10);
		vec3 painted = preserve_luminance(tex.rgb, paint_color.rgb);
		rgb = mix(tex.rgb, painted, legacy_mask * paint_strength);
	}

	COLOR = vec4(rgb, tex.a) * COLOR;
}
