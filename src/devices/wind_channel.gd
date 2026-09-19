class_name WindChannel
extends Device

## A carved wind channel: a rectangular field that carries keepers along its
## axis at `strength` pixels per second. Vayu is light enough to ride it; Zam
## is far too heavy to care, which makes the channel a *role* gate rather than
## a difficulty gate.
##
## An earth-aspect keeper standing inside the channel plugs it with its body
## (elegant vent seals are exactly the kind of masonry detail the Achaemenid
## builders used at Pasargadae, so the fiction and the mechanic agree).

@export var direction := Vector2.RIGHT
## Drift speed in px/s: how fast the channel would carry a light keeper along.
@export var strength := 450.0
@export var area := Rect2(-80, -60, 160, 120)
@export var label := ""
## Optional latch name: while that latch is on, the channel is sealed.
@export var seal_channel := ""
## Pulsing channels turn on and off; a period of 0 means "always blowing".
@export var pulse_period := 0.0
@export var pulse_duty := 0.55
@export var phase_offset := 0.0
## Sealing let off steam when a heavy keeper stands in the mouth of the vent.
@export var pluggable := true

var enabled := true
var plugged := false
var plugger: Keeper = null
var _time := 0.0
var _glow := 0.0


func _ready() -> void:
	z_index = -5


func tick(delta: float) -> void:
	_time += delta
	if pulse_period > 0.0:
		var phase := fposmod(_time + phase_offset, pulse_period) / pulse_period
		enabled = phase < pulse_duty
	else:
		enabled = true
	if world != null and seal_channel != "":
		enabled = enabled and not world.latch(seal_channel)
	plugged = false
	plugger = null
	if world != null and pluggable and enabled:
		for k in world.keepers():
			if k == null or not is_instance_valid(k):
				continue
			if not Forms.can_plug(k.aspect):
				continue
			if _overlaps_body(k):
				plugged = true
				plugger = k
				break
	_glow = move_toward(_glow, 1.0 if active_strength() > 0.0 else 0.0, delta * 4.0)
	queue_redraw()


func active_strength() -> float:
	if not enabled or plugged:
		return 0.0
	return strength


func field_at(point: Vector2) -> Vector2:
	var s := active_strength()
	if s <= 0.0:
		return Vector2.ZERO
	if not world_rect().has_point(point):
		return Vector2.ZERO
	return direction.normalized() * s


func world_rect() -> Rect2:
	return Rect2(to_global(area.position), area.size)


func _overlaps_body(keeper: Keeper) -> bool:
	var rect := world_rect()
	var top := keeper.global_position.y - keeper.height()
	if keeper.global_position.x < rect.position.x or keeper.global_position.x > rect.position.x + rect.size.x:
		return false
	return keeper.global_position.y > rect.position.y and top < rect.position.y + rect.size.y


func _draw() -> void:
	var rect := area
	var flow := active_strength() / maxf(strength, 1.0)
	var tint := Palette.TURQUOISE if flow > 0.0 else Palette.STONE_DARK
	# The carved mouth of the channel.
	draw_rect(Rect2(rect.position, rect.size), Color(tint, 0.16 + 0.18 * flow), true)
	draw_rect(Rect2(rect.position, rect.size), Color(tint, 0.5), false, 2.0)
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Palette.STONE, 3.0)
	draw_line(rect.position + Vector2(0, rect.size.y), rect.position + rect.size, Palette.STONE, 3.0)

	var axis := direction.normalized()
	var across := Vector2(-axis.y, axis.x)
	var centre := rect.position + rect.size * 0.5
	var span := absf(rect.size.x * axis.x) + absf(rect.size.y * axis.y)
	var perp := absf(rect.size.x * across.x) + absf(rect.size.y * across.y)
	var rows := 3
	for row in rows:
		var offset := (float(row) - float(rows - 1) * 0.5) * perp * 0.3
		var travel := fposmod(_time * 1.6 * (0.6 + flow), 1.0)
		for i in 4:
			var t := fposmod(travel + float(i) * 0.25, 1.0)
			var at := centre + across * offset + axis * ((t - 0.5) * span)
			if flow <= 0.01:
				continue
			var tip := at + axis * 12.0
			draw_line(at, tip, Color(Palette.WATER_LIGHT, 0.8 * flow), 2.0)
			draw_line(tip, tip - axis * 6.0 + across * 5.0, Color(Palette.WATER_LIGHT, 0.8 * flow), 2.0)
			draw_line(tip, tip - axis * 6.0 - across * 5.0, Color(Palette.WATER_LIGHT, 0.8 * flow), 2.0)

	# Sealed vents show a heavy stone plug and a puff of escaping air.
	if plugged:
		var mouth := Vector2.ZERO
		var size := Vector2.ZERO
		if absf(axis.x) > 0.5:
			size = Vector2(18.0, rect.size.y)
			mouth = centre - axis * (rect.size.x * 0.5)
		else:
			size = Vector2(rect.size.x, 18.0)
			mouth = centre - axis * (rect.size.y * 0.5)
		draw_rect(Rect2(mouth - size * 0.5, size), Palette.PLUGGED, true)
		draw_rect(Rect2(mouth - size * 0.5, size), Palette.STONE, false, 3.0)
		for i in 3:
			var t := fposmod(_time * 1.4 + float(i) / 3.0, 1.0)
			draw_circle(mouth - axis * 26.0 + across * ((t - 0.5) * 34.0) + axis * (t * 10.0), 4.0 * (1.0 - t), Color(Palette.PAPER, 0.35 * (1.0 - t)))

	if label != "":
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Palette.PAPER, 0.45))
