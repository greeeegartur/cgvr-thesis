extends ParallaxBackground
class_name CombatBackground

@export var layer_scales := {
	"Layer11_Sky": 0.03,
	"Layer10_Clouds": 0.06,
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

# Cloud variables
@export var drift_speed := 4.0
@export var reset_x := -40.0
@export var start_x := 0.0
@export var end_x := 40.0
@onready var cloudsA := $Layer10_Clouds/CloudsDrift/CloudsA
@onready var cloudsB := $Layer10_Clouds/CloudsDrift/CloudsB

func _process(delta):
	cloudsA.position.x -= drift_speed * delta
	cloudsB.position.x -= drift_speed * delta
	
	if cloudsA.position.x <= -960.0:
		cloudsA.position.x = cloudsA.position.x + 960.0
	
	if cloudsB.position.x <= -960.0:
		cloudsB.position.x = cloudsA.position.x + 960.0

func _ready():
	cloudsA.position = Vector2(317.0, 180)
	cloudsB.position = Vector2(960.0, 180)
	
	for child in get_children():
		if child is ParallaxLayer and layer_scales.has(child.name):
			child.motion_scale = Vector2(layer_scales[child.name], 1.0)
