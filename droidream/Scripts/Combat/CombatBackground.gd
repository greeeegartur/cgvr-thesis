extends ParallaxBackground
class_name CombatBackground

@export var layer_scales := {
	"Layer11_Sky": 0.03,
	"Layer10_Clouds": 0.08,
	"Layer09_Mountains": 0.10,
	"Layer08_TreesFar": 0.16,
	"Layer07_TreesMid": 0.24,
	"Layer06_PlantsFar": 0.34,
	"Layer05_TreesClose": 0.48,
	"Layer04_PlantsClose": 0.64,
	"Layer03_Ground": 1.0,
	"Layer02_BaseObjects": 1.0,
	"Layer01_Foreground": 1.08
}

const FILL_HEIGHT := 1200.0 # How far the art is extended downward
const STRETCH_HEIGHT := 48.0 # How far the last row of see-through layers is stretched (enough for fast camera moves)
const FILL_SAMPLE_ROWS := 8 # Rows at the bottom of the art that give the fill color

# How much of the original contrast each layer keeps (1.0 = unchanged): far layers are calmer, so the characters stand out
@export var layer_contrast := {
	"Layer11_Sky": 0.67,
	"Layer10_Clouds": 0.67,
	"Layer09_Mountains": 0.67,
	"Layer08_TreesFar": 0.77,
	"Layer07_TreesMid": 0.77,
	"Layer06_PlantsFar": 0.84,
	"Layer05_TreesClose": 0.87,
	"Layer04_PlantsClose": 0.90,
	"Layer03_Ground": 0.97,
	"Layer02_BaseObjects": 0.97,
	"Layer01_Foreground": 0.97
}
const GRADE_SHADER := preload("res://Scenes/Combat/BackgroundGrade.gdshader")

# Cloud variables
@export var cloud_speed := 4.0
@export var reset_x := -40.0
@export var start_x := 0.0
@export var end_x := 40.0
@onready var cloudsA := $Layer10_Clouds/CloudsDrift/CloudsA
@onready var cloudsB := $Layer10_Clouds/CloudsDrift/CloudsB

func _process(delta):
	_update_clouds(delta)

func _ready():
	cloudsA.position = Vector2(317.0, 180)
	cloudsB.position = Vector2(1277.0, 180)
	
	for child in get_children():
		if child is ParallaxLayer and layer_scales.has(child.name):
			child.motion_scale = Vector2(layer_scales[child.name], 1.0)
		_tile_layer(child)
		_grade_layer(child)
	_extend_layers_down()

# Repeats a layer sideways with its texture width, so the camera can never leave the art (zoomed out, following the far side...)
# The clouds already drift on two sprites of their own
func _tile_layer(layer: Node) -> void:
	if not layer is ParallaxLayer or layer.name == &"Layer10_Clouds":
		return
	var sprite := layer.get_node_or_null("Sprite2D") as Sprite2D
	if sprite and sprite.texture:
		layer.motion_mirroring = Vector2(sprite.texture.get_width(), 0)

func _update_clouds(delta):
	var tex_width = cloudsA.texture.get_width()
	
	cloudsA.position.x -= cloud_speed * delta
	cloudsB.position.x -= cloud_speed * delta
	
	if cloudsA.position.x <= 317 - tex_width:
		cloudsA.position.x = cloudsB.position.x + tex_width
	
	if cloudsB.position.x <= 317 - tex_width:
		cloudsB.position.x = cloudsA.position.x + tex_width

# Continues the ground and foreground layers downward (a flat color for solid layers, the stretched last row for see-through ones), so fast camera moves never show the empty viewport underneath
func _extend_layers_down() -> void:
	for layer_name in ["Layer05_TreesClose", "Layer04_PlantsClose", "Layer03_Ground", "Layer02_BaseObjects", "Layer01_Foreground"]:
		var sprite := get_node_or_null(layer_name + "/Sprite2D") as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var image := sprite.texture.get_image()
		var width := image.get_width()
		var height := image.get_height()
		
		# Average color of the bottom rows, weighted by opacity; a layer that is mostly see-through down there is not extended
		var color_sum := Color(0, 0, 0, 0)
		var alpha_sum := 0.0
		for y in range(height - FILL_SAMPLE_ROWS, height):
			for x in width:
				var pixel := image.get_pixel(x, y)
				color_sum += Color(pixel.r * pixel.a, pixel.g * pixel.a, pixel.b * pixel.a, 0.0)
				alpha_sum += pixel.a
		if alpha_sum < width * FILL_SAMPLE_ROWS * 0.5:
			_stretch_bottom_row(sprite)
			continue
		
		var fill := ColorRect.new()
		fill.name = "BottomFill"
		fill.color = Color(color_sum.r / alpha_sum, color_sum.g / alpha_sum, color_sum.b / alpha_sum)
		fill.position = Vector2(-width / 2.0, height / 2.0)
		fill.size = Vector2(width, FILL_HEIGHT)
		fill.use_parent_material = true # The fill gets the same contrast as its layer
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE # Scenery: clicks pass through to the game
		sprite.add_child(fill)

# For layers that are see-through at the bottom (the foreground plants): the last row is stretched down, so the elements that touch the edge keep going
func _stretch_bottom_row(sprite: Sprite2D) -> void:
	var width := sprite.texture.get_width()
	var height := sprite.texture.get_height()
	var stretch := Sprite2D.new()
	stretch.name = "BottomStretch"
	stretch.texture = sprite.texture
	stretch.region_enabled = true
	stretch.region_rect = Rect2(0, height - 1, width, 1)
	stretch.scale = Vector2(1, STRETCH_HEIGHT)
	stretch.position = Vector2(0, height / 2.0 + STRETCH_HEIGHT / 2.0)
	stretch.use_parent_material = true
	sprite.add_child(stretch)

# Gives every sprite of a layer the contrast of that layer (the clouds have two sprites of their own)
func _grade_layer(layer: Node) -> void:
	if not layer is ParallaxLayer or not layer_contrast.has(layer.name):
		return
	var material := ShaderMaterial.new()
	material.shader = GRADE_SHADER
	material.set_shader_parameter("contrast", layer_contrast[layer.name])
	for path in ["Sprite2D", "CloudsDrift/CloudsA", "CloudsDrift/CloudsB"]:
		var sprite := layer.get_node_or_null(path) as Sprite2D
		if sprite:
			sprite.material = material
