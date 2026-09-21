extends PanelContainer
class_name HqDiscoveryCard

@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var meta_label: Label = %MetaLabel
@onready var value_label: Label = %ValueLabel
@onready var rarity_badge: Label = %RarityBadge

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
	icon.modulate = Color.WHITE.lerp(rarity_color, 0.10)
