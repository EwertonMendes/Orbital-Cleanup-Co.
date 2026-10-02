extends RefCounted
class_name GamepadUiNavigation

## Small, reusable focus utilities for controller/keyboard UI navigation.
## Screens still own semantic navigation (tabs, back, confirm); this helper only
## keeps focusable controls consistent and visible.

static func prepare_button(button: Button) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_ALL

static func prepare_tree(root: Node) -> void:
	if root == null:
		return
	if root is Button:
		prepare_button(root as Button)
	for node in root.find_children("*", "Button", true, false):
		if node is Button:
			prepare_button(node as Button)

static func grab(preferred: Control, fallback_root: Node = null) -> void:
	if _can_focus(preferred):
		preferred.grab_focus()
		ensure_visible(preferred)
		return

	var fallback := first_focusable(fallback_root)
	if fallback != null:
		fallback.grab_focus()
		ensure_visible(fallback)

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
	for node in root.find_children("*", "Button", true, false):
		if not node is Button:
			continue
		var button := node as Button
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
