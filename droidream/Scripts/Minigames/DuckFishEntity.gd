extends Area2D
class_name DuckFishEntity

@onready var sprite: Sprite2D = $Sprite2D

var base_y := 0.0
var peak_y := 0.0
var drift_speed := 120.0
var lifetime := 1.4
var elapsed := 0.0
var frozen := false
var collected := false

func setup(p_base_y: float, p_peak_y: float, p_drift_speed: float, p_lifetime: float) -> void:
	base_y = p_base_y
	peak_y = p_peak_y
	drift_speed = p_drift_speed
	lifetime = p_lifetime

func step(delta: float) -> void:
	if frozen or collected:
		return
	
	elapsed += delta
	position.x -= drift_speed * delta
	var t = clamp(elapsed / lifetime, 0.0, 1.0)
	
	# Simple parabola: 0 -> 1 -> 0
	var arc = 4.0 * t * (1.0 - t)
	position.y = lerp(base_y, peak_y, arc)
	rotation = sin(t * TAU) * 0.25
	if elapsed >= lifetime or position.x < -24.0:
		queue_free()

func freeze() -> void:
	frozen = true
