extends LevelBase

## Garden 4 - The Flooded Court (the pressure garden)
##
## A rising flood, a staircase worn down by time, two gates that must be
## opened on the way up, and water currents that only the light keeper has to
## fight. Everything the first three gardens taught is needed at once, and the
## clock is the water itself.
##
## Fairness rules, deliberately chosen:
##   * the flood ramps: slow at first, faster as it climbs, so the early
##     mistakes are cheap;
##   * a spill pushes the water back and holds it for a moment (FLOOD_MERCY_*),
##     so nobody is trapped in a death loop;
##   * every waystone sits above the water line at the moment it is reached.

const FLOOR := 1200.0
const START_Y := 1600.0
const FINISH_Y := 480.0
const BASE_RATE := 7.0
const RAMP_RATE := 16.0

var flood_y := START_Y
var rising := true

var _mercy := 0.0
var _sheet_back: WaterSheet = null
var _sheet_front: WaterSheet = null


func _build() -> void:
	bounds = Rect2(0, 0, 3000, 1600)
	objective = "Open the two court gates and reach the high alcove before the water does."
	spawn(Vector2(180, FLOOR), Vector2(260, FLOOR))

	add_text(Vector2(170, 1160), "The water only ever rises - but a spill pushes it back a little.\nAim for the next waystone; they always sit above the flood.", 540)

	# --- Lower court ----------------------------------------------------
	add_ground(Rect2(0, FLOOR, 1100, 400))
	add_waystone(Vector2(300, FLOOR), 0)
	add_well(Vector2(520, FLOOR))

	# Staircase: 80px risers, inside a Zam jump but never a shortcut upward.
	add_platform(Vector2(1100, 1120), Vector2(220, 480), "stone")
	add_platform(Vector2(1320, 1040), Vector2(200, 560), "stone")
	add_platform(Vector2(1520, 960), Vector2(200, 640), "stone")
	add_platform(Vector2(1720, 880), Vector2(200, 720), "stone")
	add_platform(Vector2(1920, 800), Vector2(200, 800), "stone")
	add_platform(Vector2(2120, 720), Vector2(200, 880), "stone")
	add_platform(Vector2(2320, 640), Vector2(220, 960), "stone")
	add_waystone(Vector2(1600, 960), 1)
	add_waystone(Vector2(2280, 720), 2)

	# --- Court gates ----------------------------------------------------
	# Weight 2.0: a lone un-rooted Zam is 1.8 and will not do. Rooting (2.3)
	# or standing together (2.8) will. The gate itself is 240 tall so nobody
	# can simply hop over it.
	add_plate(Vector2(1200, 1120), "court_gate", {"weight": 2.0, "sticky": true, "label": "weight 2.0"})
	add_gate(Vector2(1830, 760), Vector2(48, 240), "court_gate", Vector2(0, -260), {"carving": "upper court"})

	# --- Currents -------------------------------------------------------
	# A draught across the fourth step: Vayu is swept, Zam is not.
	add_wind(Vector2(1820, 820), Rect2(-120, -60, 240, 120), Vector2.LEFT, 320.0, {
		"pluggable": false,
		"seal_channel": "flood_sealed",
		"label": "current",
	})
	# ...and the grate Zam can plug to stop it.
	add_wind(Vector2(900, FLOOR - 30), Rect2(-40, -60, 80, 60), Vector2.UP, 700.0, {
		"pluggable": true,
		"label": "grate",
	})

	# --- The alcove -----------------------------------------------------
	# The last step is 160 above the step below it: a leap for Vayu, and a
	# lift for Zam, held low by his partner up on the dry stone.
	add_platform(Vector2(2320, 640), Vector2(200, 960), "stone")
	add_platform(Vector2(2520, 500), Vector2(480, 1100), "stone")
	add_plate(Vector2(2340, 640), "court_heart", {"weight": 1.0, "label": "hold to raise the lift"})
	add_gate(Vector2(2450, 655), Vector2(140, 30), "court_heart", Vector2(0, -140), {
		"speed": 180.0,
		"carving": "lift",
	})
	add_ring(Vector2(2420, 460))
	goal_rect = Rect2(2700, 260, 200, 240)
	goal_requires_both = true
	add_heart(Rect2(2700, 260, 200, 240))
	add_decor(Vector2(860, FLOOR), Vector2(44, 200), "column")
	add_decor(Vector2(2940, 500), Vector2(44, 200), "column")
	add_decor(Vector2(1010, FLOOR), Vector2(40, 130), "cypress")

	_sheet_back = WaterSheet.new()
	_sheet_back.front = false
	_sheet_back.z_index = 14
	add_child(_sheet_back)
	_sheet_front = WaterSheet.new()
	_sheet_front.front = true
	_sheet_front.z_index = 24
	add_child(_sheet_front)
	set_water_level(flood_y)


func _step(delta: float) -> void:
	var vent_plugged := false
	for channel in wind_channels:
		if channel.pluggable and channel.plugged:
			vent_plugged = true
	set_latch("flood_sealed", vent_plugged)

	_mercy = maxf(0.0, _mercy - delta)
	if rising and _mercy <= 0.0:
		flood_y = maxf(FINISH_Y, flood_y - _rising_rate() * delta)
	set_water_level(flood_y)

	var span := Rect2(bounds.position, bounds.size)
	_sheet_back.rect = span
	_sheet_back.surface_y = flood_y
	_sheet_front.rect = span
	_sheet_front.surface_y = flood_y
	if flood_y <= FINISH_Y + 1.0:
		note("The court is full. The alcove is the only dry stone left.")


func _rising_rate() -> float:
	var progress := clampf((START_Y - flood_y) / maxf(START_Y - FINISH_Y, 1.0), 0.0, 1.0)
	return (BASE_RATE + RAMP_RATE * progress * progress) * Settings.hazard_scale()


func on_keeper_spilled(keeper: Keeper, _cause: String) -> void:
	# Mercy: the water gives back a little ground when a keeper is lost.
	flood_y = minf(START_Y, flood_y + Cfg.FLOOD_MERCY_DROP)
	_mercy = Cfg.FLOOD_MERCY_TIME
	spills += 1
	var shake := Settings.shake(9.0)
	if shake > 0.0 and camera != null:
		camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	note("The water pulls back a little. Breathe, then climb.")
	var safe := _safe_checkpoint()
	keeper.teleport(safe)


## Never respawn a keeper under water: fall back to the nearest dry stone at
## or above the current checkpoint, and only then to the highest one.
func _safe_checkpoint() -> Vector2:
	if checkpoint.y < flood_y - 40.0:
		return checkpoint
	for stone in waystones:
		if stone.global_position.y < flood_y - 40.0:
			return stone.global_position + Vector2(0, 4)
	return Vector2(2620, FINISH_Y)
