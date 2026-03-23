extends HBoxContainer

@onready var name_label = $Name
@onready var cd_container = $CooldownContainer/Container

func setup(ability):
	name_label.text = ability.data.display_name
	
	var max_cd = max(1, ability.data.cooldown_max)
	for i in max_cd:
		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(8, 8)
		
		if i < ability.cooldown:
			rect.modulate = Color(0.3, 0.3, 0.3)
		else:
			rect.modulate = Color(1, 1, 1)
		
		cd_container.add_child(rect)
