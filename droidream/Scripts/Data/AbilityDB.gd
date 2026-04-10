extends Node

var abilities := {}

func _ready():
	# Abilities
	_register(preload("res://Scripts/Data/Abilities/Repair.tres"))
	_register(preload("res://Scripts/Data/Abilities/MultiTame.tres"))
	_register(preload("res://Scripts/Data/Abilities/HeatUp.tres"))
	_register(preload("res://Scripts/Data/Abilities/Harden.tres"))
	# Passives
	_register(preload("res://Scripts/Data/Abilities/ScratchyFrame.tres"))
	_register(preload("res://Scripts/Data/Abilities/Microbots.tres"))
	_register(preload("res://Scripts/Data/Abilities/Recalibration.tres"))
	_register(preload("res://Scripts/Data/Abilities/ReflexiveSensors.tres"))
	_register(preload("res://Scripts/Data/Abilities/Enamor.tres"))
	_register(preload("res://Scripts/Data/Abilities/HumanAtHeart.tres"))
	
	

func _register(ability: Resource):
	if ability is AbilityData: # Abilities
		if ability.id == "repair":
			ability.execute = func(combat, ability, target):
				await combat._ability_repair_sequence(ability)
		
		if ability.id == "multitame":
			ability.execute = func(combat, ability, target):
				await combat._ability_multi_tame_sequence(ability, target)
		
		if ability.id == "heatup":
			ability.execute = func(combat, inventory_ability, target):
				await combat._ability_heat_up_sequence(inventory_ability)
		
		if ability.id == "harden":
			ability.execute = func(combat, ability, target):
				await combat._ability_harden_sequence(ability)
	
	# Abilities + passives
	abilities[ability.id] = ability
	# DEBUG:
	if ability.id == "human_at_heart":
		PlayerData.add_ability(ability)
	if ability.id == "multitame":
		PlayerData.add_ability(ability)

func get_ability(id: String) -> Resource:
	return abilities.get(id)
