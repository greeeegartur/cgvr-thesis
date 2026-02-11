extends Resource

# All respective data for a single stage

class_name StageData

# Base enemy counts for a stage (this one being for 1-1, first round of the Jungle)
@export var enemy_count_weights := {
	1: 0.7,
	2: 0.3,
	3: 0.0
}

# All allowed enemies in the stage
@export var allowed_enemies: Array[String]
