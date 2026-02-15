extends CanvasLayer

# Speech bubble logic

class_name SpeechBubble

enum BubbleMode {
	CINEMATIC,
	OVERLAY
}

@onready var root := $BubbleRoot
@onready var anim := $BubbleRoot/AnimationPlayer
@onready var label := $BubbleRoot/RichTextLabel
@onready var tail := $BubbleRoot/Tail

signal dialogue_finished

# Bubble follow
var target_node : Node2D
var is_typing := false
var skip_requested := false

func set_target(node: Node2D):
	target_node = node

func _ready():
	label.bbcode_enabled = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible = false

func _input(event):
	if is_typing and event.is_action_pressed("ui_accept"):
		skip_requested = true

func _process(float):
	if target_node:
		root.global_position = target_node.global_position + Vector2(90, -85)

func say(bbcode_text: String, speed := 0.02) -> void:
	visible = true
	label.text = ""
	label.append_text(bbcode_text)
	label.visible_characters = 0

	is_typing = true
	skip_requested = false

	await type_text(speed)
	is_typing = false

	await wait_for_confirm()

	visible = false
	dialogue_finished.emit()

func type_text(speed := 0.02):
	var plain_text = label.get_parsed_text()
	var total = plain_text.length()
	
	for i in range(total):
		if skip_requested:
			label.visible_characters = -1
			return
		
		label.visible_characters = i + 1
		
		# Emphasis pauses
		var char = plain_text[i]
		if char in [".", "!", "?"]:
			await get_tree().create_timer(0.2).timeout
		elif char == ",":
			await get_tree().create_timer(0.1).timeout
		else:
			await get_tree().create_timer(speed).timeout

func wait_for_confirm():
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			break

func hide_tail():
	tail.visible = false

func show_tail():
	tail.visible = true
