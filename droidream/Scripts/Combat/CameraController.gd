extends Camera2D
class_name CombatCamera

# This script is responsible for all camera movement in the combat scene (player and enemy turns)

# Camera zoom variables
@export var zoom_normal = Vector2(1.0, 1.0)
@export var zoom_focus = Vector2(1.15, 1.15)

# Camera movement variable
@export var follow_speed := 3.0
@export var x_offset := 60.0

# Camera's position variables
var default_position: Vector2
var follow_target: Node2D = null
var override = false

func _ready():
	default_position = global_position
	zoom = zoom_normal

func _process(delta):
	# If shouldn't be following
	if override:
		return
	
	# Follows only X-axis position, might rework if making bigger enemies
	var target_x := default_position.x
	if follow_target:
		target_x = follow_target.global_position.x + x_offset
	
	# Staggering behind with delay to not feel stiff
	global_position.x = lerp(
		global_position.x,
		target_x,
		delta * follow_speed
	)

# CombatManager functions to call
# Follows given entity with a given offset (80 for player for example)
func follow(node: Node2D, offset := 0.0):
	follow_target = node
	x_offset = offset
	# Focuses on entity
	var tween := create_tween()
	tween.tween_property(self, "zoom", zoom_focus, 0.3)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN)

# Stops following entity
func stop_follow():
	follow_target = null
	# Resets zoom
	var tween := create_tween()
	tween.tween_property(self, "zoom", zoom_normal, 0.3)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN)


# Camera shake for critical hits/powerful attacks
func shake(intensity := 6.0, time := 0.15):
	override = true
	
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(
		func(v):
			offset = Vector2(randf_range(-v, v), randf_range(-v, v)),
		intensity,
		0.0,
		time
	)
	tween.finished.connect(func():
		offset = Vector2.ZERO
		override = false
	)

# For critical hits
func pop_zoom(amount := 0.1, duration := 0.12):
	var tween := create_tween()
	tween.tween_property(self, "zoom", zoom * (1.0 - amount), duration * 0.4)
	tween.tween_property(self, "zoom", zoom, duration * 0.6)
