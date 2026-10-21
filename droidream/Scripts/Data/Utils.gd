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
	
	var last_key = weights.keys()[0]
	for key in weights.keys():
		if weights[key] <= 0.0:
			continue # A key without weight is never picked (not even by a roll of exactly 0)
		last_key = key
		acc += weights[key]
		if roll <= acc:
			return key
	
	# Fallback (rounding): the last key that has weight
	return last_key

# Returns an array of all the wrong types
func _get_wrong_guess_type(enemy_type: CombatTypes.EntityType) -> CombatTypes.EntityType:
	var all_types = [
		CombatTypes.EntityType.SKY,
		CombatTypes.EntityType.EARTH,
		CombatTypes.EntityType.WATER
	]
	
	var wrong_types: Array[CombatTypes.EntityType] = []
	for t in all_types:
		if t != enemy_type:
			wrong_types.append(t)
	
	return wrong_types.pick_random()

# QUARTER-STEP MATH
# All HP and intent meter values live on a 0.25 grid (see Resources/prd/hp-and-damage-math.md)
const QUARTER := 0.25
const AXIS_SNAP := 0.25 # A creature this close to either end counts as tamed/killed
const AXIS_SAFE_MARGIN := 0.5 # Effects that must never tame or kill (Scratchy Frame, Hypno Bone) stop this far from the ends

# Rounds a value to the nearest quarter (ties away from zero)
func quantize(value: float) -> float:
	return round(value / QUARTER) * QUARTER

# Rounds to the nearest quarter, but a positive amount never rounds down to nothing
func quantize_min(value: float, minimum := QUARTER) -> float:
	if value <= 0.0:
		return 0.0
	return max(quantize(value), minimum)

# Damage a hit deals to the player: rounded once at the end; a hit that deals damage is at least one step, even after defense
func hit_damage(raw_damage: float, defense: float) -> float:
	if raw_damage <= 0.0:
		return 0.0
	return max(quantize(raw_damage - defense), QUARTER)

# Quantizes an axis value, keeps it on the bar and snaps it to the end when it is within one step of it
func snap_axis(value: float, axis_max: float) -> float:
	var v := clampf(quantize(value), -axis_max, axis_max)
	if v >= axis_max - AXIS_SNAP:
		return axis_max
	if v <= -axis_max + AXIS_SNAP:
		return -axis_max
	return v
