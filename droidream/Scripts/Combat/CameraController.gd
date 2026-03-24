extends Camera2D
class_name CombatCamera

# This script is responsible for all camera movement in the combat scene (player and enemy turns)

# Camera zoom variables
@export var zoom_normal = Vector2(1.0, 1.0)
@export var zoom_focus = Vector2(1.15, 1.15)

# Camera movement variable
@export var follow_speed := 3.0
@export var x_offset := 60.0

# Temporary zoom system
var base_zoom: Vector2
var zoom_tween: Tween

# Camera's position variables
var default_position: Vector2
var follow_target: Node2D = null
var override = false

func _ready():
	default_position = global_position
	zoom = zoom_normal
	base_zoom = zoom_normal
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
func pop_zoom(amount := 0.18, duration := 0.17):
	var tween := create_tween()
	tween.tween_property(self, "zoom", zoom * (1.0 + amount), duration * 0.4)
	tween.tween_property(self, "zoom", zoom, duration * 0.6)

# Zoom in for victory screen
func victory_focus_on_player(target: Node2D) -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, 0.8)
	tween.parallel().tween_property(self, "zoom", Vector2(2.2, 2.2), 0.6)
	tween.parallel().tween_property(self, "offset", Vector2(10, 65), 0.6)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	await tween.finished

func reset_camera():
	follow_target = null
	override = true
	
	if zoom_tween:
		zoom_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", default_position, 0.5)
	tween.parallel().tween_property(self, "zoom", zoom_normal, 0.5)
	tween.parallel().tween_property(self, "offset", Vector2.ZERO, 0.5)
	
	await tween.finished
	override = false

func ability_focus_on_player(target: Node2D, zoom_amount: Vector2, duration := 0.4):
	follow_target = target
	override = false
	
	if zoom_tween:
		zoom_tween.kill()
	
	base_zoom = zoom 
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "zoom", zoom_amount, duration)
