extends Resource

# This script is responsible for all area logic in Droidream, like transitioning from the Jungle to the Caverns

class_name AreaData

# Area identification variables
@export var area_id: String
@export var area_name: String

# Presentation variables
@export var background_scene: PackedScene # Background for the scene

# Enemy logic
@export var enemy_pool: Array[String] # All the possible enemies in the area

# Stage data with 3 elements (1st, 2nd, 3rd stage)
@export var stages: Array[StageData]

# TO-DO: Difficulty modifiers
#@export var base_enemy_level := 1
#@export var karma_scaling := 0.15

func generate_enemies(stage: StageData) -> Array[String]:
	var count := stage.enemy_count_weights
	var result := []
	
	for i in count:
		result.append(stage.allowed_enemies.pick_random())
	
	return result
