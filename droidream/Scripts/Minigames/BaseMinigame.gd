extends Control

# This script is responsible for the general structure of all minigames

class_name BaseMinigame

# TEST MINIGAME
#@export var success_window := Vector2(0.0, 5.0)

# Decides if a minigame has been successfully finished or not
signal completed(success : bool)

# Base minigame variables (duration and timer)
@export var max_duration = 5.0
var elapsed = 0.0
var running = false

# Damage signal for CombatManager, including position
signal damage_taken(amount: float, world_position: Vector2)
var damage_cooldown := false

# Visual node
@onready var visual_root := $VisualRoot

func _ready():
	if self is Control:
		size = get_viewport_rect().size
	visible = true
	_force_process_always(self)
	set_process(false)
	set_process_input(false)
	
	# Node settings for minigame screen fill (just in case)
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

func _process(delta):
	# Failsafe check condition
	if not running:
		return
	
	elapsed += delta
	if elapsed >= max_duration:
		on_timeout()

func on_timeout():
	# Notify child class, child minigames decide whether win or loss
	# i.e. false – victory condition not met during 5s, true – survived 5s minigame
	end(false)

func play():
	await animate_in()
	start()

func start():
	print("Minigame started")
	elapsed = 0.0
	running = true
	set_process(true)
	set_process_input(true)

func end(success : bool):
	if not running:
		return
	
	print("Minigame ended: ", success)
	running = false
	set_process(false)
	set_process_input(false)
	
	completed.emit(success)
	await animate_out()
	queue_free()

# Ease in/out animation tween transition methods
func animate_in():
	visual_root.scale = Vector2.ZERO
	visual_root.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(visual_root, "scale", Vector2.ONE, 0.6)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual_root, "modulate:a", 1.0, 0.6)
	
	await tween.finished

func animate_out():
	var tween = create_tween()
	tween.tween_property(visual_root, "scale", Vector2.ZERO, 0.6)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual_root, "modulate:a", 0.0, 0.6)
	
	await tween.finished
	queue_free()

# Duration setting for minigames
func set_duration(value: float):
	max_duration = value

# In Combat scene methods
func _enter_tree():
	if self is Control:
		set_anchors_preset(Control.PRESET_FULL_RECT)

func _force_process_always(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	
	for child in node.get_children():
		_force_process_always(child)


# TEST MINIGAME
#func _input(event):
	#if not running:
		#return
#
	#if event.is_action_pressed("action"):
		#if elapsed >= success_window.x and elapsed <= success_window.y:
			#print("pressed - victory!")
			#end(true)
		#else:
			#print("not pressed - defeat...")
			#end(false)
