extends Control
class_name ShopItemPopup

@onready var desc = $Description
@onready var cost = $Sprite2D/Cost
@onready var item_name = $Name

const DESC_MAX_FONT_SIZE := 8
const DESC_MIN_FONT_SIZE := 6
const DESC_SIZE_BY_CHARS := [
	{ "chars": 75, "size": 8 },
	{ "chars": 115, "size": 7 },
	{ "chars": 150, "size": 6 },
	{ "chars": 9999, "size": 5 },
]

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
	await get_tree().process_frame
	
	_fit_label_by_character_count(desc, DESC_MAX_FONT_SIZE, DESC_MIN_FONT_SIZE)


func _fit_label_by_character_count(label: RichTextLabel, max_size: int, min_size: int):
	var plain_text := _strip_bbcode(label.text)
	var char_count := plain_text.length()
	var chosen_size := max_size
	
	for rule in DESC_SIZE_BY_CHARS:
		if char_count <= rule["chars"]:
			chosen_size = rule["size"]
			break
	
	chosen_size = clamp(chosen_size, min_size, max_size)
	label.add_theme_font_size_override("normal_font_size", chosen_size)
	label.add_theme_font_size_override("bold_font_size", chosen_size)
	label.add_theme_font_size_override("italics_font_size", chosen_size)
	label.add_theme_font_size_override("bold_italics_font_size", chosen_size)

func _strip_bbcode(text: String) -> String:
	var result := ""
	var inside_tag := false
	
	for i in text.length():
		var c := text[i]
		
		if c == "[":
			inside_tag = true
			continue
		
		if c == "]":
			inside_tag = false
			continue
		
		if not inside_tag:
			result += c
	
	return result
