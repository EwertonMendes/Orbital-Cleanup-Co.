extends PanelContainer
class_name HqUpgradeCard

signal purchase_requested(upgrade_id: String)

@onready var art: TextureRect = %Art
@onready var title_label: Label = %Title
@onready var description_label: Label = %Description
@onready var level_label: Label = %Level
@onready var current_effect_label: Label = %CurrentEffect
@onready var next_effect_label: Label = %NextEffect
@onready var level_segments: HBoxContainer = %LevelSegments
@onready var purchase_button: Button = %PurchaseButton

var _upgrade_id := ""

func _ready() -> void:
	assert(
		art != null
		and title_label != null
		and description_label != null
		and level_label != null
		and current_effect_label != null
		and next_effect_label != null
		and level_segments != null
		and purchase_button != null,
		"HqUpgradeCard nodes are required."
	)
	GamepadUiNavigation.prepare_button(purchase_button)
	purchase_button.pressed.connect(_on_purchase_pressed)

func configure(
	upgrade_id: String,
	title: String,
	description: String,
	level: int,
	max_level: int,
	cost: int,
	effect_text: String,
	affordable: bool
) -> void:
	_upgrade_id = upgrade_id
	art.texture = HqVisualAssets.upgrade_art(upgrade_id)
	title_label.text = title
	description_label.text = description
	level_label.text = "%d / %d" % [level, max_level]
	var split := effect_text.split("→", false, 1)
	current_effect_label.text = String(split[0]).strip_edges() if not split.is_empty() else "—"
	next_effect_label.text = String(split[1]).strip_edges() if split.size() > 1 else tr("HQ_UPGRADE_MAX")
	_refresh_level_segments(level, max_level)

	var is_maxed := level >= max_level
	purchase_button.text = tr("HQ_UPGRADE_MAX") if is_maxed else tr("HQ_UPGRADE_COST_FMT") % cost
	purchase_button.disabled = is_maxed or not affordable
	purchase_button.tooltip_text = tr("HQ_UPGRADE_NEED_CREDITS") if not is_maxed and not affordable else ""

func get_upgrade_id() -> String:
	return _upgrade_id

func get_purchase_button() -> Button:
	return purchase_button

func _refresh_level_segments(level: int, max_level: int) -> void:
	var children := level_segments.get_children()
	for index in range(children.size()):
		var segment := children[index] as ColorRect
		if segment == null:
			continue
		segment.visible = index < max_level
		segment.color = Color(0.34, 0.86, 1.0, 0.92) if index < level else Color(0.20, 0.29, 0.34, 0.72)

func _on_purchase_pressed() -> void:
	if not purchase_button.disabled:
		purchase_requested.emit(_upgrade_id)
