extends Node2D

# This script is for controlling and animating damage number visuals for EnemyVisual to use

@onready var label : RichTextLabel = $Label

# Plays a tween animation and decides label properties based on given hit type
func play(value: float, is_critical: bool, is_heal := false):
	var text := str(value)
	if is_critical:
		text = "[wave freq=10]" + text + "![/wave]"

	label.text = text
	if is_critical:
		label.modulate = Color.YELLOW
	elif is_heal:
		label.modulate = Color.GREEN
	else: 
		label.modulate = Color.RED
	
	scale = Vector2(1.3, 0.7)
	rotation_degrees = randf_range(-6, 6)

	# Random direction
	var dir := -1 if randf() < 0.5 else 1
	var x_offset := randf_range(18, 34) * dir
	var y_offset := randf_range(-28, -46)
	
	var tween := create_tween()
	# Stretching
	tween.tween_property(
		self,
		"scale",
		Vector2(0.8, 1.25),
		0.08
	)
	tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.12
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Shake effect
	if is_critical:
		_shake(0.18, 4.0)
	elif is_heal:
		_shake(0.16, 3.0)
	else:
		_shake(0.12, 2.0)
	
	# Floating
	tween.parallel().tween_property(
		self,
		"position",
		position + Vector2(x_offset, y_offset),
		0.6
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Fading
	tween.parallel().tween_property(
		self,
		"modulate:a",
		0.0,
		0.6
	)

	await tween.finished
	queue_free()

func _shake(duration: float, strength: float):
	var original := position
	var time := 0.0
	while time < duration:
		position = original + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		await get_tree().process_frame
		time += get_process_delta_time()
	position = original
