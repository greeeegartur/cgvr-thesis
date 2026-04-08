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

func _type_to_string(t: int) -> String:
	match t:
		ShopEntry.ItemType.ABILITY: return "Ability"
		ShopEntry.ItemType.PASSIVE: return "Passive"
		ShopEntry.ItemType.ITEM: return "Item"
	return "Unknown" # Should not happen

func setup(data: ShopEntry, quantity: int):
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
