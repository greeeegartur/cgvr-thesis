extends Control
class_name AbilityInfoContainer

@onready var desc: RichTextLabel = $Description

func _ready():
	desc.bbcode_enabled = true
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible = false

func setup_from_inventory_ability(ability: InventoryAbility):
	if ability == null:
		visible = false
		return
	
	visible = true
	
	var cooldown_text := "[color=#eff238]Cooldown: %d turns[/color]" % ability.data.cooldown_max
	desc.text = cooldown_text + "\n" + ability.data.description
	
	call_deferred("_fit_texts")

func _fit_texts():
	await get_tree().process_frame
	await _fit_label(desc, 12, 8)

func _fit_label(label: RichTextLabel, max_size: int, min_size: int):
	var current_size := max_size
	
	while current_size >= min_size:
		label.add_theme_font_size_override("normal_font_size", current_size)
		await get_tree().process_frame
		
		if not _is_overflowing(label):
			return
		
		current_size -= 1

func _is_overflowing(label: RichTextLabel) -> bool:
	return label.get_content_height() > label.size.y

func move_to_row(row: Control, extra_offset := Vector2.ZERO):
	var target_pos := Vector2(position.x, row.position.y) + extra_offset
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", target_pos.y, 0.14)
