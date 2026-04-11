extends HBoxContainer

@onready var visual_root = $VisualRoot
@onready var name_label = $VisualRoot/Name
@onready var cd_container = $VisualRoot/Container

var base_scale := 1.0

func setup(ability, compact_scale := 1.0):
	custom_minimum_size = Vector2(0, 32)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	base_scale = compact_scale
	visual_root.scale = Vector2.ONE * base_scale
	visual_root.modulate = Color.WHITE
	visual_root.rotation = 0.0
	name_label.text = ability.data.display_name
	
	var max_cd = ability.data.cooldown_max
	for i in cd_container.get_child_count():
		var slot = cd_container.get_child(i)
		slot.visible = i < max_cd
		slot.modulate = Color(0.3, 0.3, 0.3) if i < ability.cooldown else Color.WHITE
	
	call_deferred("_refresh_visual_pivot")

func set_visual_scale(scale_value: float):
	base_scale = scale_value
	visual_root.scale = Vector2.ONE * base_scale
	call_deferred("_refresh_visual_pivot")

func _refresh_visual_pivot():
	visual_root.pivot_offset = visual_root.size * 0.5
	visual_root.position = Vector2.ZERO
