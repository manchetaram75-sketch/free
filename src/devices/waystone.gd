class_name Waystone
extends Device

## A carved waystone: the checkpoint of a garden. Touching it (either keeper)
## makes it the place both keepers return to after a spill, which keeps the
## penalty for a mistake short and the mood cooperative.
##
## In keeping with the project's historical rule this is a *stylised* object:
## a standing stone with a lotus-plate crown, not a reproduction of any
## specific attested monument or inscription.

@export var radius := 54.0
@export var index := 0

var active := false
var _glow := 0.0


func _ready() -> void:
	z_index = 6


func tick(delta: float) -> void:
	_glow = move_toward(_glow, 1.0 if active else 0.0, delta * 3.0)
	queue_redraw()


func touched_by(keeper: Keeper) -> bool:
	return keeper.global_position.distance_to(global_position) <= radius


func _draw() -> void:
	var body := Rect2(Vector2(-16, -74), Vector2(32, 74))
	Palette.draw_masonry(self, body, Palette.STONE, Palette.STONE_DARK, 5)
	# Lotus-plate crown, a common motif in Achaemenid architectural relief -
	# used here as a decorative echo, deliberately simplified.
	var crown_y := body.position.y - 6.0
	for i in 7:
		var t := float(i) / 6.0
		var x := lerpf(-20.0, 20.0, t)
		var h := 10.0 + 8.0 * sin(t * PI)
		draw_line(Vector2(x, crown_y), Vector2(x, crown_y - h), Palette.TURQUOISE, 4.0)
	draw_line(Vector2(-22, crown_y), Vector2(22, crown_y), Palette.STONE_LIGHT, 4.0)
	draw_circle(Vector2(0, crown_y - 26.0), 6.0 + 3.0 * _glow, Palette.GOLD if active else Palette.STONE_LIGHT)

	if active:
		draw_arc(Vector2(0, -37), 40.0, 0.0, TAU, 28, Color(Palette.TURQUOISE, 0.35 + 0.25 * _glow), 2.0, true)
	elif Settings.high_contrast:
		draw_arc(Vector2(0, -37), 40.0, 0.0, TAU, 28, Color(Palette.PAPER, 0.4), 2.0, true)
