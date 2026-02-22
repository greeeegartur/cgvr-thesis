extends Node2D

# Beetle entity in Beetle Rush minigame

class_name BeetleEntity

# Node variable
@onready var anim := $BeetleAnimation

# Physics variables for beetle
var lane: int
var speed := 120.0
var scale_speed := 0.25
var flicked := false

# Position variables
var target_position : Vector2
var direction : Vector2

func _ready():
	visible = true
	anim.play("walk")

func _process(delta):
	if flicked:
		return
	
	global_position += direction * speed * delta
	scale += Vector2.ONE * scale_speed * delta

# Sets the target position for beetle entity, must be set on spawn
func set_target(pos: Vector2):
	target_position = pos
	direction = (target_position - global_position).normalized()

# Checks distance to hand
func distance_to_hand(hand: Node2D):
	return global_position.distance_to(hand.global_position)

# Despawning tween animation for beetle entity
func despawn():
	set_process(false)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.finished.connect(queue_free)

# For flicking method in BeetleRush.gd
func reset_animation():
	anim.play("RESET")
