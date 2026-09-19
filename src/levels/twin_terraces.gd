extends LevelBase

## Garden 3 - The Twin Terraces (teaching garden)
##
## Teaches the weight and hold rules:
##   1. a plate needing weight 2.0 refuses a lone un-rooted Zam (1.8) but
##      accepts a rooted one (2.3), or the pair standing together;
##   2. "hold it for me" - one keeper keeps a plate down while the other
##      travels, and the plate is *not* sticky, so the lift comes back down;
##   3. the shoulder launch - the only way up a 300px face.
##
## The three terraces are exactly one Zam-jump apart (300px) so no amount of
## platforming skill can skip the cooperation.

const LOW := 1000.0
const MID := 700.0
const HIGH := 400.0


func _build() -> void:
	bounds = Rect2(0, 0, 2900, 1500)
	objective = "Weigh the stone, hold the lift and launch your partner to the high terrace."
	spawn(Vector2(180, LOW), Vector2(260, LOW))

	add_text(Vector2(170, 960), "A plate that wants weight 2.0 will not accept one light keeper.\nRooting (ACTION held) makes a keeper press harder.\nCarrying: stand close, tap ACTION on the sturdy keeper, then JUMP.", 560)

	# --- Terraces -------------------------------------------------------
	add_ground(Rect2(0, LOW, 1400, 400))
	add_ground(Rect2(1400, MID, 800, 400))
	add_ground(Rect2(2200, HIGH, 700, 400))

	# --- Stage 1: the weight plate and the stair door -------------------
	add_plate(Vector2(320, LOW), "stair_door", {
		"weight": 2.0,
		"label": "weight 2.0: root here",
	})
	# 240 tall: more than either keeper can jump, so the plate is the only key.
	add_gate(Vector2(985, 880), Vector2(48, 240), "stair_door", Vector2(0, -260), {"carving": "stair"})
	# Four 75px steps: each one is inside a single Zam jump, so the stair
	# itself is never the puzzle - the *door* is.
	add_platform(Vector2(1010, 925), Vector2(70, 75), "stone")
	add_platform(Vector2(1080, 850), Vector2(60, 150), "stone")
	add_platform(Vector2(1140, 775), Vector2(60, 225), "stone")
	add_platform(Vector2(1200, 700), Vector2(60, 300), "stone")
	add_waystone(Vector2(700, LOW), 0)

	# --- Stage 2: the lift Zam rides ------------------------------------
	add_plate(Vector2(1650, MID), "lift_one", {"weight": 1.0, "label": "hold to raise the lift"})
	add_gate(Vector2(1330, LOW + 15), Vector2(140, 30), "lift_one", Vector2(0, -300), {
		"speed": 200.0,
		"carving": "lift",
	})
	add_waystone(Vector2(1800, MID), 1)

	# --- Stage 3: launch, then the second lift --------------------------
	add_plate(Vector2(2360, HIGH), "lift_two", {"weight": 1.0, "label": "hold to raise the high lift"})
	add_gate(Vector2(2130, MID + 15), Vector2(140, 30), "lift_two", Vector2(0, -300), {
		"speed": 200.0,
		"carving": "lift",
	})
	add_ring(Vector2(2060, HIGH - 60))

	# The high terrace is 300 above the middle one: out of reach for a jump
	# from either keeper, in reach only of a launched partner.
	add_decor(Vector2(2120, MID), Vector2(44, 200), "column")
	add_decor(Vector2(2560, HIGH), Vector2(44, 120), "cypress")
	add_decor(Vector2(1120, LOW), Vector2(40, 130), "cypress")

	goal_rect = Rect2(2660, 240, 160, 160)
	goal_requires_both = true
	add_heart(Rect2(2660, 240, 160, 160))
