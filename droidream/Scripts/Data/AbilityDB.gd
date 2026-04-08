extends Node

var abilities := {}

func _ready():
	_register(preload("res://Scripts/Data/Abilities/Repair.tres"))
	_register(preload("res://Scripts/Data/Abilities/MultiTame.tres"))

func _register(ability: Resource):
	if ability.id == "repair":
		ability.execute = func(combat, ability, target):
			await combat._ability_repair_sequence(ability)
	
	if ability.id == "multitame":
		ability.execute = func(combat, ability, target):
			await combat._ability_multi_tame_sequence(ability, target)
	
	abilities[ability.id] = ability
	# DEBUG: 
	PlayerData.add_ability(ability)

func get_ability(id: String) -> Resource:
	return abilities.get(id)
