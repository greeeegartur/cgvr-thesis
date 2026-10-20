extends UIPanel
class_name AbilityInfoContainer

# Info box next to the ability list: cooldown and description on a green panel with a tail

const TEXT_WIDTH := 180.0 # Width of the description; the panel grows in height to fit the text

@onready var desc: RichTextLabel = $Description

func _ready() -> void:
	super()
	desc.bbcode_enabled = true
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible = false

# Sets the description text and resizes the panel around it
func _show_text(text: String) -> void:
	visible = true
	desc.text = text
	desc.position = content_origin()
	desc.size = Vector2(TEXT_WIDTH, 0)
	_fit_panel()

func _fit_panel() -> void:
	await get_tree().process_frame
	desc.size = Vector2(TEXT_WIDTH, 0)
	fit_to(Vector2(TEXT_WIDTH, desc.get_content_height()))

# Slides to the given y (canvas position) so the tail points at the selected row
func move_to_y(y: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", y, 0.14)

func setup_from_inventory_ability(ability: InventoryAbility) -> void:
	if ability == null:
		visible = false
		return
	
	var cooldown_text := "[color=#eff238]Cooldown: %d turns[/color]" % ability.data.cooldown_max
	_show_text(cooldown_text + "\n" + ability.data.description)
