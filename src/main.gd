extends Node

## Scene root. Owns the level list, loads gardens, and wires the level to its
## HUD and link ribbon.
##
## Level scripts extend LevelBase and are instantiated with .new(); they build
## their own geometry in _build(), so there are no .tscn files to keep in sync
## with the code.

const LEVELS: Array = [
	preload("res://src/levels/canal_gate.gd"),
	preload("res://src/levels/wind_walk.gd"),
	preload("res://src/levels/twin_terraces.gd"),
	preload("res://src/levels/flooded_court.gd"),
]

var level: LevelBase = null
var hud: Hud = null
var menu: GardenMenu = null


func _ready() -> void:
	randomize()
	get_tree().paused = false
	var start := _startup_level()
	if start >= 0:
		# Used by the smoke tests: ... -- --level=2
		start_level(start)
	else:
		_show_menu()


## Reads "godot ... -- --level=N" so a garden can be launched directly.
func _startup_level() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			return int(arg.get_slice("=", 1))
	return -1


func _clear() -> void:
	get_tree().paused = false
	if level != null and is_instance_valid(level):
		level.queue_free()
	level = null
	hud = null
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = null


func _show_menu() -> void:
	_clear()
	menu = GardenMenu.new()
	menu.level_chosen.connect(start_level)
	add_child(menu)


func start_level(index: int) -> void:
	_clear()
	GameState.current_level = clampi(index, 0, GameState.level_count() - 1)
	var script: GDScript = LEVELS[GameState.current_level]
	level = script.new() as LevelBase
	level.name = "Garden"
	add_child(level)

	hud = Hud.new()
	hud.level = level
	level.add_child(hud)

	var ribbon := LinkRibbon.new()
	ribbon.z_index = 15
	level.add_child(ribbon)
	ribbon.keepers = level.pair

	level.level_completed.connect(_on_level_completed)
	level.request_restart.connect(_on_restart)
	level.request_menu.connect(_show_menu)
	hud.restart_requested.connect(_on_restart)
	hud.menu_requested.connect(_show_menu)


func _on_restart() -> void:
	start_level(GameState.current_level)


func _on_level_completed(time_seconds: float, spills: int, swaps: int) -> void:
	var index := GameState.current_level
	GameState.complete_level(index, time_seconds, swaps)
	var has_next := index + 1 < GameState.level_count()
	if hud != null:
		hud.show_results(time_seconds, spills, swaps, has_next)
		if has_next:
			hud.next_requested.connect(func() -> void: start_level(index + 1), CONNECT_ONE_SHOT)
		else:
			GameState.reset_progress()
			print("All four gardens restored. Progress reset for the next run.")
