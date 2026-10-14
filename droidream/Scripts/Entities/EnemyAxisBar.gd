extends Node

# This script is responsible for setting up the enemy entities' "health bar" UI so to say
# In Droidream, enemies have axis bars that can shift to the left or right, left representing the kill option and the right side representing the tame option

# Node variables
@onready var line := $AxisLine
@onready var tame_container := $TameContainer

# Tame container variables
const BASE_SCALE := Vector2.ONE
const BIG_SCALE  := Vector2(1.2, 1.2)
var trust := 0 # Initial trust variables, trust = index
var trust_max := 0 # Actual max that will be set by setup_trust

# Axis variables
@export var axis_max := 100.0
@export var move_range := 38.0 # Exact pixels to go either side of the axis bar
@export var center_x := 0.0
@export var min_scale := 1.0
@export var max_scale := 1.7

func _ready():
	center_x = line.position.x

# Updates axis position and scale with tween animations based on given value for ratio
func update_axis(value: float, delta_value := 0):
	# Checks for old ongoing tweens and stops them to not overload
	if line.has_meta("axis_tween"):	
		var old_tween: Tween = line.get_meta("axis_tween")
		if old_tween and old_tween.is_running():
			old_tween.kill()
	
	# Necessary variable setup for line movement
	var ratio = clamp(value / axis_max, -1.0, 1.0) # Setting ratio limits by axis texture
	var target_x = center_x + ratio * move_range # Target position of line, goes either left or right
	var distance = abs(target_x - line.position.x) # Exact distance to target based on line
	var impact = clamp(abs(delta_value) / axis_max, 0.0, 1.0)
	
	# Duration scales with distance (so big hits = faster movement and snapping)
	var duration = clamp(distance / move_range, 0.13, 0.32)
	
	var resting_scale = _get_resting_scale(ratio)
	
	# Tween setup
	var tween := create_tween()
	line.set_meta("axis_tween", tween)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	
	# Movement to target
	tween.tween_property(line, "position:x", target_x, duration)

	# Scale from resting_scale
	tween.parallel().tween_property(line, "scale", resting_scale, duration)
	
	# Shake tween to give a sense of impact
	tween.parallel().tween_property(
		line,
		"position:x",
		line.position + Vector2(randf_range(impact + 1.25, impact + 1.25),
		 randf_range(impact + 1.25, impact + 1.25)),
		0.1
	)
	tween.parallel().tween_property(line, "position:x", target_x, 0.1)

# Calculates a state scale for the axis line based on given ratio
func _get_resting_scale(ratio: float):
	var t = abs(ratio) # Is 0 if at the center, 1 if at the edges of the bar
	var s = lerp(min_scale, max_scale, t)
	return Vector2(s, s)

# Sets up a specific enemy's trust slots UI
func setup_trust(max_value: int):
	trust = 0
	trust_max = max_value
	
	for i in tame_container.get_child_count():
		var slot = tame_container.get_child(i)
		slot.visible = i < trust_max
		slot.modulate = Color(0.25, 0.25, 0.25)
		slot.scale = Vector2.ONE
	
	update_tame_container_scales_for_enemy()

# Tween animation for gaining trust
func gain_trust():
	# Failsafe check
	if trust >= trust_max:
		return
	
	# Gets specific trust slot by trust index
	var slot := tame_container.get_child(trust)
	trust += 1
	
	# Animating back to normal modulate level
	var tween := create_tween()
	tween.tween_property(slot, "modulate", Color.WHITE, 0.25)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	# Quick scale pop effect
	slot.scale = Vector2(1.4, 1.4)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

# Updates tame slot scales depending on how many there are for the enemy, TO-DO: Test
func update_tame_container_scales_for_enemy():
	var items := []
	for child in tame_container.get_children():
		if child is TextureRect and child.visible:
			items.append(child)
	
	match items.size():
		1:
			items[0].scale = BASE_SCALE
		
		2:
			items[0].scale = BIG_SCALE
			items[1].scale = BIG_SCALE
		
		3:
			items[0].scale = BIG_SCALE
			items[1].scale = BASE_SCALE
			items[2].scale = BIG_SCALE
