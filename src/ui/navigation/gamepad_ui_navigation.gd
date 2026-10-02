extends RefCounted
class_name GamepadUiNavigation

## Small, reusable focus utilities for controller/keyboard UI navigation.
## Screens still own semantic navigation (tabs, back, confirm); this helper only
## keeps focusable controls consistent and visible.

static func prepare_button(button: BaseButton) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_ALL

static func prepare_tree(root: Node) -> void:
	if root == null:
		return
	if root is BaseButton:
		prepare_button(root as BaseButton)
	for node in root.find_children("*", "Control", true, false):
		if node is BaseButton:
			prepare_button(node as BaseButton)

static func grab(preferred: Control, fallback_root: Node = null) -> void:
	if _can_focus(preferred):
		preferred.grab_focus()
		ensure_visible(preferred)
		return

	var fallback := first_focusable(fallback_root)
	if fallback != null:
		fallback.grab_focus()
		ensure_visible(fallback)

static func grab_by_meta(root: Node, meta_key: StringName, meta_value: Variant) -> bool:
	if root == null:
		return false
	if root is Control:
		var root_control := root as Control
		if root_control.has_meta(meta_key) and root_control.get_meta(meta_key) == meta_value and _can_focus(root_control):
			root_control.grab_focus()
			ensure_visible(root_control)
			return true
	for node in root.find_children("*", "Control", true, false):
		if not node is Control:
			continue
		var control := node as Control
		if not control.has_meta(meta_key) or control.get_meta(meta_key) != meta_value:
			continue
		if not _can_focus(control):
			continue
		control.grab_focus()
		ensure_visible(control)
		return true
	return false

static func first_focusable(root: Node) -> Control:
	if root == null:
		return null
	if root is Control and _can_focus(root as Control):
		return root as Control
	for node in root.find_children("*", "Control", true, false):
		if node is Control and _can_focus(node as Control):
			return node as Control
	return null

static func ensure_visible(control: Control) -> void:
	if control == null:
		return
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			(parent as ScrollContainer).call_deferred("ensure_control_visible", control)
		parent = parent.get_parent()

static func set_focus_enabled(root: Node, enabled: bool, except_root: Node = null) -> void:
	if root == null:
		return
	for node in root.find_children("*", "Control", true, false):
		if not node is BaseButton:
			continue
		var button := node as BaseButton
		if except_root != null and (button == except_root or except_root.is_ancestor_of(button)):
			continue

		if enabled:
			if button.has_meta("occ_focus_mode_before_scope"):
				button.focus_mode = int(button.get_meta("occ_focus_mode_before_scope"))
				button.remove_meta("occ_focus_mode_before_scope")
			continue

		if not button.has_meta("occ_focus_mode_before_scope"):
			button.set_meta("occ_focus_mode_before_scope", button.focus_mode)
		if button.has_focus():
			button.release_focus()
		button.focus_mode = Control.FOCUS_NONE

static func _can_focus(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not control.is_inside_tree() or not control.is_visible_in_tree():
		return false
	if control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true
