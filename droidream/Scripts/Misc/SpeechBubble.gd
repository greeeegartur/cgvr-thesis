extends CanvasLayer

# Speech bubble logic

class_name SpeechBubble

enum BubbleMode {
	CINEMATIC,
	OVERLAY
}

var mode := BubbleMode.CINEMATIC

@onready var root := $BubbleRoot
@onready var anim := $BubbleRoot/AnimationPlayer
@onready var label := $BubbleRoot/RichTextLabel
@onready var tail := $BubbleRoot/Tail
@onready var tail_line: Line2D = $BubbleRoot/Tail/Line2D
@onready var tail_tip: Sprite2D = $BubbleRoot/Tail/Sprite

var max_length := 69.0

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
	if not target_node:
		return
	if target_node:
		#root.global_position = target_node.global_position + Vector2(0, -80)
		update_position()
	
	update_tail_rotation()

func update_tail_rotation():
	var bubble_global = root.global_position
	var target_global = target_node.global_position
	
	var dir = target_global - bubble_global
	var distance = min(dir.length(), max_length)
	var direction = dir.normalized()
	var local_end = tail.to_local(bubble_global + direction * distance)

	tail_line.points = [
		Vector2.ZERO,
		local_end
	]

	tail_tip.position = local_end
	tail_tip.rotation = direction.angle() - PI / 2.0

func get_camera_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	var visible_rect := get_viewport().get_visible_rect()
	
	var size := visible_rect.size * cam.zoom
	var top_left := cam.global_position - size * 0.5
	
	return Rect2(top_left, size)

func update_position():
	var cam_rect := get_camera_rect()
	var bubble_size = root.size
	
	var left_pos := target_node.global_position + Vector2(-bubble_size.x - 40, -100)
	var right_pos := target_node.global_position + Vector2(40, -100)

	var left_rect := Rect2(left_pos, bubble_size)
	var right_rect := Rect2(right_pos, bubble_size)

	if cam_rect.encloses(left_rect):
		root.global_position = left_pos
	elif cam_rect.encloses(right_rect):
		root.global_position = right_pos
	else:
		root.global_position = right_pos # fallback

	# Final safety clamp
	root.global_position.x = clamp(
		root.global_position.x,
		cam_rect.position.x,
		cam_rect.end.x - bubble_size.x
	)

	root.global_position.y = clamp(
		root.global_position.y,
		cam_rect.position.y,
		cam_rect.end.y - bubble_size.y
	)

func show_bubble():
	visible = true
	
	root.scale = Vector2(0.7, 0.7)
	root.modulate.a = 0.0
	
	var tween = create_tween()
	tween.parallel().tween_property(root, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(root, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await tween.finished

func hide_bubble():
	var tween = create_tween()
	tween.parallel().tween_property(root, "modulate:a", 0.0, 0.15)
	tween.parallel().tween_property(root, "scale", Vector2(0.7, 0.7), 0.15)
	await tween.finished
	
	visible = false
	dialogue_finished.emit()


func say_line(bbcode_text: String, speed := 0.02) -> void:
	label.text = ""
	label.append_text(bbcode_text)
	label.visible_characters = 0

	is_typing = true
	skip_requested = false

	await type_text(speed)
	is_typing = false

	await wait_for_confirm()


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
	if mode == BubbleMode.OVERLAY:
		return
	
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			break

func hide_tail():
	tail.visible = false

func show_tail():
	tail.visible = true

func set_overlay(bubble_mode):
	mode = bubble_mode
