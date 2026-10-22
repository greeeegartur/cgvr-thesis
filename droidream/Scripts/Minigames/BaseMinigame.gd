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
var end_sound: Node # The dream-end sound once it plays
var end_sound_started := false
var end_serial := 0
var timer_running_sound := true # False once the timer stopped early, so the dream-end sound stays quiet
const DREAM_EXIT_FADE := 0.8
var running = false

# Damage signal for CombatManager, including position
signal damage_taken(amount: float, world_position: Vector2)
var damage_cooldown := false
var entered := false # The enter animation has played

# Visual node
@onready var visual_root := $VisualRoot
@onready var progress_bar := $VisualRoot/UI/ProgressBar
@onready var timer_label := $VisualRoot/UI/ProgressBar/Timer

func _ready():
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
	_update_end_sound()
	if elapsed >= max_duration:
		on_timeout()

# SOUNDS
# The dream-end sound starts when its own length is left on the timer, so it ends exactly when the timer reaches 0
func _update_end_sound() -> void:
	if end_sound_started or not timer_running_sound:
		return
	var remaining: float = max_duration - elapsed
	var length: float = Sfx.length_of("dream_end")
	if remaining <= length:
		end_sound_started = true
		end_sound = Sfx.play_ui("dream_end", { "from": length - remaining })
		end_serial = Sfx.serial_of(end_sound)

# The timer stopped before 0 (a win or a reveal): the dream-end sound fades away and does not start anymore
func stop_timer_sound() -> void:
	timer_running_sound = false
	if end_sound_started:
		Sfx.stop(end_sound, 0.2, end_serial)

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
	stop_timer_sound()
	
	# The box tweens out with the exit sound fading away on a sine
	var exit_sound := Sfx.play_ui("dream_exit")
	Sfx.stop(exit_sound, DREAM_EXIT_FADE, Sfx.serial_of(exit_sound))
	completed.emit(success)
	await animate_out()
	queue_free()

# Ease in/out animation tween transition methods
# The box grows in once; if it is already there (a countdown, a tutorial explanation or a pause came first) it stays where it is until the minigame ends
func animate_in():
	if entered:
		return
	entered = true
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
	ControlTextures.swap_in(self) # Every minigame's _ready calls this first: the key pictures of the scheme in use

# In Combat scene methods
func _enter_tree():
	if self is Control:
		set_anchors_preset(Control.PRESET_FULL_RECT)

func _force_process_always(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	
	for child in node.get_children():
		_force_process_always(child)

# Updates timer UI for _process method
func update_timer_ui():
	var remaining : float = max_duration - elapsed
	progress_bar.value = remaining
	timer_label.text = "%.1fs" % max(remaining, 0.0)

# freeze_frame from CombatManager to go around combat scene limitations during minigame pause
func hit_stop(time := 0.06, scale := 0.6):
	Engine.time_scale = scale
	await get_tree().create_timer(time, true).timeout
	Engine.time_scale = 1.0

# Creates light position shake for minigame node (from EnemyVisual)
func shake_node(strength: float):
	var original_pos = position
	
	# Tween that gets more powerful with stregnth modifier given by minigame
	var tween := create_tween()
	tween.tween_property(
		self,
		"position",
		original_pos + Vector2(randf_range(strength * -8.0, strength * 8.0),
		 randf_range(strength * -8.0, strength * 8.0)),
		0.05
	)
	tween.tween_property(self, "position", original_pos, 0.1)

# TEST MINIGAME
#func _input(event):
	#if not running:
		#return
#
	#if event.is_action_pressed("ui_accept"):
		#if elapsed >= success_window.x and elapsed <= success_window.y:
			#print("pressed - victory!")
			#end(true)
		#else:
			#print("not pressed - defeat...")
			#end(false)
