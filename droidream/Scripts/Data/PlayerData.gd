extends Node

# This script is for storing and updating all player data, including functions to do so

# Base player variables (self-explanatory)
var max_hp : float = 10.0
var hp : float = 10.0
var attack : float = 4.0
var defense : float = 0.0
@export var guesses := { # Amount of guesses for each type
	CombatTypes.EntityType.SKY: 3,
	CombatTypes.EntityType.EARTH: 3,
	CombatTypes.EntityType.WATER: 3
}

var currency := 0
var experience := 0
# For later...
var karma := 0

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
