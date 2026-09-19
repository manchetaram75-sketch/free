class_name SolidArt
extends Node2D

## Purely decorative child of a solid body: draws the carved stone. It never
## takes part in collision, so the level code can build geometry and looks
## independently.

@export var size := Vector2(64, 64)
@export var style := "masonry"


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	match style:
		"ground":
			Palette.draw_masonry(self, rect, Palette.STONE_DARK, Palette.STONE.darkened(0.35), maxi(2, int(size.y / 22.0)))
			# Parapet band: the top course is lighter, with a carved dentil line.
			var band := Rect2(rect.position, Vector2(rect.size.x, minf(12.0, rect.size.y)))
			draw_rect(band, Palette.STONE, true)
			var x := 0.0
			while x < rect.size.x:
				draw_rect(Rect2(rect.position + Vector2(x + 4.0, 3.0), Vector2(8.0, 5.0)), Palette.STONE_LIGHT, true)
				x += 24.0
		"brick":
			Palette.draw_masonry(self, rect, Palette.BRICK, Palette.BRICK_DARK, maxi(2, int(size.y / 20.0)))
			draw_rect(rect, Palette.BRICK_DARK, false, 2.0)
			var rows := maxi(2, int(size.y / 24.0))
			var step := rect.size.y / float(rows)
			var y := rect.position.y + step
			while y < rect.position.y + rect.size.y - 1.0:
				draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + rect.size.x, y), Palette.BRICK_DARK, 2.0)
				y += step
		"stone":
			Palette.draw_masonry(self, rect, Palette.STONE_LIGHT, Palette.STONE_DARK, maxi(2, int(size.y / 26.0)))
			draw_rect(rect, Palette.STONE.darkened(0.3), false, 3.0)
		_:
			Palette.draw_masonry(self, rect, Palette.STONE, Palette.STONE_DARK, maxi(2, int(size.y / 24.0)))
			draw_rect(rect, Palette.STONE.darkened(0.35), false, 2.0)
	if Settings.high_contrast:
		draw_rect(rect, Color(Palette.PAPER, 0.25), false, 1.0)
