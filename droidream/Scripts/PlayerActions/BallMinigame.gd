extends Control
class_name BallMeterMinigame

signal finished(intent: String, multiplier: float, fill_ratio: float)

@onready var meter_bg := $MeterBG
@onready var pink_fill := $MeterBG/PinkFill
@onready var red_fill := $MeterBG/RedFill

var active_intent := "tame" # pink starts
var current_ratio := 0.0
var grow_speed := 1.35
var running := false
var resolved := false
var anchor: Node2D # The Droid: the meter keeps its place relative to it while the camera moves
var since_wrap := 99.0 # Seconds since the meter last changed color
var wrapped_intent := "tame" # The color it had before that change

const GRACE := 0.08 # A press this close before or after the full zone still counts as full

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_reset_visuals()

func play():
	running = true
	resolved = false
	active_intent = "tame"
	current_ratio = 0.0
	_reset_visuals()

func _process(delta):
	_follow_camera()
	if not running or resolved:
		return

	current_ratio += grow_speed * delta

	since_wrap += delta
	if current_ratio >= 1.0:
		current_ratio = 0.0
		wrapped_intent = active_intent
		active_intent = "kill" if active_intent == "tame" else "tame"
		since_wrap = 0.0

	_update_visuals()

func _unhandled_input(event):
	if not running or resolved:
		return
	
	if event.is_action_pressed("ui_accept"):
		_resolve()

func _resolve():
	resolved = true
	running = false

	# Grace: a press just before the meter is full, or just after it changed color, counts as full (of the color that filled)
	var ratio := current_ratio
	if since_wrap <= GRACE:
		ratio = 1.0
		active_intent = wrapped_intent
	elif current_ratio + grow_speed * GRACE >= 1.0:
		ratio = 1.0
	var multiplier := _ratio_to_multiplier(ratio)
	
	# A bright flash, a pop and the meter shrinks away
	var tween := create_tween()
	tween.tween_property(meter_bg, "modulate", Color(1.8, 1.8, 1.8), 0.05)
	tween.parallel().tween_property(meter_bg, "scale", Vector2(1.14, 1.14), 0.08)
	tween.tween_property(meter_bg, "scale", Vector2.ZERO, 0.14)
	await tween.finished

	finished.emit(active_intent, multiplier, ratio)
	queue_free()

func _ratio_to_multiplier(ratio: float) -> float:
	# The zones are about 25% wider than they were (0.85 / 0.75 / 0.60)
	if ratio >= 0.80:
		return 1.75
	elif ratio >= 0.70:
		return 1.5
	elif ratio >= 0.55:
		return 1.25
	return 1.0

func _reset_visuals():
	meter_bg.pivot_offset = meter_bg.size * 0.5
	meter_bg.scale = Vector2.ONE
	pink_fill.pivot_offset = Vector2(pink_fill.size.x * 0.5, pink_fill.size.y)
	red_fill.pivot_offset = Vector2(red_fill.size.x * 0.5, red_fill.size.y)
	pink_fill.scale.y = 0.0
	red_fill.scale.y = 0.0
	_update_visuals()

func _update_visuals():
	if active_intent == "tame":
		pink_fill.scale.y = current_ratio
		red_fill.scale.y = 0.0
	else:
		red_fill.scale.y = current_ratio
		pink_fill.scale.y = 0.0

# The meter is placed for the normal camera, so it is drawn through the camera like a world object and stays attached to the Droid
func _follow_camera() -> void:
	var canvas := get_viewport().get_canvas_transform()
	position = canvas.origin
	scale = canvas.get_scale()
