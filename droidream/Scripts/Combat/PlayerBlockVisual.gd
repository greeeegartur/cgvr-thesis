extends Node2D

# Responsible for visual effects when the player executes a block

class_name PlayerBlockVisual

@onready var ring := $Ring
@onready var cooldown := $CooldownOverlay
var initial_scale = Vector2.ONE * 0.21

func _ready():
	ring.visible = false
	cooldown.visible = false

# Successful block feedback
func play_success():
	ring.visible = true
	ring.scale = initial_scale
	ring.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(ring, "scale", initial_scale * 1.6, 0.25)
	tween.tween_property(ring, "modulate:a", 0.0, 0.25)
	await tween.finished
	ring.visible = false

# Failed block feedback
func play_fail():
	ring.visible = true
	ring.scale = initial_scale
	ring.modulate = Color(1, 0.3, 0.3, 0.8)

	var tween := create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.2)
	await tween.finished
	ring.visible = false

# Cooldown visual
func set_cooldown_active(active: bool):
	cooldown.visible = active
