class_name TextArt
extends Node2D

## In-world hint text on a translucent stone panel. Lines are authored with
## explicit breaks so the layout is predictable at any camera zoom.

@export var text := ""
@export var width := 420.0
@export var font_size := 18


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	if text == "":
		return
	var lines := text.split("\n")
	var font := ThemeDB.fallback_font
	var line_height := float(font_size) * 1.35
	var height := line_height * float(lines.size()) + 20.0
	draw_rect(Rect2(Vector2(-10, -height + 6.0), Vector2(width + 20.0, height)), Color(Palette.INK, 0.55), true)
	draw_rect(Rect2(Vector2(-10, -height + 6.0), Vector2(width + 20.0, height)), Color(Palette.STONE, 0.5), false, 2.0)
	for i in lines.size():
		var y := -height + 26.0 + line_height * float(i)
		draw_string(font, Vector2(0, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, width, font_size, Palette.PAPER)
