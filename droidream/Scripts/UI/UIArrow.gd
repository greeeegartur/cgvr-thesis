extends Control
class_name UIArrow

# Small pixel arrow (white with a black outline) that shows the player they can move left or right

@export var facing := 1 # 1 points right, -1 points left

const ARROW_SIZE := Vector2(7, 11)

func _init() -> void:
	custom_minimum_size = ARROW_SIZE
	size = ARROW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	# Four columns from the base to the tip, each 2 px shorter than the one before; outline first
	for pass_index in 2:
		var color := Color.BLACK if pass_index == 0 else Color.WHITE
		var grow := 1 if pass_index == 0 else 0
		for i in 4:
			var column := i if facing > 0 else 3 - i
			var height := 9 - i * 2
			var top := (ARROW_SIZE.y - height) / 2.0
			draw_rect(Rect2(1 + column - grow, top - grow, 1 + grow * 2, height + grow * 2), color)
