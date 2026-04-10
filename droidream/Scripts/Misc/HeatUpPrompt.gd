extends Control
class_name HeatUpPrompt

signal resolved(success: bool)

@onready var sprite := $Sprite2D
@export var lifetime := 0.9
const KEY_POOL := [
	{ "action": "heat_a", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_a.png") },
	{ "action": "heat_b", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_b.png") },
	{ "action": "heat_c", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_c.png") },
	{ "action": "heat_f", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_f.png") },
	{ "action": "heat_j", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_j.png") },
	{ "action": "heat_k", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_k.png") },
	{ "action": "heat_l", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_l.png") },
	{ "action": "heat_m", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_m.png") },
	{ "action": "heat_o", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_o.png") },
	{ "action": "heat_p", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_p.png") },
	{ "action": "heat_s", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_s.png") },
	{ "action": "heat_y", "texture": preload("res://Graphics/Placeholders/Minigames/HeatUp keys/heatup_y.png") },
]

var prompt_action := ""
var finished := false

func setup():
	var data = KEY_POOL.pick_random()
	prompt_action = data["action"]
	sprite.texture = data["texture"]
	modulate = Color.WHITE
	scale = Vector2.ONE * 4

func play_prompt():
	finished = false
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.06)
	tween.parallel().tween_property(self, "scale", Vector2.ONE * 4.2, 0.1)
	tween.tween_property(self, "scale", Vector2.ONE * 4, 0.08)
	
	var timer := 0.0
	while timer < lifetime and not finished:
		await get_tree().process_frame
		timer += get_process_delta_time()
		if Input.is_action_just_pressed(prompt_action):
			await _on_success()
			return
	await _on_fail()

func _on_success():
	if finished:
		return
	finished = true
	
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 4.3, 0.06)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	
	resolved.emit(true)
	queue_free()

func _on_fail():
	if finished:
		return
	finished = true
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.08)
	await tween.finished
	
	resolved.emit(false)
	queue_free()
