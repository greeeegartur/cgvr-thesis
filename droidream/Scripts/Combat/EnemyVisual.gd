extends Node2D

# Universal attack pattern logic for all enemies, uses emitters for connecting animations in CombatManager

class_name EnemyVisual

signal attack_started
signal attack_hit
signal attack_finished

# Node variables
@onready var anim := $AnimationPlayer
@onready var visual: Node2D = $Visual
@onready var hud := $EnemyHUD
@onready var target_arrow := $TargetArrow
@onready var target_arrow_anim := $TargetArrow/AnimationPlayer
@onready var turn_order_label: Label = $TurnOrder
@onready var axis_bar := $EnemyAxisBar

# Shake variables
@export var shake_strength = 3.0
@export var crit_shake_strength = 6.0
var attack_animation_name: String
var support_animation_name: String

# Position variables + defeated check
var home_position : Vector2 # The enemy's original position
var attack_position : Vector2 # The position where the enemy's pattern will connect to the (intended) player sprite
var attack_offset := Vector2.ZERO # The attack position's offset for the enemy (different for every enemy)
var move_speed := 0 # Pixels per second, different for every enemy
var is_defeated := false # Checks if visual can play any other animations

# Enemy moves to position, attacks, returns back to original position
func play_attack(animation_name: String):
	attack_animation_name = animation_name
	await _move_to_attack_position(attack_position)
	attack_started.emit()
	anim.play(animation_name)

# Enemy support animation (attack method but not moving to attack position)
func play_support(animation_name: String):
	support_animation_name = animation_name
	attack_started.emit()
	anim.play(animation_name)
	await anim.animation_finished
	attack_finished.emit()

# Plays from CombatManager to decide defeat animation
func play_defeat(subdued: bool):
	is_defeated = true
	anim.play("subdue" if subdued else "death")

func on_attack_hit():
	attack_hit.emit()

func _ready():
	# Making visual visible (for some reason does not render otherwise)
	top_level = true
	visible = true
	z_index = 1
	
	anim.animation_finished.connect(on_anim_finished)
	
	# Combat scene's process mode (pausing) for minigames
	process_mode = Node.PROCESS_MODE_PAUSABLE

# When animation has finished
func on_anim_finished(name: String):
	if is_defeated:
		return
	if name == "RESET":
		return
	if name == attack_animation_name or name == support_animation_name:
		anim.play("idle")
	await _move_to_home_position()
	attack_finished.emit()

# Movement methods for connecting patterns using tweens (same methods just in reverse)
func _move_to_attack_position(target: Vector2):
	var dist = global_position.distance_to(target)
	var duration = dist / move_speed # t = d/v
	
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, duration)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished

func _move_to_home_position():
	var dist = global_position.distance_to(home_position)
	var duration = dist / move_speed # t = d/v
	
	var tween := create_tween()
	tween.tween_property(self, "global_position", home_position, duration)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN)
	await tween.finished

# Sets up axis UI info for CombatManager
func setup_axis(axis_max: float, trust_max: int):
	axis_bar.axis_max = axis_max
	axis_bar.setup_trust(trust_max)

# Updates axis UI info for enemy with EnemyAxisBar functions
func update_axis(value: float, delta_value := 0):
	axis_bar.update_axis(value, delta_value)

func update_axis_trust():
	axis_bar.gain_trust()

# Creates light position shake for enemy
func shake(is_critical: bool):
	var strength = crit_shake_strength if is_critical else shake_strength
	var original_pos = visual.position
	
	var tween := create_tween()
	tween.tween_property(
		visual,
		"position",
		original_pos + Vector2(randf_range(-strength, strength), randf_range(-strength, strength)),
		0.05
	)
	tween.tween_property(visual, "position", original_pos, 0.1)

# Target arrow UI elements
func show_target_arrow():
	if target_arrow.visible:
		return
	target_arrow.visible = true
	target_arrow_anim.play("idle")

func hide_target_arrow():
	if is_defeated:
		return
	target_arrow.visible = false
	target_arrow_anim.play("RESET")

# Turn order UI elements
func show_turn_order(n: int):
	turn_order_label.text = str(n)
	turn_order_label.visible = true

func hide_turn_order():
	turn_order_label.visible = false
