extends Node
# Utility methods for global use everywhere (global script)

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
