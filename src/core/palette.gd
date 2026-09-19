class_name Palette
extends RefCounted

## Colours and small drawing helpers.
##
## The palette is inspired by Achaemenid materials -- lapis lazuli, turquoise
## glaze, ochre, terracotta brick and limestone -- but is deliberately stylised
## and flat-shaded: the game does not attempt archaeological reconstruction.
##
## Readability rule: nothing in this game is signalled by hue alone. Player 1
## carries a square badge and player 2 a round badge; every device also changes
## shape as well as colour when it is active.

const SKY_TOP := Color("171a2b")
const SKY_BOTTOM := Color("3b3350")
const RIDGE_FAR := Color("2a2b45")
const RIDGE_NEAR := Color("423a52")

const STONE := Color("c9b184")
const STONE_DARK := Color("8f7a55")
const STONE_LIGHT := Color("e2cfa5")
const BRICK := Color("b4743f")
const BRICK_DARK := Color("7d4a26")
const LAPIS := Color("2f58a8")
const TURQUOISE := Color("2f9e8f")
const OCHRE := Color("c2703a")
const GOLD := Color("e0b45c")
const WATER := Color("2a6f8a")
const WATER_LIGHT := Color("55b0c4")
const INK := Color("14131a")
const PAPER := Color("f2e7cf")
const DANGER := Color("b8412f")
const PLUGGED := Color("4a4458")

## Keeper identity colours: keeper 0 = lapis, keeper 1 = ochre.
const KEEPER_COLORS := [LAPIS, OCHRE]
const KEEPER_LIGHT := [Color("6f96e0"), Color("e6a271")]

## Aspect accents: Zam (earth) reads as stone cyan-grey, Vayu (air) as pale gold.
const ASPECT_ACCENT := [Color("8fb6c9"), Color("f0dda2")]


static func keeper_color(index: int) -> Color:
	return KEEPER_COLORS[index % KEEPER_COLORS.size()]


static func keeper_light(index: int) -> Color:
	return KEEPER_LIGHT[index % KEEPER_LIGHT.size()]


## Draws a slab of masonry: base colour plus joint lines, so geometry reads as
## built stone rather than as a solid rectangle.
static func draw_masonry(ci: CanvasItem, rect: Rect2, base: Color, joints: Color, rows: int = 4) -> void:
	ci.draw_rect(rect, base, true)
	if rows <= 0 or rect.size.y < 6.0:
		return
	var step := rect.size.y / float(rows)
	var y := rect.position.y + step
	while y < rect.position.y + rect.size.y - 1.0:
		ci.draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x + rect.size.x, y), joints, 1.0)
		y += step
