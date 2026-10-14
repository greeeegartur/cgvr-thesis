extends Node2D

# Script logic for death screen scene that appears when the player has died during combat

class_name DeathScreen

signal retry_selected
signal back_selected

var selection_index := 0
var pop_tween: Tween
var arrow_tween: Tween

@onready var game_over_label := $GameOverLabel
@onready var options_node := $Options
@onready var retry_label := $Options/RetryLabel
@onready var quit_label := $Options/QuitLabel
@onready var left_arrow := $LeftArrow
@onready var right_arrow := $RightArrow

var left_arrow_positions := {"retry": Vector2(263, 113), "quit": Vector2(275, 162)}
var right_arrow_positions := {"retry": Vector2(377, 113), "quit": Vector2(366, 162)}

func show_death():
	_stop_arrow_anim() # From possible previous instances
	_stop_pop()
	visible = true
	
	game_over_label.modulate.a = 0
	options_node.modulate.a = 0
	
	await get_tree().create_timer(1.5).timeout # Waits before showing death screen
	
	# Game over text animates in
	var t1 = create_tween()
	t1.tween_property(game_over_label, "modulate:a", 1.0, 1.2)
	await t1.finished
	
	var t2 = create_tween()
	t2.tween_property(options_node, "modulate:a", 1.0, 0.6)
	await t2.finished
	
	selection_index = 0
	_update_selection()
	set_process_unhandled_input(true)

func _unhandled_input(event):
	if not visible:
		return
	
	if event.is_action_pressed("ui_down"):
		_move_selection(1)
	elif event.is_action_pressed("ui_up"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()

func _move_selection(dir: int):
	var new_index = clamp(selection_index + dir, 0, 1)
	if new_index == selection_index:
		return
	
	selection_index = new_index
	_update_selection()

func _update_selection():
	_stop_pop()
	_stop_arrow_anim()
	
	var selected_label = retry_label if selection_index == 0 else quit_label
	_start_pop(selected_label)
	_start_arrow_anim(selected_label)

func _confirm_selection():
	set_process_unhandled_input(false)
	
	if selection_index == 0:
		retry_selected.emit()
	else:
		back_selected.emit()

func _start_pop(node):
	pop_tween = create_tween()
	pop_tween.set_loops()
	pop_tween.tween_property(node, "scale", Vector2(1.1,1.1), 0.5)
	pop_tween.tween_property(node, "scale", Vector2.ONE, 0.5)

func _stop_pop():
	if pop_tween:
		pop_tween.kill()

func _start_arrow_anim(target):
	left_arrow.visible = true
	right_arrow.visible = true
	
	if target == retry_label:
		left_arrow.position = left_arrow_positions.get("retry")
		right_arrow.position = right_arrow_positions.get("retry")
	else:
		left_arrow.position = left_arrow_positions.get("quit")
		right_arrow.position = right_arrow_positions.get("quit")
	var base_left_x = left_arrow.position.x
	var base_right_x = right_arrow.position.x
	
	arrow_tween = create_tween()
	arrow_tween.set_loops()
	arrow_tween.tween_property(left_arrow, "position:x", base_left_x - 8, 0.4)
	arrow_tween.parallel().tween_property(right_arrow, "position:x", base_right_x + 8, 0.4)
	arrow_tween.tween_property(left_arrow, "position:x", base_left_x, 0.4)
	arrow_tween.parallel().tween_property(right_arrow, "position:x", base_right_x, 0.4)

func _stop_arrow_anim():
	if arrow_tween:
		arrow_tween.kill()
	
	left_arrow.visible = false
	right_arrow.visible = false

func _hide():
	visible = false
	
	_stop_arrow_anim()
	_stop_pop()
	
	selection_index = 0
