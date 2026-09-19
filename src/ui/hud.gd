class_name Hud
extends CanvasLayer

## HUD layer: the drawn gameplay panel plus the pause menu and the results
## panel. The whole layer runs with PROCESS_MODE_ALWAYS so the menus keep
## working while the tree is paused.
##
## The pause menu is built from real Controls, which gives mouse, keyboard and
## gamepad navigation for free (Godot's built-in ui_* actions are left intact).

signal resume_requested
signal restart_requested
signal menu_requested
signal next_requested

var level: LevelBase = null

var _panel: HudPanel
var _pause_root: Control
var _results_root: Control
var _assist_button: CheckButton
var _shake_slider: HSlider
var _input_button: Button
var _results_label: Label
var _next_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_panel = HudPanel.new()
	_panel.level = level
	add_child(_panel)
	_build_pause_menu()
	_build_results_panel()
	Settings.changed.connect(_on_setting_changed)


func _unhandled_input(event: InputEvent) -> void:
	if level == null:
		return
	if event.is_action_pressed("pause") and not level.finished:
		var now_paused := not level.is_paused()
		level.set_paused(now_paused)
		set_paused_ui(now_paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset_level") and not level.finished:
		restart_requested.emit()
		get_viewport().set_input_as_handled()


# --- Public API -------------------------------------------------------------

func pull() -> void:
	if _panel != null:
		_panel.queue_redraw()


func refresh() -> void:
	pull()


func set_paused_ui(paused: bool) -> void:
	if _pause_root == null:
		return
	_pause_root.visible = paused
	if not paused:
		# Otherwise a focused menu button would eat the jump key on resume.
		get_viewport().gui_release_focus()
	if paused:
		_sync_menu_values()
		for child in _pause_root.find_children("*", "Button", true, false):
			var button := child as Button
			if button != null and button.focus_mode != Control.FOCUS_NONE and button.visible:
				button.grab_focus()
				break


func show_results(time_seconds: float, spills: int, swaps: int, has_next: bool) -> void:
	if _results_root == null:
		return
	var minutes := int(time_seconds) / 60
	var seconds := int(time_seconds) % 60
	_results_label.text = "%s restored\n\ntime   %02d:%02d\nshape changes   %d\nspills   %d\n\n%s" % [
		GameState.level_title(GameState.current_level),
		minutes,
		seconds,
		swaps,
		spills,
		"Both keepers stood together in the garden heart." if spills == 0 else "Every spill cost you nothing but pride.",
	]
	_next_button.visible = has_next
	_next_button.text = "Next garden"
	_results_root.visible = true
	for child in _results_root.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.visible:
			button.grab_focus()
			break


# --- Construction -----------------------------------------------------------

func _build_pause_menu() -> void:
	var root := CenterContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	_pause_root = root

	var panel := PanelContainer.new()
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(420, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Keeper 1: WASD + Space + F (change) + S (action)\nKeeper 2: Arrows + Z + C (change) + X (action)"
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)

	box.add_child(HSeparator.new())

	var resume := _add_button(box, "Resume")
	resume.pressed.connect(func() -> void:
		set_paused_ui(false)
		level.set_paused(false)
		resume_requested.emit()
	)
	var restart := _add_button(box, "Restart garden")
	restart.pressed.connect(func() -> void:
		level.set_paused(false)
		restart_requested.emit()
	)

	_assist_button = CheckButton.new()
	_assist_button.text = "Assist mode (wider attunement, gentler water)"
	_assist_button.add_theme_font_size_override("font_size", 15)
	_assist_button.toggled.connect(func(value: bool) -> void:
		Settings.set_value("assist_mode", value)
	)
	box.add_child(_assist_button)

	var shake_label := Label.new()
	shake_label.text = "Screen shake (0 turns it off)"
	shake_label.add_theme_font_size_override("font_size", 14)
	box.add_child(shake_label)
	_shake_slider = HSlider.new()
	_shake_slider.min_value = 0.0
	_shake_slider.max_value = 1.0
	_shake_slider.step = 0.1
	_shake_slider.value_changed.connect(func(value: float) -> void:
		Settings.set_value("screen_shake", value)
		level.camera.offset = Vector2.ZERO
	)
	box.add_child(_shake_slider)

	_input_button = _add_button(box, "")
	_input_button.pressed.connect(func() -> void:
		Settings.cycle_input_method()
		_input_button.text = "Controls: %s" % Settings.input_method_label()
	)

	var menu := _add_button(box, "Leave to garden gate")
	menu.pressed.connect(func() -> void:
		level.set_paused(false)
		menu_requested.emit()
	)

	_sync_menu_values()


func _build_results_panel() -> void:
	var root := CenterContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	_results_root = root

	var panel := PanelContainer.new()
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(440, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "THE GARDEN ANSWERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)

	_results_label = Label.new()
	_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_label.add_theme_font_size_override("font_size", 17)
	box.add_child(_results_label)

	_next_button = _add_button(box, "Next garden")
	_next_button.pressed.connect(func() -> void: next_requested.emit())
	var replay := _add_button(box, "Play it again")
	replay.pressed.connect(func() -> void: restart_requested.emit())
	var menu := _add_button(box, "Leave to garden gate")
	menu.pressed.connect(func() -> void: menu_requested.emit())


func _add_button(box: VBoxContainer, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)
	box.add_child(button)
	return button


func _sync_menu_values() -> void:
	if _assist_button != null:
		_assist_button.set_pressed_no_signal(Settings.assist_mode)
	if _shake_slider != null:
		_shake_slider.set_value_no_signal(Settings.screen_shake)
	if _input_button != null:
		_input_button.text = "Controls: %s" % Settings.input_method_label()


func _on_setting_changed(_key: String) -> void:
	_sync_menu_values()
	pull()
