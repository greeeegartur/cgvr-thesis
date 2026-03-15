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

func generate():
	var count = Utils.weighted_pick(enemy_count_weights)
	var result := []
	
	var weights = creature_weights[count]
	for i in count:
		var enemy_id = Utils.weighted_pick(weights)
		result.append(enemy_id)
	
	return result
