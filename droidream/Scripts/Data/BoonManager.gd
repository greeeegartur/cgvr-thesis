extends Node

# This script is responsible for rolling 3 different boons from an available pool and assigning their specific effects

class_name BoonManager

@onready var available_boons: Array[BoonData] = []
var always_available_ids := [
		"hp",
		"power",
		"defense",
		"chips"
	]

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
	
	var enamor = preload("res://Scripts/Data/Boons/EnamorBoon.tres")
	enamor.effect = func():
		PlayerData.add_ability(AbilityDb.get_ability("enamor"))
	
	available_boons = [hp, power, defense, chips, repair, multi_tame, heat_up, harden, scratchy_frame, microbots, recalibration, reflexive_sensors, human_at_heart, enamor]

# Rolls 3 different boons: the stat boons are always valid (except Defense once it is at its cap), ability boons only while they are not owned and a slot is free
func roll_boons() -> Array[BoonData]:
	var pool: Array[BoonData] = []
	var stat_pool: Array[BoonData] = []
	var abilities_full := PlayerData.has_max_abilities()
	
	for boon in available_boons:
		if boon.id in always_available_ids:
			if boon.id == "defense" and PlayerData.has_max_defense():
				continue
			stat_pool.append(boon)
			pool.append(boon)
		elif not abilities_full and not PlayerData.has_ability(boon.id):
			pool.append(boon)
	
	pool.shuffle()
	var result: Array[BoonData] = pool.slice(0, 3)
	
	# Fills missing slots with stat boons (HP, Power and Chips are always there, so this never stays short)
	if result.size() < 3:
		stat_pool.shuffle()
		for boon in stat_pool:
			if result.size() >= 3:
				break
			if not result.has(boon):
				result.append(boon)
	if result.size() < 3:
		push_error("Boon roll found only %d valid boons." % result.size())
	
	return result
