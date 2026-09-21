extends PanelContainer
class_name HqDiscoveryCard

@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var meta_label: Label = %MetaLabel
@onready var value_label: Label = %ValueLabel
@onready var rarity_badge: Label = %RarityBadge
@onready var rarity_glow: ColorRect = %RarityGlow
@onready var rarity_line: ColorRect = %RarityLine

var _reveal_tween: Tween
var _glow_tween: Tween

func configure(
	texture: Texture2D,
	display_name: String,
	meta: String,
	value_text: String,
	rarity_text: String,
	rarity_color: Color
) -> void:
	icon.texture = texture
	name_label.text = display_name
	meta_label.text = meta
	value_label.text = value_text
	rarity_badge.text = rarity_text
	rarity_badge.add_theme_color_override("font_color", rarity_color)
	icon.modulate = Color.WHITE.lerp(rarity_color, 0.08)
	rarity_line.color = Color(rarity_color, 0.78)
	rarity_glow.color = Color(rarity_color, 0.045)
	_configure_glow(rarity_text)

func reveal(delay: float = 0.0) -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	modulate.a = 0.0
	scale = Vector2.ONE * 0.985
	pivot_offset = size * 0.5
	_reveal_tween = create_tween().set_parallel(true)
	if delay > 0.0:
		_reveal_tween.tween_interval(delay)
	_reveal_tween.tween_property(self, "modulate:a", 1.0, 0.20).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(self, "scale", Vector2.ONE, 0.24).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _configure_glow(rarity_text: String) -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	var normalized := rarity_text.to_upper()
	if normalized not in ["RARE", "EPIC", "RARO", "ÉPICO"]:
		return
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(rarity_glow, "modulate:a", 0.72, 1.15).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(rarity_glow, "modulate:a", 1.0, 1.15).set_trans(Tween.TRANS_SINE)
