extends Control
class_name MultiTamePrompt

signal resolved(score: float)

@onready var ghost = $Ghost
@onready var shape = $Shape

@export var shape_textures: Array[Texture2D]
@export var shrink_time := 0.8
@export var start_scale := Vector2(2.2, 2.2)
@export var target_scale := Vector2.ONE
var score := 0.25

func setup():
	var shape_tex = shape_textures.pick_random()
	ghost.texture = shape_tex
	shape.texture = shape_tex
	
	ghost.modulate = Color(1, 1, 1, 0.35)
	shape.modulate = Color.WHITE
	shape.scale = start_scale
	ghost.scale = target_scale
	modulate = Color.WHITE

func play_prompt() -> float:
	score = 0.25
	var elapsed := 0.0
	var tween := create_tween()
	tween.tween_property(shape, "scale", target_scale, shrink_time)
	
	while elapsed < shrink_time:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		
		if Input.is_action_just_pressed("ui_accept"):
			var t = clamp(elapsed / shrink_time, 0.0, 1.0)
			var accuracy = 1.0 - abs(t - 1.0)
			
			if accuracy >= 0.86:
				score = 1.0
			elif accuracy >= 0.76:
				score = 0.9
			elif accuracy >= 0.62:
				score = 0.75
			elif accuracy >= 0.46:
				score = 0.6
			else:
				score = 0.4
			
			await _play_hit_feedback(accuracy)
			return score
	
	await _play_miss_feedback()
	return 0.25

func _play_hit_feedback(accuracy: float):
	var pop_scale := 1.35 if accuracy >= 0.92 else 1.05
	var tween := create_tween()
	tween.tween_property(shape, "scale", Vector2.ONE * pop_scale, 0.05)
	tween.tween_property(shape, "scale", Vector2.ONE, 0.08)
	await tween.finished

func _play_miss_feedback():
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.35, 0.08)
	tween.tween_property(self, "modulate:a", 1.0, 0.08)
	await tween.finished
