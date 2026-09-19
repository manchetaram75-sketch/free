class_name LinkRibbon
extends Node2D

## The braid of light between the two keepers, plus the tether rope.
##
## This is the game's most important piece of communication feedback: it is
## bright and taut when the pair is attuned (close enough to change Aspect) and
## dim and frayed when they are apart. A player can read "can I change shape
## right now?" without reading a single word.

## Set by the level loader after the keepers exist; the ribbon deliberately
## knows nothing else about the world it is drawn in.
var keepers: Array[Keeper] = []
var _time := 0.0


func _ready() -> void:
	z_index = 15


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if keepers.size() < 2:
		return
	var a := keepers[0]
	var b := keepers[1]
	if not is_instance_valid(a) or not is_instance_valid(b):
		return

	var pa := a.center_position()
	var pb := b.center_position()
	var distance := pa.distance_to(pb)
	var attuned := distance <= Settings.attunement_radius()
	var span := pb - pa
	if span.length() < 1.0:
		return
	var normal := Vector2(-span.y, span.x).normalized()

	var colour := Palette.GOLD if attuned else Palette.STONE_DARK
	var alpha := 0.85 if attuned else 0.45
	var segments := 22
	var amplitude := clampf(distance * 0.045, 2.0, 20.0)
	if not attuned:
		amplitude *= 0.4

	var flow := _time * (2.6 if attuned else 1.2)
	var points := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / float(segments)
		var taper := 1.0 - absf(t - 0.5) * 2.0
		var wobble := sin(t * TAU * 1.5 - flow) * amplitude * taper
		points.append(pa.lerp(pb, t) + normal * wobble)

	if attuned:
		draw_polyline(points, Color(colour, alpha), 3.0, true)
		# A second, brighter strand for the "braided" read.
		var offsets := PackedVector2Array()
		for i in points.size():
			var t := float(i) / float(points.size() - 1)
			offsets.append(points[i] + normal * sin(t * TAU * 1.5 - flow + PI) * 5.0)
		draw_polyline(offsets, Color(Palette.WATER_LIGHT, 0.6), 1.5, true)
	else:
		# Dashed when apart: unmistakable without relying on colour.
		for i in range(0, points.size() - 1, 3):
			draw_line(points[i], points[i + 1], Color(colour, alpha), 2.0, true)

	# Attunement rings on the keepers themselves.
	for keeper in [a, b]:
		var r := Settings.attunement_radius()
		if attuned:
			draw_arc(keeper.center_position(), keeper.height() * 0.7, 0.0, TAU, 24, Color(Palette.GOLD, 0.25), 2.0, true)
		else:
			var p: Vector2 = keeper.center_position()
			draw_arc(p, r * 0.25, PI * 0.85, PI * 1.15, 8, Color(Palette.DANGER, 0.4), 2.0, true)

	# Tether ropes.
	for keeper in [a, b]:
		if not keeper.tether_active or keeper.tether_target == null:
			continue
		if not is_instance_valid(keeper.tether_target):
			continue
		var from: Vector2 = keeper.center_position()
		var to: Vector2 = keeper.tether_anchor_position()
		_draw_rope(from, to, keeper.reeling)


func _draw_rope(from: Vector2, to: Vector2, reeling: bool) -> void:
	var span := to - from
	var segments := 16
	var sag := clampf(span.length() * 0.06, 3.0, 16.0)
	var points := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / float(segments)
		var point := from.lerp(to, t)
		point.y += sin(t * PI) * sag
		points.append(point)
	draw_polyline(points, Palette.PAPER if not reeling else Palette.GOLD, 2.0, true)
	draw_circle(to, 5.0, Palette.GOLD)
