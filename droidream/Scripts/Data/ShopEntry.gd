extends Resource
class_name ShopEntry

# Shop item type
enum ItemType {
	ABILITY,
	PASSIVE,
	ITEM
}

# How often an item shows up in shops and creature drops
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE
}

const RARITY_WEIGHTS := {
	Rarity.COMMON: 6,
	Rarity.UNCOMMON: 3,
	Rarity.RARE: 1
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
@export var rarity := Rarity.UNCOMMON # Only items use their rarity; abilities and passives count as uncommon

# The weight of this entry in a draw
func draw_weight() -> int:
	return RARITY_WEIGHTS[rarity if type == ItemType.ITEM else Rarity.UNCOMMON]
