class_name KeeperWorld
extends Node2D

## The contract between a keeper and the world it lives in.
##
## Levels extend this class (see src/levels/level_base.gd) and override the
## hooks they care about. Keeping the keeper's dependency behind this small
## interface means the keeper never needs to know about specific levels, the
## class dependency graph stays acyclic, and the movement code can be unit
## tested inside a bare KeeperWorld.

signal latch_changed(channel: String, active: bool)

## Level bounds in world pixels; a keeper that falls past them is spilled.
var bounds := Rect2(0, 0, 2048, 1152)


func keepers() -> Array[Keeper]:
	return []


## Everything that can weigh down a pressure plate.
func pressers() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for k in keepers():
		out.append(k)
	return out


func partner_of(_index: int) -> Keeper:
	return null


# --- Water and wind ---------------------------------------------------------

func get_water_level() -> float:
	## INF means "this world has no water at all" - anything finite is a real
	## surface, so a dry garden can never be mistaken for a flooded one.
	return INF


func set_water_level(_y: float) -> void:
	pass


## Sum of every wind field covering this point, as a *drift velocity* in px/s.
## The keeper pulls this once per physics step, so wind never depends on the
## order nodes happen to be processed in.
func wind_at(_point: Vector2) -> Vector2:
	return Vector2.ZERO


# --- Tether -----------------------------------------------------------------

func nearest_tether_anchor(_from: Vector2, _radius: float) -> Node2D:
	return null


func request_tether(keeper: Keeper) -> bool:
	var anchor := nearest_tether_anchor(keeper.center_position(), Cfg.RING_REACH)
	if anchor == null:
		return false
	keeper.tether_attach(anchor, keeper.global_position.distance_to(anchor.global_position))
	return true


# --- Reservoir, latches and feedback ----------------------------------------

func request_aspect_change(_keeper: Keeper) -> bool:
	return true


func spent_swap(_amount: float) -> void:
	pass


func refill_reservoir(_amount: float) -> void:
	pass


func press_source(channel: String, source: Node, pressed: bool) -> void:
	set_latch(channel, pressed)


func set_latch(channel: String, active: bool) -> void:
	latch_changed.emit(channel, active)


func latch(_channel: String) -> bool:
	return false


func note(_message: String) -> void:
	pass


# --- Events -----------------------------------------------------------------

func on_keeper_spilled(_keeper: Keeper, _cause: String) -> void:
	pass


func on_keeper_jumped(_keeper: Keeper) -> void:
	pass


func on_keeper_summoned(_keeper: Keeper) -> void:
	pass


func on_keeper_landed(_keeper: Keeper) -> void:
	pass


func on_aspect_changed(_keeper: Keeper, _from: int, _to: int) -> void:
	pass
