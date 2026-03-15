extends Node

class_name ItemDB

# New items in new areas
var unlocked_item_ids: Array[String] = []

var items := {}

func _ready():
	_register_base_items()

# TO-DO: simplify this
# All items in stops by default
func _register_base_items():
	_register(preload("res://Scripts/Data/Items/EarthChip.tres"))
	_register(preload("res://Scripts/Data/Items/SkyChip.tres"))
	_register(preload("res://Scripts/Data/Items/WaterChip.tres"))

func _register(item: ItemData):
	items[item.id] = item
	unlocked_item_ids.append(item.id)

func get_item(id: String) -> ItemData:
	return items[id]

func get_unlocked_items():
	var result := []
	for id in unlocked_item_ids:
		result.append(items[id])
	return result
