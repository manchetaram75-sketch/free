class_name WaterSheet
extends Node2D

## The flood, drawn twice: a solid body behind the keepers and a translucent
## sheet in front of them, so a submerged keeper reads as *underwater* without
## hiding the puzzle above the surface.
##
## Purely visual - all water physics lives in Keeper via KeeperWorld's
## get_water_level().

var rect := Rect2(0, 0, 2048, 1152)
var surface_y := 1200.0
var front := false

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if surface_y >= rect.end.y:
		return
	var top := Rect2(Vector2(rect.position.x, surface_y), Vector2(rect.size.x, rect.end.y - surface_y))
	var colour := Color(Palette.WATER, 0.34 if front else 0.72)
	draw_rect(top, colour, true)

	# Surface line with a slow swell.
	var points := PackedVector2Array()
	var step := 64.0
	var x := rect.position.x - step
	while x <= rect.end.x + step:
		var wave := sin(x * 0.008 + _time * 1.1) * 5.0 + sin(x * 0.021 - _time * 0.7) * 3.0
		points.append(Vector2(x, surface_y + wave))
		x += step
	if points.size() > 1:
		draw_polyline(points, Color(Palette.WATER_LIGHT, 0.9 if not front else 0.5), 3.0 if not front else 2.0, true)

	if front:
		return

	# Murky depth bands, so the water reads as volume rather than a flat fill.
	for i in 3:
		var band_y := surface_y + 40.0 + float(i) * 90.0
		if band_y > rect.end.y:
			break
		draw_rect(Rect2(rect.position.x, band_y, rect.size.x, 26.0), Color(Palette.LAPIS.darkened(0.2), 0.10), true)

	# Danger line where the water will not be survivable for long.
	var danger := surface_y + 60.0
	draw_line(Vector2(rect.position.x, danger), Vector2(rect.end.x, danger), Color(Palette.DANGER, 0.12), 30.0)
