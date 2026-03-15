extends Control

@onready var icon = $Icon
@onready var name_label = $Name
@onready var desc_label = $Description

func set_boon(boon: BoonData):
	icon.texture = boon.icon
	name_label.text = boon.name
	desc_label.text = boon.description
