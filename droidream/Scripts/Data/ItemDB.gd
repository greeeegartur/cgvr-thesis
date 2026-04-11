extends Node

# New items in new areas
var unlocked_item_ids: Array[String] = []

var items := {}

func _ready():
	_register_base_items()

# TO-DO: simplify this
# All items in stops by default
func _register_base_items():
	# Base
	_register(preload("res://Scripts/Data/ShopItems/EarthChip.tres"))
	_register(preload("res://Scripts/Data/ShopItems/SkyChip.tres"))
	_register(preload("res://Scripts/Data/ShopItems/WaterChip.tres"))
	_register(preload("res://Scripts/Data/ShopItems/BeetleJuiceEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/MemoryChipEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/SoftBranchEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/ThickJellyEntry.tres"))
	# Abilities
	_register(preload("res://Scripts/Data/ShopItems/RepairEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/MultiTameEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/HeatUpEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/HardenEntry.tres"))
	# Passives
	_register(preload("res://Scripts/Data/ShopItems/ScratchyFrameEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/MicrobotsEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/RecalibrationEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/ReflexiveSensorsEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/EnamorEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/HumanAtHeartEntry.tres"))

func _register(item: ShopEntry):
	items[item.id] = item
	unlocked_item_ids.append(item.id)

func get_item(id: String) -> ShopEntry:
	return items[id]

func get_unlocked_items():
	var result := []
	for id in unlocked_item_ids:
		result.append(items[id])
	return result
