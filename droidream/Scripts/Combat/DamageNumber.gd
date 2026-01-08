extends Node2D

# This script is for controlling and animating damage number visuals for EnemyVisual to use

# Plays a tween animation and decides label properties based on given hit type
func play(value: float, is_critical: bool):
	$Label.text = str(round(value)) + "!" if is_critical else str(round(value))
	$Label.modulate = Color.YELLOW if is_critical else Color.RED
	$Label.scale = Vector2.ONE * (1.4 if is_critical else 1.0)

	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 30, 0.6)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	tween.finished.connect(queue_free)
