extends Control
class_name MultiTameMinigame

signal finished(multiplier: float)

@export var PromptScene: PackedScene
@onready var prompt_area := $PromptArea

var anchors: Array = [] # Creatures the ability hits: shapes appear over them, one after another

func play():
	var scores: Array[float] = []
	var prompt_count = randi_range(3, 4)
	
	for i in prompt_count:
		var prompt = PromptScene.instantiate()
		prompt_area.add_child(prompt)
		prompt.scale = Vector2(PROMPT_SCALE, PROMPT_SCALE)
		prompt.setup()
		_place_prompt_over(prompt, i)
		
		var score = await prompt.play_prompt()
		scores.append(score)
		prompt.queue_free()
		await get_tree().create_timer(0.15).timeout
	
	finished.emit(_score_to_multiplier(scores))

const PROMPT_SCALE := 2.6
const HEIGHT_ABOVE := 100.0 # World pixels from a creature to its shape

# Puts the shape above the creature it belongs to (through the camera); with several creatures the shapes go round them in turn
func _place_prompt_over(prompt: Control, index: int) -> void:
	if anchors.is_empty():
		_place_prompt_randomly(prompt)
		return
	var anchor: Node2D = anchors[index % anchors.size()]
	var canvas := get_viewport().get_canvas_transform()
	var spot := canvas * anchor.global_position + canvas.basis_xform(Vector2(0, -HEIGHT_ABOVE))
	prompt.position = spot - prompt_area.global_position
	prompt.scale *= canvas.get_scale().x

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
		return 1.85
	elif avg >= 0.82:
		return 1.6
	elif avg >= 0.68:
		return 1.35
	elif avg >= 0.54:
		return 1.1
	elif avg >= 0.38:
		return 0.6
	return 0.25
