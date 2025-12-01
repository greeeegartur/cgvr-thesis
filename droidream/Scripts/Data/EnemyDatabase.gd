extends Node

# Global script that holds all necessary enemy info as dictionary entries.

# FORMAT FOR ADDING ENTRIES
# Key: string like "monkey1", "monkey_basic" etc.
# Value: list of dictionaries with following values:
#	name: string, full name of enemy, like "Jungle Monkey"
#	type: either grounded, flying or special
#	max_hp: enemy's max HP value
#	attack: enemy's attack power, used for calculating damage to the player
#	defense: enemy's defense that negates/reduces damage taken, can be reduced
#	snapped_max: max number of "snaps" for minigame victory condition, meaning how many minigame wins needed for victory
#	minigame_id: id for loading enemy's specific minigame


# List of enemies in the format {string: list[dictionary]}, where the list holds dictionary values
var ENEMIES := {
	"enemy_beetle": {
		"name": "Giant Beetle",
		"type": CombatTypes.EntityType.GROUNDED,
		"max_hp": 7,
		"attack": 1,
		"defense": 10,
		"snapped_max": 1,
		"minigame_id": "beetle_rush"
	}
}

func get_enemy(id: String) -> Dictionary:
	if not ENEMIES.has(id):
		push_warning("Enemy ID not found: %s" % id)
		return {}
	return ENEMIES[id]
