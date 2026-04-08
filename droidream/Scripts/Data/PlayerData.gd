extends Node

# This script is for storing and updating all player data, including functions to do so

# Base player variables (for reseting)
const BASE_MAX_HP := 10.0
const BASE_ATTACK := 4.0
const BASE_DEFENSE := 0.0
const BASE_GUESSES := {
	CombatTypes.EntityType.SKY: 3,
	CombatTypes.EntityType.EARTH: 3,
	CombatTypes.EntityType.WATER: 3
}
const MAX_ITEM_TYPES := 6
const MAX_ABILITY_SLOTS := 6

# Actual adjustable player variables (can change for the player)
var max_hp : float
var hp : float
var attack : float
var defense : float
@export var guesses := { } # Amount of guesses for each type
var currency := 0

# Inventory variables
var items: Array[InventoryItem] = []
var abilities: Array[InventoryAbility] = []

# For later...
var karma := 0

signal stats_changed

func _ready():
	reset_run()

func reset_run():
	# Reset stats
	max_hp = BASE_MAX_HP
	hp = BASE_MAX_HP
	attack = BASE_ATTACK
	defense = BASE_DEFENSE
	guesses = BASE_GUESSES.duplicate(true)
	
	# Reset progression
	currency = 0
	karma = 0

# Helper methods for use in CombatManager
func has_guess(t: CombatTypes.EntityType) -> bool:
	return guesses.get(t, 0) > 0

func consume_guess(t: CombatTypes.EntityType) -> void:
	if not has_guess(t):
		push_error("Tried to use guess with none left: %s" % CombatTypes.guess_type_to_string(t))
		return
	guesses[t] -= 1

func add_guesses(t: CombatTypes.EntityType, amount: int) -> void:
	guesses[t] = guesses.get(t, 0) + amount

func add_power(amount):
	attack += amount
	stats_changed.emit()

func add_defense(amount):
	defense += amount
	stats_changed.emit()

func add_hp(amount):
	max_hp += amount
	hp += amount
	stats_changed.emit()

func _get_total_chips():
	var sum := 0
	for g in guesses.values():
		sum += g
	return sum

# Inventory methods
func add_item(item_data: ItemData, amount := 1) -> bool:
	# Trying item stacking first (if already inside inventory)
	for item in items:
		if item.data == item_data:
			if item.amount < item_data.max_stack:
				item.amount = min(item.amount + amount, item_data.max_stack)
				return true
			return false
	
	# If the player gains a new item
	if items.size() >= MAX_ITEM_TYPES: # Checks if the player's inventory is full
		return false
	var new_item := InventoryItem.new()
	new_item.data = item_data
	new_item.amount = min(amount, item_data.max_stack)
	items.append(new_item)
	return true

func add_ability(ability_data: AbilityData) -> bool:
	# Prevents duplicates – the player can only have 1 of each ability
	for a in abilities:
		if a.data == ability_data:
			return false
	
	if abilities.size() >= MAX_ABILITY_SLOTS:
		return false
	var ability := InventoryAbility.new()
	ability.data = ability_data
	ability.cooldown = 0
	abilities.append(ability)
	return true

# Item/ability use methods
func use_item(index: int, combat_manager):
	var item = items[index]
	if item.data.use_effect:
		item.data.use_effect.call(combat_manager)
	
	item.amount -= 1
	if item.amount <= 0:
		items.remove_at(index)

func use_ability(index: int, combat_manager):
	var ability = abilities[index]
	if ability.cooldown > 0: # Does not allow ability to be used if it has a cooldown active
		return
	if ability.data.use_effect:
		ability.data.use_effect.call(combat_manager)
	ability.cooldown = ability.data.cooldown_max

func has_ability(id: String) -> bool:
	for ability in abilities:
		if ability.data.id == id:
			return true
	return false

func has_ability_from_entry(entry: ShopEntry) -> bool:
	if entry.type == ShopEntry.ItemType.ABILITY and entry.ability_data:
		return has_ability(entry.ability_data.id)
	return false

func get_active_abilities():
	return abilities.filter(func(a): return a.is_active())

func get_passives():
	return abilities.filter(func(a): return a.is_passive())
