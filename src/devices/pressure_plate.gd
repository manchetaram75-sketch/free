class_name PressurePlate
extends Device

## A carved floor slab that latches when enough weight rests on it.
##
## weighting rules (see Keeper.plate_weight):
##   any keeper                     1.0
##   a keeper wearing Zam (earth)   1.8
##   a rooted keeper                2.3  <- rooting is a *puzzle* verb, not a stat
## so a plate that needs 2.0 can be held by two light keepers, by one earth
## keeper, or by one rooted earth keeper: several valid solutions per room.

@export var channel := "plate"
@export var size := Vector2(96, 14)
@export var required_weight := 1.0
@export var required_keepers := 1
## Sticky plates stay latched once pressed: a mercyswitch for anxious players.
@export var sticky := false
@export var label := ""

var pressed := false
var current_weight := 0.0
var current_keepers := 0
var _sink := 0.0
var _stuck := false


func _ready() -> void:
	z_index = 5


func tick(delta: float) -> void:
	var weight := 0.0
	var count := 0
	if world != null:
		for body_node in world.pressers():
			var node := body_node
			if node == null or not is_instance_valid(node):
				continue
			var node_2d := node as Node2D
			if node_2d == null:
				continue
			var w := 1.0
			if node.has_method("plate_weight"):
				var value: Variant = node.call("plate_weight")
				if value is float or value is int:
					w = float(value)
			if not _on_slab(node_2d):
				continue
			weight += w
			count += 1

	current_weight = weight
	current_keepers = count
	var satisfied := weight >= required_weight and count >= required_keepers
	if sticky and satisfied:
		_stuck = true
	pressed = satisfied or _stuck
	_sink = move_toward(_sink, 1.0 if pressed else 0.0, delta * 6.0)
	if world != null:
		world.press_source(channel, self, pressed)
	queue_redraw()


func _on_slab(node: Node2D) -> bool:
	var half := size.x * 0.5
	var pos := node.global_position
	var radius := 12.0
	if node.has_method("radius"):
		var value: Variant = node.call("radius")
		if value is float or value is int:
			radius = float(value)
	if absf(pos.x - global_position.x) > half + radius * 0.7:
		return false
	var top := global_position.y
	if pos.y < top - 10.0 or pos.y > top + size.y + 22.0:
		return false
	if node.has_method("is_grounded"):
		var grounded: Variant = node.call("is_grounded")
		if grounded is bool and not bool(grounded):
			return false
	return true


func _draw() -> void:
	var sunk := 4.0 * _sink
	var rect := Rect2(Vector2(-size.x * 0.5, sunk), size)
	draw_rect(Rect2(Vector2(-size.x * 0.5, 0), Vector2(size.x, size.y)), Palette.STONE_DARK, true)
	draw_rect(rect, Palette.STONE if not pressed else Palette.TURQUOISE.darkened(0.15), true)
	draw_rect(rect, Palette.STONE_LIGHT, false, 2.0)

	# Weight requirement glyph: one filled square per unit, drawn hollow until
	# the plate is satisfied. Shape carries the information, not only colour.
	var units := int(ceil(required_weight))
	for i in units:
		var x := -float(units - 1) * 9.0 + float(i) * 18.0
		var r := Rect2(Vector2(x - 6.0, sunk + 1.0), Vector2(12.0, 12.0))
		if pressed:
			draw_rect(r, Palette.INK, true)
		else:
			draw_rect(r, Palette.INK, false, 2.0)
	if required_keepers >= 2:
		draw_arc(Vector2(size.x * 0.5 - 12.0, sunk + size.y * 0.5), 8.0, 0.0, TAU, 16, Palette.INK, 2.0, true)

	if label != "":
		draw_string(ThemeDB.fallback_font, Vector2(-size.x * 0.5, -10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Palette.PAPER, 0.5))

	if Settings.high_contrast and pressed:
		draw_arc(Vector2(0, size.y * 0.5), size.x * 0.7, 0.0, TAU, 24, Palette.PAPER, 2.0, true)
