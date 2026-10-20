extends UIPanel

# Boon card: icon, name and description on a UIPanel

@onready var icon = $Icon
@onready var name_label = $Name
@onready var desc_label = $Description

const TEXT_LEFT := 82.0 # Where the name and description start (after the icon)
const PAD := 10.0
const TITLE_HEIGHT := 26.0
const MIN_HEIGHT := 80.0

var slot_center_y := 0.0 # Vertical center the card keeps whatever its height (set by the boon screen)

var colors = {
	"Upgrade": Color("3d9feb"),
	"Item": Color("00d200ff"),
	"Passive": Color("9a2ea3ff"),
	"Ability": Color("#eff238")
}

func _ready():
	super()
	# Share the panel's material so the selection flash reaches the icon and the text
	for node in [icon, name_label, desc_label]:
		node.use_parent_material = true
	desc_label.bbcode_enabled = true
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func set_boon(data: BoonData):
	var type_color = colors.get(data.type, Color.WHITE)
	var extra_text := ""
	if data.type == "Ability":
		extra_text = " [color=#cfcfcf](Cooldown: %d)[/color]" % AbilityDb.get_ability(data.id).cooldown_max
		
	desc_label.text = "[color=#%s][b]%s.[/b][/color] %s%s" % [
		type_color.to_html(false),
		data.type,
		data.description,
		extra_text
	]
	name_label.text = data.name
	icon.texture = data.icon
	
	_fit_card()

# Sizes the card around the text and keeps it centered on its slot (the gear beside it)
func _fit_card() -> void:
	await get_tree().process_frame
	var text_width := size.x - TEXT_LEFT - PAD
	desc_label.position = Vector2(TEXT_LEFT, TITLE_HEIGHT + 6)
	desc_label.size = Vector2(text_width, 0)
	name_label.position = Vector2(TEXT_LEFT, 8)
	name_label.size = Vector2(text_width, TITLE_HEIGHT)
	await get_tree().process_frame
	desc_label.size = Vector2(text_width, desc_label.get_content_height())
	
	size.y = maxf(MIN_HEIGHT, desc_label.position.y + desc_label.size.y + PAD)
	pivot_offset = size / 2.0
	icon.position = Vector2(PAD + 32, size.y / 2.0)
	position.y = roundf(slot_center_y - size.y / 2.0)
