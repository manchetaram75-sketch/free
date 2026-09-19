class_name Gate
extends AnimatableBody2D

## A stone door, bar or drawbridge. It slides by `open_offset` while its latch
## channel is on. Because it is an AnimatableBody2D with sync_to_physics, it
## carries keepers standing on it and reports its velocity, so a keeper can
## also tether to a gate and be swung by it.
##
## A gate refuses to keep closing through a keeper: it pauses instead. This
## removes the classic co-op frustration of being squashed by your own puzzle.

@export var channel := "gate"
@export var size := Vector2(48, 160)
@export var open_offset := Vector2(0, -200)
@export var speed := 220.0
@export var invert := false
@export var one_way := false
@export var start_open := false
@export var carving := ""

var world: KeeperWorld = null
var open := false
var progress := 0.0

var _shape: CollisionShape2D
var _last_position := Vector2.ZERO
var _velocity := Vector2.ZERO
var _blocked := false
var _ever_opened := false


func _ready() -> void:
	collision_layer = Cfg.LAYER_DEVICE
	collision_mask = 0
	sync_to_physics = true
	z_index = 4
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)
	progress = 1.0 if start_open else 0.0
	_ever_opened = start_open
	_position_from_progress()
	_last_position = global_position
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if world != null:
		var wanted := world.latch(channel)
		if invert:
			wanted = not wanted
		if one_way and _ever_opened:
			wanted = true
		if wanted:
			_ever_opened = true
		open = wanted

	var target := 1.0 if open else 0.0
	if not is_equal_approx(progress, target):
		var step := (speed / maxf(_travel_length(), 1.0)) * delta
		if target > progress:
			progress = minf(target, progress + step)
		else:
			progress = maxf(target, progress - step)

	_move_to(progress)
	_velocity = (global_position - _last_position) / maxf(delta, 0.0001)
	_last_position = global_position
	queue_redraw()


func get_velocity() -> Vector2:
	return _velocity


func _travel_length() -> float:
	return maxf(open_offset.length(), 1.0)


func _position_from_progress() -> void:
	global_position += open_offset * progress


func _move_to(value: float) -> void:
	var current := global_position
	var desired := position + open_offset * value
	var motion := (desired - current)
	if motion.length_squared() < 0.0001:
		position = desired
		return
	var collision := move_and_collide(motion, true)
	if collision != null:
		var collider := collision.get_collider()
		if collider is Keeper:
			# Never crush a keeper: hold position and let the players solve it.
			_blocked = true
			return
	_blocked = false
	position = desired


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	Palette.draw_masonry(self, rect, Palette.STONE_DARK, Palette.STONE.darkened(0.4), 6)
	draw_rect(rect, Palette.BRICK, false, 3.0)
	# A carved panel that fills as the door opens.
	var panel := Rect2(-size * 0.5 + Vector2(6, 6), size - Vector2(12, 12))
	draw_rect(panel, Palette.STONE.darkened(0.12), true)
	var filled := Rect2(panel.position + Vector2(0, panel.size.y * (1.0 - progress)), Vector2(panel.size.x, panel.size.y * progress))
	draw_rect(filled, Palette.LAPIS, true)
	for i in 4:
		var y := panel.position.y + panel.size.y * float(i) / 4.0
		draw_line(Vector2(panel.position.x, y), Vector2(panel.position.x + panel.size.x, y), Palette.STONE_DARK, 2.0)
	if carving != "":
		draw_string(ThemeDB.fallback_font, Vector2(-size.x * 0.5, -8.0), carving, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Palette.PAPER, 0.5))
	if _blocked:
		draw_rect(rect.grow(6.0), Color(Palette.GOLD, 0.5), false, 2.0)
	if Settings.high_contrast:
		draw_rect(rect.grow(12.0), Color(Palette.PAPER, 0.5), false, 1.0)
