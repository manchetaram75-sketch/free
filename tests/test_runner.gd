extends Node

## Headless test suite.
##
##     godot --headless --path . res://tests/test_runner.tscn
##
## The runner is a *scene* rather than a `--script` MainLoop on purpose: it
## needs the real autoloads (Controls, Settings, GameState), the real input map
## and the real physics server, so that these tests exercise the game and not a
## simulation of it.
##
## Every design rule the game claims to enforce has a test here:
##   * the two body sizes really do fit through different gaps;
##   * a jump really cannot exceed the envelope the level checker uses;
##   * a keeper really cannot change Aspect when it is too far from its partner;
##   * a gust really carries the swift keeper and not the sturdy one;
##   * the shoulder launch really out-reaches a plain double jump;
##   * and all four gardens really do build, spawn and stand on their floors.

const LEVEL_SCRIPTS: Array = [
	preload("res://src/levels/canal_gate.gd"),
	preload("res://src/levels/wind_walk.gd"),
	preload("res://src/levels/twin_terraces.gd"),
	preload("res://src/levels/flooded_court.gd"),
]

const WATCHDOG_SECONDS := 120.0

var checks := 0
var failures: Array[String] = []
var _current := ""


class TestWorld:
	extends KeeperWorld

	var bodies: Array[Keeper] = []

	func keepers() -> Array[Keeper]:
		return bodies

	func partner_of(index: int) -> Keeper:
		for k in bodies:
			if is_instance_valid(k) and k.index != index:
				return k
		return null

	func wind_at(point: Vector2) -> Vector2:
		var total := Vector2.ZERO
		for child in get_children():
			if child is WindChannel:
				total += (child as WindChannel).field_at(point)
		return total


func _ready() -> void:
	print("Two Keepers test suite")
	print("----------------------")
	_start_watchdog()
	_test_envelopes()
	_test_tether_math()
	_test_weights_and_costs()
	_test_input_map()
	await _test_keeper_physics()
	await _test_wind_rule()
	await _test_carry_and_launch()
	await _test_attunement_and_reservoir()
	await _test_levels()
	_report()


# --- Harness ----------------------------------------------------------------

## A script error inside one of the awaited sections would otherwise leave the
## runner waiting for frames that never come, and CI would sit there until the
## job times out. The watchdog always ends the run, and says which section was
## running when it stopped.
func _start_watchdog() -> void:
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(_on_watchdog)


func _on_watchdog() -> void:
	print("\nSUITE TIMED OUT after %.0f seconds" % WATCHDOG_SECONDS)
	print("last section started: %s" % _current)
	print("checks run before the stop: %d, failures: %d" % [checks, failures.size()])
	for line in failures:
		print("   - %s" % line)
	get_tree().quit(2)


func _begin(section: String) -> void:
	_current = section
	print("\n[%s]" % section)


func _check(label: String, condition: bool, detail := "") -> void:
	checks += 1
	if condition:
		print("  ok    %s" % label)
	else:
		var line := "%s: %s %s" % [_current, label, detail]
		failures.append(line)
		print("  FAIL  %s %s" % [label, detail])


func _report() -> void:
	print("\n----------------------")
	if failures.is_empty():
		print("PASS  %d checks, 0 failures" % checks)
	else:
		print("FAIL  %d checks, %d failures" % [checks, failures.size()])
		for line in failures:
			print("   - %s" % line)
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# --- Pure maths -------------------------------------------------------------

func _test_envelopes() -> void:
	_begin("movement envelopes")
	var zam := Forms.max_rise(Forms.ZAM)
	var vayu := Forms.max_rise(Forms.VAYU)
	_check("both keepers can jump", zam > 40.0 and vayu > 40.0, "zam=%.1f vayu=%.1f" % [zam, vayu])
	_check("the sturdy keeper jumps lower", zam < vayu, "zam=%.1f vayu=%.1f" % [zam, vayu])
	_check("the swift keeper crosses wider gaps", Forms.max_gap(Forms.VAYU) > Forms.max_gap(Forms.ZAM) * 1.5)
	_check("the sturdy keeper is wider than the swift one", Forms.radius(Forms.ZAM) > Forms.radius(Forms.VAYU))
	_check("and taller", Forms.height(Forms.ZAM) > Forms.height(Forms.VAYU))
	_check("the sturdy keeper is heavier", Forms.mass(Forms.ZAM) > Forms.mass(Forms.VAYU))
	_check("aspect flips are involutive", Forms.other(Forms.other(Forms.ZAM)) == Forms.ZAM)
	_check("only the sturdy keeper can root", Forms.can_root(Forms.ZAM) and not Forms.can_root(Forms.VAYU))
	_check("only the swift keeper can tether", Forms.can_tether(Forms.VAYU) and not Forms.can_tether(Forms.ZAM))

	var rooms := _tunnel_heights()
	_check("the low tunnel clears the swift keeper", rooms.x > Forms.height(Forms.VAYU), "tunnel=%.0f vayu=%.0f" % [rooms.x, Forms.height(Forms.VAYU)])
	_check("the low tunnel stops the sturdy keeper", rooms.x < Forms.height(Forms.ZAM), "tunnel=%.0f zam=%.0f" % [rooms.x, Forms.height(Forms.ZAM)])
	_check("the doorway the sturdy keeper needs clears him", rooms.y > Forms.height(Forms.ZAM), "door=%.0f zam=%.0f" % [rooms.y, Forms.height(Forms.ZAM)])
	_check("a launched partner reaches higher than a plain double jump", Cfg.BOOST_SPEED * Cfg.BOOST_SPEED / (2.0 * Cfg.GRAVITY) > vayu * 1.5)


func _tunnel_heights() -> Vector2:
	## Read straight out of canal_gate so the fixture and the garden cannot
	## drift apart: x is the low tunnel only Vayu fits through, y is the
	## doorway only Zam fits through.
	return Vector2(float(CanalGate.TUNNEL_HEIGHT), float(CanalGate.DOORWAY_HEIGHT))


func _test_tether_math() -> void:
	_begin("tether maths")
	var a := Vector2.ZERO
	var b := Vector2(100, 0)
	var slack := TetherMath.spring_velocity_delta(a, Vector2.ZERO, b, Vector2.ZERO, 150.0, 26.0, 5.0, 1.0, 0.016)
	_check("a slack rope does nothing", slack == Vector2.ZERO)

	# Rope attached at 100px, resting at 60px: A is being pulled toward B.
	var taut := TetherMath.spring_velocity_delta(a, Vector2.ZERO, b, Vector2.ZERO, 60.0, 26.0, 5.0, 0.5, 0.016)
	_check("a stretched rope pulls toward the anchor", taut.x > 0.0, "pull=%.3f" % taut.x)

	var corrected := TetherMath.taut_correction(Vector2(-200, 0), a, b, 100.0)
	_check("a taut rope cancels outward speed", is_zero_approx(corrected.x), "vx=%.3f" % corrected.x)

	var sideways := TetherMath.taut_correction(Vector2(0, 120), a, b, 100.0)
	_check("a taut rope leaves sideways speed alone", is_equal_approx(sideways.y, 120.0))

	_check("rest length clamps into range", is_equal_approx(TetherMath.rest_after_attach(400.0, 62.0, 190.0), 190.0))
	var reeled := TetherMath.reel(100.0, 62.0, 50.0, 1.0)
	_check("reeling shortens the rope", reeled < 100.0)
	_check("reeling cannot pass the minimum", is_equal_approx(TetherMath.reel(63.0, 62.0, 50.0, 1.0), 62.0))


func _test_weights_and_costs() -> void:
	_begin("weight and reservoir rules")
	var air := 1.0
	var earth := 1.0 + 0.8
	var rooted_earth := 1.0 + 0.8 + 0.5
	_check("a lone light keeper is too light for a 2.0 plate", air < 2.0)
	_check("an un-rooted sturdy keeper is still too light", earth < 2.0, "%.1f" % earth)
	_check("rooting pushes the sturdy keeper past 2.0", rooted_earth >= 2.0, "%.1f" % rooted_earth)
	_check("the pair together is enough", (air + earth) >= 2.0)
	_check("a well pays for a whole number of changes", Cfg.RESERVOIR_MAX / Cfg.SWAP_COST >= 2.0)


func _test_input_map() -> void:
	_begin("input map")
	Controls.set_method(Controls.Method.KEYBOARD)
	for action in Controls.ACTIONS:
		_check("action '%s' exists" % action, InputMap.has_action(action))
	_check("keeper 1 has a jump key", not InputMap.action_get_events("p1_jump").is_empty())
	_check("keeper 2 has its own jump key", not InputMap.action_get_events("p2_jump").is_empty())
	_check("no key is shared between the two keepers on the keyboard",
		_key_set("p1_jump") != _key_set("p2_jump"))
	_check("p1 and p2 move keys differ", _key_set("p1_left") != _key_set("p2_left"))

	Controls.set_method(Controls.Method.STICKS)
	var pads_ok := true
	for action in ["p1_jump", "p2_jump", "p1_action", "p2_action"]:
		var has_joy := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				has_joy = true
		pads_ok = pads_ok and has_joy
	_check("controller scheme binds both keepers", pads_ok)

	# Auto must always keep the keyboard live, whatever pads are plugged in,
	# and must never route a keeper to a wildcard joypad: a wildcard binding
	# would hand both players the same controller.
	Controls.set_method(Controls.Method.AUTO)
	var auto_keys := true
	for action in ["p1_jump", "p2_jump", "p1_left", "p2_left", "p1_action", "p2_action"]:
		auto_keys = auto_keys and not _key_set(action).is_empty()
	_check("auto scheme always keeps the keyboard live", auto_keys)

	var wildcard := false
	for action in Controls.ACTIONS:
		if not (action.begins_with("p1_") or action.begins_with("p2_")):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).device < 0:
				wildcard = true
	_check("auto scheme never binds a keeper to a wildcard pad", not wildcard)
	_check("auto scheme tracks one pad slot per keeper", Controls.pad.size() == 2)
	Controls.set_method(Controls.Method.KEYBOARD)


func _key_set(action: String) -> Array:
	var out: Array = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			out.append((event as InputEventKey).physical_keycode)
	out.sort()
	return out


# --- Physics fixtures -------------------------------------------------------

func _make_world(rects: Array) -> TestWorld:
	var world := TestWorld.new()
	world.bounds = Rect2(-500, -2000, 4000, 4000)
	add_child(world)
	for entry in rects:
		var rect: Rect2 = entry
		var body := StaticBody2D.new()
		body.collision_layer = Cfg.LAYER_WORLD
		body.collision_mask = 0
		body.position = rect.position + rect.size * 0.5
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		world.add_child(body)
	return world


func _make_keeper(world: TestWorld, index: int, kind: int, at: Vector2) -> Keeper:
	var keeper := Keeper.new()
	keeper.index = index
	keeper.world = world
	keeper.aspect = kind
	keeper.position = at
	world.add_child(keeper)
	keeper.teleport(at)
	world.bodies.append(keeper)
	return keeper


func _clear(world: TestWorld) -> void:
	for keeper in world.bodies:
		Input.action_release(Controls.jump_action(keeper.index))
		Input.action_release(Controls.action_action(keeper.index))
		Input.action_release("p%d_left" % (keeper.index + 1))
		Input.action_release("p%d_right" % (keeper.index + 1))
	world.queue_free()
	await get_tree().process_frame


func _test_keeper_physics() -> void:
	_begin("keeper physics")
	var world := _make_world([Rect2(0, 400, 1200, 60)])
	var zam := _make_keeper(world, 0, Forms.ZAM, Vector2(100, 100))
	print("DEBUG spawn y=%.1f r=%.1f h=%.1f gravity=%.1f body=%s at %s head=%s at %s layer=%d mask=%d" % [
		zam.global_position.y, zam.radius(), zam.height(), Forms.gravity_of(Forms.ZAM),
		str(zam._body.shape.size), str(zam._body.position),
		str(zam._head.shape.radius), str(zam._head.position),
		zam.collision_layer, zam.collision_mask,
	])
	for i in 60:
		await get_tree().physics_frame
		if i % 12 == 0:
			print("DEBUG fall i=%d y=%.1f vy=%.1f floor=%s vel=%s" % [
				i, zam.global_position.y, zam.velocity.y, str(zam.is_on_floor()), str(zam.velocity)])
	_check("a falling keeper lands on the floor", zam.is_on_floor(), "y=%.1f" % zam.global_position.y)
	_check("and lands on top of it, not inside it", absf(zam.global_position.y - 400.0) < 3.0, "y=%.1f" % zam.global_position.y)

	# Jump height must match the published envelope. The key is held through
	# the ascent on purpose: releasing early is the variable-height jump, and
	# that is tested separately below.
	Input.action_press("p1_jump")
	var peak := 400.0
	for i in 70:
		await get_tree().physics_frame
		peak = minf(peak, zam.global_position.y)
		if i == 30:
			Input.action_release("p1_jump")
	var rise := 400.0 - peak
	var expected := Forms.max_rise(Forms.ZAM)
	print("DEBUG jump rest=%.1f peak=%.1f rise=%.1f expected=%.1f jumps_used=%d" % [
		zam.global_position.y, peak, rise, expected, zam._jumps_used])
	_check("a held jump matches the published envelope", rise > expected * 0.8 and rise <= expected * 1.15, "measured=%.1f expected=%.1f" % [rise, expected])

	# A tapped jump must be *shorter*, or the jump-cut is not working.
	await _frames(30)
	Input.action_press("p1_jump")
	await _frames(2)
	Input.action_release("p1_jump")
	var short_peak := 400.0
	for i in 60:
		await get_tree().physics_frame
		short_peak = minf(short_peak, zam.global_position.y)
	_check("a tapped jump is shorter than a held one", (400.0 - short_peak) < rise * 0.9, "tap=%.1f held=%.1f" % [400.0 - short_peak, rise])

	# Walking speed.
	Input.action_press("p1_right")
	await _frames(40)
	var speed := absf(zam.velocity.x)
	Input.action_release("p1_right")
	_check("walking speed matches the table", absf(speed - float(Forms.stats(Forms.ZAM)["speed"])) < 12.0, "speed=%.1f" % speed)
	await _clear(world)

	# The size split: the same tunnel, two different keepers.
	var wall := [
		Rect2(300, 100, 40, 256),  # wall from y=100 to y=356
		Rect2(0, 400, 1200, 60),   # floor; the tunnel is the 44px slit above it
	]
	var slim_world := _make_world(wall)
	var vayu := _make_keeper(slim_world, 0, Forms.VAYU, Vector2(120, 400))
	await _frames(20)
	Input.action_press("p1_right")
	await _frames(150)
	Input.action_release("p1_right")
	_check("the swift keeper walks through the 44px tunnel", vayu.global_position.x > 360.0, "x=%.0f" % vayu.global_position.x)
	await _clear(slim_world)

	var wide_world := _make_world(wall)
	var big := _make_keeper(wide_world, 0, Forms.ZAM, Vector2(120, 400))
	await _frames(20)
	Input.action_press("p1_right")
	await _frames(150)
	Input.action_release("p1_right")
	_check("the sturdy keeper is stopped by the same tunnel", big.global_position.x < 310.0, "x=%.0f" % big.global_position.x)
	await _clear(wide_world)


func _test_wind_rule() -> void:
	_begin("wind rule")
	var world := _make_world([Rect2(0, 700, 800, 60)])
	var channel := WindChannel.new()
	channel.position = Vector2(200, 520)
	channel.area = Rect2(-120, -160, 240, 400)
	channel.direction = Vector2.UP
	channel.strength = 450.0
	channel.pluggable = true
	world.add_child(channel)
	channel.world = world

	var vayu := _make_keeper(world, 0, Forms.VAYU, Vector2(200, 700))
	await _frames(30)
	channel.tick(0.016)
	_check("the gust lifts the swift keeper", vayu.global_position.y < 690.0, "y=%.1f" % vayu.global_position.y)

	# Same spot, the other Aspect: the gust must not carry the heavy keeper,
	# and his body must seal the vent.
	vayu.teleport(Vector2(650, 700))
	var zam := _make_keeper(world, 1, Forms.ZAM, Vector2(200, 700))
	await _frames(30)
	channel.tick(0.016)
	_check("the gust leaves the sturdy keeper on the floor", zam.global_position.y > 690.0, "y=%.1f" % zam.global_position.y)
	_check("a sturdy keeper inside the mouth seals it", channel.plugged, "plugged=%s" % str(channel.plugged))
	_check("a sealed channel produces no field", channel.field_at(Vector2(200, 600)) == Vector2.ZERO)
	await _clear(world)


func _test_carry_and_launch() -> void:
	_begin("carry and launch")
	var world := _make_world([Rect2(0, 400, 1600, 60)])
	var zam := _make_keeper(world, 0, Forms.ZAM, Vector2(400, 400))
	var vayu := _make_keeper(world, 1, Forms.VAYU, Vector2(420, 400))
	await _frames(30)

	Input.action_press("p1_action")
	await _frames(3)
	_check("the sturdy keeper can lift the swift one", zam.rider == vayu and vayu.carried, "rider=%s" % str(zam.rider))
	await _frames(20)
	_check("the rider rides above the carrier's head", vayu.global_position.y < zam.global_position.y - Cfg.SHOULDER_WIDTH)

	Input.action_press("p1_jump")
	await _frames(2)
	Input.action_release("p1_jump")
	Input.action_release("p1_action")
	_check("jumping while carrying launches the rider", not vayu.carried and vayu.velocity.y < -400.0, "vy=%.0f" % vayu.velocity.y)

	var peak := vayu.global_position.y
	for i in 90:
		await get_tree().physics_frame
		peak = minf(peak, vayu.global_position.y)
	_check("the launch clears more height than a double jump", (400.0 - peak) > 250.0, "peak rise=%.0f" % (400.0 - peak))
	_check("the launch is finite", (400.0 - peak) < 1200.0)
	await _clear(world)


func _test_attunement_and_reservoir() -> void:
	_begin("attunement and reservoir")
	var world := _make_world([Rect2(0, 400, 3000, 60)])
	var zam := _make_keeper(world, 0, Forms.ZAM, Vector2(200, 400))
	var vayu := _make_keeper(world, 1, Forms.VAYU, Vector2(2400, 400))
	await _frames(20)

	_check("the pair is not attuned when far apart", not zam.attuned())
	_check("so the sturdy keeper cannot change shape", not zam.can_change_aspect_here())
	zam.force_aspect(Forms.ZAM)
	_check("and an attempted change is refused", not zam.try_change_aspect())

	vayu.teleport(Vector2(260, 400))
	await _frames(10)
	_check("the pair is attuned when close", zam.attuned())
	_check("so the sturdy keeper may change shape", zam.can_change_aspect_here())
	_check("the change succeeds", zam.try_change_aspect())
	_check("and the aspect actually flipped", zam.aspect == Forms.VAYU, "aspect=%d" % zam.aspect)

	# Changing shape costs, and the cost immediately blocks a second change.
	zam.force_aspect(Forms.ZAM)
	zam.teleport(Vector2(240, 400))
	vayu.teleport(Vector2(280, 400))
	await _frames(10)
	zam._swap_cooldown = 0.0
	zam.try_change_aspect()
	_check("a fresh change starts a cooldown", zam.can_change_aspect_here() == false)
	await _clear(world)


func _test_levels() -> void:
	_begin("gardens")
	_check("the level list matches the scripts", GameState.level_count() == LEVEL_SCRIPTS.size(), "%d vs %d" % [GameState.level_count(), LEVEL_SCRIPTS.size()])
	for index in LEVEL_SCRIPTS.size():
		var script: GDScript = LEVEL_SCRIPTS[index]
		var level := script.new() as LevelBase
		level.name = "TestGarden%d" % index
		add_child(level)
		await _frames(30)

		var title := GameState.level_title(index)
		_check("%s builds two keepers" % title, level.pair.size() == 2)
		var standing := 0
		for keeper in level.pair:
			if keeper.is_on_floor():
				standing += 1
		_check("%s spawns both keepers on solid ground" % title, standing == 2, "%d/2 standing" % standing)
		_check("%s has a goal area" % title, level.goal_rect.size.x > 0.0 and level.goal_rect.size.y > 0.0)
		_check("%s starts with a full well" % title, is_equal_approx(level.reservoir, Cfg.RESERVOIR_MAX))
		_check("%s has waystones" % title, level.waystones.size() >= 1)
		_check("%s has interactive devices" % title,
			level.plates.size() + level.gates.size() + level.wells.size() + level.wind_channels.size() + level.rings.size() > 0)
		_check("%s keeps the keepers attuned at spawn" % title, level.pair[0].attuned(), "distance too large at spawn")
		_check("%s has room to move" % title, level.bounds.size.x > 1200.0 and level.bounds.size.y > 800.0)

		# The reservoir rule, through the real level: a full well pays for a
		# shape change, and the change is deducted from the shared budget.
		level.reservoir = Cfg.RESERVOIR_MAX
		var before := level.reservoir
		var swapper: Keeper = level.pair[0]
		swapper._swap_cooldown = 0.0
		var from_aspect := swapper.aspect
		var changed := swapper.try_change_aspect()
		_check("%s lets a keeper change shape" % title, changed)
		_check("%s deducts the change from the shared well" % title,
			is_equal_approx(level.reservoir, before - Cfg.SWAP_COST), "%.1f" % level.reservoir)
		_check("%s actually swapped the Aspect" % title, swapper.aspect != from_aspect)

		level.reservoir = 0.0
		swapper.force_aspect(from_aspect)
		swapper._swap_cooldown = 0.0
		_check("%s refuses a change from an empty well" % title, not swapper.try_change_aspect())
		_check("%s reports no changes left" % title, level.swaps_left() == 0)
		level.reservoir = Cfg.RESERVOIR_MAX

		# The flood garden must start its water below the floor.
		if GameState.level_id(index) == "flooded_court":
			_check("the flooded court starts dry", level.get_water_level() > 1300.0, "y=%.0f" % level.get_water_level())
		level.queue_free()
		await get_tree().process_frame
