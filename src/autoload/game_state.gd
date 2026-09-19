extends Node

## GameState (autoload "GameState")
##
## Level registry and save file. The level list drives the menu, the tests and
## the "next garden" flow, so adding a level means adding one line here plus one
## level script in src/levels/.

const SAVE_PATH := "user://progress.cfg"

const LEVELS := [
	{
		"id": "canal_gate",
		"title": "The Canal Gate",
		"note": "Raise the water, open the pair of gates, reach the terrace.",
	},
	{
		"id": "wind_walk",
		"title": "The Wind Walk",
		"note": "Ride a friend's arm, plug the wind channel, climb the aqueduct.",
	},
	{
		"id": "twin_terraces",
		"title": "The Twin Terraces",
		"note": "One keeper holds, one keeper rides; the bridge is never meant to stand still.",
	},
	{
		"id": "flooded_court",
		"title": "The Flooded Court",
		"note": "Timer, tether and transform - keep above the rising water.",
	},
]

var current_level := 0
var completed: Dictionary = {}
var totals: Dictionary = {}

signal progress_changed


func level_count() -> int:
	return LEVELS.size()


func level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]


func level_id(index: int) -> String:
	return str(level(index)["id"])


func level_title(index: int) -> String:
	return str(level(index)["title"])


func level_note(index: int) -> String:
	return str(level(index)["note"])


func is_completed(index: int) -> bool:
	return completed.has(index)


func best_time(index: int) -> float:
	return float(completed.get(index, {}).get("time", 0.0))


func first_unfinished() -> int:
	for i in LEVELS.size():
		if not is_completed(i):
			return i
	return LEVELS.size() - 1


func complete_level(index: int, time_seconds: float, swaps: int) -> void:
	var previous: Dictionary = completed.get(index, {})
	if previous.is_empty() or time_seconds < float(previous.get("time", 1e9)):
		completed[index] = {"time": time_seconds, "swaps": swaps}
	else:
		previous["swaps"] = swaps
		completed[index] = previous
	totals["swaps"] = int(totals.get("swaps", 0)) + swaps
	save_progress()
	progress_changed.emit()


func all_completed() -> bool:
	return completed.size() >= LEVELS.size()


func save_progress() -> void:
	var config := ConfigFile.new()
	for key in completed.keys():
		config.set_value("levels", str(key), completed[key])
	config.set_value("totals", "swaps", int(totals.get("swaps", 0)))
	config.save(SAVE_PATH)


func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for key in config.get_section_keys("levels"):
		var value: Variant = config.get_value("levels", key)
		if value is Dictionary and key.is_valid_int():
			completed[int(key)] = value
	totals["swaps"] = int(config.get_value("totals", "swaps", 0))
	progress_changed.emit()


func reset_progress() -> void:
	completed.clear()
	totals.clear()
	save_progress()
	progress_changed.emit()


func _ready() -> void:
	load_progress()
