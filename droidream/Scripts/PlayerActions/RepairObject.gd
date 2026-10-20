extends Sprite2D
class_name RepairObject

# A part the player pulls in during the Repair ability: big with an outline, it pops in at the edge of the play area, flies toward the Droid
# leaving a trail, and hovers (with a chevron pointing at the Droid) until the player presses the opposite direction

const OUTLINE_SHADER := preload("res://Scenes/VFX/TargetOutline.gdshader")
const CHEVRON := preload("res://Scripts/PlayerActions/RepairChevron.gd")
const SPAWN_DISTANCE := { "left": 215.0, "right": 215.0, "up": 135.0, "down": 65.0 } # How far from the Droid each direction starts (near the screen edge)
const HOVER_DISTANCE := { "left": 90.0, "right": 90.0, "up": 100.0, "down": 55.0 } # How far from the Droid it waits
const BASE_SCALE := 2.0 # The 16 px art at 2x
const OUTLINE_PADDING := 2 # Transparent border around the art, so the outline is never cut off by the texture edge
const SPIN := PI * 0.6 # How far a part turns while it flies in
const WOBBLE := 0.12 # How far it sways while it waits
const TRAIL_POINTS := 9

@export var objects : Array[Texture2D]

var trail: Line2D
var chevron: Node2D
var travelling := false

func _ready():
	texture = _padded(objects.pick_random())
	scale = Vector2(BASE_SCALE, BASE_SCALE)
	
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("outline_width", 1.0)
	mat.set_shader_parameter("outline_color", Color.WHITE)
	material = mat

# Starts at the edge in the given direction (relative to the Droid), pops in and flies to its waiting place
func launch(target: Node2D, dir: String) -> void:
	var direction: Vector2 = Utils.DIR_MAP[dir]
	global_position = target.global_position + direction * SPAWN_DISTANCE[dir]
	scale = Vector2.ZERO
	
	trail = Line2D.new()
	trail.top_level = true
	trail.width = 10.0
	trail.default_color = Color(1, 1, 1, 0.55)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.7))
	trail.gradient = fade
	add_child(trail)
	trail.global_position = Vector2.ZERO
	
	chevron = CHEVRON.new()
	chevron.inward = -direction
	chevron.position = Vector2.ZERO
	chevron.top_level = true
	add_child(chevron)
	chevron.visible = false
	
	var hover: Vector2 = target.global_position + direction * HOVER_DISTANCE[dir]
	travelling = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(BASE_SCALE, BASE_SCALE) * 1.25, 0.14).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2(BASE_SCALE, BASE_SCALE), 0.1)
	tween.parallel().tween_property(self, "global_position", hover, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "rotation", SPIN, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		travelling = false
		rotation = 0.0
		trail.clear_points()
		chevron.visible = true
		# A small wobble while it waits
		var wobble := create_tween().set_loops()
		wobble.tween_property(self, "rotation", WOBBLE, 0.4).set_trans(Tween.TRANS_SINE)
		wobble.tween_property(self, "rotation", -WOBBLE, 0.8).set_trans(Tween.TRANS_SINE)
		wobble.tween_property(self, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_SINE))

func _process(_delta: float) -> void:
	if trail and travelling:
		trail.add_point(global_position)
		while trail.get_point_count() > TRAIL_POINTS:
			trail.remove_point(0)
	if chevron:
		# The chevron sits on the Droid's side of the part
		chevron.global_position = global_position + chevron.inward * 26.0

# The art with a transparent border around it
func _padded(source: Texture2D) -> Texture2D:
	var image := source.get_image()
	var padded := Image.create_empty(image.get_width() + OUTLINE_PADDING * 2, image.get_height() + OUTLINE_PADDING * 2, false, Image.FORMAT_RGBA8)
	padded.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(OUTLINE_PADDING, OUTLINE_PADDING))
	return ImageTexture.create_from_image(padded)
