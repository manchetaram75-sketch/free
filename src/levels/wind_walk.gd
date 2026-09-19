extends LevelBase

## Garden 2 - The Wind Walk (teaching garden)
##
## Teaches the remaining verbs:
##   1. updrafts are Vayu's ladder; Zam is too heavy to notice them;
##   2. Zam's body plugs a vent, and a sealed vent stops a crosswind;
##   3. the shoulder launch - carry your partner and jump.
##
## The crosswind section has two honest solutions: sequence the seal, or ride
## the tether ring through the gust. Either is a win.

const GROUND := 1000.0
const WALL_X := 2400.0


func _build() -> void:
	bounds = Rect2(0, 0, 3200, 1600)
	objective = "Ride the wind, seal the vent and launch your partner up the aqueduct."
	spawn(Vector2(160, GROUND), Vector2(240, GROUND))

	add_text(Vector2(150, 960), "Only the swift keeper rides an updraft.\nOnly the sturdy keeper can plug a vent with his body.\nCarry your partner by pressing ACTION beside them.", 520)

	add_ground(Rect2(0, GROUND, 3200, 400))

	# --- 1. The updraft and Vayu's ledge --------------------------------
	add_wind(Vector2(420, 765), Rect2(-120, -335, 240, 610), Vector2.UP, 450.0, {
		"pluggable": false,
		"label": "updraft",
	})
	add_platform(Vector2(560, 480), Vector2(280, 40), "brick")
	add_decor(Vector2(340, GROUND), Vector2(44, 140), "cypress")

	# Sticky plate at ground level, reached by dropping off the ledge.
	add_plate(Vector2(940, GROUND), "gate_a", {"weight": 1.0, "sticky": true, "label": "opens the way"})
	add_gate(Vector2(1120, GROUND - 80), Vector2(48, 160), "gate_a", Vector2(0, -170), {"carving": "way"})
	add_waystone(Vector2(1240, GROUND), 0)

	# --- 2. Plug the vent, cross the gust -------------------------------
	add_wind(Vector2(1500, GROUND - 20), Rect2(-40, -40, 80, 80), Vector2.UP, 700.0, {
		"pluggable": true,
		"label": "vent",
	})
	add_wind(Vector2(1900, 700), Rect2(-300, -90, 600, 180), Vector2.LEFT, 320.0, {
		"seal_channel": "wind_sealed",
		"pluggable": false,
		"label": "crosswind",
	})

	# The gusty walkway: Zam shrugs it off, Vayu does not.
	add_platform(Vector2(1700, 780), Vector2(520, 30), "brick")
	add_plate(Vector2(2140, 780), "crosswind_off", {"weight": 1.0, "sticky": true, "label": "seals the gust"})
	# A ring above the walkway: swing through the gust instead of sealing it.
	add_ring(Vector2(1900, 620))
	# Stair for Zam up to the walkway.
	add_platform(Vector2(1560, 960), Vector2(80, 40), "stone")
	add_platform(Vector2(1640, 900), Vector2(60, 100), "stone")
	add_platform(Vector2(1690, 840), Vector2(40, 60), "stone")
	add_waystone(Vector2(1800, GROUND), 1)
	add_decor(Vector2(2200, GROUND), Vector2(44, 140), "cypress")

	# --- 3. The shoulder launch and the lift ----------------------------
	add_solid(Rect2(WALL_X, 480, 60, 520), "masonry")
	add_platform(Vector2(2080, 620), Vector2(160, 40), "stone")
	add_plate(Vector2(2620, 480), "lift", {"weight": 1.0, "label": "hold to raise the lift"})
	add_gate(Vector2(2320, 1015), Vector2(160, 30), "lift", Vector2(0, -520), {
		"speed": 260.0,
		"carving": "lift",
	})
	# The terrace Zam rides up to.
	add_platform(Vector2(2400, 480), Vector2(640, 60), "brick")
	add_decor(Vector2(2560, 480), Vector2(44, 240), "column")
	add_decor(Vector2(2960, 480), Vector2(44, 240), "column")
	add_ring(Vector2(2450, 380))

	goal_rect = Rect2(2860, 280, 140, 200)
	goal_requires_both = true
	add_heart(Rect2(2860, 280, 140, 200))


func _step(_delta: float) -> void:
	# The vent Zam plugs and the far-side plate are two ways to stop the gust.
	var vent_plugged := false
	for channel in wind_channels:
		if channel.pluggable and channel.plugged:
			vent_plugged = true
	set_latch("wind_sealed", vent_plugged or latch("crosswind_off"))
