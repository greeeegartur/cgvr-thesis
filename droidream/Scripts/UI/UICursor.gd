extends Control
class_name UICursor

# The highlight bar and marker of a UIList; one cursor moves between the rows, drawn in whole pixels

var bar_color := Color(1, 1, 1, 0.3)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_rect(Rect2(0, 1, size.x, size.y - 2), bar_color)
	
	# Marker: a small triangle with a black outline
	var mid := roundi(size.y / 2.0)
	for i in 4:
		draw_rect(Rect2(i, mid - 4 + i, 3, 9 - i * 2), Color.BLACK)
	for i in 4:
		draw_rect(Rect2(1 + i, mid - 3 + i, 1, 7 - i * 2), Color.WHITE)
