extends Node2D
class_name StarBurst

# One shared effect for hits, blocks, crits, kills and taming: chunky outlined stars, impact rays, rings, a slash line and sparkle crosses (Paper Mario style, all drawn in code)

enum Preset { NORMAL, BLOCK, CRIT, KILL, TAME, TAME_FAIL }

const PARTICLE_CAP := 80 # Live stars and sparkles over all bursts; bigger bursts shrink instead of piling up
const OUTLINE := Color(0, 0, 0, 1)
const PRESETS := {
	Preset.NORMAL: { "stars": 5, "star_size": Vector2(4, 6), "speed": Vector2(40, 85), "rays": 6, "ray_len": 20.0, "ring": 22.0, "sparkles": 0, "slash": false, "gravity": 0.0, "life": 0.4, "colors": [Color.WHITE] },
	Preset.BLOCK: { "stars": 4, "star_size": Vector2(3, 5), "speed": Vector2(30, 70), "rays": 0, "ray_len": 0.0, "ring": 30.0, "ring2": 18.0, "sparkles": 5, "slash": false, "gravity": 0.0, "life": 0.5, "colors": [Color("#9dffb0"), Color.WHITE] },
	Preset.CRIT: { "stars": 9, "star_size": Vector2(4, 7), "speed": Vector2(60, 130), "rays": 10, "ray_len": 38.0, "ring": 38.0, "sparkles": 4, "slash": true, "gravity": 0.0, "life": 0.55, "colors": [Color("#fff27a"), Color.WHITE, Color("#ff9a2e")] },
	Preset.KILL: { "stars": 8, "star_size": Vector2(3, 6), "speed": Vector2(40, 100), "rays": 8, "ray_len": 28.0, "ring": 30.0, "sparkles": 3, "slash": false, "gravity": 90.0, "life": 0.75, "colors": [Color("#ff3a3a"), Color.WHITE, Color("#ff9a8a")] },
	Preset.TAME: { "stars": 10, "star_size": Vector2(3, 6), "speed": Vector2(20, 60), "rays": 0, "ray_len": 0.0, "ring": 34.0, "ring2": 20.0, "sparkles": 8, "slash": false, "gravity": -50.0, "life": 0.9, "colors": [Color("#ff7ae0"), Color.WHITE, Color("#ffe27a")] },
	Preset.TAME_FAIL: { "stars": 0, "star_size": Vector2(2, 3), "speed": Vector2(10, 30), "rays": 0, "ray_len": 0.0, "ring": 22.0, "sparkles": 6, "slash": false, "gravity": 80.0, "life": 0.7, "colors": [Color("#9a9aa8"), Color("#c8c8d0")] },
}

static var live_particles := 0

var preset := Preset.NORMAL
var color_override := Color(0, 0, 0, 0) # Alpha 0 means use the preset colors
var delay := 0.0
var data: Dictionary
var stars: Array[Dictionary] = []
var sparkles: Array[Dictionary] = []
var rays: Array[float] = []
var slash_angle := 0.0
var age := 0.0
var counted := 0

# Plays a burst at a position inside the given layer; delay holds it back (a kill waits for the hit to land)
static func play(layer: Node, at: Vector2, burst_preset: Preset, color := Color(0, 0, 0, 0), burst_delay := 0.0) -> void:
	var node := StarBurst.new()
	node.preset = burst_preset
	node.position = at
	node.color_override = color
	node.delay = burst_delay
	layer.add_child(node)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 3
	data = PRESETS[preset]
	var requested: int = data["stars"] + data["sparkles"]
	var room := maxi(PARTICLE_CAP - live_particles, 0)
	var factor := 1.0 if requested <= room else float(room) / maxf(requested, 1.0)
	var star_count := int(round(data["stars"] * factor))
	var sparkle_count := int(round(data["sparkles"] * factor))
	counted = star_count + sparkle_count
	live_particles += counted
	var colors: Array = data["colors"]
	if color_override.a > 0.0 and preset == Preset.NORMAL:
		colors = [color_override, Color.WHITE] # Normal hits take the hit color
	var speed: Vector2 = data["speed"]
	var size: Vector2 = data["star_size"]
	for i in star_count:
		var angle := TAU * i / maxf(star_count, 1) + randf_range(-0.3, 0.3)
		stars.append({
			"dir": Vector2(cos(angle), sin(angle)),
			"speed": randf_range(speed.x, speed.y),
			"size": randf_range(size.x, size.y),
			"rot": randf() * TAU,
			"spin": randf_range(-4.0, 4.0),
			"color": colors.pick_random(),
			"points": 5 if randf() < 0.6 else 4,
		})
	for i in sparkle_count:
		sparkles.append({
			"pos": Vector2(randf_range(-22, 22), randf_range(-22, 22)),
			"phase": randf(),
			"color": colors.pick_random(),
		})
	for i in int(data["rays"]):
		rays.append(TAU * i / data["rays"] + randf_range(-0.12, 0.12))
	slash_angle = randf_range(-0.6, -0.2)

func _exit_tree() -> void:
	live_particles = maxi(live_particles - counted, 0)

func _process(delta: float) -> void:
	age += delta
	if age >= delay + data["life"]:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = (age - delay) / data["life"]
	if t < 0.0:
		return
	var fade: float = 1.0 - t
	var ease_out: float = 1.0 - pow(1.0 - t, 2.0)
	var ring_color := Color.WHITE
	var colors: Array = data["colors"]
	if preset == Preset.BLOCK or preset == Preset.TAME or preset == Preset.TAME_FAIL:
		ring_color = colors[0]
	if color_override.a > 0.0 and preset == Preset.NORMAL:
		ring_color = Color.WHITE
	# Rings expand and fade
	for key in ["ring", "ring2"]:
		if data.has(key):
			var offset := 0.0 if key == "ring" else 0.15
			var rt: float = clampf((t - offset) / (1.0 - offset), 0.0, 1.0)
			if rt > 0.0 and rt < 1.0:
				var radius: float = 4.0 + (1.0 - pow(1.0 - rt, 2.0)) * data[key]
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(OUTLINE, 1.0 - rt), 3.5)
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(ring_color, 1.0 - rt), 2.0)
	# Rays radiate out quickly and shrink
	if t < 0.55:
		var rt: float = t / 0.55
		for angle in rays:
			var dir := Vector2(cos(angle), sin(angle))
			var start: Vector2 = dir * (6.0 + rt * 10.0)
			var end: Vector2 = dir * (6.0 + rt * data["ray_len"])
			draw_line(start.round(), end.round(), Color(ring_color, 1.0 - rt), 2.0)
	# Slash line through the target on crits
	if data["slash"] and t < 0.35:
		var st: float = t / 0.35
		var dir := Vector2(cos(slash_angle), sin(slash_angle))
		var half: float = 32.0 * (1.0 - st * 0.4)
		draw_line((-dir * half).round(), (dir * half).round(), Color(1, 1, 1, 1.0 - st), 3.0 - st * 2.0)
	# Stars fly out, spin and fade (gravity pulls them down, or lifts them for taming)
	for star in stars:
		var pos: Vector2 = star["dir"] * star["speed"] * ease_out * data["life"] * 1.6 + Vector2(0, data["gravity"] * t * t * data["life"])
		var size: float = star["size"] * (1.0 - t * 0.5)
		_draw_star(pos.round(), size, star["rot"] + star["spin"] * t, star["points"], Color(star["color"], clampf(fade * 2.0, 0.0, 1.0)))
	# Sparkle crosses twinkle
	for sparkle in sparkles:
		var twinkle := 0.5 + 0.5 * sin((t + sparkle["phase"]) * TAU * 2.0)
		var pos: Vector2 = sparkle["pos"] + Vector2(0, data["gravity"] * t * 0.3)
		var arm := 3.0 + 2.0 * twinkle
		var color := Color(sparkle["color"], fade * (0.5 + 0.5 * twinkle))
		draw_rect(Rect2(pos.round() + Vector2(-arm, -0.5), Vector2(arm * 2.0, 1.0)), color)
		draw_rect(Rect2(pos.round() + Vector2(-0.5, -arm), Vector2(1.0, arm * 2.0)), color)

# A star with a black outline: the outline is a slightly bigger copy drawn first
func _draw_star(pos: Vector2, size: float, rot: float, points: int, color: Color) -> void:
	draw_colored_polygon(_star_points(pos, size + 1.5, rot, points), Color(OUTLINE, color.a))
	draw_colored_polygon(_star_points(pos, size, rot, points), color)

func _star_points(pos: Vector2, size: float, rot: float, points: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var inner := size * (0.45 if points == 5 else 0.4)
	for i in points * 2:
		var radius := size if i % 2 == 0 else inner
		var angle := rot + PI * i / points - PI * 0.5
		result.append(pos + Vector2(cos(angle), sin(angle)) * radius)
	return result
