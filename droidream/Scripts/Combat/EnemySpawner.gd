extends Node

class_name EnemySpawner

func generate(stage: StageData):
	var count = Utils.weighted_pick(stage.enemy_count_weights)
	var result := []
	
	for i in count:
		result.append(stage.allowed_enemies.pick_random())
	
	return result
