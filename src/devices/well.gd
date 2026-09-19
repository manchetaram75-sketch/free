class_name Well
extends Device

## A garden well: the only thing in the world that refills the shared
## reservoir of transformation. Standing in the water refills it; standing in
## it **together** refills it roughly three times faster, so splitting up has a
## real cost.
##
## Wells are also the resurrection point when a keeper is spilled and no
## waystone checkpoint has been reached.

@export var radius := Cfg.WELL_RADIUS
@export var partner_radius := Cfg.WELL_TOGETHER_RANGE

var occupied := [false, false]
var _ripple := 0.0


func tick(delta: float) -> void:
	_ripple = fmod(_ripple + delta, 4.0)
	_sample(delta)
	queue_redraw()


func _sample(delta: float) -> void:
	## Called by the level once per physics frame, before wind and hazards, so
	## that node order never changes how fast the reservoir fills.
	occupied = [false, false]
	if world == null:
		return
	var keepers := world.keepers()
	var inside: Array[Keeper] = []
	for k in keepers:
		if k == null or not is_instance_valid(k):
			continue
		var d := k.global_position.distance_to(global_position)
		if d <= radius:
			inside.append(k)
			if k.index >= 0 and k.index < 2:
				occupied[k.index] = true
	var together := false
	if inside.size() == 2:
		together = inside[0].global_position.distance_to(inside[1].global_position) <= partner_radius
	var rate := 0.0
	if inside.size() >= 1:
		rate = Cfg.WELL_RATE_SOLO if not together else Cfg.WELL_RATE_TOGETHER
	if rate > 0.0:
		world.refill_reservoir(rate * delta)


func fill_rate_per_second() -> float:
	if occupied[0] and occupied[1]:
		return Cfg.WELL_RATE_TOGETHER
	if occupied[0] or occupied[1]:
		return Cfg.WELL_RATE_SOLO
	return 0.0


func _draw() -> void:
	# Basin.
	draw_circle(Vector2.ZERO, radius * 1.25, Palette.STONE_DARK)
	draw_circle(Vector2.ZERO, radius, Palette.LAPIS.darkened(0.35))
	draw_circle(Vector2.ZERO, radius * 0.86, Palette.WATER)
	# Rim carving: eight spokes, echoing a stylised lotus plan rather than any
	# specific archaeological reconstruction.
	for i in 8:
		var a := TAU * float(i) / 8.0
		draw_line(Vector2.from_angle(a) * radius * 0.6, Vector2.from_angle(a) * radius * 0.98, Palette.STONE, 2.0)
	# Ripples when occupied.
	var glow := 1.0 if fill_rate_per_second() >= Cfg.WELL_RATE_TOGETHER else 0.5
	if fill_rate_per_second() > 0.0:
		for i in 3:
			var t := fposmod(_ripple * 0.6 + float(i) / 3.0, 1.0)
			draw_arc(Vector2.ZERO, radius * (0.3 + t * 0.7), 0.0, TAU, 24, Color(Palette.WATER_LIGHT, (1.0 - t) * 0.5 * glow), 2.0, true)
	# A carved band on the rim marks the "both of you" bonus.
	draw_arc(Vector2.ZERO, radius * 1.12, PI, TAU, 24, Palette.TURQUOISE, 4.0, true)
	draw_arc(Vector2.ZERO, radius * 1.12, 0.0, PI, 24, Palette.STONE, 4.0, true)
