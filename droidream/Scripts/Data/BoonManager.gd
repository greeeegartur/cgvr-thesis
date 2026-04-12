extends Node

# This script is responsible for rolling 3 different boons from an available pool and assigning their specific effects

class_name BoonManager

@onready var available_boons: Array[BoonData] = []
var always_available_ids := [
		"hp",
		"power",
		"defense",
		"free_chips"
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
	
	available_boons = [hp, power, defense, chips, repair, multi_tame, heat_up, harden, scratchy_frame, microbots, recalibration, reflexive_sensors, human_at_heart]

# Rolls random boons
func roll_boons() -> Array[BoonData]:
	var pool: Array[BoonData] = []
	var fallback_pool: Array[BoonData] = []
	var abilities_full := PlayerData.has_max_abilities()
	
	for boon in available_boons:
		var is_always_available := boon.id in always_available_ids
		var is_ability_like := boon.id != ""
		
		# Skips boons if the player already has them
		if is_ability_like and PlayerData.has_ability(boon.id):
			continue
		
		# Skip all ability/passive boons if player is at cap
		if is_ability_like and abilities_full:
			continue
		
		if is_always_available:
			fallback_pool.append(boon)
		
		pool.append(boon)
	
	pool.shuffle()
	return pool.slice(0, 3)
	
	var result: Array[BoonData] = pool.duplicate()
	fallback_pool.shuffle()

	for boon in fallback_pool:
		if result.size() >= 3:
			break
		if result.has(boon):
			continue
		result.append(boon)

	return result
