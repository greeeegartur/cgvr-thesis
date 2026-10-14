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

func _ready():
	desc_label.bbcode_enabled = true
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func set_boon(data: BoonData):
	var type_color = colors.get(data.type, Color.WHITE)
	var extra_text := ""
	if data.type == "Ability":
		extra_text = " [color=#cfcfcf](Cooldown: %d)[/color]" % AbilityDb.get_ability(data.id).cooldown_max
		
	desc_label.text = "[color=#%s]%s.[/color] %s%s" % [
		type_color.to_html(false),
		data.type,
		data.description,
		extra_text
	]
	name_label.text = data.name
	icon.texture = data.icon

	call_deferred("_fit_texts")

func _fit_texts():
	await get_tree().process_frame
	await _fit_label(desc_label, 12, 8)

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
