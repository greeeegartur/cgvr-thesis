extends Control
class_name MultiTameMinigame

signal finished(multiplier: float)

@export var PromptScene: PackedScene
@onready var prompt_area := $PromptArea

func play():
	var scores: Array[float] = []
	var prompt_count = randi_range(3, 4)
	
	for i in prompt_count:
		var prompt = PromptScene.instantiate()
		var random_scale = randf_range(2.0, 3.5)
		prompt_area.add_child(prompt)
		prompt.scale = Vector2(random_scale, random_scale)
		prompt.setup()
		_place_prompt_randomly(prompt)
		
		var score = await prompt.play_prompt()
		scores.append(score)
		prompt.queue_free()
		await get_tree().create_timer(0.15).timeout
	
	finished.emit(_score_to_multiplier(scores))

func _place_prompt_randomly(prompt: Control):
	var area_size = prompt_area.size
	var prompt_w := 96.0
	var prompt_h := 96.0
	var margin := 24.0
	
	prompt.position = Vector2(
		randf_range(margin, area_size.x - prompt_w - margin),
		randf_range(margin, area_size.y - prompt_h - margin)
	)

func _score_to_multiplier(scores: Array[float]) -> float:
	if scores.is_empty():
		return 0.5
	
	var avg := 0.0
	for s in scores:
		avg += s
	avg /= scores.size()
	print(avg)
	if avg >= 0.93:
		return 1.75
	elif avg >= 0.82:
		return 1.5
	elif avg >= 0.68:
		return 1.25
	elif avg >= 0.54:
		return 1.0
	elif avg >= 0.38:
		return 0.5
	return 0.25
