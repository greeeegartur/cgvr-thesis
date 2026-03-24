extends Node
# Utility methods and variables for global use everywhere (global script)

const DIR_MAP = {
	"up": Vector2(0, -1),
	"down": Vector2(0, 1),
	"left": Vector2(-1, 0),
	"right": Vector2(1, 0)
}

const OPPOSITE_INPUT = {
	"up": "ui_down",
	"down": "ui_up",
	"left": "ui_right",
	"right": "ui_left"
}

# Picks an option from a dictionary based on its given probability rates
func weighted_pick(weights: Dictionary):
	var total := 0.0
	for value in weights.values():
		total += value
	
	var roll := randf() * total
	var acc := 0.0
	
	for key in weights.keys():
		acc += weights[key]
		if roll <= acc:
			return key
	
	# Fallback (should never happen)
	return weights.keys()[0]
