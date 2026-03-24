extends Node

# This script is responsible for rolling 3 different boons from an available pool and assigning their specific effects

class_name BoonManager

@onready var available_boons: Array[BoonData] = []

# Sets up all boons for use
func _ready():
	var hp = preload("res://Scripts/Data/Boons/HP.tres")
	hp.effect = func():
		PlayerData.add_hp(2.0)
	
	var power = preload("res://Scripts/Data/Boons/Power.tres")
	power.effect = func():
		PlayerData.add_power(1.0)
	
	var defense = preload("res://Scripts/Data/Boons/Defense.tres")
	defense.effect = func():
		PlayerData.add_defense(0.25)
	
	var chips = preload("res://Scripts/Data/Boons/FreeChips.tres")
	chips.effect = func():
		PlayerData.add_guesses(CombatTypes.EntityType.SKY, 1)
		PlayerData.add_guesses(CombatTypes.EntityType.EARTH, 1)
		PlayerData.add_guesses(CombatTypes.EntityType.WATER, 1)
	
	var repair = preload("res://Scripts/Data/Boons/RepairBoon.tres")
	repair.effect = func():
		PlayerData.add_ability(AbilityDb.get_ability("repair"))
	
	available_boons = [hp, power, defense, chips, repair]

# Rolls random boons
func roll_boons() -> Array[BoonData]:
	var pool := available_boons.duplicate()
	pool.shuffle()
	return pool.slice(0,3)
