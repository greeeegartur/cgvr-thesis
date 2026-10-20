extends Node2D
class_name BuffParticles

# A one-shot burst of small pixel particles that shows a heal, power or defense effect, then frees itself

enum Kind { HEAL, POWER, DEFENSE_UP, DEFENSE_DOWN }

const LIFETIME := 0.8
const COUNT_MIN := 6
const COUNT_MAX := 10
const TRAVEL_MIN := 40.0
const TRAVEL_MAX := 64.0
const SPREAD := Vector2(20, 4) # Half size of the area the particles start in
const START_Y := 26.0 # Particles start at the feet and rise to the head (the other way around when defense is lost)
const SIZE := 2 # Pixel size of the shapes

var kind := Kind.HEAL
var particles: Array[Dictionary] = []
var age := 0.0

# Spawns a burst at a position inside the given layer
static func burst(layer: Node, at: Vector2, burst_kind: Kind) -> void:
	var node := BuffParticles.new()
	node.kind = burst_kind
	node.position = at
	layer.add_child(node)

func _ready() -> void:
	var direction := 1.0 if kind == Kind.DEFENSE_DOWN else -1.0 # Everything rises except lost defense
	for i in randi_range(COUNT_MIN, COUNT_MAX):
		particles.append({
			"start": Vector2(randf_range(-SPREAD.x, SPREAD.x), -direction * START_Y + randf_range(-SPREAD.y, SPREAD.y)),
			"travel": randf_range(TRAVEL_MIN, TRAVEL_MAX) * direction,
			"delay": randf_range(0.0, 0.15),
		})

func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME + 0.15:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var color := _color()
	for particle in particles:
		var t: float = clamp((age - particle["delay"]) / LIFETIME, 0.0, 1.0)
		if t <= 0.0:
			continue
		var pos: Vector2 = particle["start"] + Vector2(0, particle["travel"] * t)
		pos = pos.round() # Whole pixels
		var faded := Color(color, 1.0 - t * t)
		_draw_shape(pos, faded)

func _color() -> Color:
	match kind:
		Kind.HEAL:
			return Color("#3ee66b")
		Kind.POWER:
			return Color("#ff9a2e")
		Kind.DEFENSE_UP:
			return Color("#4aa8ff")
	return Color("#4a6a8a") # Defense lost: dull blue

func _draw_shape(pos: Vector2, color: Color) -> void:
	match kind:
		Kind.HEAL: # Plus sign
			draw_rect(Rect2(pos + Vector2(-1, -3) * SIZE, Vector2(2, 6) * SIZE), color)
			draw_rect(Rect2(pos + Vector2(-3, -1) * SIZE, Vector2(6, 2) * SIZE), color)
		Kind.POWER: # Upward chevron
			for i in 3:
				draw_rect(Rect2(pos + Vector2(-3 + i, i) * SIZE, Vector2(SIZE, SIZE)), color)
				draw_rect(Rect2(pos + Vector2(2 - i, i) * SIZE, Vector2(SIZE, SIZE)), color)
		_: # Square
			draw_rect(Rect2(pos, Vector2(3, 3) * SIZE), color)
