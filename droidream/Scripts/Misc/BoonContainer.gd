extends Control

@onready var icon = $Icon
@onready var name_label = $Name
@onready var desc_label = $Description

var colors = {
	"Upgrade": Color("3d9feb"),
	"Item": Color("00d200ff"),
	"Passive": Color("9a2ea3ff"),
	"Ability": Color("#eff238")
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
