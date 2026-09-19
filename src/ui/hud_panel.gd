class_name HudPanel
extends Control

## The gameplay HUD, drawn entirely in code so it scales with Settings.ui_scale
## and needs no imported assets.
##
## Information rules:
##   * everything is doubled between an icon/shape and a word, so nothing is
##     carried by hue alone;
##   * the reservoir (your shared budget of transformation) is always visible,
##     because "can we still change?" is the most common question in the game.

var level: LevelBase = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _font_size(base: int) -> int:
	return int(round(float(base) * Settings.ui_scale))


func _draw() -> void:
	if level == null:
		return
	var font := ThemeDB.fallback_font
	var view := size

	_draw_keeper_card(font, 0, Vector2(24, 24))
	_draw_keeper_card(font, 1, Vector2(view.x - 24.0, 24), true)
	_draw_reservoir(font, Vector2(view.x * 0.5, 30))
	_draw_mission(font, Vector2(view.x * 0.5, 96))
	_draw_note(font, Vector2(view.x * 0.5, view.y - 96.0))
	_draw_goal_progress(font, Vector2(view.x * 0.5, view.y * 0.5))
	_draw_off_screen_markers(font, view)


func _draw_keeper_card(font: Font, index: int, corner: Vector2, right_aligned := false) -> void:
	var keeper := level.pair[index] if level.pair.size() > index else null
	if keeper == null or not is_instance_valid(keeper):
		return
	var fs := _font_size(18)
	var small := _font_size(14)
	var card_w := 300.0 * Settings.ui_scale
	var card_h := 92.0 * Settings.ui_scale
	var origin := Vector2(corner.x if not right_aligned else corner.x - card_w, corner.y)
	var rect := Rect2(origin, Vector2(card_w, card_h))
	draw_rect(rect, Color(Palette.INK, 0.55), true)
	draw_rect(rect, Color(Palette.keeper_color(index), 0.9), false, 3.0)

	# Badge: square for keeper 1, ring for keeper 2.
	var badge := origin + Vector2(28, 30) * Settings.ui_scale
	if index == 0:
		draw_rect(Rect2(badge - Vector2.ONE * 11.0, Vector2.ONE * 22.0), Palette.PAPER, true)
	else:
		draw_circle(badge, 11.0, Palette.PAPER)
		draw_circle(badge, 5.5, Palette.INK)

	var text_x := origin.x + 52.0 * Settings.ui_scale
	draw_string(font, Vector2(text_x, origin.y + 30.0 * Settings.ui_scale), "KEEPER %d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.keeper_color(index))
	draw_string(font, Vector2(text_x, origin.y + 56.0 * Settings.ui_scale), "%s - %s" % [keeper.aspect_name().to_upper(), Forms.subtitle_of(keeper.aspect).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, small, Palette.PAPER)

	var device := Controls.device_label(index)
	var attuned := keeper.attuned()
	var state := "LINKED" if attuned else "APART"
	var state_colour := Palette.TURQUOISE if attuned else Palette.DANGER
	draw_string(font, Vector2(text_x, origin.y + 78.0 * Settings.ui_scale), "%s  |  %s" % [device, state], HORIZONTAL_ALIGNMENT_LEFT, -1, small, state_colour)

	# Aspect verbs, so players can learn the rules from the HUD.
	var verbs := _verbs_for(keeper)
	draw_string(font, Vector2(origin.x + 12.0 * Settings.ui_scale, origin.y + card_h - 12.0 * Settings.ui_scale), verbs, HORIZONTAL_ALIGNMENT_LEFT, card_w - 24.0, _font_size(13), Color(Palette.PAPER, 0.75))

	# A small flame shows the roots when a keeper is anchored.
	if keeper.rooted:
		draw_string(font, Vector2(origin.x + card_w - 60.0 * Settings.ui_scale, origin.y + card_h - 12.0 * Settings.ui_scale), "ROOTED", HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(13), Palette.GOLD)


func _verbs_for(keeper: Keeper) -> String:
	if keeper.carried:
		return "JUMP: leap off the shoulders"
	if keeper.rider != null:
		return "ACTION held: carry   JUMP: launch"
	if keeper.aspect == Forms.ZAM:
		return "ACTION held: root   ACTION tap: lift partner"
	if keeper.tether_active:
		return "ACTION held: reel in   tap: release"
	return "ACTION: tether a ring or your partner"


func _draw_reservoir(font: Font, centre: Vector2) -> void:
	var width := 320.0 * Settings.ui_scale
	var height := 22.0 * Settings.ui_scale
	var rect := Rect2(Vector2(centre.x - width * 0.5, centre.y - height * 0.5), Vector2(width, height))
	draw_rect(rect.grow(4.0), Color(Palette.INK, 0.6), true)
	draw_rect(rect, Color(Palette.STONE_DARK, 0.8), true)
	var fill := Rect2(rect.position, Vector2(rect.size.x * level.reservoir_ratio(), rect.size.y))
	var full := level.reservoir_ratio() > 0.66
	draw_rect(fill, Palette.LAPIS if not full else Palette.TURQUOISE, true)
	# Tick marks: one per Aspect change the well can still pay for.
	var cost_ratio := Cfg.SWAP_COST / Cfg.RESERVOIR_MAX
	var ticks := int(Cfg.RESERVOIR_MAX / Cfg.SWAP_COST)
	for i in ticks:
		var x := rect.position.x + rect.size.x * cost_ratio * float(i + 1)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + rect.size.y), Color(Palette.INK, 0.7), 2.0)
	draw_rect(rect, Palette.STONE_LIGHT, false, 2.0)
	var label := "GARDEN WELL   %d SHAPES LEFT" % level.swaps_left()
	draw_string(font, Vector2(centre.x - width * 0.5, rect.position.y - 8.0 * Settings.ui_scale), label, HORIZONTAL_ALIGNMENT_LEFT, width, _font_size(14), Palette.PAPER)


func _draw_mission(font: Font, centre: Vector2) -> void:
	var title := GameState.level_title(GameState.current_level)
	var line := "%s   |   %02d:%02d   |   spills %d" % [title.to_upper(), int(level.elapsed) / 60, int(level.elapsed) % 60, level.spills]
	draw_string(font, Vector2(centre.x - 300.0, centre.y), line, HORIZONTAL_ALIGNMENT_CENTER, 600.0, _font_size(15), Color(Palette.PAPER, 0.85))
	draw_string(font, Vector2(centre.x - 320.0, centre.y + 24.0), level.objective, HORIZONTAL_ALIGNMENT_CENTER, 640.0, _font_size(14), Color(Palette.PAPER, 0.6))


func _draw_note(font: Font, centre: Vector2) -> void:
	var note := level.current_note()
	if note == "":
		_draw_hint(font, centre)
		return
	draw_string(font, Vector2(centre.x - 300.0, centre.y), note, HORIZONTAL_ALIGNMENT_CENTER, 600.0, _font_size(18), Palette.GOLD)


func _draw_hint(font: Font, centre: Vector2) -> void:
	# A single, contextual nudge: the pair is apart and cannot transform, or a
	# keeper is loaded and could tether, or one keeper is carrying the other.
	for keeper in level.pair:
		if not is_instance_valid(keeper):
			continue
		if keeper.rider != null:
			draw_string(font, Vector2(centre.x - 300.0, centre.y), "Carrying your partner - JUMP launches them up", HORIZONTAL_ALIGNMENT_CENTER, 600.0, _font_size(16), Color(Palette.PAPER, 0.8))
			return
	if level.pair.size() == 2 and not level.pair[0].attuned():
		draw_string(font, Vector2(centre.x - 300.0, centre.y), "Too far apart to change shape - stand close and the braid brightens", HORIZONTAL_ALIGNMENT_CENTER, 600.0, _font_size(16), Color(Palette.PAPER, 0.7))
		return
	for keeper in level.pair:
		if not is_instance_valid(keeper):
			continue
		if keeper.aspect == Forms.VAYU and not keeper.tether_active:
			for ring in level.rings:
				if keeper.global_position.distance_to(ring.global_position) <= Cfg.RING_REACH:
					draw_string(font, Vector2(centre.x - 300.0, centre.y), "ACTION tethers the ring - hold to reel, swing to travel", HORIZONTAL_ALIGNMENT_CENTER, 600.0, _font_size(16), Color(Palette.PAPER, 0.7))
					return


func _draw_goal_progress(font: Font, centre: Vector2) -> void:
	var progress := level.goal_progress()
	if progress <= 0.01:
		return
	var rect := Rect2(Vector2(centre.x - 140.0, centre.y - 12.0), Vector2(280.0, 24.0))
	draw_rect(rect, Color(Palette.INK, 0.7), true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * progress, rect.size.y)), Palette.GOLD, true)
	draw_rect(rect, Palette.PAPER, false, 2.0)
	draw_string(font, Vector2(rect.position.x, rect.position.y - 8.0), "STAND TOGETHER TO RESTORE THE GARDEN", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, _font_size(14), Palette.PAPER)


func _draw_off_screen_markers(_font: Font, view: Vector2) -> void:
	if level.camera == null:
		return
	var transform := level.camera.get_canvas_transform()
	var margin := 48.0
	# The "is this keeper on screen?" test rect has to be a real rect. A degenerate
	# viewport (a headless run, or a window dragged down to nothing) would make it
	# negative, and Rect2 refuses to answer queries about a negative size, so the
	# markers are simply skipped instead.
	var inset := view - Vector2(margin, margin) * 2.0
	if inset.x <= 0.0 or inset.y <= 0.0:
		return
	var on_screen := Rect2(Vector2(margin, margin), inset)
	for index in level.pair.size():
		var keeper := level.pair[index]
		if not is_instance_valid(keeper):
			continue
		var screen := transform * keeper.center_position()
		if on_screen.has_point(screen):
			continue
		var clamped := Vector2(clampf(screen.x, margin, view.x - margin), clampf(screen.y, margin, view.y - margin))
		var direction := (screen - clamped)
		if direction.length() < 1.0:
			direction = Vector2.DOWN
		direction = direction.normalized()
		var side := Vector2(-direction.y, direction.x)
		var tip := clamped + direction * 14.0
		draw_colored_polygon(PackedVector2Array([
			tip,
			clamped - direction * 10.0 + side * 12.0,
			clamped - direction * 10.0 - side * 12.0,
		]), Palette.keeper_color(index))
		if index == 0:
			draw_rect(Rect2(clamped - Vector2.ONE * 6.0, Vector2.ONE * 12.0), Palette.PAPER, true)
		else:
			draw_circle(clamped, 7.0, Palette.PAPER)
			draw_circle(clamped, 3.5, Palette.keeper_color(index))
