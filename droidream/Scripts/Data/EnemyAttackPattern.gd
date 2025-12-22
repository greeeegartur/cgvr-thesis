extends Resource

# This script is for defining initial enemy attack pattern data (will change respectively with each enemy)

class_name EnemyAttackPattern

# Unique for each attack
@export var pattern_id: String

# Initial animation variables
@export var animation_name: String = ""
@export var total_duration: float = 1.0

# Pattern's attack logic, can happen multiple times and is stored as dictionary entries with the following structure:
# {
#   "time": float,
#   "damage_multiplier": float,
#   "block_window": Vector2(start_time, end_time)
# }
#
# time – when the hit happens (seconds since start)
# damage_multiplier - damage multiplier for the attack(s)
# block_window - any interval between "time", shows when the player can block the hit
@export var hits: Array[Dictionary] = []
