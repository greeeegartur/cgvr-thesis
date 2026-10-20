extends Node2D
class_name TameAura

# Purple-pink neon light that swirls up from inside a creature while it is being tamed; the creature scales up while it grows

const SHADER := preload("res://Scenes/VFX/TameAura.gdshader")
const SCALE_UP := 1.15
const GROW_TIME := 0.7
const FADE_TIME := 0.4
const SPARK_COUNT := 10
const SPARK_COLORS := [Color("#b04aff"), Color("#ff4ac0"), Color("#ffffff")]

var source: Sprite2D # The creature's own sprite, copied frame by frame so the aura keeps its silhouette
var copy: Sprite2D
var material_ref: ShaderMaterial
var host: Node2D # The creature's Visual node (scaled while the aura is up)
var base_scale := Vector2.ONE
var tween: Tween
var age := 0.0
var intensity := 0.0
var ending := false
var sparks: Array[Dictionary] = []

# Puts an aura on an EnemyVisual; the glow starts after delay seconds
static func attach(enemy_visual: EnemyVisual, delay := 0.0) -> TameAura:
	var src := enemy_visual.visual.get_node_or_null("Sprite2D") as Sprite2D
	if src == null:
		return null
	var aura := TameAura.new()
	aura.source = src
	aura.host = enemy_visual.visual
	enemy_visual.visual.add_child(aura)
	aura.start(delay)
	return aura

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1
	base_scale = host.scale
	copy = Sprite2D.new()
	material_ref = ShaderMaterial.new()
	material_ref.shader = SHADER
	copy.material = material_ref
	add_child(copy)
	for i in SPARK_COUNT:
		sparks.append({
			"angle": randf() * TAU,
			"radius": randf_range(4.0, 14.0),
			"speed": randf_range(0.8, 1.4),
			"phase": randf(),
			"color": SPARK_COLORS.pick_random(),
		})

func start(delay: float) -> void:
	tween = create_tween().set_parallel(true)
	tween.tween_method(_set_intensity, 0.0, 1.0, GROW_TIME).set_delay(delay)
	tween.tween_property(host, "scale", base_scale * SCALE_UP, GROW_TIME).set_delay(delay)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_intensity(value: float) -> void:
	intensity = value
	material_ref.set_shader_parameter("intensity", value)

# Fades the light and returns the creature to its size, then frees itself
func finish() -> void:
	if ending:
		return
	ending = true
	if tween:
		tween.kill()
	var out := create_tween().set_parallel(true)
	out.tween_method(_set_intensity, intensity, 0.0, FADE_TIME)
	out.tween_property(host, "scale", base_scale, FADE_TIME)
	await out.finished
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(host):
		host.scale = base_scale

func _process(delta: float) -> void:
	age += delta
	if is_instance_valid(source):
		copy.texture = source.texture
		copy.hframes = source.hframes
		copy.vframes = source.vframes
		copy.frame = source.frame
		copy.flip_h = source.flip_h
		copy.centered = source.centered
		copy.offset = source.offset
		copy.position = source.position
		copy.scale = source.scale
		copy.rotation = source.rotation
	queue_redraw()

# Small neon sparks spiral outward from the creature's center
func _draw() -> void:
	if intensity <= 0.0 or source == null:
		return
	var center := source.position
	for spark in sparks:
		var t := fmod(age * spark["speed"] * 0.5 + spark["phase"], 1.0)
		var radius: float = spark["radius"] + t * 28.0
		var angle: float = spark["angle"] + t * 3.0
		var pos := (center + Vector2(cos(angle), sin(angle)) * radius).round()
		var color: Color = spark["color"]
		color.a = intensity * (1.0 - t)
		draw_rect(Rect2(pos, Vector2(2, 2)), color)
