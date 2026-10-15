extends Node2D

# Responsible for visual effects when the player executes a block

class_name PlayerBlockVisual

@onready var ring := $Ring
@onready var cooldown := $CooldownOverlay
@onready var anim := $Ring/AnimationPlayer

const SUCCESS_COLOR := Color.WHITE # Ring texture is green, so white keeps it green
const FAIL_COLOR := Color(1.0, 0.302, 0.302, 1.0)

# Single tween handles so overlapping presses never fight over the same properties
var ring_tween: Tween
var cooldown_tween: Tween

func _ready():
	ring.visible = false
	cooldown.visible = false

# Shown on every block button press, regardless of timing
func play_press():
	await _play_ring(SUCCESS_COLOR, 1.2, 0.12, 0.15)

# Successful block feedback
func play_success():
	await _play_ring(SUCCESS_COLOR, 1.6, 0.28, 0.28)

# Failed block feedback
func play_fail():
	await _play_ring(FAIL_COLOR, 1.0, 0.0, 0.28)

# Cooldown visual
func set_cooldown_active(active: bool):
	if cooldown_tween:
		cooldown_tween.kill()
	
	if not active:
		cooldown.visible = false
		return
	
	cooldown.visible = true
	cooldown.modulate.a = 0.6
	cooldown.scale = Vector2(1.15, 1.15)
	cooldown_tween = create_tween()
	cooldown_tween.tween_property(cooldown, "modulate:a", 0.0, 0.75)
	cooldown_tween.parallel().tween_property(cooldown, "scale", Vector2.ONE, 0.2)

# Shows the ring from the start every time: grows (optional) then fades out
func _play_ring(color: Color, end_scale: float, grow_time: float, fade_time: float):
	if ring_tween:
		ring_tween.kill()
	
	anim.play("shatter")
	ring.visible = true
	ring.modulate = color
	ring.scale = Vector2(0.5, 0.5)
	
	ring_tween = create_tween()
	if grow_time > 0.0:
		ring_tween.tween_property(ring, "scale", Vector2.ONE * end_scale, grow_time)
	ring_tween.tween_property(ring, "modulate:a", 0.0, fade_time)
	await ring_tween.finished
	ring.visible = false
