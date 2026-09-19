class_name LevelBase
extends KeeperWorld

## Base class for a garden.
##
## A level implements _build() and optionally _step(delta); everything else --
## keepers, camera, shared reservoir, checkpoints, spills, HUD, pause menu --
## is handled here. Device ticking is ordered explicitly (wells, then wind,
## then plates, then rings, then waystones) so the simulation does not depend
## on node order.
##
## AUTHORING NOTE: place devices as direct children of the level with
## position = world position (the level root itself sits at the origin).

signal level_completed(time_seconds: float, spills: int, swaps: int)
signal request_restart
signal request_menu

var pair: Array[Keeper] = []
var wells: Array[Well] = []
var wind_channels: Array[WindChannel] = []
var plates: Array[PressurePlate] = []
var rings: Array[TetherRing] = []
var waystones: Array[Waystone] = []
var gates: Array[Gate] = []

var reservoir := Cfg.RESERVOIR_MAX
var spills := 0
var swaps := 0
var elapsed := 0.0
var finished := false
var started := false

var spawn_points: Array[Vector2] = [Vector2(220, 700), Vector2(300, 700)]
var default_aspects := [Forms.ZAM, Forms.VAYU]
var checkpoint := Vector2(220, 700)
var objective := "Reach the far terrace together."

## Goal: a rectangle both keepers must stand in. Set
## `goal_requires_both = false` for a single-keeper exit.
var goal_rect := Rect2(0, 0, 0, 0)
var goal_requires_both := true
var goal_active := false

var camera: Camera2D = null

var _backdrop: Node2D = null
var _note_text := ""
var _note_time := 0.0
var _goal_hold := 0.0
var _pressers: Array[Node2D] = []
var _latches: Dictionary = {}
var _sources: Dictionary = {}
var _water_level := INF  # INF until a garden actually floods
var _camera_position := Vector2.ZERO
var _camera_zoom := 1.0
var _paused := false


# --- Lifecycle --------------------------------------------------------------

func _ready() -> void:
	z_index = 0
	if spawn_points.size() < 2:
		push_error("Level %s needs two spawn points" % name)
	_build()
	_backdrop = Backdrop.new()
	_backdrop.z_index = -100
	add_child(_backdrop)
	_collect_devices()
	_create_keepers()
	_create_camera()
	started = true
	# Any garden that declared a goal area is winnable; a garden may also turn
	# its goal on later (goal_active = true) for a scripted finale.
	goal_active = goal_rect.size.x > 0.0 and goal_rect.size.y > 0.0
	_checkpoint_scan()


## Override: build geometry and devices here.
func _build() -> void:
	pass


## Override: run level-specific logic (rising water, scripted gates, ...).
func _step(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if finished or _paused:
		return
	elapsed += delta
	_note_time = maxf(0.0, _note_time - delta)

	for well in wells:
		well.tick(delta)
	for channel in wind_channels:
		channel.tick(delta)
	for plate in plates:
		plate.tick(delta)
	for ring in rings:
		ring.tick(delta)
	for stone in waystones:
		stone.tick(delta)

	_check_restart()
	_step(delta)
	_checkpoint_scan()
	_check_goal(delta)


## R / V sends that keeper back to the last waystone it touched. It cannot skip
## a puzzle - it only undoes the walk since the last checkpoint you reached.
func _check_restart() -> void:
	for keeper in pair:
		if Input.is_action_just_pressed(Controls.restart_action(keeper.index)):
			keeper.teleport(keeper.spawn_point)
			note("%s returns to the last waystone." % Forms.name_of(keeper.aspect))


func _process(delta: float) -> void:
	_update_camera(delta)


# --- Keeper world contract --------------------------------------------------

## The two keepers; KeeperWorld.keepers() exposes the same list to devices.
func keepers() -> Array[Keeper]:
	return pair


func keeper0() -> Keeper:
	return pair[0] if pair.size() > 0 else null


func keeper1() -> Keeper:
	return pair[1] if pair.size() > 1 else null


func pressers() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for k in pair:
		if is_instance_valid(k):
			out.append(k)
	for p in _pressers:
		if is_instance_valid(p):
			out.append(p)
	return out


func add_presser(node: Node2D) -> void:
	_pressers.append(node)


func partner_of(index: int) -> Keeper:
	for k in pair:
		if is_instance_valid(k) and k.index != index:
			return k
	return null


func get_water_level() -> float:
	return _water_level


func wind_at(point: Vector2) -> Vector2:
	var total := Vector2.ZERO
	for channel in wind_channels:
		total += channel.field_at(point)
	return total


func nearest_tether_anchor(from: Vector2, radius: float) -> Node2D:
	var best: Node2D = null
	var best_distance := radius
	var space := get_world_2d().direct_space_state if is_inside_tree() else null
	for ring in rings:
		if not is_instance_valid(ring):
			continue
		var d := from.distance_to(ring.global_position)
		if d > best_distance:
			continue
		if space != null and not _clear_path(space, from, ring.global_position):
			continue
		best = ring
		best_distance = d
	return best


func _clear_path(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> bool:
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.collision_mask = Cfg.LAYER_WORLD | Cfg.LAYER_DEVICE
	params.collide_with_areas = false
	return space.intersect_ray(params).is_empty()


func request_tether(keeper: Keeper) -> bool:
	# Rings are deliberate placements, so they win ties; the partner is the
	# fallback and has the longer reach.
	var anchor := nearest_tether_anchor(keeper.center_position(), Cfg.RING_REACH)
	if anchor == null:
		var partner := partner_of(keeper.index)
		if partner != null and keeper.global_position.distance_to(partner.global_position) <= Cfg.TETHER_ATTACH_RANGE:
			anchor = partner
	if anchor == null:
		note("Nothing within reach to tether.")
		return false
	keeper.tether_attach(anchor, keeper.global_position.distance_to(anchor.global_position))
	return true


func request_aspect_change(_keeper: Keeper) -> bool:
	if reservoir < Cfg.SWAP_COST:
		note("The garden well is dry - refill at a well.")
		return false
	return true


func spent_swap(amount: float) -> void:
	reservoir = maxf(0.0, reservoir - amount)
	swaps += 1


func refill_reservoir(amount: float) -> void:
	reservoir = minf(Cfg.RESERVOIR_MAX, reservoir + amount)


func on_keeper_spilled(keeper: Keeper, cause: String) -> void:
	spills += 1
	var shake := Settings.shake(7.0)
	if shake > 0.0 and camera != null:
		camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	note("%s slipped (%s). Back to the waystone." % [Forms.name_of(keeper.aspect), cause])
	keeper.teleport(checkpoint)


func on_aspect_changed(keeper: Keeper, _from: int, _to: int) -> void:
	keeper.spawn_point = checkpoint


func note(message: String) -> void:
	_note_text = message
	_note_time = 3.0


func current_note() -> String:
	return _note_text if _note_time > 0.0 else ""


# --- Latches ----------------------------------------------------------------

func press_source(channel: String, source: Node, pressed: bool) -> void:
	var sources: Dictionary = _sources.get(channel, {})
	if pressed:
		sources[source] = true
	else:
		sources.erase(source)
	_sources[channel] = sources
	set_latch(channel, not sources.is_empty())


func set_latch(channel: String, active: bool) -> void:
	var was := latch(channel)
	if was == active:
		return
	_latches[channel] = active
	latch_changed.emit(channel, active)


func latch(channel: String) -> bool:
	return bool(_latches.get(channel, false))


# --- Checkpoints ------------------------------------------------------------

func _checkpoint_scan() -> void:
	for stone in waystones:
		if stone.active:
			continue
		for keeper in pair:
			if not is_instance_valid(keeper):
				continue
			if stone.touched_by(keeper):
				stone.active = true
				checkpoint = stone.global_position + Vector2(0, 4)
				note("Waystone %d lit." % (stone.index + 1))
				break


# --- Goal -------------------------------------------------------------------

func _check_goal(delta: float) -> void:
	if finished or not goal_active or goal_rect.size == Vector2.ZERO:
		return
	var inside := 0
	for keeper in pair:
		if not is_instance_valid(keeper):
			continue
		if goal_rect.has_point(keeper.center_position()):
			inside += 1
	var needed := 2 if goal_requires_both else 1
	if inside >= needed:
		_goal_hold += delta
		if _goal_hold >= Cfg.GOAL_HOLD_TIME:
			_finish()
	else:
		_goal_hold = maxf(0.0, _goal_hold - delta * 2.0)


func _finish() -> void:
	if finished:
		return
	finished = true
	# Freeze the garden behind the results panel.
	get_tree().paused = true
	level_completed.emit(elapsed, spills, swaps)


func goal_progress() -> float:
	return clampf(_goal_hold / Cfg.GOAL_HOLD_TIME, 0.0, 1.0)


# --- Building helpers -------------------------------------------------------

func spawn(point0: Vector2, point1: Vector2) -> void:
	spawn_points = [point0, point1]
	checkpoint = point0


func add_solid(rect: Rect2, style := "masonry") -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = Cfg.LAYER_WORLD
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	var art := SolidArt.new()
	art.size = rect.size
	art.style = style
	body.add_child(art)
	add_child(body)
	return body


func add_ground(rect: Rect2) -> StaticBody2D:
	return add_solid(rect, "ground")


func add_platform(pos: Vector2, size: Vector2, style := "brick") -> StaticBody2D:
	return add_solid(Rect2(pos, size), style)


func add_well(pos: Vector2, radius := Cfg.WELL_RADIUS) -> Well:
	var well := Well.new()
	well.position = pos
	well.radius = radius
	add_child(well)
	return well


func add_wind(
	pos: Vector2,
	area: Rect2,
	direction: Vector2,
	strength := 900.0,
	options := {}
) -> WindChannel:
	var channel := WindChannel.new()
	channel.position = pos
	channel.area = area
	channel.direction = direction
	channel.strength = strength
	channel.seal_channel = str(options.get("seal_channel", ""))
	channel.pulse_period = float(options.get("pulse_period", 0.0))
	channel.pulse_duty = float(options.get("pulse_duty", 0.55))
	channel.phase_offset = float(options.get("phase_offset", 0.0))
	channel.pluggable = bool(options.get("pluggable", true))
	channel.label = str(options.get("label", ""))
	add_child(channel)
	return channel


func add_plate(pos: Vector2, channel: String, options := {}) -> PressurePlate:
	var plate := PressurePlate.new()
	plate.position = pos
	plate.channel = channel
	plate.size = options.get("size", Vector2(96, 14))
	plate.required_weight = float(options.get("weight", 1.0))
	plate.required_keepers = int(options.get("keepers", 1))
	plate.sticky = bool(options.get("sticky", false))
	plate.label = str(options.get("label", ""))
	add_child(plate)
	return plate


func add_gate(pos: Vector2, size: Vector2, channel: String, open_offset: Vector2, options := {}) -> Gate:
	var gate := Gate.new()
	gate.position = pos
	gate.size = size
	gate.channel = channel
	gate.open_offset = open_offset
	gate.speed = float(options.get("speed", 220.0))
	gate.invert = bool(options.get("invert", false))
	gate.one_way = bool(options.get("one_way", false))
	gate.start_open = bool(options.get("start_open", false))
	gate.carving = str(options.get("carving", ""))
	add_child(gate)
	return gate


func add_ring(pos: Vector2) -> TetherRing:
	var ring := TetherRing.new()
	ring.position = pos
	add_child(ring)
	return ring


func add_waystone(pos: Vector2, index := 0) -> Waystone:
	var stone := Waystone.new()
	stone.position = pos
	stone.index = index
	add_child(stone)
	return stone


func add_decor(pos: Vector2, size: Vector2, style := "column") -> Node2D:
	var art := DecorArt.new()
	art.position = pos
	art.size = size
	art.style = style
	art.z_index = -2
	add_child(art)
	return art


## The garden heart: the shared objective marker both keepers must stand in.
func add_heart(rect: Rect2) -> Node2D:
	var art := DecorArt.new()
	art.position = rect.position + rect.size * 0.5
	art.size = rect.size
	art.style = "heart"
	art.z_index = 3
	add_child(art)
	return art


func add_text(pos: Vector2, text: String, width := 420.0) -> Node2D:
	var art := TextArt.new()
	art.position = pos
	art.text = text
	art.width = width
	art.z_index = -1
	add_child(art)
	return art


# --- Internals --------------------------------------------------------------

func _collect_devices() -> void:
	wells.clear()
	wind_channels.clear()
	plates.clear()
	rings.clear()
	waystones.clear()
	gates.clear()
	for child in get_children():
		if child is Well:
			(child as Well).world = self
			wells.append(child)
		elif child is WindChannel:
			(child as WindChannel).world = self
			wind_channels.append(child)
		elif child is PressurePlate:
			(child as PressurePlate).world = self
			plates.append(child)
		elif child is TetherRing:
			(child as TetherRing).world = self
			rings.append(child)
		elif child is Waystone:
			(child as Waystone).world = self
			waystones.append(child)
		elif child is Gate:
			(child as Gate).world = self
			gates.append(child)


func _create_keepers() -> void:
	pair.clear()
	for i in 2:
		var keeper := Keeper.new()
		keeper.index = i
		keeper.world = self
		keeper.aspect = default_aspects[i]
		keeper.spawn_point = spawn_points[i]
		keeper.position = spawn_points[i]
		add_child(keeper)
		keeper.teleport(spawn_points[i])
		pair.append(keeper)


func _create_camera() -> void:
	camera = Camera2D.new()
	camera.position = pair[0].global_position
	camera.limit_left = int(bounds.position.x) - 200
	camera.limit_top = int(bounds.position.y) - 400
	camera.limit_right = int(bounds.end.x) + 200
	camera.limit_bottom = int(bounds.end.y) + 200
	camera.ignore_rotation = true
	add_child(camera)
	camera.make_current()
	_camera_position = camera.position
	_camera_zoom = 1.0


func _update_camera(delta: float) -> void:
	if camera == null or pair.size() < 2:
		return
	var a := pair[0].center_position()
	var b := pair[1].center_position()
	var view := get_viewport_rect().size
	var centre := (a + b) * 0.5
	var extent := (b - a).abs() + Cfg.CAMERA_MARGIN
	var zoom := minf(view.x / maxf(extent.x, 1.0), view.y / maxf(extent.y, 1.0))
	zoom = clampf(zoom, Cfg.CAMERA_MIN_ZOOM, Cfg.CAMERA_MAX_ZOOM)

	# Keep the camera inside the level bounds when zoomed out to the limit.
	var half := view * 0.5 / zoom
	var min_corner := bounds.position + half
	var max_corner := bounds.end - half
	if min_corner.x <= max_corner.x:
		centre.x = clampf(centre.x, min_corner.x, max_corner.x)
	if min_corner.y <= max_corner.y:
		centre.y = clampf(centre.y, min_corner.y, max_corner.y)

	_camera_position = _camera_position.lerp(centre, clampf(delta * Cfg.CAMERA_FOLLOW_SPEED, 0.0, 1.0))
	_camera_zoom = lerpf(_camera_zoom, zoom, clampf(delta * Cfg.CAMERA_ZOOM_SPEED, 0.0, 1.0))
	camera.position = _camera_position
	camera.zoom = Vector2(_camera_zoom, _camera_zoom)
	camera.offset = camera.offset.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	if _backdrop != null:
		_backdrop.set_view(_camera_position, _camera_zoom, bounds)


# --- Pause ------------------------------------------------------------------

func is_paused() -> bool:
	return _paused


func set_paused(value: bool) -> void:
	_paused = value
	get_tree().paused = value


# --- HUD data ---------------------------------------------------------------

func reservoir_ratio() -> float:
	return clampf(reservoir / Cfg.RESERVOIR_MAX, 0.0, 1.0)


func swaps_left() -> int:
	return int(reservoir / Cfg.SWAP_COST)


func set_water_level(y: float) -> void:
	_water_level = y


func attuned_for(keeper: Keeper) -> bool:
	return keeper.attuned()


func restart() -> void:
	request_restart.emit()


func to_menu() -> void:
	request_menu.emit()
