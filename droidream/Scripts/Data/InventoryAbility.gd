extends Resource
class_name InventoryAbility

var data: Resource # Either AbilityData or PassiveData
var cooldown := 0
var just_used := false

func is_passive() -> bool:
	return data is PassiveData

func is_active() -> bool:
	return data is AbilityData
