extends Resource
class_name UIPanelStyle

# The four colors of a UI panel; UIPanel recolors the template art with them (the black outline is kept)

@export var fill := Color8(85, 85, 85)
@export var ring := Color8(129, 129, 129) # Light rim just inside the outline
@export var mark_dark := Color8(58, 58, 58) # Corner marks
@export var mark_light := Color8(115, 115, 115) # Rim corner dots

# Builds a style from the four colors
static func make(p_fill: Color, p_ring: Color, p_mark_dark: Color, p_mark_light: Color) -> UIPanelStyle:
	var style := UIPanelStyle.new()
	style.fill = p_fill
	style.ring = p_ring
	style.mark_dark = p_mark_dark
	style.mark_light = p_mark_light
	return style

# Derives a whole style from one base (fill) color, with the same lightness steps as the default gray panel
static func from_base(base: Color) -> UIPanelStyle:
	var v := base.v
	return make(
		base,
		Color.from_hsv(base.h, base.s, v + (1.0 - v) * 0.26),
		Color.from_hsv(base.h, base.s, v * 0.68),
		Color.from_hsv(base.h, base.s, v + (1.0 - v) * 0.15)
	)

# Presets with the exact colors of the original panel images
static func default_style() -> UIPanelStyle:
	return make(Color8(85, 85, 85), Color8(129, 129, 129), Color8(58, 58, 58), Color8(115, 115, 115))

static func ability_style() -> UIPanelStyle:
	return make(Color8(40, 128, 34), Color8(48, 169, 42), Color8(28, 110, 23), Color8(39, 151, 33))

static func item_style() -> UIPanelStyle:
	return make(Color8(38, 122, 136), Color8(52, 162, 182), Color8(34, 110, 123), Color8(44, 140, 157))

static func tame_style() -> UIPanelStyle:
	return make(Color8(156, 90, 25), Color8(189, 110, 31), Color8(138, 80, 23), Color8(169, 97, 27))
