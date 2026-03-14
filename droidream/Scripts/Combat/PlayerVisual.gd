extends Node2D

# This script is responsible for player animations and UI

class_name PlayerVisual

# Attack and action signals
signal attack_started
signal attack_hit
signal attack_finished
signal action_pressed

# _unhandled_input method check variable
var input_enabled = true

# Node variables
@onready var anim := $Visual/Sprite2D/AnimationPlayer
@onready var text_anim := $Visual/RichTextLabel/TextAnimationPlayer
@onready var text := $Visual/RichTextLabel
@onready var block_visual := $PlayerBlockVisual
@onready var hud := $PlayerHUD

# Position variables
var home_position : Vector2 # The player's original position
var attack_position : Vector2 # The position where the player's pattern will connect to the enemy sprite
@export var move_speed := 400.0 # Pixels per second

# HUD variables, will change these 
@onready var hp_bar := $PlayerHUD/HPBar
@onready var hp_fill := $PlayerHUD/HPBar/Fill
@onready var hp_label := $PlayerHUD/HPBar/Label

var hp_fill_max_width = 10.0
var def_fill_max_width = 10.0

func _ready():
	set_home_position()
	anim.animation_finished.connect(_on_anim_finished)
	
	hp_fill_max_width = hp_fill.size.x
	
	anim.play("player_idle")
	# Combat scene's process mode (pausing) for minigames
	process_mode = Node.PROCESS_MODE_PAUSABLE

# Enables _input during enemy turn
func set_input_enabled(enabled):
	input_enabled = enabled

# Attack methods for critical hit timing
func play_attack():
	await _move_to_attack_position(attack_position)
	attack_started.emit()
	anim.play("player_attack")

func on_attack_hit():
	attack_hit.emit()

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
	

# PlayerBlockVisual methods to call
func play_block_success():
	anim.play("player_block")
	block_visual.play_success()

func play_block_fail():
	anim.play("player_hurt")
	block_visual.play_fail()
	
func play_defeat():
	input_enabled = false
	anim.play("player_defeat")

func play_subdue():
	anim.play("player_subdue")
	# Waits for the animation to finish
	while anim.current_animation == "player_subdue":
		await anim.animation_finished

# Logic for animations after they have ended
func _on_anim_finished(anim_name):
	# Coroutine method
	_handle_animation_finished(anim_name)

func _handle_animation_finished(anim_name):
	if anim_name == "player_attack":
		await _move_to_home_position()
		attack_finished.emit()
	elif anim_name == "player_block" or anim_name == "player_hurt":
		anim.play("player_idle")
	elif anim_name == "player_walk" or anim_name == "player_defeat":
		# player_walk is handled by tween logic, player_defeat stays on last frame
		pass

# Plays PlayerBlockVisual cooldown active method
func set_block_cooldown(active: bool):
	block_visual.set_cooldown_active(active)

# Updates UI for player stats with helper functions (identical to EnemyVisual.gd)
func update_hp(current: float, max_hp):
	var ratio = clamp(current / max_hp, 0.0, 1.0)
	hp_fill.size.x = hp_fill_max_width * ratio
	hp_label.text = "%.1f / %.1f" % [current, max_hp]

func hide_hp():
	var tween = create_tween()
	tween.tween_property(hp_bar, "modulate:a", 0.0, 1)
	await tween.finished
	
	hp_bar.visible = false

func show_hp():
	hp_bar.visible = true
	
	var tween = create_tween()
	tween.tween_property(hp_bar, "modulate:a", 1.0, 1)
	await tween.finished
