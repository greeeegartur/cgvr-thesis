extends Node2D

class_name TitleScreen

@export var tutorial_scene_path := "res://Scenes/TutorialScene.tscn"

var selection_index := 0
var pop_tween: Tween
var arrow_tween: Tween
var fade_tween: Tween

@onready var background := $Background

@onready var options_node := $Options
@onready var play_label := $Options/PlayLabel
@onready var quit_label := $Options/QuitLabel
@onready var left_arrow := $LeftArrow
@onready var right_arrow := $RightArrow
@onready var black := $Black

var left_arrow_positions := {
	"play": Vector2(89, 142),
	"quit": Vector2(93, 201)
}

var right_arrow_positions := {
	"play": Vector2(181, 142),
	"quit": Vector2(179, 201)
}


func _ready():
	set_process_unhandled_input(false)
	
	black.visible = true
	black.modulate.a = 1.0
	
	options_node.modulate.a = 0.0
	
	left_arrow.visible = false
	right_arrow.visible = false
	
	await _show_title_screen()

func _unhandled_input(event):
	if event.is_action_pressed("ui_down"):
		_move_selection(1)
	elif event.is_action_pressed("ui_up"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_accept"):
		_confirm_selection()

func _show_title_screen():
	await _fade_from_black(1.0)
	
	var options_tween := create_tween()
	options_tween.tween_property(options_node, "modulate:a", 1.0, 0.35)
	await options_tween.finished
	
	selection_index = 0
	_update_selection()
	set_process_unhandled_input(true)


func _move_selection(dir: int):
	var new_index = clamp(selection_index + dir, 0, 1)
	if new_index == selection_index:
		return
	
	selection_index = new_index
	_update_selection()


func _update_selection():
	_stop_pop()
	_stop_arrow_anim()
	
	var selected_label = play_label if selection_index == 0 else quit_label
	_start_pop(selected_label)
	_start_arrow_anim(selected_label)


func _confirm_selection():
	set_process_unhandled_input(false)
	_stop_pop()
	_stop_arrow_anim()
	
	await _fade_to_black(1.0)
	
	if selection_index == 0:
		get_tree().change_scene_to_file(tutorial_scene_path)
	else:
		get_tree().quit()


func _start_pop(node):
	pop_tween = create_tween()
	pop_tween.set_loops()
	pop_tween.tween_property(node, "scale", Vector2(1.1, 1.1), 0.5)
	pop_tween.tween_property(node, "scale", Vector2.ONE, 0.5)


func _stop_pop():
	if pop_tween:
		pop_tween.kill()
		pop_tween = null
	
	play_label.scale = Vector2.ONE
	quit_label.scale = Vector2.ONE


func _start_arrow_anim(target: Node):
	left_arrow.visible = true
	right_arrow.visible = true
	
	if target == play_label:
		left_arrow.position = left_arrow_positions["play"]
		right_arrow.position = right_arrow_positions["play"]
	else:
		left_arrow.position = left_arrow_positions["quit"]
		right_arrow.position = right_arrow_positions["quit"]
	
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
		arrow_tween = null
	
	left_arrow.visible = false
	right_arrow.visible = false


func _fade_from_black(duration := 1.0):
	black.visible = true
	black.modulate.a = 1.0
	
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(black, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	await fade_tween.finished
	black.visible = false


func _fade_to_black(duration := 0.75):
	black.visible = true
	black.modulate.a = 0.0
	
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(black, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	
	await fade_tween.finished
