extends Node

## Settings (autoload "Settings")
##
## Player-facing options, including the accessibility set. Everything here is
## persisted to user://settings.cfg and read by the gameplay code every frame,
## so changes from the pause menu apply instantly.

signal changed(key: String)

const SAVE_PATH := "user://settings.cfg"

## Assist mode is the single "make the game kinder" switch. It widens the
## attunement window for aspect changes and slows environmental hazards.
var assist_mode := false

## Screen shake strength, 0.0 disables it entirely. Motion-sensitive players can
## set this to zero without losing any feedback (the HUD also flashes).
var screen_shake := 1.0

## Multiplies all HUD text sizes.
var ui_scale := 1.0

## Draws bright outlines around keepers and devices for low-vision players.
var high_contrast := false

## &"auto", &"keyboard" or &"sticks" - see Controls.Method.
var default_input_method := &"auto"

var _dirty := false
var _save_timer := 0.0


## Settings are written at most once a second, so dragging the screen-shake
## slider does not hammer the disk.
func _process(delta: float) -> void:
	if not _dirty:
		return
	_save_timer += delta
	if _save_timer >= 1.0:
		_save_timer = 0.0
		_dirty = false
		save_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _dirty:
			save_settings()


func _ready() -> void:
	load_settings()


func attunement_radius() -> float:
	return Cfg.ATTUNEMENT_ASSIST_RADIUS if assist_mode else Cfg.ATTUNEMENT_RADIUS


func hazard_scale() -> float:
	return Cfg.ASSIST_HAZARD_SCALE if assist_mode else 1.0


func shake(amount: float) -> float:
	return amount * clampf(screen_shake, 0.0, 1.0)


func set_value(key: String, value: Variant) -> void:
	match key:
		"assist_mode":
			assist_mode = bool(value)
		"screen_shake":
			screen_shake = clampf(float(value), 0.0, 1.0)
		"ui_scale":
			ui_scale = clampf(float(value), 0.8, 1.6)
		"high_contrast":
			high_contrast = bool(value)
		"default_input_method":
			default_input_method = StringName(value)
		_:
			push_warning("Unknown setting: %s" % key)
			return
	_dirty = true
	changed.emit(key)


func cycle_input_method() -> void:
	var order := [&"auto", &"keyboard", &"sticks"]
	var index := order.find(default_input_method)
	# Controls reacts to the change signal, so no direct call is needed here.
	set_value("default_input_method", String(order[(index + 1) % order.size()]))


func input_method_label() -> String:
	match default_input_method:
		&"keyboard":
			return "SHARED KEYBOARD"
		&"sticks":
			return "TWO CONTROLLERS"
		_:
			return "AUTO (keyboard + any pad)"


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("gameplay", "assist_mode", assist_mode)
	config.set_value("access", "screen_shake", screen_shake)
	config.set_value("access", "ui_scale", ui_scale)
	config.set_value("access", "high_contrast", high_contrast)
	config.set_value("input", "method", String(default_input_method))
	config.save(SAVE_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	assist_mode = bool(config.get_value("gameplay", "assist_mode", assist_mode))
	screen_shake = clampf(float(config.get_value("access", "screen_shake", screen_shake)), 0.0, 1.0)
	ui_scale = clampf(float(config.get_value("access", "ui_scale", ui_scale)), 0.8, 1.6)
	high_contrast = bool(config.get_value("access", "high_contrast", high_contrast))
	default_input_method = StringName(config.get_value("input", "method", String(default_input_method)))
