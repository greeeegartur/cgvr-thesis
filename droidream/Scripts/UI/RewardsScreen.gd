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
var revealing := false # True while rows are still appearing
var closing := false # True once confirmed, so pressing again while it leaves plays no second sound
var rows: Array[RewardRow] = []

const ROW_FINAL_SCALE := 1.0 # Scale rows keep after their pop (reduced for all rows if they would not fit in the container)
const ROW_GAP := 4.0 # Empty space between two rows, small so the list reads as one block

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		# First press finishes the whole reveal, the next press confirms
		if revealing:
			skipping = true
			for row in rows:
				row.finish_instantly()
			return
		if not closing:
			closing = true
			Sfx.play_ui("shop_buy")
		confirmed.emit()

# Spawns and shows rewards menu
func show_rewards(rewards:Dictionary):
	skipping = false
	closing = false
	rows.clear()
	visible = true
	panel.visible = true
	panel.scale = Vector2(0.0, 0.6)
	panel.modulate.a = 0.0
	rewards_container.modulate.a = 1.0
	
	_start_gear_spin()
	
	# Stretch: the panel widens first and settles in height a moment later, both easing out into the final scale in one go
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale:x", scene_scale.x, ScreenMotion.ENTER_TIME + 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale:y", scene_scale.y, ScreenMotion.ENTER_TIME + 0.1).set_delay(0.05)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, ScreenMotion.ENTER_TIME * 0.5)
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
	
	for item_reward in rewards.get("items", []):
		list.append({
			"name": item_reward.name,
			"icon": item_reward.icon,
			"amount": item_reward.amount
		})
	
	# All slots are reserved first (rows stay invisible) so the list never shifts while rows appear
	var new_rows: Array[RewardRow] = []
	for reward in list:
		new_rows.append(_add_row(reward))
	_fit_rows(new_rows) # Shared row size, one tight slot per row from the top of the container
	
	revealing = true
	for i in new_rows.size():
		var row := new_rows[i]
		if not skipping:
			await get_tree().create_timer(0.04).timeout
			Sfx.play_ui("option_move", { "pitch": Sfx.semitones(i * 2) }) # Each row pops a step higher
		
		row.skipped = skipping
		await row.animate_in()
		await row.play_count()
	revealing = false
	
	await confirmed

# Adds a row inside a plain Control slot: containers reset their children's scale on every re-sort, a slot does not
# Each slot is only as tall as its row (set in _fit_rows), so the list starts at the top of the container
func _add_row(reward: Dictionary) -> RewardRow:
	var slot := Control.new()
	rewards_container.add_child(slot)
	
	var row: RewardRow = reward_row_scene.instantiate()
	slot.add_child(row)
	row.setup(reward.icon, reward.name, reward.amount)
	
	rows.append(row)
	return row

# Gives all rows the same final scale (the widest row must fit the width and all rows must fit the height),
# sizes each slot to its row plus a small gap and centers the row horizontally in it
func _fit_rows(new_rows: Array[RewardRow]):
	if new_rows.is_empty():
		return
	
	var widest := 1.0
	var tallest := 1.0
	for row in new_rows:
		var row_min := row.get_combined_minimum_size()
		widest = max(widest, row_min.x)
		tallest = max(tallest, row_min.y)
	
	var container_width: float = rewards_container.size.x
	var container_height: float = rewards_container.size.y
	var width_fit := container_width / widest
	var height_fit := container_height / (new_rows.size() * (tallest + ROW_GAP))
	var final_scale: float = min(ROW_FINAL_SCALE, min(width_fit, height_fit))
	
	for row in new_rows:
		var row_size: Vector2 = row.get_combined_minimum_size()
		row.final_scale = final_scale
		row.size = row_size
		row.pivot_offset = row_size / 2.0 # Scales around its center
		
		var slot: Control = row.get_parent()
		slot.custom_minimum_size = Vector2(0, ceilf(row_size.y * final_scale) + ROW_GAP)
		row.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)

# Hides rewards menu after input has been made: the rows fade first, then the panel squashes away (the reverse of its entrance)
func hide_rewards():
	var rows_tween := create_tween()
	rows_tween.tween_property(rewards_container, "modulate:a", 0.0, ScreenMotion.EXIT_TIME * 0.6)
	await rows_tween.finished
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale:x", 0.0, ScreenMotion.EXIT_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "scale:y", 0.6, ScreenMotion.EXIT_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, ScreenMotion.EXIT_TIME).set_delay(ScreenMotion.EXIT_TIME * 0.4)
	await tween.finished
	
	_stop_gear_spin()
	panel.visible = false
	visible = false
	rows.clear()
	for c in rewards_container.get_children():
		c.queue_free()

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
