class_name Device
extends Node2D

## Base class for every garden device the level can drive.
##
## The level calls tick() in a fixed order once per physics frame instead of
## letting each device run its own _physics_process. That makes the simulation
## deterministic (and testable): well refill always happens before wind, wind
## before plates, plates before latches, latches before gates.

var world: KeeperWorld = null


func tick(_delta: float) -> void:
	pass
