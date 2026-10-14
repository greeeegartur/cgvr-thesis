extends Node2D
class_name TuhU

@onready var sprite: Sprite2D = $Sprite2D
@onready var hover_particles: CPUParticles2D = $HoverParticles
@onready var emotion_bubble: Node2D = $EmotionBubble
@onready var emotion_icon: Sprite2D = $EmotionBubble/Bubble

@export var normal_texture: Texture2D
@export var happy_texture: Texture2D
@export var sad_texture: Texture2D
@export var look_right_texture: Texture2D
@export var look_down_texture: Texture2D
@export var look_up_texture: Texture2D

@export var worry_emote: Texture2D
@export var exclamation_emote: Texture2D
@export var question_emote: Texture2D

var texture_tween: Tween
var emote_tween: Tween
var move_tween: Tween


func _ready():
	emotion_bubble.visible = false
	
	if hover_particles:
		hover_particles.emitting = true
	
	play_normal()


func play_normal():
	_set_texture(normal_texture)


func play_happy():
	_set_texture(happy_texture)


func play_sad():
	_set_texture(sad_texture)


func play_look_right():
	_set_texture(look_right_texture)


func play_look_down():
	_set_texture(look_down_texture)


func play_look_up():
	_set_texture(look_up_texture)


func _set_texture(texture: Texture2D):
	if texture == null:
		return
	
	if texture_tween:
		texture_tween.kill()
	
	sprite.texture = texture
	sprite.scale = Vector2(0.72, 0.88)
	
	texture_tween = create_tween()
	texture_tween.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


func flip_toward_left():
	scale.x = -abs(scale.x)


func flip_toward_right():
	scale.x = abs(scale.x)


func set_facing_left(is_left: bool):
	if is_left:
		flip_toward_left()
	else:
		flip_toward_right()


func bubble_emote(emote_id: String, duration := 1.5):
	var texture := _get_emote_texture(emote_id)
	if texture == null:
		return
	
	if emote_tween:
		emote_tween.kill()
	
	emotion_icon.texture = texture
	emotion_bubble.visible = true
	emotion_bubble.modulate.a = 0.0
	emotion_bubble.scale = Vector2.ZERO
	
	emote_tween = create_tween()
	emote_tween.tween_property(emotion_bubble, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	emote_tween.parallel().tween_property(emotion_bubble, "modulate:a", 1.0, 0.12)
	emote_tween.tween_interval(duration)
	emote_tween.tween_property(emotion_bubble, "scale", Vector2.ZERO, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
	emote_tween.parallel().tween_property(emotion_bubble, "modulate:a", 0.0, 0.15)
	
	await emote_tween.finished
	emotion_bubble.visible = false


func move_to(target: Vector2, duration := 0.75):
	if move_tween:
		move_tween.kill()
	
	move_tween = create_tween()
	move_tween.tween_property(self, "global_position", target, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)
	
	await move_tween.finished


func hop():
	var base_y := position.y
	var tween := create_tween()
	tween.tween_property(self, "position:y", base_y - 16, 0.12)
	tween.tween_property(self, "position:y", base_y, 0.18)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished


func shake():
	var original := position
	var tween := create_tween()
	for i in 4:
		tween.tween_property(self, "position", original + Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.04)
	tween.tween_property(self, "position", original, 0.08)
	await tween.finished


func _get_emote_texture(emote_id: String) -> Texture2D:
	match emote_id:
		"worry":
			return worry_emote
		"exclamation":
			return exclamation_emote
		"question":
			return question_emote
	
	push_warning("Unknown Tuh-U emote: " + emote_id)
	return null
