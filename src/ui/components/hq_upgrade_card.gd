extends PanelContainer
class_name HqUpgradeCard

signal purchase_requested(upgrade_id: String)

@onready var title_label: Label = %Title
@onready var description_label: Label = %Description
@onready var level_label: Label = %Level
@onready var effect_label: Label = %Effect
@onready var purchase_button: Button = %PurchaseButton

var _upgrade_id := ""

func _ready() -> void:
	assert(title_label != null, "HqUpgradeCard requires Title.")
	assert(description_label != null, "HqUpgradeCard requires Description.")
	assert(level_label != null, "HqUpgradeCard requires Level.")
	assert(effect_label != null, "HqUpgradeCard requires Effect.")
	assert(purchase_button != null, "HqUpgradeCard requires PurchaseButton.")
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
	assert(not upgrade_id.is_empty(), "HqUpgradeCard requires upgrade id.")
	_upgrade_id = upgrade_id
	purchase_button.set_meta(&"occ_focus_restore_key", "upgrade:%s" % upgrade_id)
	title_label.text = title
	description_label.text = description
	level_label.text = "%d / %d" % [level, max_level]
	effect_label.text = effect_text

	var at_max := level >= max_level
	if at_max:
		purchase_button.text = tr("HQ_UPGRADE_MAX")
		purchase_button.disabled = true
	else:
		purchase_button.text = tr("HQ_UPGRADE_COST_FMT") % cost
		purchase_button.disabled = not affordable
		purchase_button.tooltip_text = tr("HQ_UPGRADE_NEED_CREDITS") if not affordable else ""

func _on_purchase_pressed() -> void:
	if _upgrade_id.is_empty():
		return
	purchase_requested.emit(_upgrade_id)


func get_upgrade_id() -> String:
	return _upgrade_id

func get_purchase_button() -> Button:
	return purchase_button
