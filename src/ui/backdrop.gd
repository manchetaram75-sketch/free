class_name Backdrop
extends Node2D

## Stylised sky and distant ridges.
##
## The sky is drawn in *screen* space (an infinitely distant layer) and the
## ridges use a parallax factor, so the world feels deep without any imported
## textures. Everything here is procedural: no external art is used anywhere in
## the project.

var sky_top := Palette.SKY_TOP
var sky_bottom := Palette.SKY_BOTTOM
var ridge_colors := [Palette.RIDGE_FAR, Palette.RIDGE_NEAR]
var ridge_seed := 20250919

var _centre := Vector2.ZERO
var _zoom := 1.0
var _bounds := Rect2(0, 0, 2048, 1152)
var _ridges: Array[PackedVector2Array] = []


func _ready() -> void:
	z_index = -100
	_build_ridges()


func _build_ridges() -> void:
	_ridges.clear()
	var rng := RandomNumberGenerator.new()
	for layer in 2:
		rng.seed = ridge_seed + layer * 977
		var points := PackedVector2Array()
		var x := -3000.0
		var y := 240.0 + float(layer) * 150.0
		points.append(Vector2(x, y + 400.0))
		while x < 6000.0:
			x += rng.randf_range(180.0, 420.0)
			y = clampf(y + rng.randf_range(-90.0, 90.0), 120.0 + float(layer) * 90.0, 460.0 + float(layer) * 120.0)
			points.append(Vector2(x, y))
		points.append(Vector2(x, y + 400.0))
		_ridges.append(points)


func set_view(centre: Vector2, zoom: float, bounds: Rect2) -> void:
	_bounds = bounds
	if centre.distance_to(_centre) < 6.0 and is_equal_approx(_zoom, zoom):
		return
	_centre = centre
	_zoom = zoom
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size / maxf(_zoom, 0.01)
	var rect := Rect2(_centre - view * 0.6, view * 1.2)

	# Sky: horizontal strips standing in for a gradient.
	var strips := 32
	for i in strips:
		var t := float(i) / float(strips - 1)
		var strip := Rect2(rect.position + Vector2(0, rect.size.y * t / float(strips)), Vector2(rect.size.x, rect.size.y / float(strips) + 2.0))
		draw_rect(strip, sky_top.lerp(sky_bottom, t), true)

	# A low sun disc, a recurring device in Persian garden imagery.
	var sun := Vector2(rect.position.x + rect.size.x * 0.72, rect.position.y + rect.size.y * 0.3)
	draw_circle(sun, minf(rect.size.x, rect.size.y) * 0.16, Color(Palette.GOLD, 0.10))
	draw_circle(sun, minf(rect.size.x, rect.size.y) * 0.10, Color(Palette.GOLD, 0.16))

	# Ridges with parallax.
	for layer in _ridges.size():
		var factor := 0.35 + 0.3 * float(layer)
		var offset := Vector2(_centre.x * (1.0 - factor), _centre.y * (1.0 - factor) * 0.35)
		var points := PackedVector2Array()
		for p in _ridges[layer]:
			points.append(Vector2(p.x + offset.x, p.y + offset.y - _bounds.position.y * 0.0))
		var shade := ridge_colors[layer]
		draw_colored_polygon(points, shade if layer == 0 else shade.lightened(0.08))

	# Haze band over the horizon.
	var haze := Rect2(rect.position + Vector2(0, rect.size.y * 0.52), Vector2(rect.size.x, rect.size.y * 0.12))
	draw_rect(haze, Color(Palette.OCHRE, 0.06), true)
