extends Node

# New items in new areas
var unlocked_item_ids: Array[String] = []

var items := {}

func _ready():
	_register_base_items()

# TO-DO: simplify this
# All items in stops by default
func _register_base_items():
	# Items
	_register(preload("res://Scripts/Data/ShopItems/EarthChip.tres"))
	_register(preload("res://Scripts/Data/ShopItems/SkyChip.tres"))
	_register(preload("res://Scripts/Data/ShopItems/WaterChip.tres"))
	_register(preload("res://Scripts/Data/ShopItems/BeetleJuiceEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/MemoryChipEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/SoftBranchEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/ThickJellyEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/BallEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/IceCubeEntry.tres"))
	_register(preload("res://Scripts/Data/ShopItems/HypnoBoneEntry.tres"))
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

# Chips are always valid shop cards (they need no inventory slot), so they fill a shop that has too few valid entries
const FILLER_IDS := ["sky_chip", "earth_chip", "water_chip"]

# Draws up to count different entries by their rarity weights
func pick_weighted(entries: Array, count: int) -> Array[ShopEntry]:
	var pool := entries.duplicate()
	var picked: Array[ShopEntry] = []
	while picked.size() < count and not pool.is_empty():
		var total := 0
		for entry in pool:
			total += entry.draw_weight()
		var roll := randi_range(1, total)
		for entry in pool:
			roll -= entry.draw_weight()
			if roll <= 0:
				picked.append(entry)
				pool.erase(entry)
				break
	return picked

func get_item(id: String) -> ShopEntry:
	return items[id]

func get_unlocked_items():
	var result := []
	for id in unlocked_item_ids:
		result.append(items[id])
	return result
