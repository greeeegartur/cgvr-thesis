extends ColorRect
class_name MinigameGlow

# A swirling, blob-like dream glow with drifting sparks behind the minigame box; fades in with the minigame and out when it ends

const SHADER := preload("res://Scenes/VFX/MinigameGlow.gdshader")
const MARGIN := 100.0 # How far the glow reaches past the box on each side
const FALLBACK_BOX := Vector2(272, 302) # Minigames whose box has no PlayArea (Beetle Rush)
const FADE_IN := 0.6
const FADE_OUT := 0.4
const SPARK_COUNT := 26
const SPARK_COLORS := [Color("#b04aff"), Color("#ff4ac0"), Color("#ffffff")]

var material_ref: ShaderMaterial
var intensity := 0.0
var root_ref: Node2D # The minigame's VisualRoot, which sits at the middle of the box
var box_size := FALLBACK_BOX
var box_offset := Vector2.ZERO # Where the box center is relative to the root

# Drifting dream sparks that stay inside the glow (a child, so the glow shader does not tint them)
class Sparks extends Node2D:
	var area := Vector2.ZERO
	var sparks: Array[Dictionary] = []
	var age := 0.0
	var intensity := 0.0

	func _ready() -> void:
		for i in SPARK_COUNT:
			sparks.append({
				"x": randf(),
				"y": randf(),
				"speed": randf_range(0.04, 0.1),
				"sway": randf_range(6.0, 16.0),
				"phase": randf() * TAU,
				"color": SPARK_COLORS.pick_random(),
			})

	func _process(delta: float) -> void:
		age += delta
		queue_redraw()

	func _draw() -> void:
		for spark in sparks:
			var t := fmod(age * spark["speed"] + spark["y"], 1.0) # Rises from the bottom to the top and wraps
			var pos := Vector2(
				area.x * (0.15 + 0.7 * spark["x"]) + sin(age * 0.8 + spark["phase"]) * spark["sway"],
				area.y * (0.85 - 0.7 * t)
			).round()
			var twinkle := 0.5 + 0.5 * sin(age * 3.0 + spark["phase"])
			var color: Color = spark["color"]
			color.a = intensity * twinkle * sin(t * PI)
			draw_rect(Rect2(pos, Vector2(2, 2)), color)

var sparks_node: Sparks

# Puts a glow behind a minigame, centered on its box
static func attach(minigame: Control) -> MinigameGlow:
	var root := minigame.get_node_or_null("VisualRoot") as Node2D
	if root == null:
		return null
	var glow := MinigameGlow.new()
	root.add_child(glow)
	root.move_child(glow, 0) # Behind everything of the minigame
	var area := root.get_node_or_null("PlayArea") as Control
	if area:
		glow.box_size = area.size
		glow.box_offset = area.position + area.size * 0.5
	glow.setup(root)
	return glow

func setup(root: Node2D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	root_ref = root
	material_ref = ShaderMaterial.new()
	material_ref.shader = SHADER
	material_ref.set_shader_parameter("intensity", 0.0)
	material = material_ref
	sparks_node = Sparks.new()
	add_child(sparks_node)
	_follow_area()
	create_tween().tween_method(_set_intensity, 0.0, 1.0, FADE_IN)

# The glow keeps itself centered on the box
func _follow_area() -> void:
	size = box_size + Vector2(MARGIN, MARGIN) * 2.0
	global_position = root_ref.global_position + box_offset - size * 0.5
	material_ref.set_shader_parameter("rect_size", size)
	sparks_node.area = size

func _process(_delta: float) -> void:
	if is_instance_valid(root_ref):
		_follow_area()

func _set_intensity(value: float) -> void:
	intensity = value
	material_ref.set_shader_parameter("intensity", value)
	sparks_node.intensity = value

func finish() -> void:
	var tween := create_tween()
	tween.tween_method(_set_intensity, intensity, 0.0, FADE_OUT)
	await tween.finished
	queue_free()
