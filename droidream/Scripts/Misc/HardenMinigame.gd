extends Control
class_name HardenMinigame

signal finished(defense_bonus: float)
signal prompt_hit(position: Vector2)

@onready var sequence_row := $SequenceRow
@export var duration := 5.0

const ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right"]

@export var up_texture: Texture2D
@export var down_texture: Texture2D
@export var left_texture: Texture2D
@export var right_texture: Texture2D

var _stages: Array = []
var _current_stage := 0
var _current_input_index := 0
var _completed_stages := 0
var _running := false

func play():
	_build_stages()
	_current_stage = 0
	_current_input_index = 0
	_completed_stages = 0
	_running = true
	
	_show_stage(_current_stage)
	
	var timer := 0.0
	while timer < duration and _running:
		await get_tree().process_frame
		timer += get_process_delta_time()
	
	finished.emit(_stages_to_bonus(_completed_stages))
	queue_free()

func _build_stages():
	_stages.clear()
	
	for len in [4, 5, 6]:
		var seq: Array[String] = []
		for i in len:
			seq.append(ACTIONS.pick_random())
		_stages.append(seq)

func _show_stage(stage_index: int):
	var seq: Array = _stages[stage_index]
	for i in range(sequence_row.get_child_count()):
		var slot: TextureRect = sequence_row.get_child(i)
		if i < seq.size():
			slot.visible = true
			slot.texture = _get_texture_for_action(seq[i])
			slot.modulate = Color.WHITE
			slot.scale = Vector2.ONE
		else:
			slot.visible = false

func _unhandled_input(event):
	if not _running:
		return
	if _current_stage >= _stages.size():
		return
	
	for action in ACTIONS:
		if event.is_action_pressed(action):
			_process_action(action)
			break

func _process_action(action: String):
	var seq: Array = _stages[_current_stage]
	var expected: String = seq[_current_input_index]
	var slot: TextureRect = sequence_row.get_child(_current_input_index)
	
	if action == expected:
		_play_correct_feedback(slot)
		prompt_hit.emit(slot.global_position)
		
		_current_input_index += 1
		
		if _current_input_index >= seq.size():
			_completed_stages += 1
			_current_stage += 1
			_current_input_index = 0
			
			if _current_stage >= _stages.size():
				_running = false
				return
			
			_show_stage(_current_stage)
	else:
		_play_wrong_feedback(slot)

func _play_correct_feedback(slot: TextureRect):
	var tween := create_tween()
	tween.tween_property(slot, "scale", Vector2.ONE * 1.2, 0.06)
	tween.parallel().tween_property(slot, "modulate", Color(0.7, 1.0, 0.7), 0.06)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.08)

func _play_wrong_feedback(slot: TextureRect):
	var original_pos := slot.position
	var tween := create_tween()
	tween.tween_property(slot, "position", original_pos + Vector2(-4, 0), 0.03)
	tween.tween_property(slot, "position", original_pos + Vector2(4, 0), 0.03)
	tween.tween_property(slot, "position", original_pos, 0.03)

func _get_texture_for_action(action: String) -> Texture2D:
	match action:
		"ui_up":
			return up_texture
		"ui_down":
			return down_texture
		"ui_left":
			return left_texture
		"ui_right":
			return right_texture
	return null

func _stages_to_bonus(completed: int) -> float:
	match completed:
		3:
			return 2.0
		2:
			return 1.0
		1:
			return 0.5
		_:
			return 0.25
