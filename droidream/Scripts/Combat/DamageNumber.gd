extends Node2D

# This script is for controlling and animating damage number visuals for EnemyVisual to use

@onready var label : Label = $Label

# Plays a tween animation and decides label properties based on given hit type
func play(value: float, is_critical: bool):
	label.text = str((value)) + "!" if is_critical else str((value))
	label.modulate = Color.YELLOW if is_critical else Color.RED
	label.scale = Vector2.ONE * (1.4 if is_critical else 1.0)
	
	var dir = -1 if randf() < 0.5 else 1
	var x_offset = randf_range(16, 32) * dir
	var y_offset = randf_range(-24, -40)
	
	var tween := create_tween()
	tween.tween_property(
		self,
		"position",
		position + Vector2(x_offset, y_offset),
		0.6
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	tween.parallel().tween_property(
		self,
		"modulate:a",
		0.0,
		0.6
	)
	
	tween.finished.connect(queue_free)
