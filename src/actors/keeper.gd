class_name Keeper
extends CharacterBody2D

## One of the two apprentice keepers.
##
## A keeper is defined by the Aspect it currently wears. The Aspect decides its
## body size (which openings in the world it fits through), its movement
## envelope, and which verbs it owns. Both players can wear either Aspect, but
## only one Aspect each at a time, and a keeper may only change shape while it
## is attuned to its partner -- that rule is what keeps the two players talking
## to each other instead of playing two solo games side by side.
##
## The node origin is at the keeper's FEET, so levels place keepers by giving
## the ground height directly.

signal aspect_changed(index: int, from: int, to: int)
signal spilled(cause: String)
signal carried_changed(is_carried: bool)

const CARRY_STIFFNESS := 16.0
const CARRY_MAX_SPEED := 1100.0
const CARRY_SPEED_SCALE := 0.74
const LIFT_RANGE := 46.0
const LAUNCH_LOCK := 0.22
const SWIM_STROKE := 0.62
const WATER_BUOYANCY := 1150.0
const WATER_SIDE_DRAG := 1.1
const WATER_VERTICAL_DRAG := 1.5

var index := 0

## The world this keeper lives in (a LevelBase in game, a bare KeeperWorld in
## tests). Deliberately untyped: KeeperWorld already refers to Keeper in its
## signatures, and a typed reference back would make the two scripts mutually
## dependent. The calls below are duck-typed against the KeeperWorld contract.
var world = null

var aspect := Forms.ZAM

# --- Runtime state, read by the HUD, camera and levels ----------------------
var carried := false
var carrier: Keeper = null
var rider: Keeper = null
var rooted := false
var tether_active := false
var tether_target: Node2D = null
var tether_rest := Cfg.TETHER_REST
var reeling := false
var facing := 1.0
var water_level := -1.0e9
var spawn_point := Vector2.ZERO
var swaps := 0

var _launch_timer := 0.0
var _swap_cooldown := 0.0
var _spill_grace := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _jumps_used := 0
var _jump_cut_done := false
var _was_jump_held := false
var _wind := Vector2.ZERO
var _squash := 0.0
var _walk_phase := 0.0
var _spill_flash := 0.0

var _body: CollisionShape2D
var _head: CollisionShape2D
var _body_shape: RectangleShape2D
var _head_shape: CircleShape2D


func _ready() -> void:
	collision_layer = Cfg.LAYER_KEEPER
	collision_mask = Cfg.LAYER_WORLD | Cfg.LAYER_DEVICE | Cfg.LAYER_HAZARD
	z_index = 20
	_body = CollisionShape2D.new()
	_head = CollisionShape2D.new()
	_body_shape = RectangleShape2D.new()
	_head_shape = CircleShape2D.new()
	_body.shape = _body_shape
	_head.shape = _head_shape
	add_child(_body)
	add_child(_head)
	_apply_shape()


# --- Queries ----------------------------------------------------------------

func stats() -> Dictionary:
	return Forms.stats(aspect)


func radius() -> float:
	return Forms.radius(aspect)


func height() -> float:
	return Forms.height(aspect)


func mass() -> float:
	return Forms.mass(aspect)


func aspect_name() -> String:
	return Forms.name_of(aspect)


func is_grounded() -> bool:
	return is_on_floor()


func in_water() -> bool:
	return global_position.y > water_level


func head_position() -> Vector2:
	return global_position + Vector2(0, -height())


func center_position() -> Vector2:
	return global_position + Vector2(0, -height() * 0.5)


## How hard this keeper presses a pressure plate. Rooting doubles down.
func plate_weight() -> float:
	var weight := 1.0
	if aspect == Forms.ZAM:
		weight += 0.8
	if rooted:
		weight += 0.5
	return weight


func attuned() -> bool:
	if world == null:
		return true
	var partner: Keeper = world.partner_of(index)
	if partner == null:
		return true
	return global_position.distance_to(partner.center_position()) <= Settings.attunement_radius()


func is_riding() -> bool:
	return carried


# --- Input helpers ----------------------------------------------------------

func _action_held() -> bool:
	return Input.is_action_pressed(Controls.action_action(index))


func _action_just() -> bool:
	return Input.is_action_just_pressed(Controls.action_action(index))


func _jump_just() -> bool:
	return Input.is_action_just_pressed(Controls.jump_action(index))


func _jump_held() -> bool:
	return Input.is_action_pressed(Controls.jump_action(index))


func _move_axis() -> float:
	return Controls.axis(index)


# --- Physics ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	water_level = world.get_water_level() if world != null else -1.0e9
	_wind = world.wind_at(center_position()) if world != null else Vector2.ZERO
	_swap_cooldown = maxf(0.0, _swap_cooldown - delta)
	_spill_grace = maxf(0.0, _spill_grace - delta)
	_spill_flash = maxf(0.0, _spill_flash - delta)
	_launch_timer = maxf(0.0, _launch_timer - delta)
	_squash = move_toward(_squash, 0.0, delta * 4.0)

	if carried:
		_handle_carried(delta)
		return
	if rooted:
		_physics_rooted()
		return

	_handle_jump(delta)
	_handle_horizontal(delta)
	_handle_gravity(delta)
	_handle_wind(delta)
	_handle_tether(delta)
	_handle_action(delta)

	var was_airborne := not is_on_floor()
	move_and_slide()
	_after_move(was_airborne)
	queue_redraw()


func _physics_rooted() -> void:
	velocity = Vector2.ZERO
	if not _action_held() or not is_on_floor():
		rooted = false
		return
	move_and_slide()
	queue_redraw()


func _handle_gravity(delta: float) -> void:
	var s := stats()
	var vy := velocity.y + Forms.gravity_of(aspect) * delta

	if in_water():
		var depth := clampf((global_position.y - water_level) / maxf(height(), 1.0), 0.0, 1.0)
		vy -= WATER_BUOYANCY * depth * delta
		vy -= vy * WATER_VERTICAL_DRAG * depth * delta
	elif bool(s["glide"]) and _jump_held() and _jumps_used >= 1 and vy > Cfg.GLIDE_FALL_SPEED:
		vy = move_toward(vy, Cfg.GLIDE_FALL_SPEED, Cfg.GLIDE_RESPONSE * delta)

	velocity.y = minf(vy, Cfg.MAX_FALL_SPEED)


## Wind is applied as a drift the keeper is dragged toward, after gravity and
## after walking, so the "gust carries the light keeper" rule always wins over
## either one on its own.
func _handle_wind(delta: float) -> void:
	if _wind == Vector2.ZERO or rooted:
		return
	var scale := Cfg.WIND_EARTH_SCALE if aspect == Forms.ZAM else Cfg.WIND_AIR_SCALE
	velocity = velocity.move_toward(_wind * scale, Cfg.WIND_PULL * scale * delta)


func _handle_horizontal(delta: float) -> void:
	var s := stats()
	var locked := _launch_timer > 0.0
	var dir := 0.0 if locked else _move_axis()

	if absf(dir) > 0.15:
		facing = signf(dir)
		if is_on_floor():
			_walk_phase += delta * absf(velocity.x) * 0.02

	var speed := float(s["speed"])
	if rider != null:
		speed *= CARRY_SPEED_SCALE
	if in_water():
		speed *= 0.7
	var target := dir * speed

	var rate := float(s["accel"]) if is_on_floor() else float(s["air_accel"])
	if locked:
		rate = float(s["air_accel"]) * 0.2
	elif absf(dir) < 0.15 and is_on_floor():
		rate = float(s["friction"])

	velocity.x = move_toward(velocity.x, target, rate * delta)
	if in_water():
		velocity.x -= velocity.x * WATER_SIDE_DRAG * delta


func _handle_jump(delta: float) -> void:
	var s := stats()
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if _jump_just():
		_jump_buffer = Cfg.JUMP_BUFFER_TIME
		if rider != null:
			drop_rider(true)

	if is_on_floor():
		_coyote = Cfg.COYOTE_TIME
		_jumps_used = 0
	elif in_water():
		_coyote = Cfg.COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)

	var held := _jump_held()
	if _was_jump_held and not held and velocity.y < 0.0 and not _jump_cut_done:
		velocity.y *= Cfg.JUMP_CUT
		_jump_cut_done = true
	_was_jump_held = held

	if _jump_buffer <= 0.0:
		return

	if _coyote > 0.0:
		_jump_buffer = 0.0
		_coyote = 0.0
		_jump_cut_done = false
		_jumps_used = 1
		rooted = false
		var power := float(s["jump"])
		if in_water():
			power *= SWIM_STROKE
		velocity.y = -power
		_squash = -0.28
		if world != null:
			world.on_keeper_jumped(self)
	elif bool(s["double_jump"]) and _jumps_used < 2:
		_jump_buffer = 0.0
		_jumps_used = 2
		_jump_cut_done = false
		_squash = -0.22
		velocity.y = -float(s["double_jump_power"])


func _after_move(was_airborne: bool) -> void:
	if was_airborne and is_on_floor():
		_jumps_used = 0
		_squash = 0.18
		if world != null:
			world.on_keeper_landed(self)
	if is_on_floor():
		rooted = rooted and _action_held()

	if world == null:
		return
	if global_position.y > world.bounds.end.y + Cfg.FALL_MARGIN:
		spill("fell")
	elif in_water() and global_position.y - water_level > height() * 2.2:
		spill("drowned")


# --- Actions ----------------------------------------------------------------

func _handle_action(delta: float) -> void:
	var partner: Keeper = world.partner_of(index) if world != null else null

	if rider != null:
		# The action button is the grip while someone is riding your shoulders.
		if not _action_held() or not is_on_floor():
			drop_rider(false)
		return

	if _action_just() and partner != null and _can_lift(partner):
		_lift(partner)
		return

	if Forms.can_root(aspect):
		rooted = _action_held() and is_on_floor()
	else:
		rooted = false
		_handle_tether_action(delta)


func _can_lift(partner: Keeper) -> bool:
	if not bool(stats()["carries"]):
		return false
	if not is_on_floor() or rider != null or partner.carried or partner.rooted:
		return false
	if partner.aspect != Forms.VAYU or not partner.tether_free():
		return false
	return global_position.distance_to(partner.global_position) <= LIFT_RANGE


func _lift(partner: Keeper) -> void:
	rider = partner
	partner.carried = true
	partner.carrier = self
	partner.rooted = false
	partner.tether_release()
	partner.carried_changed.emit(true)


## Sets the rider down (launch = false) or throws them skyward (launch = true).
func drop_rider(launch: bool) -> void:
	if rider == null:
		return
	var r := rider
	rider = null
	r.carried = false
	r.carrier = null
	if launch:
		r.velocity = Vector2(velocity.x * 0.4 + facing * Cfg.BOOST_SIDE_PUSH, -Cfg.BOOST_SPEED)
		r._launch_timer = LAUNCH_LOCK
		r._jumps_used = 1
	else:
		r.velocity = Vector2(velocity.x, minf(velocity.y, -180.0))
	r.carried_changed.emit(false)


## Called by a carried keeper that jumps off its carrier.
func jump_off_carrier() -> void:
	if carrier == null:
		return
	var old := carrier
	var power := float(Forms.stats(aspect)["jump"]) * 0.95
	velocity = old.velocity + Vector2(0, -power)
	carrier = null
	carried = false
	old.rider = null
	_launch_timer = LAUNCH_LOCK
	_jumps_used = 1
	carried_changed.emit(false)
	old.queue_redraw()


func _handle_carried(_delta: float) -> void:
	if carrier == null or not is_instance_valid(carrier):
		carried = false
		return
	if _jump_just():
		jump_off_carrier()
		return
	if _action_just() and can_change_aspect_here():
		try_change_aspect()
	var seat := carrier.global_position + Vector2(0, -(carrier.height() + 2.0))
	var desired := ((seat - global_position) * CARRY_STIFFNESS).limit_length(CARRY_MAX_SPEED)
	velocity = desired
	move_and_slide()
	facing = carrier.facing
	_after_move(false)
	queue_redraw()


# --- Tether -----------------------------------------------------------------

func tether_free() -> bool:
	return not tether_active


func tether_attach(target: Node2D, distance: float) -> void:
	tether_active = true
	tether_target = target
	tether_rest = TetherMath.rest_after_attach(distance, Cfg.TETHER_MIN, Cfg.TETHER_MAX)
	reeling = false


func tether_release() -> void:
	if not tether_active:
		return
	tether_active = false
	tether_target = null
	reeling = false


func tether_anchor_position() -> Vector2:
	if tether_target == null or not is_instance_valid(tether_target):
		return global_position
	if tether_target is Keeper:
		return (tether_target as Keeper).center_position()
	return tether_target.global_position


func _handle_tether_action(_delta: float) -> void:
	if not Forms.can_tether(aspect):
		return
	if tether_active:
		reeling = _action_held()
		if _action_just():
			tether_release()
		return
	if _action_just() and world != null:
		world.request_tether(self)


func _handle_tether(delta: float) -> void:
	if not tether_active:
		return
	if tether_target == null or not is_instance_valid(tether_target):
		tether_release()
		return

	var anchor_pos := tether_anchor_position()
	var anchor_vel := node_velocity(tether_target)
	var distance := global_position.distance_to(anchor_pos)

	if reeling and distance > Cfg.TETHER_MIN:
		tether_rest = TetherMath.reel(tether_rest, Cfg.TETHER_MIN, Cfg.TETHER_REEL_SPEED, delta)

	velocity += TetherMath.spring_velocity_delta(
		global_position, velocity, anchor_pos, anchor_vel,
		tether_rest, Cfg.TETHER_STIFFNESS, Cfg.TETHER_DAMPING, mass(), delta
	)
	velocity = TetherMath.taut_correction(velocity, global_position, anchor_pos, tether_rest)

	if tether_target is Keeper:
		var partner := tether_target as Keeper
		if not partner.rooted:
			partner.velocity += TetherMath.spring_velocity_delta(
				partner.global_position, partner.velocity, global_position, velocity,
				tether_rest, Cfg.TETHER_STIFFNESS, Cfg.TETHER_DAMPING, partner.mass(), delta
			)


## Velocity of a tether anchor. Devices expose get_velocity(); a static ring
## simply reports zero.
static func node_velocity(node: Node) -> Vector2:
	if node == null:
		return Vector2.ZERO
	if node is Keeper:
		return (node as Keeper).velocity
	if node is CharacterBody2D:
		return (node as CharacterBody2D).velocity
	if node.has_method("get_velocity"):
		var value: Variant = node.call("get_velocity")
		if value is Vector2:
			return value
	return Vector2.ZERO


# --- Aspect change ----------------------------------------------------------

func can_change_aspect_here() -> bool:
	if carried or tether_active or rider != null:
		return false
	if _swap_cooldown > 0.0:
		return false
	return attuned()


func try_change_aspect() -> bool:
	if not can_change_aspect_here():
		return false
	var to := Forms.other(aspect)
	if not fits_aspect(to):
		if world != null:
			world.note("No room to change shape here.")
		return false
	if world != null and not world.request_aspect_change(self):
		return false

	var from := aspect
	aspect = to
	_swap_cooldown = Cfg.SWAP_COOLDOWN
	swaps += 1
	rooted = false
	_jumps_used = 0
	_apply_shape()
	if world != null:
		world.spent_swap(Cfg.SWAP_COST)
		world.on_aspect_changed(self, from, to)
	aspect_changed.emit(index, from, to)
	return true


## True when the keeper's current space could hold the given Aspect. Growing
## inside a shaft is refused rather than squeezing the body out of geometry.
func fits_aspect(kind: int) -> bool:
	if kind == aspect:
		return true
	var space := get_world_2d().direct_space_state
	var r := Forms.radius(kind)
	var h := Forms.height(kind)
	var params := PhysicsShapeQueryParameters2D.new()
	params.exclude = [get_rid()]
	params.collision_mask = Cfg.LAYER_WORLD | Cfg.LAYER_DEVICE
	params.collide_with_bodies = true
	params.collide_with_areas = false

	# The query boxes are inset by a pixel so that merely standing on a floor
	# (touching it, not overlapping it) never counts as "no room".
	var body_shape := RectangleShape2D.new()
	body_shape.size = Vector2(r * 2.0 - 2.0, h - r - 2.0)
	params.shape = body_shape
	params.transform = Transform2D(0.0, global_position + Vector2(0, r * 0.5 - h * 0.5 - 1.0))
	if not space.intersect_shape(params, 1).is_empty():
		return false

	var head_shape := CircleShape2D.new()
	head_shape.radius = r * 0.96
	params.shape = head_shape
	params.transform = Transform2D(0.0, global_position + Vector2(0, -h + r))
	return space.intersect_shape(params, 1).is_empty()


func force_aspect(kind: int) -> void:
	if kind == aspect:
		return
	var from := aspect
	aspect = kind
	rooted = false
	tether_release()
	_apply_shape()
	aspect_changed.emit(index, from, kind)


func _apply_shape() -> void:
	var r := radius()
	var h := height()
	_body_shape.size = Vector2(r * 2.0, h - r)
	_body.position = Vector2(0, r * 0.5 - h * 0.5)
	_head_shape.radius = r
	_head.position = Vector2(0, -h + r)
	# The heavier keeper wins body pushes: this is what lets Zam nudge Vayu.
	collision_priority = mass() * 1.2
	queue_redraw()


# --- Spills and respawn -----------------------------------------------------

func spill(cause: String) -> void:
	if _spill_grace > 0.0:
		return
	_spill_grace = Cfg.RESPAWN_GRACE
	_spill_flash = 1.0
	velocity = Vector2.ZERO
	spilled.emit(cause)
	if world != null:
		world.on_keeper_spilled(self, cause)


func teleport(point: Vector2, keep_aspect := true) -> void:
	tether_release()
	if rider != null:
		drop_rider(false)
	if carried:
		jump_off_carrier()
	carried = false
	carrier = null
	rooted = false
	velocity = Vector2.ZERO
	global_position = point
	_spill_grace = Cfg.RESPAWN_GRACE
	_jumps_used = 0
	_launch_timer = 0.0
	if not keep_aspect:
		force_aspect(Forms.ZAM)
	queue_redraw()


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var r := radius()
	var h := height()
	var base := Palette.keeper_color(index)
	var accent := Palette.ASPECT_ACCENT[aspect]
	if _spill_flash > 0.0:
		base = base.lerp(Color.WHITE, _spill_flash * 0.6)

	var squash := clampf(1.0 + _squash, 0.72, 1.28)
	var top := -h * squash
	var half := r * (2.0 - squash)
	var head_r := maxf(r * 0.62, 7.0)
	var head_y := top + head_r * 0.75
	var shoulder_y := head_y + head_r * 0.55

	# Torso: a straight-sided robe from the shoulders to the feet.
	draw_rect(Rect2(Vector2(-half, shoulder_y), Vector2(half * 2.0, -shoulder_y)), base, true)
	draw_circle(Vector2(0, shoulder_y), half, base)
	# Robe fold, so the silhouette reads at a distance.
	draw_line(Vector2(0, shoulder_y + r * 0.4), Vector2(half * 0.35 * facing, -r * 0.35), Palette.keeper_light(index), 2.0)
	# Arms.
	draw_line(Vector2(-half, shoulder_y + r * 0.5), Vector2(-half - r * 0.5, shoulder_y + r * 1.3), accent.darkened(0.2), maxf(r * 0.3, 2.0))
	draw_line(Vector2(half, shoulder_y + r * 0.5), Vector2(half + r * 0.5, shoulder_y + r * 1.3), accent.darkened(0.2), maxf(r * 0.3, 2.0))
	# Head.
	draw_circle(Vector2(0, head_y), head_r, Palette.PAPER)
	draw_arc(Vector2(0, head_y), head_r, PI, TAU, 16, accent, maxf(head_r * 0.42, 2.0), true)

	# Eyes (facing aware).
	var eye_y := head_y + head_r * 0.12
	var eye_x := head_r * 0.42 * facing
	draw_circle(Vector2(eye_x, eye_y), maxf(head_r * 0.15, 1.5), Palette.INK)
	draw_circle(Vector2(eye_x - head_r * 0.45 * facing, eye_y), maxf(head_r * 0.15, 1.5), Palette.INK)

	# Player badge: a square for keeper 1, a ring for keeper 2 (shape, not hue).
	var badge := Vector2(-facing * r * 0.15, shoulder_y + r * 0.9)
	if index == 0:
		draw_rect(Rect2(badge - Vector2.ONE * r * 0.24, Vector2.ONE * r * 0.48), Palette.PAPER, true)
	else:
		draw_circle(badge, r * 0.3, Palette.PAPER)
		draw_circle(badge, r * 0.15, base)

	# Aspect marker: solid wedge (earth) against two gust lines (air).
	if aspect == Forms.ZAM:
		draw_colored_polygon(PackedVector2Array([
			badge + Vector2(0, r * 0.6),
			badge + Vector2(-r * 0.45, r * 1.15),
			badge + Vector2(r * 0.45, r * 1.15),
		]), accent)
	else:
		for i in 2:
			var y := badge.y + r * (0.62 + 0.44 * float(i))
			draw_line(Vector2(-r * 0.6, y), Vector2(r * 0.6, y), accent, maxf(r * 0.2, 2.0))

	if rooted:
		draw_line(Vector2(-r * 0.9, 0), Vector2(-r * 1.6, r * 0.5), accent, 3.0)
		draw_line(Vector2(r * 0.9, 0), Vector2(r * 1.6, r * 0.5), accent, 3.0)

	if carried:
		draw_arc(Vector2(0, top * 0.5), h * 0.6, PI * 0.12, PI * 0.88, 12, Palette.GOLD, 2.0, true)

	if Settings.high_contrast:
		draw_arc(Vector2(0, top * 0.5), h * 0.68, 0.0, TAU, 24, Palette.PAPER, 2.0, true)

	if _spill_flash > 0.0:
		draw_arc(Vector2(0, top * 0.5), h * 0.9 * (1.0 - _spill_flash), 0.0, TAU, 24, Palette.DANGER, 3.0, true)

	if is_on_floor() and absf(velocity.x) > 20.0:
		var bob := absf(sin(_walk_phase)) * r * 0.3
		draw_line(Vector2(-r * 0.6, 0), Vector2(-r * 0.6, bob), base.darkened(0.4), 3.0)
		draw_line(Vector2(r * 0.6, 0), Vector2(r * 0.6, -bob), base.darkened(0.4), 3.0)

	if aspect == Forms.VAYU and not is_on_floor() and not carried:
		draw_line(Vector2(-half - r * 0.2, shoulder_y), Vector2(-half - r * 0.8, shoulder_y + r * 1.6), accent, 2.0)
		draw_line(Vector2(half + r * 0.2, shoulder_y), Vector2(half + r * 0.8, shoulder_y + r * 1.6), accent, 2.0)
