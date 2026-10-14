extends Node2D

# Responsible for visual effects when the player executes a block

class_name PlayerBlockVisual

@onready var ring := $Ring
@onready var cooldown := $CooldownOverlay
@onready var anim := $Ring/AnimationPlayer
func _ready():
	ring.visible = false
	cooldown.visible = false

# Successful block feedback
func play_success():
	anim.play("shatter")
	ring.visible = true
	ring.modulate.a = 1.0
	ring.scale = Vector2(0.5, 0.5)

	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.6, 0.28)
	tween.tween_property(ring, "modulate:a", 0.0, 0.28)
	await tween.finished
	ring.visible = false

# Failed block feedback
func play_fail():
	anim.play("shatter")
	ring.visible = true
	ring.modulate = Color(1.0, 0.302, 0.302, 1.0)
	ring.scale = Vector2(0.5, 0.5)

	var tween := create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.28)
	await tween.finished
	ring.visible = false

# Cooldown visual
func set_cooldown_active(active: bool):
	cooldown.visible = active
	cooldown.modulate.a = 0.6
	cooldown.scale = Vector2(1.15, 1.15)
	var tween = create_tween()
	tween.tween_property(cooldown, "modulate:a", 0.0, 0.75)
	tween.parallel().tween_property(cooldown, "scale", Vector2.ONE, 0.2)
	await tween.finished
	
