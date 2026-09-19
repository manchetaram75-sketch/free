class_name DecorArt
extends Node2D

## Background decoration, and the garden heart objective marker.
##
## All motifs are stylised to the point of being emblems rather than
## reconstructions: a fluted column with a double-bull capital (a real feature
## of Achaemenid architecture), a cypress, a planter, a lotus rosette. Nothing
## here is copied from a photograph, a scan, an inscription or another game.

@export var size := Vector2(48, 200)
@export var style := "column"


func _ready() -> void:
	z_index = -2


func _draw() -> void:
	match style:
		"column":
			_column()
		"cypress":
			_cypress()
		"planter":
			_planter()
		"heart":
			_heart()
		_:
			_column()


func _column() -> void:
	var h := size.y
	var x := 0.0
	# Base.
	draw_rect(Rect2(Vector2(-size.x * 0.6, -8), Vector2(size.x * 1.2, 8)), Palette.STONE_DARK, true)
	# Fluted shaft: alternating light and shadow pairs read as flutes.
	var flutes := 5
	for i in flutes:
		var t := float(i) / float(flutes)
		var fx := lerpf(-size.x * 0.45, size.x * 0.45, t)
		draw_rect(Rect2(Vector2(fx, -h), Vector2(size.x * 0.10, h - 8.0)), Palette.STONE.darkened(0.18), true)
		draw_rect(Rect2(Vector2(fx + size.x * 0.11, -h), Vector2(size.x * 0.09, h - 8.0)), Palette.STONE_LIGHT, true)
	# Capital: twin bull protomes, reduced to two wedges facing outward.
	var cap_y := -h
	draw_rect(Rect2(Vector2(-size.x * 0.7, cap_y - 10.0), Vector2(size.x * 1.4, 10.0)), Palette.STONE_LIGHT, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-size.x * 0.7, cap_y - 10.0),
		Vector2(-size.x * 1.35, cap_y - 26.0),
		Vector2(-size.x * 1.3, cap_y - 10.0),
	]), Palette.STONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.7, cap_y - 10.0),
		Vector2(size.x * 1.35, cap_y - 26.0),
		Vector2(size.x * 1.3, cap_y - 10.0),
	]), Palette.STONE)
	# On the capital: a disc, echoing the farohar-like roundel without
	# reproducing any particular inscription.
	draw_arc(Vector2(0, cap_y - 26.0), 9.0, 0.0, TAU, 20, Palette.TURQUOISE, 3.0, true)


func _cypress() -> void:
	var h := size.y
	draw_rect(Rect2(Vector2(-4, -12), Vector2(8, 12)), Palette.BRICK_DARK, true)
	var body := PackedVector2Array([
		Vector2(0, -h),
		Vector2(size.x * 0.42, -h * 0.45),
		Vector2(size.x * 0.22, -10.0),
		Vector2(-size.x * 0.22, -10.0),
		Vector2(-size.x * 0.42, -h * 0.45),
	])
	draw_colored_polygon(body, Color("3f6b4a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -h),
		Vector2(size.x * 0.2, -h * 0.5),
		Vector2(0, -10.0),
	]), Color("57865f"))
	draw_line(Vector2(0, -h * 0.9), Vector2(0, -12.0), Color("2f5540"), 2.0)


func _planter() -> void:
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y), Vector2(size.x, size.y)), Palette.BRICK, true)
	draw_rect(Rect2(Vector2(-size.x * 0.55, -size.y - 6.0), Vector2(size.x * 1.1, 6.0)), Palette.STONE, true)
	for i in 4:
		var t := float(i) / 3.0
		draw_line(Vector2(lerpf(-size.x * 0.35, size.x * 0.35, t), -size.y - 6.0), Vector2(lerpf(-size.x * 0.5, size.x * 0.5, t), -size.y - 26.0), Palette.WATER_LIGHT, 2.0)


## The garden heart: a lotus rosette on a plinth, with a dashed "stand here"
## boundary. Both keepers must stand inside it, which is what makes it the
## shared objective rather than an exit door.
func _heart() -> void:
	var w := size.x
	var h := size.y
	var small := minf(w, h)
	var plinth := Rect2(Vector2(-w * 0.5, h * 0.5 - 16.0), Vector2(w, 16.0))
	draw_rect(plinth, Palette.STONE, true)
	draw_rect(plinth, Palette.STONE_LIGHT, false, 2.0)
	var centre := Vector2(0, -small * 0.05)
	for i in 8:
		var a := TAU * float(i) / 8.0
		draw_line(centre, centre + Vector2.from_angle(a) * small * 0.3, Palette.TURQUOISE, 6.0)
	draw_circle(centre, small * 0.13, Palette.GOLD)
	draw_arc(centre, small * 0.3, 0.0, TAU, 32, Palette.STONE_DARK, 3.0, true)
	draw_arc(centre, small * 0.44, 0.0, TAU, 32, Color(Palette.PAPER, 0.35), 2.0, true)
