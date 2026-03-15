extends Control

@onready var icon = $Icon
@onready var name_label = $Name
@onready var desc_label = $Description

var colors = {
	"Upgrade": Color("#eff238"),
	"Item": Color("00d200ff"),
	"Passive": Color("3d9feb"),
	"Ability": Color("9a2ea3ff")
}

func set_boon(data: BoonData):
	var type_color = colors.get(data.type, Color.WHITE)
	var type_text = data.type
	desc_label.text = "[color=#%s]%s.[/color] %s" % [
		type_color.to_html(false),
		type_text,
		data.description
	]
	name_label.text = data.name
	icon.texture = data.icon
