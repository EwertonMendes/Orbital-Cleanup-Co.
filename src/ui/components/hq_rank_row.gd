extends PanelContainer
class_name HqRankRow

@onready var status_label: Label = %Status
@onready var name_label: Label = %Name
@onready var xp_label: Label = %Xp

func _ready() -> void:
	assert(status_label != null and name_label != null and xp_label != null, "HqRankRow nodes are required.")

func configure(rank_name: String, min_xp: int, unlocked: bool, current: bool) -> void:
	name_label.text = rank_name
	xp_label.text = tr("HQ_RANK_XP_FMT") % min_xp
	if current:
		status_label.text = tr("HQ_RANK_CURRENT")
		status_label.add_theme_color_override("font_color", Color("#278a61"))
	elif unlocked:
		status_label.text = tr("HQ_RANK_UNLOCKED")
		status_label.add_theme_color_override("font_color", Color("#4e555e"))
	else:
		status_label.text = tr("HQ_RANK_LOCKED")
		status_label.add_theme_color_override("font_color", Color("#b67b16"))
