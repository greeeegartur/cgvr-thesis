extends Control

# Script logic for the RewardsScreen scene

class_name RewardsScreen

signal confirmed

@onready var panel := $Panel
@onready var gear_sprite := $Panel/GearSprite
@onready var rewards_container := $Panel/RewardsContainer
@export var reward_row_scene: PackedScene
@export var bolt_icon: Texture2D

# Variables
var gear_spin_tween: Tween
var scene_scale = Vector2(0.9, 0.9)
var skipping := false

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		for r in rewards_container.get_children():
			if r.animating:
				r.skipped = true
				return
		confirmed.emit()

# Spawns and shows rewards menu
func show_rewards(rewards:Dictionary):
	skipping = false
	visible = true
	panel.visible = true
	panel.scale = Vector2(0.0, 0.65)
	
	_start_gear_spin()
	
	# Stretch/scaling animation
	var tween := create_tween()
	tween.tween_property(
		panel,
		"scale",
		Vector2(0.75,1.0),
		0.2
	)
	tween.tween_property(
		panel,
		"scale",
		scene_scale,
		0.3
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	await _play_rewards(rewards)

func _play_rewards(rewards: Dictionary):
	var list = []
	if rewards.currency > 0:
		list.append({
			"name":"Bolts",
			"icon": bolt_icon,
			"amount": rewards.currency
		})
	
	for reward in list:
		var row = reward_row_scene.instantiate()
		rewards_container.add_child(row)
		row.setup(reward.icon, reward.name, reward.amount)
		await get_tree().create_timer(0.04).timeout
		
		await row.animate_in()
		await row.play_count()
	
	await confirmed

# Hides rewards menu after input has been made
func hide_rewards():
	_stop_gear_spin()
	var tween := create_tween()
	tween.tween_property(
		panel,
		"scale",
		Vector2(1.0,0.65),
		0.12
	)
	tween.tween_property(
		panel,
		"scale",
		Vector2.ZERO,
		0.35
	)
	
	await get_tree().create_timer(0.05).timeout
	await tween.finished
	panel.visible = false
	visible = false

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
