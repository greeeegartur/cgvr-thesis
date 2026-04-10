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
	
	var multi_tame = preload("res://Scripts/Data/Boons/MultiTameBoon.tres")
	multi_tame.effect = func():
		PlayerData.add_ability(AbilityDb.get_ability("multitame"))
	
	var heat_up = preload("res://Scripts/Data/Boons/HeatUpBoon.tres")
	heat_up.effect = func():
		PlayerData.add_ability(AbilityDb.get_ability("heatup"))
	
	var harden = preload("res://Scripts/Data/Boons/HardenBoon.tres")
	harden.effect = func():
		PlayerData.add_ability(AbilityDb.get_ability("harden"))
	
	var scratchy_frame = preload("res://Scripts/Data/Boons/ScratchyFrameBoon.tres")
	scratchy_frame.effect = func():
		PlayerData.add_ability(AbilityDb.get_ability("scratchy_frame"))
	
	var microbots = preload("res://Scripts/Data/Boons/MicrobotsBoon.tres")
	microbots.effect = func():
		PlayerData.add_ability(AbilityDb.get_ability("microbots"))
	
	var recalibration = preload("res://Scripts/Data/Boons/RecalibrationBoon.tres")
	recalibration.effect = func():
		PlayerData.add_ability(AbilityDb.get_ability("recalibration"))
	
	var reflexive_sensors = preload("res://Scripts/Data/Boons/ReflexiveSensorsBoon.tres")
	reflexive_sensors.effect = func():
		PlayerData.add_ability(AbilityDb.get_ability("reflexive_sensors"))
	
	var human_at_heart = preload("res://Scripts/Data/Boons/HumanAtHeartBoon.tres")
	human_at_heart.effect = func():
		PlayerData.add_ability(AbilityDb.get_ability("human_at_heart"))
	
	available_boons = [hp, power, defense, chips, repair, multi_tame, heat_up, harden, scratchy_frame, microbots, recalibration, reflexive_sensors, human_at_heart]

# Rolls random boons
func roll_boons() -> Array[BoonData]:
	var pool: Array[BoonData] = []
	for boon in available_boons:
		# Skips boons if the player already has them
		if boon.id != "":
			if PlayerData.has_ability(boon.id):
				continue
		
		pool.append(boon)
	
	pool.shuffle()
	return pool.slice(0, 3)
