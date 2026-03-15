extends Control

# Script logic for the RewardsScreen scene

class_name RewardsScreen

signal confirmed

@onready var panel := $Panel
@onready var gear_sprite := $Panel/GearSprite
@onready var reward_label := $Panel/RewardsLabel

# Variables
var gear_spin_tween: Tween
var scene_scale = Vector2(0.9, 0.9)

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		confirmed.emit()

# Spawns and shows rewards menu
func show_rewards(rewards: Dictionary):
	visible = true
	panel.visible = true
	_update_rewards_text(rewards)
	_start_gear_spin()
	
	var tween := create_tween()
	tween.tween_property(panel, "scale", scene_scale, 0.4)
	await tween.finished

# Hides rewards menu after input has been made
func hide_rewards() -> void:
	_stop_gear_spin()

	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ZERO, 0.4)
	await tween.finished
	
	panel.visible = false
	visible = false

func _update_rewards_text(rewards: Dictionary) -> void:
	# For now
	reward_label.text = "Bolts: +%d" % rewards.currency

# Gear spin logic from PlayerTurnUI
func _start_gear_spin():
	_stop_gear_spin()
	gear_spin_tween = create_tween()
	gear_spin_tween.set_loops()
	gear_spin_tween.tween_property(
		gear_sprite,
		"rotation",
		TAU,
		3.5
	).set_trans(Tween.TRANS_LINEAR).as_relative()

func _stop_gear_spin():
	if gear_spin_tween:
		gear_spin_tween.kill()
		gear_spin_tween = null
