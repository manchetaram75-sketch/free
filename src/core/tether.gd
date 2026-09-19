class_name TetherMath
extends RefCounted

## Pure rope maths for the tether, kept free of engine state so it can be
## unit tested headlessly and reasoned about on paper.
##
## The rope is a soft spring plus a hard "taut" velocity constraint:
##   * while slack (distance <= rest length) it does nothing at all;
##   * while stretched it pulls both ends together, damped;
##   * while taut it removes the outward radial velocity so momentum is
##     redirected sideways -- that is what makes a swing feel like a swing.


## Velocity change to apply to body A this physics step, in px/s.
static func spring_velocity_delta(
	a_pos: Vector2,
	a_vel: Vector2,
	b_pos: Vector2,
	b_vel: Vector2,
	rest: float,
	stiffness: float,
	damping: float,
	mass_a: float,
	delta: float
) -> Vector2:
	var offset := a_pos - b_pos
	var dist := offset.length()
	if dist <= rest or dist < 0.0001:
		return Vector2.ZERO
	var inward := -offset / dist                      # points from A toward B
	var stretch := dist - rest
	var outward_speed := (a_vel - b_vel).dot(-inward) # positive = separating
	var accel := stiffness * stretch + damping * maxf(outward_speed, 0.0)
	accel = maxf(accel, 0.0)
	return inward * (accel / maxf(mass_a, 0.05)) * delta


## Removes the outward radial component of a velocity while the rope is taut.
static func taut_correction(a_vel: Vector2, a_pos: Vector2, b_pos: Vector2, rest: float) -> Vector2:
	var offset := a_pos - b_pos
	var dist := offset.length()
	if dist < rest or dist < 0.0001:
		return a_vel
	var outward := offset / dist
	var radial := a_vel.dot(outward)
	if radial <= 0.0:
		return a_vel
	return a_vel - outward * radial


## Rest length chosen when a rope is first attached: the distance you attached
## at, clamped into the rope's usable range.
static func rest_after_attach(distance: float, min_rest: float, max_rest: float) -> float:
	return clampf(distance, min_rest, max_rest)


## Reeling in shortens the rope; the clamp keeps it from collapsing to nothing.
static func reel(rest: float, min_rest: float, speed: float, delta: float) -> float:
	return maxf(min_rest, rest - speed * delta)
