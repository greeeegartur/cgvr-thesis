extends Resource
class_name ItemData

enum ItemType {
	ABILITY,
	PASSIVE,
	ITEM
}

@export var id: String
@export var display_name: String
@export var description: String
@export var type: ItemType
@export var icon: Texture2D

@export var cost: int = 2
@export var max_stack: int = 1   # 1 = unique and if >1 = stackable
