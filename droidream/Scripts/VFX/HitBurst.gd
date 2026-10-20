extends Node2D
class_name HitBurst

# The pixel burst for every hit: radial shards plus a short ring flash, bigger with strength

enum Strength { NORMAL, BLOCK, CRIT }

const SHARD_COUNT := [8, 10, 16]
const SHARD_SPEED := [70.0, 85.0, 120.0]
const RING_SIZE := [16.0, 22.0, 32.0]
const LIFETIME := 0.35

var color := Color.WHITE
var strength := Strength.NORMAL
var shards: Array[Dictionary] = []
var age := 0.0

static func burst(layer: Node, at: Vector2, burst_color: Color, burst_strength: Strength) -> void:
	var node := HitBurst.new()
	node.position = at
	node.color = burst_color
	node.strength = burst_strength
	layer.add_child(node)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 3
	for i in SHARD_COUNT[strength]:
		var angle: float = TAU * i / SHARD_COUNT[strength] + randf_range(-0.2, 0.2)
		shards.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"speed": SHARD_SPEED[strength] * randf_range(0.6, 1.0),
			"size": randi_range(2, 4),
		})

func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := age / LIFETIME
	var fade := 1.0 - t
	for shard in shards:
		var pos: Vector2 = (shard["dir"] * shard["speed"] * (1.0 - fade * fade) * LIFETIME).round() # Fast at first, then slowing
		var size: int = shard["size"]
		draw_rect(Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size)), Color(color, fade))
	if t < 0.5:
		var ring := t * 2.0
		draw_arc(Vector2.ZERO, 4.0 + ring * RING_SIZE[strength], 0.0, TAU, 32, Color(Color.WHITE, 1.0 - ring), 2.0)
