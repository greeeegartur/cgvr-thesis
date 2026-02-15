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

# Actual adjustable player variables (can change for the player)
var max_hp : float
var hp : float
var attack : float
var defense : float
@export var guesses := { } # Amount of guesses for each type

var currency := 0
var experience := 0
# For later...
var karma := 0

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
	experience = 0
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
