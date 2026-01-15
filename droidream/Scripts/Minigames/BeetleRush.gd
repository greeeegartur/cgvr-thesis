extends BaseMinigame

# Beetle rush minigame for the Giant Beetle enemy

# HOW TO PLAY?
# The player is protecting a colony of ants from giant beetles and must flick them away.
# Giant beetles can be flicked by pressing LEFT or RIGHT when they are parallel to the player's lane.
# Survive for 5s to win!

class_name BeetleRush

# Scene variables
@export var beetle_entity: PackedScene
@export var DamageNumberScene: PackedScene

# Node variables
@onready var beetles_node := $VisualRoot/Beetles
@onready var hand := $VisualRoot/PlayerHand
@onready var progress_bar := $VisualRoot/UI/ProgressBar
@onready var timer_label := $VisualRoot/UI/ProgressBar/Timer
@onready var hand_anim := $VisualRoot/PlayerHand/AnimationPlayer
@onready var health_container := $VisualRoot/UI/HealthContainer

# Lane variables
enum Lane { LEFT, MIDDLE, RIGHT }
@onready var lane_positions = {
	Lane.LEFT: $VisualRoot/Lanes/LeftLane.global_position,
	Lane.MIDDLE: $VisualRoot/Lanes/MiddleLane.global_position,
	Lane.RIGHT: $VisualRoot/Lanes/RightLane.global_position,
}
@onready var lane_data = {
	Lane.LEFT: {
		"spawn": $VisualRoot/Lanes/LeftLane/Spawn.global_position,
		"target": $VisualRoot/Lanes/LeftLane/Control.global_position,
	},
	Lane.RIGHT: {
		"spawn": $VisualRoot/Lanes/RightLane/Spawn.global_position,
		"target": $VisualRoot/Lanes/RightLane/Control.global_position,
	}
}

# Player variables
var current_lane := Lane.MIDDLE # Starts from middle
var can_move := true
var hand_cooldown := false
@export var max_hits := 3
var hits_taken := 0 # Default

# Constants
const FLICK_DISTANCE := 80.0
const DAMAGE := 0.3 # Damage player takes if hurt, TO-DO: change this to consider for defense in the future

# Start/Pause variables
var collision_enabled := false
var beetles_paused := false

func _ready():
	# Progress bar setup
	progress_bar.max_value = max_duration
	progress_bar.value = max_duration
	timer_label.text = "%.1fs" % max_duration
	
	# Node order just in case + animation setup
	beetles_node.z_index = 3
	hand_anim.animation_finished.connect(_on_hand_anim_finished)
	
	# Starting minigame – FOR TESTING INSIDE SCENE, DO NOT TURN ON FOR COMBATMANAGER
	#play()

func _process(delta):
	super._process(delta) # for elapsing variable and minigame end condition
	
	if not running:
		return
	
	update_timer_ui()
	check_collisions()

# Player inputs (can move either left or right)
func _unhandled_input(event):
	if not can_move or not running:
		return
	
	if event.is_action_pressed("ui_left"):
		try_flick_move("left")
	elif event.is_action_pressed("ui_right"):
		try_flick_move("right")

# Overriding base function for collision reading (player doesn't get hurt during tween animation)
func play():
	await animate_in()
	# Setting duration of 7.5 seconds
	set_duration(7.5)
	collision_enabled = true
	start()
	spawn_loop()

# Moves hand to position and flicks with try_flick
func try_flick_move(dir: String):
	if hand_cooldown:
		return
	
	var target_lane: int
	if dir == "left":
		target_lane = Lane.LEFT
		hand_anim.play("flick_left")
	elif dir == "right":
		target_lane = Lane.RIGHT
		hand_anim.play("flick_right")
	else:
		return
	
	# If passed check, move hand
	current_lane = target_lane
	hand_cooldown = true # During animation
	
	# Tween animation for hand moving
	var tween = create_tween()
	tween.tween_property(hand, "global_position", lane_positions[target_lane], 0.08)
	try_flick()

# Checks if beetle can be flicked
func try_flick():
	for beetle in beetles_node.get_children():
		if beetle.lane != current_lane:
			continue
		
		if beetle.distance_to_hand(hand) < FLICK_DISTANCE:
			flick_beetle(beetle)

# Main flicking method including tween animation
func flick_beetle(beetle):
	if beetle.flicked:
		return
	
	# Stop beetle activity
	beetle.flicked = true
	beetle.set_process(false)
	beetle.reset_animation()
	
	# Flick direction
	var dir = Vector2.LEFT if beetle.lane == Lane.LEFT else Vector2.RIGHT
	var rotation_dir = -0.8 if beetle.lane == Lane.LEFT else 0.8
	
	# Tween animation
	var tween = create_tween()
	tween.tween_property(beetle, "global_position",
		beetle.global_position + dir * 40,
		0.25)
	tween.parallel().tween_property(beetle, "rotation", rotation_dir, randf_range(0.2, 0.3))
	
	# Individual beetle despawning
	tween.finished.connect(beetle.despawn)

# Checks if player has collided with a beetle or taken damage
func check_collisions():
	if beetles_paused or not collision_enabled:
		return
	
	for beetle in beetles_node.get_children():
		# For rotation tween
		if beetle.flicked:
			continue
		
		# Beetle touches player hand
		if beetle.distance_to_hand(hand) < 33: # in pixels
			deal_damage()
			beetle.despawn()
			
		# Beetle passes
		elif beetle.global_position.distance_to(lane_data[beetle.lane]["target"]) < 7: # in pixels, both set for good feel
			deal_damage()
			beetle.despawn()

# Deals damage to the player in combat scene and spawns DamageNumber scene
func deal_damage():
	if damage_cooldown:
		return
	
	damage_cooldown = true
	hits_taken += 1
	# TO-DO: edit the DAMAGE amount when defense is considered in future
	damage_taken.emit(DAMAGE, hand.global_position)
	spawn_damage_number(DAMAGE)
	hit_stop(0.1)
	shake_node(hits_taken)
	
	update_health()
	if hits_taken >= max_hits:
		end(false)
		return
	
	await get_tree().create_timer(0.25).timeout # Damage cooldown
	damage_cooldown = false

# Spawns combat scene's damage number near the player hand
func spawn_damage_number(damage: float):
	if not DamageNumberScene:
		return
	
	var dmg_scene = DamageNumberScene.instantiate()
	dmg_scene.global_position = hand.global_position
	add_child(dmg_scene)
	dmg_scene.z_index = 5 # Above player hand
	dmg_scene.play(damage, false)

# Starts a loop of spawning BeetleEntity instantiations after every random interval of 0.4 - 0.8 seconds
func spawn_loop():
	while running:
		spawn_beetles()
		await get_tree().create_timer(randf_range(0.55, 0.9)).timeout

# Spawns BeetleEntity instantiations in a random amount from 1-3
func spawn_beetles():
	var lane = [Lane.LEFT, Lane.RIGHT].pick_random()
	var count := randi_range(1, 3) # max 3 at once to not overwhelm player (beetle is 1st enemy after all)
	
	for i in count:
		spawn_beetle(lane)

# Spawns a single BeetleEntity instantiation
func spawn_beetle(lane: int):
	var beetle = beetle_entity.instantiate() as BeetleEntity
	beetle.lane = lane
	
	beetles_node.add_child(beetle)
	
	beetle.global_position = lane_data[lane]["spawn"]
	beetle.set_target(lane_data[lane]["target"])

# Updates timer UI for _process method
func update_timer_ui():
	var remaining : float = max_duration - elapsed
	progress_bar.value = remaining
	timer_label.text = "%.1fs" % max(remaining, 0.0)

# Updates health UI element
func update_health():
	for i in range(health_container.get_child_count()):
		var icon := health_container.get_child(i)
		icon.visible = i < max_hits
		icon.modulate = Color("ffffffff") if i + 1 > hits_taken else Color(1.0, 1.0, 1.0, 0.094)

# Hand reset method, including animation
func _on_hand_anim_finished(anim_name: String):
	if anim_name == "flick_left" or anim_name == "flick_right":
		current_lane = Lane.MIDDLE
		hand_cooldown = false
		hand_anim.play("RESET")
		
		# Make sure hand is physically in middle lane
		hand.global_position = lane_positions[Lane.MIDDLE]

# Overriding BaseMinigame function – win condition is surviving 5s
func on_timeout():
	# Stopping beetle movement (so player can't take any more damage)
	beetles_paused = true
	for beetle in beetles_node.get_children():
		beetle.set_process(false)
	
	end(true)
