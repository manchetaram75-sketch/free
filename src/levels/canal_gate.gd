class_name CanalGate
extends LevelBase

## Garden 1 - The Canal Gate (teaching garden)
##
## Teaches, in order:
##   1. the two body sizes  - a low tunnel only the swift keeper fits through;
##   2. the two verbs       - Zam roots and carries, Vayu doubles and glides;
##   3. one holds for the other - Vayu's plate opens Zam's doorway;
##   4. the waystone         - checkpoints, so a mistake costs seconds.
##
## Deliberately free of wind and water: nothing here can kill you except the
## chasm, and the chasm has a tether ring over it as a forgiving second route.

const GROUND := 900.0
## The low tunnel between the wall foot and the floor: Vayu's route.
const TUNNEL_HEIGHT := 44.0
## The gateless opening above it, which only Zam's body fits through.
const DOORWAY_HEIGHT := 140.0
const WALL_X := 700.0
const CHASM_LEFT := 2120.0
const CHASM_RIGHT := 2400.0


func _build() -> void:
	bounds = Rect2(0, 0, 2800, 1280)
	objective = "Cross the great wall and restore the canal heart together."
	spawn(Vector2(240, GROUND), Vector2(320, GROUND))

	add_text(Vector2(210, 860), "Keeper 1: A/D move, Space jumps, F changes shape, S acts.\nKeeper 2: arrows move, Z jumps, C changes shape, X acts.\nYou can only change shape while the braid between you is bright.", 560)

	# --- Ground ---------------------------------------------------------
	add_ground(Rect2(0, GROUND, CHASM_LEFT, 380))
	add_ground(Rect2(CHASM_RIGHT, GROUND, 400, 380))

	# --- Grand stair up to Zam's doorway -------------------------------
	add_platform(Vector2(500, 830), Vector2(120, 70), "stone")
	add_platform(Vector2(620, 760), Vector2(80, 140), "stone")

	# --- The wall: low tunnel for Vayu, high doorway for Zam -------------
	add_solid(Rect2(WALL_X, 420, 60, 200), "masonry")
	add_solid(Rect2(WALL_X, 760, 60, GROUND - TUNNEL_HEIGHT - 760.0), "masonry")
	# Vayu's tunnel is the 44px gap between y 856 and y 900.
	add_decor(Vector2(830, GROUND), Vector2(40, 60), "planter")

	# Zam's doorway (y 620..760) is filled by the gate until Vayu's plate
	# is pressed.
	add_gate(Vector2(WALL_X + 30, 690), Vector2(60, DOORWAY_HEIGHT), "canal", Vector2(0, -DOORWAY_HEIGHT), {
		"carving": "canal gate",
	})
	add_plate(Vector2(1120, GROUND), "canal", {"weight": 1.0, "sticky": true, "label": "holds the canal gate"})

	# --- Well and waystones ---------------------------------------------
	add_well(Vector2(1000, GROUND))
	add_waystone(Vector2(180, GROUND), 0)
	add_waystone(Vector2(1800, GROUND), 1)

	# --- Barrier 2: the chasm -------------------------------------------
	# 280px across: Vayu clears it with a double jump; Zam cannot, ever.
	# A tether ring hangs over the middle so Vayu can also simply swing.
	add_ring(Vector2((CHASM_LEFT + CHASM_RIGHT) * 0.5, 690))
	add_decor(Vector2(1980, GROUND), Vector2(44, 120), "cypress")

	# The drawbridge: retracted into the far masonry until Vayu's plate.
	add_plate(Vector2(2520, GROUND), "bridge", {"weight": 1.0, "sticky": true, "label": "drawbridge"})
	add_gate(Vector2(CHASM_RIGHT + 140, GROUND + 12), Vector2(280, 24), "bridge", Vector2(-280, 0), {
		"speed": 260.0,
		"carving": "",
	})

	# --- The garden heart -----------------------------------------------
	goal_rect = Rect2(2620, 700, 150, 200)
	goal_requires_both = true
	add_heart(Rect2(2620, 700, 150, 200))
	add_decor(Vector2(2450, GROUND), Vector2(44, 260), "column")
	add_decor(Vector2(2340, GROUND), Vector2(44, 200), "column")
	add_decor(Vector2(430, GROUND), Vector2(40, 140), "cypress")
	add_decor(Vector2(1600, GROUND), Vector2(52, 220), "column")


func _step(_delta: float) -> void:
	# Nothing dynamic in this garden; it is the quiet one.
	pass
