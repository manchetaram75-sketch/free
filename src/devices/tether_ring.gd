class_name TetherRing
extends Device

## A bronze ring set into the masonry. Vayu can throw the tether to it and
## swing or reel. Rings on a moving platform report their own movement, so the
## rope pulls the rider along with the platform.

@export var radius := 18.0
@export var label := ""

var in_range := false
var occupied := false

var _last_position := Vector2.ZERO
var _velocity := Vector2.ZERO
var _spin := 0.0


func _ready() -> void:
	z_index = 6
	_last_position = global_position


func tick(delta: float) -> void:
	_velocity = (global_position - _last_position) / maxf(delta, 0.0001)
	_last_position = global_position
	_spin = fmod(_spin + delta * 0.6, TAU)

	var nearest := 1.0e9
	if world != null:
		for k in world.keepers():
			if k == null or not is_instance_valid(k):
				continue
			nearest = minf(nearest, k.global_position.distance_to(global_position))
	in_range = nearest <= Cfg.RING_REACH
	occupied = false
	queue_redraw()


func get_velocity() -> Vector2:
	return _velocity


func _draw() -> void:
	var lit := in_range or Settings.high_contrast
	var metal := Palette.GOLD if lit else Palette.STONE_DARK
	draw_circle(Vector2.ZERO, radius * 1.35, Color(Palette.INK, 0.35))
	draw_arc(Vector2.ZERO, radius * 1.15, 0.0, TAU, 28, Palette.STONE_DARK, 5.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, metal, 4.0, true)
	if lit:
		draw_arc(Vector2.ZERO, radius * 1.5, _spin, _spin + PI * 0.6, 20, Color(Palette.WATER_LIGHT, 0.7), 2.0, true)
		draw_arc(Vector2.ZERO, radius * 1.5, _spin + PI, _spin + PI * 1.6, 20, Color(Palette.WATER_LIGHT, 0.7), 2.0, true)
	if label != "":
		draw_string(ThemeDB.fallback_font, Vector2(-radius, -radius * 2.2), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 12, Color(Palette.PAPER, 0.5))
