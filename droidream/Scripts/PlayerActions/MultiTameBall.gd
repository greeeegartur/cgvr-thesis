extends Node2D
class_name MultiTameBall

@onready var sprite := $Sprite2D
@export var ball_texture : Texture2D
@export var multi_ball_texture : Texture2D

func fly_to(target_pos: Vector2, arc_height := 40.0, duration := 0.3):
	var start = global_position
	var mid = (start + target_pos) * 0.5 + Vector2(0, -arc_height)
	var tween := create_tween()
	tween.tween_method(
		func(t):
			global_position = _quadratic_bezier(start, mid, target_pos, t)
			rotation = lerp(-0.2, 0.25, t),
		0.0,
		1.0,
		duration
	)
	await tween.finished

func bounce_and_fade(target_pos: Vector2):
	var tween := create_tween()
	tween.set_parallel(false)
	
	# Squashes on impact
	tween.tween_property(sprite, "scale", Vector2(1.25, 0.75), 0.05)
	
	# Bounces up
	tween.parallel().tween_property(self, "global_position:y", target_pos.y - 26, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.12)
	tween.parallel().tween_property(self, "rotation", 0.18, 0.12)
	
	# Falls back down
	tween.tween_property(self, "global_position:y", target_pos.y, 0.14)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.85), 0.08)
	
	# Fades
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.08)
	tween.parallel().tween_property(self, "rotation", 0.0, 0.08)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	
	await tween.finished
	queue_free()

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

func set_to_ball_texture():
	sprite.texture = ball_texture
	sprite.vframes = 1

func reset_after_ball_texture():
	sprite.texture = multi_ball_texture
	sprite.vframes = 2
