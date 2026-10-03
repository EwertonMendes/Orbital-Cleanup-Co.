extends PanelContainer
class_name HqRankRow

@onready var badge: TextureRect = %Badge
@onready var status_label: Label = %Status
@onready var name_label: Label = %Name
@onready var xp_label: Label = %Xp

func _ready() -> void:
	assert(badge != null and status_label != null and name_label != null and xp_label != null, "HqRankRow nodes are required.")
	if ResponsiveUiProfile.is_phone(ResponsiveUiProfile.current()):
		status_label.custom_minimum_size.x = 112.0

func configure(rank_id: String, rank_name: String, min_xp: int, unlocked: bool, current: bool) -> void:
	badge.texture = HqVisualAssets.rank_badge(rank_id)
	name_label.text = rank_name
	xp_label.text = tr("HQ_RANK_XP_FMT") % min_xp
	if current:
		status_label.text = tr("HQ_RANK_CURRENT")
		status_label.add_theme_color_override("font_color", OccPalette.MINT)
		self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	elif unlocked:
		status_label.text = tr("HQ_RANK_UNLOCKED")
		status_label.add_theme_color_override("font_color", OccPalette.TEXT_MUTED)
		self_modulate = Color(0.88, 0.92, 0.96, 0.88)
	else:
		status_label.text = tr("HQ_RANK_LOCKED")
		status_label.add_theme_color_override("font_color", OccPalette.AMBER)
		self_modulate = Color(0.62, 0.67, 0.72, 0.74)
