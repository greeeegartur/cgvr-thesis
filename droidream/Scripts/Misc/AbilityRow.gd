extends HBoxContainer

@onready var name_label = $Name
@onready var cd_container = $Container

func setup(ability):
	name_label.text = ability.data.display_name
	
	var max_cd = ability.data.cooldown_max
	for i in cd_container.get_child_count():
		var slot = cd_container.get_child(i)
		slot.visible = i < max_cd
		if i < ability.cooldown:
			slot.modulate = Color(0.3, 0.3, 0.3)
		else:
			slot.modulate = Color(1, 1, 1)
	
