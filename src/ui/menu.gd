class_name GardenMenu
extends Control

## The garden gate: title, level select, controls reference and settings.
##
## Built from standard Controls so the whole screen works with mouse, keyboard
## and gamepad focus navigation without any bespoke code.

signal level_chosen(index: int)

const HELP := """KEEPER 1   A / D move   SPACE jump   S act   F change shape   R restart
KEEPER 2   LEFT / RIGHT move   Z or UP jump   X act   C change shape   V restart
PADS       left stick or d-pad   A jump   X act   Y change   START pause

ACT can be held or tapped: the sturdy keeper roots or carries,
the swift keeper throws and reels the tether.
You may only change shape while the braid between you is bright."""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Palette.SKY_TOP, true)
	var bands := 24
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(Vector2(0, rect.size.y * t / float(bands)), Vector2(rect.size.x, rect.size.y / float(bands) + 2.0)), Palette.SKY_TOP.lerp(Palette.SKY_BOTTOM, t), true)
	draw_circle(Vector2(rect.size.x * 0.82, rect.size.y * 0.24), 90.0, Color(Palette.GOLD, 0.10))
	draw_circle(Vector2(rect.size.x * 0.82, rect.size.y * 0.24), 54.0, Color(Palette.GOLD, 0.14))
	for i in 8:
		var a := TAU * float(i) / 8.0
		draw_line(Vector2(rect.size.x * 0.82, rect.size.y * 0.24), Vector2(rect.size.x * 0.82, rect.size.y * 0.24) + Vector2.from_angle(a) * 70.0, Color(Palette.TURQUOISE, 0.25), 4.0)


func _build() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(760, 0)
	centre.add_child(box)

	var title := Label.new()
	title.text = "TWO KEEPERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Gardens of Cyrus - a local two-player puzzle of shapes, stones and water"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	box.add_child(subtitle)

	var note := Label.new()
	note.text = "Set at Pasargadae in the reign of Cyrus the Great. The history is the setting, not a claim:\nthis is a stylised garden of stone, water and wind, invented for two people at one machine."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 13)
	note.modulate = Color(1, 1, 1, 0.65)
	box.add_child(note)

	box.add_child(HSeparator.new())

	var continue_button := _button(box, "Continue the gardens")
	continue_button.pressed.connect(func() -> void: level_chosen.emit(GameState.first_unfinished()))

	for i in GameState.level_count():
		var text := "%d. %s" % [i + 1, GameState.level_title(i)]
		if GameState.is_completed(i):
			text += "   -  restored in %02d:%02d" % [int(GameState.best_time(i)) / 60, int(GameState.best_time(i)) % 60]
		var button := _button(box, text)
		var index := i
		button.pressed.connect(func() -> void: level_chosen.emit(index))

	box.add_child(HSeparator.new())

	var controls := Label.new()
	controls.text = HELP
	controls.add_theme_font_size_override("font_size", 13)
	controls.modulate = Color(1, 1, 1, 0.8)
	box.add_child(controls)

	var settings_row := HBoxContainer.new()
	settings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_row.add_theme_constant_override("separation", 12)
	box.add_child(settings_row)

	var assist := CheckButton.new()
	assist.text = "Assist mode"
	assist.set_pressed_no_signal(Settings.assist_mode)
	assist.toggled.connect(func(value: bool) -> void: Settings.set_value("assist_mode", value))
	settings_row.add_child(assist)

	var clear := CheckButton.new()
	clear.text = "High contrast"
	clear.set_pressed_no_signal(Settings.high_contrast)
	clear.toggled.connect(func(value: bool) -> void: Settings.set_value("high_contrast", value))
	settings_row.add_child(clear)

	var input := Button.new()
	input.text = "Controls: %s" % Settings.input_method_label()
	input.pressed.connect(func() -> void:
		Settings.cycle_input_method()
		input.text = "Controls: %s" % Settings.input_method_label()
	)
	settings_row.add_child(input)

	var quit := _button(box, "Leave the garden")
	quit.pressed.connect(func() -> void: get_tree().quit())

	for child in box.get_children():
		if child is Button and (child as Button).focus_mode != Control.FOCUS_NONE:
			(child as Button).focus_mode = Control.FOCUS_ALL
	continue_button.grab_focus()


func _button(box: VBoxContainer, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)
	box.add_child(button)
	return button
