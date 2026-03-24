extends Node

var abilities := {}

func _ready():
	_register(preload("res://Scripts/Data/Abilities/Repair.tres"))

func _register(ability: Resource):
	if ability.id == "repair":
		ability.execute = func(combat, ability, target):
			await combat._ability_repair_sequence(ability)
	
	abilities[ability.id] = ability
	PlayerData.add_ability(ability)

func get_ability(id: String) -> Resource:
	return abilities.get(id)
