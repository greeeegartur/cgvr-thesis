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

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	pivot_offset = size * 0.5
	set_process_unhandled_input(true)
	_reset_visuals()

func play():
	running = true
	resolved = false
	active_intent = "tame"
	current_ratio = 0.0
	_reset_visuals()

func _process(delta):
	if not running or resolved:
		return

	current_ratio += grow_speed * delta

	if current_ratio >= 1.0:
		current_ratio = 0.0
		active_intent = "kill" if active_intent == "tame" else "tame"

	_update_visuals()

func _unhandled_input(event):
	if not running or resolved:
		return
	
	if event.is_action_pressed("ui_accept"):
		_resolve()

func _resolve():
	resolved = true
	running = false

	var multiplier := _ratio_to_multiplier(current_ratio)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.08)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12)
	await tween.finished

	finished.emit(active_intent, multiplier, current_ratio)
	queue_free()

func _ratio_to_multiplier(ratio: float) -> float:
	if ratio >= 0.85:
		return 1.75
	elif ratio >= 0.75:
		return 1.5
	elif ratio >= 0.60:
		return 1.25
	return 1.0

func _reset_visuals():
	scale = Vector2.ONE
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
