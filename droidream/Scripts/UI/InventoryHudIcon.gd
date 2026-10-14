extends Control
class_name InventoryHudIcon

@export var icon_size := Vector2(18, 18)

@onready var icon: TextureRect = $Icon
@onready var amount_label: Label = $Icon/AmountLabel

func _ready():
	custom_minimum_size = icon_size
	size = icon_size
	icon.custom_minimum_size = icon_size
	icon.size = icon_size

func setup(texture: Texture2D, amount := 1, show_amount := false):
	custom_minimum_size = icon_size
	size = icon_size
	icon.texture = texture
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	
	amount_label.visible = show_amount
	if show_amount:
		amount_label.text = "x%d" % amount
