extends Node

# This script is for storing and updating all player data, including functions to do so

# Base player variables (for reseting)
const BASE_MAX_HP := 10.0
const BASE_ATTACK := 5.0
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

# Ending trackers for creatures and the player
var killed_creatures: Array[String] = []
var tamed_creatures: Array[String] = []
var karma := 0
const KARMA_THRESHOLDS := [15, 25, 40, 50, 60, 75]

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
	killed_creatures.clear()
	tamed_creatures.clear()
	
	# 1 ball to start the run
	#add_item(CombatItemDb.get_item("ball"))

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
			if item.amount >= item_data.max_stack:
				return false
			
			item.amount = min(item.amount + amount, item_data.max_stack)
			return true
	
	# If the player gains a new item
	if items.size() >= MAX_ITEM_TYPES: # Checks if the player's inventory is full
		return false
	
	var new_item := InventoryItem.new()
	new_item.data = item_data
	new_item.amount = min(amount, item_data.max_stack)
	items.append(new_item)
	return true

func add_ability(ability_data: Resource) -> bool: # Ability or passive
	if not (ability_data is AbilityData or ability_data is PassiveData):
		push_error("Tried to add invalid ability resource.")
		return false
	
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

func get_combat_items() -> Array[InventoryItem]:
	return items

func has_item(id: String) -> bool:
	for item in items:
		if item.data.id == id:
			return true
	return false

# ENDING / KARMA SPECIFIC METHODS
func record_killed_creature(enemy_id: String):
	if enemy_id in tamed_creatures:
		tamed_creatures.erase(enemy_id)
	if enemy_id not in killed_creatures:
		killed_creatures.append(enemy_id)

func record_tamed_creature(enemy_id: String):
	# Kills take priority, so won't be added if a creature has been killed previously
	if enemy_id in killed_creatures:
		return
	if enemy_id not in tamed_creatures:
		tamed_creatures.append(enemy_id)

func get_karma_stage() -> int:
	var stage := 0
	for threshold in KARMA_THRESHOLDS:
		if karma >= threshold:
			stage += 1
	return stage

func get_enemy_crit_chance() -> float:
	match get_karma_stage():
		0:
			return 0.0
		1:
			return 0.05
		2:
			return 0.10
		3:
			return 0.20
		4:
			return 0.30
		5:
			return 0.40
		6:
			return 0.50
	return 0.0

func get_shop_price_increase() -> int:
	match get_karma_stage():
		0, 1:
			return 0
		2:
			return 2
		3:
			return 3
		4:
			return 5
		5:
			return 7
		6:
			return 10
	return 0

func get_karma_overlay_alpha() -> float:
	match get_karma_stage():
		0:
			return 0.0
		1:
			return 0.05
		2:
			return 0.10
		3:
			return 0.16
		4:
			return 0.22
		5:
			return 0.26
		6:
			return 0.30
	return 0.0

func get_total_killed_count() -> int:
	return killed_creatures.size()

func get_total_tamed_count() -> int:
	return tamed_creatures.size()

func get_ending_type() -> String:
	var killed := get_total_killed_count()
	var tamed := get_total_tamed_count()
	
	if killed > 0 and tamed == 0:
		return "genocide"
	if tamed > 0 and killed == 0:
		return "pacifist"
	if killed > 0 and tamed > 0:
		return "neutral"
	return "?" # Should not happen

func has_max_abilities() -> bool:
	return abilities.size() >= MAX_ABILITY_SLOTS

func has_max_item_types() -> bool:
	return items.size() >= MAX_ITEM_TYPES

func is_item_stack_full(item_data: ItemData) -> bool:
	for item in items:
		if item.data == item_data:
			return item.amount >= item_data.max_stack
	return false

func can_add_item(item_data: ItemData, amount := 1) -> bool:
	# Existing stack can still grow
	for item in items:
		if item.data == item_data:
			return item.amount < item_data.max_stack
	
	return items.size() < MAX_ITEM_TYPES

func can_add_ability_resource(ability_data: Resource) -> bool:
	if not (ability_data is AbilityData or ability_data is PassiveData):
		return false
	
	for a in abilities:
		if a.data == ability_data:
			return false
	
	return abilities.size() < MAX_ABILITY_SLOTS

func add_currency(amount: int) -> void:
	currency += amount
	stats_changed.emit()

func spend_currency(amount: int) -> bool:
	if currency < amount:
		return false
	
	currency -= amount
	stats_changed.emit()
	return true
