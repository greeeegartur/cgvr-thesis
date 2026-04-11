extends Node

var items := {}

func _ready():
	_register(preload("res://Scripts/Data/Items/BeetleJuice.tres"))
	_register(preload("res://Scripts/Data/Items/MemoryChip.tres"))
	_register(preload("res://Scripts/Data/Items/ThickJelly.tres"))
	_register(preload("res://Scripts/Data/Items/SoftBranch.tres"))

func _register(item: ItemData):
	match item.id:
		"beetlejuice":
			item.use_effect = func(combat, inventory_item, target):
				await combat._item_beetle_juice_sequence(inventory_item, target)
		
		"memory_chip":
			item.use_effect = func(combat, inventory_item, target):
				await combat._item_memory_chip_sequence(inventory_item, target)
		
		"thick_jelly":
			item.use_effect = func(combat, inventory_item, target):
				await combat._item_thick_jelly_sequence(inventory_item, target)
		
		"soft_branch":
			item.use_effect = func(combat, inventory_item, target):
				await combat._item_soft_branch_sequence(inventory_item, target)
	
	items[item.id] = item

func get_item(id: String) -> ItemData:
	return items.get(id)
