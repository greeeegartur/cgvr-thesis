extends Control
class_name ShopItemPopup

@onready var desc = $Description
@onready var cost = $Sprite2D/Cost
@onready var item_name = $Name

var colors = {
	ShopEntry.ItemType.ABILITY: Color("#eff238"),
	ShopEntry.ItemType.PASSIVE: Color("9a2ea3ff"),
	ShopEntry.ItemType.ITEM: Color("#00d200")
}

func _ready():
	desc.bbcode_enabled = true
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _type_to_string(t: int) -> String:
	match t:
		ShopEntry.ItemType.ABILITY: return "Ability"
		ShopEntry.ItemType.PASSIVE: return "Passive"
		ShopEntry.ItemType.ITEM: return "Item"
	return "Unknown" # Should not happen

func setup(data: ShopEntry, quantity: int, modified_cost := 0):
	item_name.text = data.display_name
	cost.text = "x%d" % (modified_cost if modified_cost > 0 else data.cost)
	var type_name = _type_to_string(data.type)
	var type_color = colors[data.type].to_html()
	var extra_text := ""
	
	if data.type == ShopEntry.ItemType.ABILITY:
		extra_text = " [color=#cfcfcf](Cooldown: %d)[/color]" % data.ability_data.cooldown_max
	desc.text = "[color=%s]%s[/color]. %s%s" % [
		type_color,
		type_name,
		data.description,
		extra_text
	]
	
	call_deferred("_fit_texts")

func _fit_texts():
	await get_tree().process_frame
	await _fit_label(desc, 7, 4)

func _fit_label(label: Control, max_size: int, min_size: int):
	var current_size := max_size
	
	while current_size >= min_size:
		label.add_theme_font_size_override("normal_font_size", current_size)
		await get_tree().process_frame
		if not _is_overflowing(label):
			return
		
		current_size -= 1

func _is_overflowing(label: Control) -> bool:
	return label.get_content_height() > label.get_size().y
