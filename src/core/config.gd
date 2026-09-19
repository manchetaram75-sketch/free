class_name Cfg
extends RefCounted

## Central tuning table for Two Keepers.
##
## Every number a designer is likely to touch lives here so that the game
## feel, the level-authoring rules (tools/level_check) and the automated
## tests all read from one source of truth.

# --- Movement / physics -----------------------------------------------------
const GRAVITY := 1800.0
const MAX_FALL_SPEED := 1250.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.12
const JUMP_CUT := 0.45            # upward velocity kept when the jump key is released
const GLIDE_FALL_SPEED := 168.0   # terminal fall speed while gliding (Vayu)
const GLIDE_RESPONSE := 1500.0    # how quickly the glide speed is reached

# --- Collision layers (bitmasks) --------------------------------------------
const LAYER_WORLD := 1
const LAYER_KEEPER := 2
const LAYER_DEVICE := 4
const LAYER_HAZARD := 8

# --- The shared reservoir (the garden well) ---------------------------------
const RESERVOIR_MAX := 100.0
const SWAP_COST := 34.0           # cost of ONE keeper changing Aspect
const SWAP_COOLDOWN := 0.30
const WELL_RATE_SOLO := 22.0      # reservoir units / second, one keeper at a well
const WELL_RATE_TOGETHER := 60.0  # both keepers at the same well
const WELL_RADIUS := 46.0
const WELL_TOGETHER_RANGE := 130.0

# --- Attunement -------------------------------------------------------------
# Keepers may only change Aspect while attuned: close enough that the light
# braid between them is bright. Levels may widen or disable this.
const ATTUNEMENT_RADIUS := 250.0
const ATTUNEMENT_ASSIST_RADIUS := 520.0

# --- Tether (Vayu only) -----------------------------------------------------
const TETHER_ATTACH_RANGE := 230.0
const TETHER_REST := 150.0
const TETHER_MAX := 190.0
const TETHER_MIN := 62.0
const TETHER_REEL_SPEED := 50.0    # px/second the rope shortens while held
const TETHER_STIFFNESS := 26.0     # acceleration per pixel of stretch
const TETHER_DAMPING := 5.0
const RING_REACH := 240.0

# --- Wind channels ----------------------------------------------------------
# A wind channel publishes a *drift velocity*: the speed at which it would
# carry a body along. A keeper is dragged toward that drift at WIND_PULL, which
# is deliberately stronger than either keeper's own acceleration: this makes
# the rule crisp ("a gust simply carries the swift keeper, and barely touches
# the sturdy one") instead of a muddle of competing accelerations.
const WIND_EARTH_SCALE := 0.12     # Zam is too heavy for a gust to matter
const WIND_AIR_SCALE := 1.0
const WIND_PULL := 2600.0

# --- Shoulder boost (Zam launches a rider) ----------------------------------
const BOOST_SPEED := 1150.0
const BOOST_SIDE_PUSH := 70.0
const SHOULDER_WIDTH := 46.0
const SHOULDER_HEIGHT := 16.0

# --- Failure / recovery -----------------------------------------------------
const RESPAWN_GRACE := 0.6
const FALL_MARGIN := 140.0         # distance below the level bounds that counts as a fall
const FLOOD_MERCY_TIME := 1.6
const FLOOD_MERCY_DROP := 44.0
const GOAL_HOLD_TIME := 0.5
const ASSIST_HAZARD_SCALE := 0.45  # flood rise speed multiplier in assist mode

# --- Camera -----------------------------------------------------------------
const CAMERA_MIN_ZOOM := 0.46
const CAMERA_MAX_ZOOM := 1.05
const CAMERA_MARGIN := Vector2(320.0, 300.0)
const CAMERA_FOLLOW_SPEED := 6.0
const CAMERA_ZOOM_SPEED := 3.0
