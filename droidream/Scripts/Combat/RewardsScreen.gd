extends Node2D

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
	_update_rewards_text(rewards)
	_start_gear_spin()
	
	var tween := create_tween()
	tween.tween_property(self, "scale", scene_scale, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.4)
	await tween.finished

# Hides rewards menu after input has been made
func hide_rewards() -> void:
	_stop_gear_spin()

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished

	visible = false

func _update_rewards_text(rewards: Dictionary) -> void:
	# For now
	reward_label.text = "Bolts: +%d" % rewards.currency

# Gear spin logic from EnemyAxisBar
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

	create_tween().tween_property(
		gear_sprite,
		"rotation",
		round(gear_sprite.rotation / PI) * PI,
		0.12
	).set_trans(Tween.TRANS_LINEAR)
