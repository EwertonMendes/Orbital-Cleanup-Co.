extends RefCounted
class_name ResponsiveUiProfile

enum Profile {
	DESKTOP,
	COMPACT,
	PHONE_LANDSCAPE,
	PHONE_PORTRAIT,
}

const PHONE_SHORT_SIDE_MAX := 520
const COMPACT_WIDTH_MAX := 980
const COMPACT_HEIGHT_MAX := 620

const BASE_TOUCH_TARGET := 48.0
const COMPACT_TOUCH_TARGET := 56.0
const PHONE_TOUCH_TARGET := 84.0

const FONT_MINIMUMS := {
	&"HudEyebrow": 18,
	&"HudTitle": 24,
	&"HudTitleSmall": 22,
	&"HudTelemetry": 18,
	&"HudBody": 19,
	&"HudActionButton": 19,
	&"HudDangerButton": 19,
	&"HudSuccessButton": 19,
	&"DisplayLabel": 32,
	&"ScreenTitle": 26,
	&"SectionTitle": 22,
	&"UiBody": 20,
	&"UiBodyMuted": 19,
	&"TelemetryLabel": 18,
	&"ValueLabel": 20,
	&"RarityLabel": 18,
	&"PrimaryButton": 19,
	&"SecondaryButton": 19,
	&"TabButton": 19,
	&"UtilityButton": 18,
	&"DangerButton": 18,
	&"SettingsButton": 18,
	&"SuccessValue": 24,
	&"RewardValue": 24,
	&"AccentValue": 20,
}

static func current() -> Profile:
	return classify(DisplayServer.window_get_size())

static func classify(window_size: Vector2i) -> Profile:
	if window_size.x <= 0 or window_size.y <= 0:
		return Profile.DESKTOP

	var portrait := window_size.y > window_size.x
	var short_side := mini(window_size.x, window_size.y)
	if short_side <= PHONE_SHORT_SIDE_MAX:
		return Profile.PHONE_PORTRAIT if portrait else Profile.PHONE_LANDSCAPE
	if window_size.x < COMPACT_WIDTH_MAX or window_size.y < COMPACT_HEIGHT_MAX:
		return Profile.COMPACT
	return Profile.DESKTOP

static func is_phone(profile: Profile) -> bool:
	return profile == Profile.PHONE_LANDSCAPE or profile == Profile.PHONE_PORTRAIT

static func is_compact(profile: Profile) -> bool:
	return profile != Profile.DESKTOP

static func is_portrait_window() -> bool:
	var window_size := DisplayServer.window_get_size()
	return window_size.y > window_size.x

static func font_scale(profile: Profile) -> float:
	match profile:
		Profile.COMPACT:
			return 1.12
		Profile.PHONE_LANDSCAPE, Profile.PHONE_PORTRAIT:
			return 1.75
		_:
			return 1.0

static func touch_target_height(profile: Profile) -> float:
	match profile:
		Profile.COMPACT:
			return COMPACT_TOUCH_TARGET
		Profile.PHONE_LANDSCAPE, Profile.PHONE_PORTRAIT:
			return PHONE_TOUCH_TARGET
		_:
			return BASE_TOUCH_TARGET

static func build_theme(base_theme: Theme, profile: Profile) -> Theme:
	assert(base_theme != null, "ResponsiveUiProfile requires a base Theme.")
	if profile == Profile.DESKTOP:
		return base_theme

	var adapted := base_theme.duplicate(true) as Theme
	var scale := font_scale(profile)
	adapted.default_font_size = maxi(
		int(round(float(base_theme.default_font_size) * scale)),
		18 if is_phone(profile) else base_theme.default_font_size
	)

	for type_variant in FONT_MINIMUMS:
		var theme_type := type_variant as StringName
		if not adapted.has_font_size(&"font_size", theme_type):
			continue
		var current_size := adapted.get_font_size(&"font_size", theme_type)
		var minimum_size := int(FONT_MINIMUMS[type_variant]) if is_phone(profile) else current_size
		var scaled_size := maxi(int(round(float(current_size) * scale)), minimum_size)
		adapted.set_font_size(&"font_size", theme_type, scaled_size)

	return adapted

static func apply_minimum_touch_targets(root: Node, profile: Profile) -> void:
	assert(root != null, "ResponsiveUiProfile requires a UI root.")
	var target_height := touch_target_height(profile)
	for candidate in root.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button == null:
			continue
		if not button.has_meta("responsive_base_min_height"):
			button.set_meta("responsive_base_min_height", button.custom_minimum_size.y)
		var base_height := float(button.get_meta("responsive_base_min_height"))
		button.custom_minimum_size.y = maxf(base_height, target_height)
