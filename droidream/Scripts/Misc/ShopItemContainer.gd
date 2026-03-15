extends Control
class_name ShopItemPopup

@onready var desc = $Description
@onready var cost = $Sprite2D/Cost
@onready var item_name = $Name

var colors = {
	ItemData.ItemType.ABILITY: Color("#9a2ea3"),
	ItemData.ItemType.PASSIVE: Color("#3d9feb"),
	ItemData.ItemType.ITEM: Color("#00d200")
}

func _type_to_string(t: int) -> String:
	match t:
		ItemData.ItemType.ABILITY: return "Ability"
		ItemData.ItemType.PASSIVE: return "Passive"
		ItemData.ItemType.ITEM: return "Item"
	return "Unknown" # Should not happen

func setup(data: ItemData, quantity: int):
	item_name.text = data.display_name
	cost.text = "x%d" % data.cost

	# Type formatting
	var type_name = _type_to_string(data.type)
	var type_color = colors[data.type].to_html()
	desc.bbcode_enabled = true
	desc.text = "[color=%s]%s[/color]. %s" % [
		type_color,
		type_name,
		data.description
	]
