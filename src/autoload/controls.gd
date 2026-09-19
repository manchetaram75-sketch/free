extends Node

## Controls (autoload "Controls")
##
## Builds the whole input map in code, so the project needs no hand-made
## InputMap entries in project.godot, and ships three control schemes that can
## be switched at runtime from the pause menu:
##
##   AUTO     - start on the shared keyboard; a controller that is touched
##              takes over the *second* player first, then the first player.
##   KEYBOARD - both keepers on one keyboard (WASD side / arrow side).
##   STICKS   - one gamepad per keeper.
##
## Every action is also asserted at run time by tests/run_tests.gd, so a typo in
## an action name fails the test suite rather than silently doing nothing.

enum Method { AUTO, KEYBOARD, STICKS }

const PLAYERS := 2

## Internal device ids handed out by the routing layer.
const DEV_KEYBOARD := 100
const DEV_JOY := 200

const ACTIONS := [
	"p1_left", "p1_right", "p1_jump", "p1_action", "p1_change", "p1_restart",
	"p2_left", "p2_right", "p2_jump", "p2_action", "p2_change", "p2_restart",
	"pause", "reset_level",
]

const _KEYBOARD_MAP := {
	"p1_left": [KEY_A],
	"p1_right": [KEY_D],
	"p1_jump": [KEY_SPACE, KEY_W],
	"p1_action": [KEY_S],
	"p1_change": [KEY_F],
	"p1_restart": [KEY_R],
	"p2_left": [KEY_LEFT],
	"p2_right": [KEY_RIGHT],
	"p2_jump": [KEY_UP, KEY_Z, KEY_KP_0],
	"p2_action": [KEY_DOWN, KEY_X],
	"p2_change": [KEY_C],
	"p2_restart": [KEY_V],
	"pause": [KEY_ESCAPE, KEY_P],
	"reset_level": [KEY_BACKSPACE],
}

const _JOY_MAP := {
	"p1_left": [JOY_BUTTON_DPAD_LEFT],
	"p1_right": [JOY_BUTTON_DPAD_RIGHT],
	"p1_jump": [JOY_BUTTON_A],
	"p1_action": [JOY_BUTTON_X],
	"p1_change": [JOY_BUTTON_Y],
	"p1_restart": [JOY_BUTTON_RIGHT_SHOULDER],
	"p2_left": [JOY_BUTTON_DPAD_LEFT],
	"p2_right": [JOY_BUTTON_DPAD_RIGHT],
	"p2_jump": [JOY_BUTTON_A],
	"p2_action": [JOY_BUTTON_X],
	"p2_change": [JOY_BUTTON_Y],
	"p2_restart": [JOY_BUTTON_RIGHT_SHOULDER],
	"pause": [JOY_BUTTON_START],
	"reset_level": [JOY_BUTTON_BACK],
}

signal routing_changed

var method: int = Method.AUTO
var device: Array[int] = [DEV_KEYBOARD, DEV_KEYBOARD]
var pad: Array[int] = [-1, -1]


func _ready() -> void:
	_rebuild_input_map()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	Settings.changed.connect(_on_setting_changed)
	_apply_default_method()


func _on_setting_changed(key: String) -> void:
	if key == "default_input_method":
		set_method(_method_id())


func _apply_default_method() -> void:
	set_method(int(Settings.default_input_method))


func set_method(value: int) -> void:
	method = clampi(value, 0, Method.STICKS)
	if method == Method.KEYBOARD:
		device = [DEV_KEYBOARD, DEV_KEYBOARD]
		pad = [-1, -1]
	elif method == Method.STICKS:
		device = [DEV_JOY, DEV_JOY]
		pad = [0, 1]
	else:
		device = [DEV_KEYBOARD, DEV_KEYBOARD]
		pad = [-1, -1]
		_auto_assign_connected_pads()
	_rebuild_input_map()
	routing_changed.emit()


## True when this player's actions come from the keyboard. In AUTO mode a
## player on the keyboard always answers, so a single controller never locks
## anybody out.
func uses_keyboard(player: int) -> bool:
	return device[player] == DEV_KEYBOARD or method == Method.AUTO


func keyboard_owned(player: int) -> bool:
	return device[player] == DEV_KEYBOARD


func is_joy_keycode(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func _input(event: InputEvent) -> void:
	if method != Method.AUTO:
		return
	if event is InputEventJoypadButton:
		_claim_pad(event.device, true)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) > 0.6:
			_claim_pad(motion.device, true)


## Routes an unclaimed pad to the player who is still on the keyboard,
## preferring player 2 ("hand the second keeper the controller").
func _claim_pad(joy_device: int, emit: bool) -> void:
	if joy_device < 0:
		return
	for p in PLAYERS:
		if device[p] == DEV_JOY and pad[p] == joy_device:
			return
	var order := [1, 0]
	for p in order:
		if device[p] == DEV_KEYBOARD and not _pad_used(joy_device):
			device[p] = DEV_JOY
			pad[p] = joy_device
			_rebuild_input_map()
			if emit:
				routing_changed.emit()
			return


func _pad_used(joy_device: int) -> bool:
	for p in PLAYERS:
		if device[p] == DEV_JOY and pad[p] == joy_device:
			return true
	return false


func _auto_assign_connected_pads() -> void:
	var pads := Input.get_connected_joypads()
	var index := 0
	for p in [1, 0]:
		if index < pads.size():
			device[p] = DEV_JOY
			pad[p] = pads[index]
			index += 1


func _on_joy_connection_changed(joy_device: int, connected: bool) -> void:
	if connected:
		return
	for p in PLAYERS:
		if device[p] == DEV_JOY and pad[p] == joy_device:
			device[p] = DEV_KEYBOARD
			pad[p] = -1
	_rebuild_input_map()
	if method == Method.STICKS:
		# Rebuild the pad list from scratch so the remaining pad keeps working.
		var pads := Input.get_connected_joypads()
		for p in PLAYERS:
			device[p] = DEV_JOY
			pad[p] = pads[p] if p < pads.size() else -1
	routing_changed.emit()


## Human readable device name, used by the HUD and the pause menu.
func device_label(player: int) -> String:
	if method == Method.STICKS or device[player] == DEV_JOY:
		if pad[player] < 0:
			return "no pad"
		return "PAD %d" % (pad[player] + 1)
	return "KEYS"


func jump_action(player: int) -> StringName:
	return StringName("p%d_jump" % (player + 1))


func action_action(player: int) -> StringName:
	return StringName("p%d_action" % (player + 1))


func change_action(player: int) -> StringName:
	return StringName("p%d_change" % (player + 1))


func restart_action(player: int) -> StringName:
	return StringName("p%d_restart" % (player + 1))


func axis(player: int) -> float:
	var left := Input.get_axis(StringName("p%d_left" % (player + 1)), StringName("p%d_right" % (player + 1)))
	return clampf(left, -1.0, 1.0)


## True when any device mapped to this player is using the keyboard, i.e. when
## keyboard input for this player should be honoured.
func _kb_after(event: InputEvent, player: int) -> bool:
	if not uses_keyboard(player):
		return false
	return _keyboard_event(event)


func _keyboard_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	return false


# --- Input map construction -------------------------------------------------

func _rebuild_input_map() -> void:
	for action_name in ACTIONS:
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
		InputMap.add_action(action_name, 0.5)

	var method_id := _method_id()
	for action_name in ACTIONS:
		for key in _keyboard_events_for(action_name, method_id):
			InputMap.action_add_event(action_name, key)
		for joy in _joy_events_for(action_name, method_id):
			InputMap.action_add_event(action_name, joy)


func _method_id() -> int:
	if Settings.default_input_method == &"keyboard":
		return Method.KEYBOARD
	if Settings.default_input_method == &"sticks":
		return Method.STICKS
	return Method.AUTO


func _keyboard_events_for(action_name: String, method_id: int) -> Array[InputEventKey]:
	var out: Array[InputEventKey] = []
	if not _uses_keyboard(action_name, method_id):
		return out
	for code in _KEYBOARD_MAP.get(action_name, []):
		out.append(_key_event(code))
	return out


func _joy_events_for(action_name: String, method_id: int) -> Array[InputEventJoypadButton]:
	var out: Array[InputEventJoypadButton] = []
	if method_id == Method.KEYBOARD:
		return out
	if not _uses_joy(action_name, method_id):
		return out
	var player := _player_of(action_name)
	if player < 0:
		# Meta actions answer on any pad.
		for code in _JOY_MAP.get(action_name, []):
			out.append(_joy_event(code, -1))
		return out
	var device_id := _device_for_player(player)
	if device_id < 0:
		# No pad has been handed to this keeper yet.
		return out
	for code in _JOY_MAP.get(action_name, []):
		out.append(_joy_event(code, device_id))
	return out


func _is_meta_action(action_name: String) -> bool:
	return action_name == "pause" or action_name == "reset_level"


## In the shared-keyboard scheme both keepers are on the keyboard; in the
## two-controller scheme nobody is. A pad may always pause, whichever scheme
## is selected, so nobody is ever stuck.
func _uses_keyboard(action_name: String, method_id: int) -> bool:
	if method_id == Method.STICKS:
		return _is_meta_action(action_name)
	return true


func _uses_joy(action_name: String, method_id: int) -> bool:
	if method_id == Method.KEYBOARD:
		return _is_meta_action(action_name)
	return true


## Which physical pad answers for a keeper: pad 0 for keeper 1 and pad 1 for
## keeper 2 in the two-controller scheme; in AUTO, whichever pad has actually
## been touched by that keeper (-1 = none yet, so the other keeper's pad can
## never drive this one).
func _device_for_player(player: int) -> int:
	if method == Method.AUTO:
		return pad[player]
	return player


func _player_of(action_name: String) -> int:
	if action_name.begins_with("p1_"):
		return 0
	if action_name.begins_with("p2_"):
		return 1
	return -1


func _key_event(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _joy_event(code: JoyButton, joy_device: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = code
	e.device = joy_device
	return e
