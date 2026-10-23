extends Resource

# All respective data for a single stage

class_name StageData

# Base enemy counts for a stage (this one being for 1-1, first round of the Jungle)
@export var enemy_count_weights := {
	1: 0.7,
	2: 0.3,
	3: 0.0
}

# Defaults, meant to be changed
@export var creature_weights := {
	1: {
		"bat": 0.2,
		"beetle": 0.8
	},

	2: {
		"bat": 0.4,
		"beetle": 0.6
	},

	3: {
		"bat": 0.7,
		"beetle": 0.3
	}
}

# Generation fairness: weight multipliers that make repeats less likely
const SAME_ENCOUNTER_PENALTY := 0.3 # Per copy already picked in this encounter (2nd copy x0.3, 3rd x0.09)
const PREVIOUS_ENCOUNTER_PENALTY := 0.7 # For creatures that appeared in the previous encounter
const NO_CHIP_PENALTY := 0.78 # For creatures whose type the player has no chips left for: it counts only a little, so the right chip is often missing
const MIN_WEIGHT := 0.02
const REPEAT_TRIES := 5 # Rolls before a repeat of the previous encounter is allowed (a stage with only one possible set never hangs)

# Creatures of the last generated encounter (shared by all stages)
static var last_encounter: Array = []

# Rolls the creatures of an encounter; an encounter with exactly the same creatures as the previous one (in any order) is rolled again, a few times at most
func generate():
	var previous := last_encounter.duplicate()
	previous.sort()
	var result := _roll()
	for attempt in REPEAT_TRIES - 1:
		var sorted := result.duplicate()
		sorted.sort()
		if previous.is_empty() or sorted != previous:
			break
		result = _roll()
	last_encounter = result.duplicate()
	return result

# One roll of an encounter's creatures (the fairness multipliers lower repeats and creatures without chips)
func _roll() -> Array:
	var count = Utils.weighted_pick(enemy_count_weights)
	var result := []
	
	var base_weights = creature_weights[count]
	for i in count:
		var weights := {}
		for enemy_id in base_weights:
			var base: float = base_weights[enemy_id]
			if base <= 0.0:
				weights[enemy_id] = 0.0 # Creatures not part of this stage stay out
				continue
			weights[enemy_id] = max(MIN_WEIGHT, base * _fairness_multiplier(enemy_id, result))
		result.append(Utils.weighted_pick(weights))
	
	return result

# Lowers a creature's odds based on this encounter so far, the previous encounter and the player's chips
func _fairness_multiplier(enemy_id: String, picked_so_far: Array) -> float:
	var multiplier := 1.0
	multiplier *= pow(SAME_ENCOUNTER_PENALTY, picked_so_far.count(enemy_id))
	
	if last_encounter.has(enemy_id):
		multiplier *= PREVIOUS_ENCOUNTER_PENALTY
	
	var enemy = EnemyDatabase.get_enemy(enemy_id)
	if enemy is EnemyInfo and enemy.type != CombatTypes.EntityType.NONE and not PlayerData.has_guess(enemy.type):
		multiplier *= NO_CHIP_PENALTY
	
	return multiplier
