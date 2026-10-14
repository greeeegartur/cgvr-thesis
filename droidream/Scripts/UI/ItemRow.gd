extends HBoxContainer
class_name ItemRow

@onready var visual_root = $VisualRoot
@onready var icon = $VisualRoot/Icon
@onready var name_label = $VisualRoot/Name
@onready var count_label = $VisualRoot/Count

func setup(item: InventoryItem, base_scale := 1.0):
	custom_minimum_size = Vector2(0, 32)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	visual_root.scale = Vector2.ONE
	visual_root.modulate = Color.WHITE
	visual_root.rotation = 0.0
	
	icon.texture = item.data.icon
	name_label.text = item.data.display_name
	count_label.text = "x%d" % item.amount
	
	call_deferred("_refresh_visual_pivot")

func _refresh_visual_pivot():
	visual_root.pivot_offset = visual_root.size * 0.5
