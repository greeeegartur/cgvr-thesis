extends Sprite2D
class_name RepairObject

@export var objects : Array[Texture2D]

func _ready():
	texture = objects.pick_random()
	scale = Vector2(1.5, 1.5)
