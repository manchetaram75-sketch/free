class_name Forms
extends RefCounted

## The two Aspects a keeper can wear.
##
## ZAM  (Earth) - "the sturdy keeper": broad and heavy. Short jump, slow walk,
##                 roots itself in place, presses heavy plates, plugs wind
##                 channels with its body, carries the other keeper, and can
##                 launch a rider upward.
## VAYU (Air)   - "the swift keeper": slender and light. Fast, double jump,
##                 glide, thrown on the tether. Too light to move heavy stones.
##
## The body sizes are the mechanical heart of the game: Zam is 30x60, Vayu is
## 18x38, so the *shape* you wear decides which openings in the world you fit
## through. Every puzzle in the game is built out of that difference.

const ZAM := 0
const VAYU := 1
const COUNT := 2

## Keys are plain integers so the table is a valid constant expression.
## Use the constants above (ZAM / VAYU) when reading it.
const STATS := {
	0: {
		"name": "Zam",
		"subtitle": "Earth",
		"speed": 205.0,
		"accel": 1700.0,
		"air_accel": 860.0,
		"friction": 2400.0,
		"jump": 720.0,
		"gravity_scale": 1.10,
		"mass": 1.70,
		"radius": 15.0,
		"height": 60.0,
		"double_jump": false,
		"glide": false,
		"can_root": true,
		"can_plug": true,
		"can_tether": false,
		"carries": true,
	},
	1: {
		"name": "Vayu",
		"subtitle": "Air",
		"speed": 265.0,
		"accel": 2100.0,
		"air_accel": 1200.0,
		"friction": 1500.0,
		"jump": 640.0,
		"double_jump_power": 520.0,
		"gravity_scale": 1.0,
		"mass": 0.50,
		"radius": 9.0,
		"height": 38.0,
		"double_jump": true,
		"glide": true,
		"can_root": false,
		"can_plug": false,
		"can_tether": true,
		"carries": false,
	},
}


static func stats(kind: int) -> Dictionary:
	## The returned dictionary is the shared constant table: treat it as read-only.
	return STATS.get(kind, STATS[ZAM])


static func name_of(kind: int) -> String:
	return str(stats(kind)["name"])


static func subtitle_of(kind: int) -> String:
	return str(stats(kind)["subtitle"])


static func other(kind: int) -> int:
	return VAYU if kind == ZAM else ZAM


static func radius(kind: int) -> float:
	return float(stats(kind)["radius"])


static func height(kind: int) -> float:
	return float(stats(kind)["height"])


static func mass(kind: int) -> float:
	return float(stats(kind)["mass"])


static func gravity_of(kind: int) -> float:
	return Cfg.GRAVITY * float(stats(kind)["gravity_scale"])


static func can_root(kind: int) -> bool:
	return bool(stats(kind)["can_root"])


static func can_tether(kind: int) -> bool:
	return bool(stats(kind)["can_tether"])


static func can_plug(kind: int) -> bool:
	return bool(stats(kind)["can_plug"])


# --- Design envelopes -------------------------------------------------------
# These formulas are the contract between the tuning table and the level data:
# tools/level_check.py and tests/run_tests.gd both use them to prove that a gap
# really is too wide to jump and a terrace really is too high to reach.

const SAFETY := 0.85


static func max_rise(kind: int) -> float:
	## Highest a keeper can raise its feet from a standing start, using
	## everything it has (jump, plus a mid-air jump for Vayu).
	var s := stats(kind)
	var g := gravity_of(kind)
	var rise := float(s["jump"]) * float(s["jump"]) / (2.0 * g)
	if bool(s["double_jump"]):
		var power := float(s.get("double_jump_power", 0.0))
		rise += power * power / (2.0 * g)
	return rise


static func hang_time(kind: int) -> float:
	## Approximate seconds aloft when jumping and returning to the same height,
	## including the glide for Vayu.
	var s := stats(kind)
	var g := gravity_of(kind)
	var jump := float(s["jump"])
	var time := jump / g
	var rise := jump * jump / (2.0 * g)
	if bool(s.get("double_jump", false)):
		var power := float(s.get("double_jump_power", 0.0))
		time += power / g
		rise += power * power / (2.0 * g)
	var fall_speed := Cfg.MAX_FALL_SPEED
	if bool(s.get("glide", false)):
		fall_speed = Cfg.GLIDE_FALL_SPEED
	time += rise / fall_speed
	return time


static func max_gap(kind: int) -> float:
	## Widest same-height gap a keeper can clear from a run-up, with a safety
	## margin. Gaps wider than this are treated as hard blockers by the
	## level checker.
	return float(stats(kind)["speed"]) * hang_time(kind) * SAFETY


static func envelope(kind: int) -> Dictionary:
	return {
		"rise": max_rise(kind),
		"gap": max_gap(kind),
		"hang": hang_time(kind),
		"height": height(kind),
		"width": radius(kind) * 2.0,
	}
