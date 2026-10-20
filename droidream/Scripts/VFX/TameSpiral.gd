extends Node2D
class_name TameSpiral

# Neon pixels start on a ring around a creature and spiral into its center, ending in a small pulse

const LIFETIME := 0.5
const COUNT := 28
const START_RADIUS := 64.0
const TURNS := 1.25
const COLORS := [Color("#b04aff"), Color("#ff4ac0"), Color("#ffffff")]

var particles: Array[Dictionary] = []
var age := 0.0

static func play(layer: Node, at: Vector2) -> void:
	var node := TameSpiral.new()
	node.position = at
	layer.add_child(node)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 3
	for i in COUNT:
		particles.append({
			"angle": randf() * TAU,
			"radius": START_RADIUS * randf_range(0.6, 1.0),
			"delay": randf_range(0.0, 0.12),
			"color": COLORS.pick_random(),
		})

func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME + 0.3:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for particle in particles:
		var t: float = clamp((age - particle["delay"]) / LIFETIME, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		var eased := t * t # Slow at first, then pulled in
		var angle: float = particle["angle"] + eased * TURNS * TAU
		var radius: float = particle["radius"] * (1.0 - eased)
		var pos := (Vector2(cos(angle), sin(angle)) * radius).round()
		var color: Color = particle["color"]
		color.a = min(1.0, t * 4.0)
		draw_rect(Rect2(pos, Vector2(3, 3)), color)
	# Pulse ring when everything has arrived
	var pulse: float = (age - LIFETIME) / 0.3
	if pulse > 0.0 and pulse < 1.0:
		draw_arc(Vector2.ZERO, 8.0 + pulse * 22.0, 0.0, TAU, 32, Color("#ff7ae0", 1.0 - pulse), 2.0)
