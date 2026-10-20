extends Node2D

# This script is responsible for player animations and UI

class_name PlayerVisual

# Attack and action signals
signal action_pressed
signal ability_entered
signal ability_finished
signal item_finished

var in_ability_animation := false

# _unhandled_input method check variable
var input_enabled = true

# Node variables
var selection_pulse: SelectionPulse
@onready var anim := $Visual/Sprite2D/AnimationPlayer
@onready var text_anim := $Visual/RichTextLabel/TextAnimationPlayer
@onready var text := $Visual/RichTextLabel
@onready var block_visual := $PlayerBlockVisual
@onready var hud := $PlayerHUD
@onready var target_arrow := $TargetArrow
@onready var target_arrow_anim := $TargetArrow/AnimationPlayer
@onready var emotion_bubble: Node2D = $EmotionBubble
@onready var emotion_icon: Sprite2D = $EmotionBubble/Bubble
@export var worry_emote: Texture2D
@export var exclamation_emote: Texture2D
@export var question_emote: Texture2D
var emote_tween: Tween

# Position variables
var home_position : Vector2 # The player's original position
var attack_position : Vector2 # The position where the player's pattern will connect to the enemy sprite
@export var move_speed := 400.0 # Pixels per second

# HUD variables
@onready var hp_icon := $PlayerHUD/HPIcon
@onready var hp_progress: TextureProgressBar = $PlayerHUD/HPIcon/HeartProgress
@onready var hp_label: Label = $PlayerHUD/HPIcon/Label

var hp_tween: Tween

func _ready():
	selection_pulse = SelectionPulse.new(self, $Visual, $Visual/Sprite2D)
	set_home_position()
	anim.animation_finished.connect(_on_anim_finished)
	
	hp_progress.min_value = 0.0
	hp_progress.max_value = 1.0
	hp_progress.value = 1.0
	emotion_bubble.visible = false
	
	anim.play("player_idle")
	# Combat scene's process mode (pausing) for minigames
	process_mode = Node.PROCESS_MODE_PAUSABLE

# Enables _input during enemy turn
func set_input_enabled(enabled):
	input_enabled = enabled

# Walks to the creature and waits there (the tame timing sequence runs on its own)
func walk_to_target():
	await _move_to_attack_position(attack_position)
	anim.play("player_idle")

# POSES WHILE TAMING
# Every press of the tame sequence snaps the Droid into a random pose (never the same twice in a row) at a random speed; the newest press overrides the last
const TAME_POSES := ["player_ability_start", "player_ability_loop", "player_ability_end", "player_subdue"] # No item pose: it looks too much like the dream animation
const POSE_SPEED := Vector2(0.9, 1.4)
const POSE_MAX_TIME := 0.8 # A pose does not need to play fully: after this long (at its speed) the Droid is idle again
var last_pose := ""
var pose_serial := 0

func pose_on_press() -> void:
	if in_ability_animation:
		return
	var options := TAME_POSES.filter(func(name): return name != last_pose)
	last_pose = options.pick_random()
	var speed := randf_range(POSE_SPEED.x, POSE_SPEED.y)
	pose_serial += 1
	var mine := pose_serial
	anim.play(last_pose, -1, speed) # The custom speed only applies to this play
	var length := minf(anim.current_animation_length / speed, POSE_MAX_TIME)
	await get_tree().create_timer(length).timeout
	# Back to idle unless a newer press or another animation took over
	if mine == pose_serial and anim.current_animation == last_pose:
		anim.play("player_idle")

# A small shrug after a sequence without a single press (no sound, no hurt animation)
func play_shrug() -> void:
	pose_serial += 1
	anim.play("player_idle")
	var base_scale: Vector2 = $Visual.scale
	var base_rotation: float = $Visual.rotation
	var tween := create_tween()
	tween.tween_property($Visual, "scale", base_scale * Vector2(1.06, 0.92), 0.1)
	tween.parallel().tween_property($Visual, "rotation", deg_to_rad(-4.0), 0.1)
	tween.tween_property($Visual, "scale", base_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($Visual, "rotation", base_rotation, 0.2)

# Movement methods for connecting patterns using tweens (same methods just in reverse, identical to EnemyVisual)
func _move_to_attack_position(target: Vector2):
	var dist = global_position.distance_to(target)
	var duration = dist / move_speed # t = d/v
	
	anim.play("player_walk")
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, duration)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished

func _move_to_home_position():
	var dist = global_position.distance_to(home_position)
	var duration = dist / move_speed # t = d/v
	
	anim.play("player_walk")
	var tween := create_tween()
	tween.tween_property(self, "global_position", home_position, duration)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN)
	await tween.finished
	anim.play("player_idle")

# Sets the home position in CombatManager
func set_home_position():
	home_position = global_position

# Post-minigame return logic after subdue animation
func return_to_home():
	await _move_to_home_position()
	anim.play("player_idle")

# Listens to block/critical input for CombatManager to play according PlayerBlockVisual animations
func _unhandled_input(event):
	if not input_enabled:
		return
	
	if event.is_action_pressed("ui_accept"):
		action_pressed.emit()
		# action_pressed emit here

func play_restore_chip():
	text.visible = true
	text_anim.play("restored")
	

# Plays the block pose on every block button press, regardless of timing or cooldown
func play_block_press():
	if in_ability_animation:
		return
	anim.play("player_block")
	block_visual.play_press()

# PlayerBlockVisual methods to call
# Stun jitter while a hit-stop lasts: a few whole pixels at 30 Hz in real time (off with the Camera shake setting)
func stun(duration: float) -> void:
	if not Settings.camera_shake:
		return
	var base: Vector2 = $Visual.position
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	for i in int(duration * 30.0):
		tween.tween_property($Visual, "position", base + Vector2(randi_range(-2, 2), randi_range(-2, 2)), 1.0 / 30.0)
	tween.tween_property($Visual, "position", base, 0.0)

# Shoves the player away from the attacker and back home again (off with the Camera shake setting)
var push_tween: Tween
func push_back(distance: float) -> void:
	if not Settings.camera_shake:
		return
	if push_tween:
		push_tween.kill()
	push_tween = create_tween() # Scaled time, so the shove plays out after the hit-stop
	push_tween.tween_property(self, "global_position:x", home_position.x - distance, 0.06)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	push_tween.tween_property(self, "global_position:x", home_position.x, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func play_block_success():
	if in_ability_animation:
		return
	# Does not restart the pose if the press already started it
	if anim.current_animation != "player_block":
		anim.play("player_block")
	block_visual.play_success()
	push_back(12.0)

func play_block_fail():
	if in_ability_animation:
		return
	anim.play("player_hurt")
	block_visual.play_fail()
	push_back(18.0)
	
func play_defeat():
	input_enabled = false
	anim.play("player_defeat")

func play_subdue():
	anim.play("player_dream")
	# Waits for the animation to finish
	while anim.current_animation == "player_dream":
		await anim.animation_finished

func play_ability_start():
	in_ability_animation = true
	anim.play("player_ability_start")
	await ability_entered

func play_ability_end():
	if not in_ability_animation:
		return
	
	anim.play("player_ability_end")
	await ability_finished
	in_ability_animation = false
	anim.play("player_idle")

func play_item_use():
	in_ability_animation = true
	anim.play("player_item")
	await item_finished
	in_ability_animation = false
	anim.play("player_idle")

# Logic for animations after they have ended
func _on_anim_finished(anim_name):
	# Coroutine method
	_handle_animation_finished(anim_name)

func _handle_animation_finished(anim_name):
	if anim_name == "player_block" or anim_name == "player_hurt":
		anim.play("player_idle")
	elif anim_name == "player_ability_start":
		if not in_ability_animation: # A pose of the tame sequence does not start the ability loop
			return
		anim.play("player_ability_loop")
		ability_entered.emit()
	elif anim_name == "player_ability_end":
		ability_finished.emit()
	elif anim_name == "player_item":
		item_finished.emit()
	elif anim_name == "player_walk" or anim_name == "player_defeat":
		# player_walk is handled by tween logic, player_defeat stays on last frame
		pass

# Plays PlayerBlockVisual cooldown active method
func set_block_cooldown(active: bool):
	block_visual.set_cooldown_active(active)

# Updates UI for player stats with helper functions (identical to EnemyVisual.gd)
func update_hp(current: float, max_hp: float):
	# HP is already stored in quarters, so it is shown as it is
	var rounded_current = current
	var rounded_max = max_hp
	var ratio := 0.0
	if rounded_max > 0.0:
		ratio = clamp(rounded_current / rounded_max, 0.0, 1.0)
	
	if hp_tween:
		hp_tween.kill()
	
	hp_tween = create_tween()
	hp_tween.tween_property(hp_progress, "value", ratio, 0.25)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	
	hp_label.text = format_quarter_number(rounded_current)
	_fit_hp_label()

func hide_hp():
	var tween = create_tween()
	tween.tween_property(hp_icon, "modulate:a", 0.0, 1)
	await tween.finished
	
	hp_icon.visible = false

func show_hp():
	hp_icon.visible = true
	
	var tween = create_tween()
	tween.tween_property(hp_icon, "modulate:a", 1.0, 1)
	await tween.finished

# The player's selection uses the same effect as creatures: pop, tint, outline and arrow bob on one beat
func show_target_arrow():
	target_arrow.visible = true
	target_arrow_anim.stop()
	selection_pulse.start(1.0, 1.5, target_arrow.get_node("Sprite2D"))

func hide_target_arrow():
	selection_pulse.stop()
	target_arrow.visible = false

# HELPERS
func format_quarter_number(value: float) -> String:
	value = Utils.quantize(value)
	
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	
	var text := "%.2f" % value
	if text.ends_with("0"):
		text = text.left(text.length() - 1)
	
	return text

func _fit_hp_label():
	await get_tree().process_frame
	
	var max_size := 16
	var min_size := 12
	var current_size := max_size
	
	while current_size >= min_size:
		hp_label.add_theme_font_size_override("font_size", current_size)
		await get_tree().process_frame
		
		if not _is_hp_label_overflowing():
			return
		
		current_size -= 1

func _is_hp_label_overflowing() -> bool:
	var font := hp_label.get_theme_font("font")
	var font_size := hp_label.get_theme_font_size("font_size")
	var text_size := font.get_string_size(hp_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	return text_size.x > hp_label.size.x or text_size.y > hp_label.size.y

func bubble_emote(emote_id: String, duration := 1.5):
	var texture := _get_emote_texture(emote_id)
	if texture == null:
		return
	
	if emote_tween:
		emote_tween.kill()
	
	emotion_icon.texture = texture
	emotion_bubble.visible = true
	emotion_bubble.modulate.a = 0.0
	emotion_bubble.scale = Vector2.ZERO
	
	emote_tween = create_tween()
	emote_tween.tween_property(emotion_bubble, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	emote_tween.parallel().tween_property(emotion_bubble, "modulate:a", 1.0, 0.12)
	emote_tween.tween_interval(duration)
	emote_tween.tween_property(emotion_bubble, "scale", Vector2.ZERO, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
	emote_tween.parallel().tween_property(emotion_bubble, "modulate:a", 0.0, 0.15)
	
	await emote_tween.finished
	emotion_bubble.visible = false

func _get_emote_texture(emote_id: String) -> Texture2D:
	match emote_id:
		"worry":
			return worry_emote
		"exclamation":
			return exclamation_emote
		"question":
			return question_emote
	
	push_warning("Unknown player emote: " + emote_id)
	return null

func hop():
	var base_y := position.y
	var tween := create_tween()
	tween.tween_property(self, "position:y", base_y - 14, 0.12)
	tween.tween_property(self, "position:y", base_y, 0.18)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished

func walk_in_to(target_pos: Vector2, from_offset := Vector2(-180, 0), duration := 0.9):
	visible = true
	position = target_pos + from_offset
	home_position = target_pos
	
	anim.play("player_walk")
	
	var tween := create_tween()
	tween.tween_property(self, "position", target_pos, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	position = target_pos
	set_home_position()
	anim.play("player_idle")
