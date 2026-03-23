extends Resource
class_name ShopEntry

# Shop item type
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
@export var max_stack: int = 9   # 1 = unique and if >1 = stackable

@export var ability_data: AbilityData
@export var passive_data: PassiveData
@export var item_data: ItemData
