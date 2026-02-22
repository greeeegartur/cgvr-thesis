extends Node
class_name CombatEntity

# This script is for handling entity data in combat, such as the player and enemy(s)

# Initial values for loading enemies
var entity_name := ""
var is_player := false # Possibly will use
var max_hp := 0.0
var hp := 0.0
var attack_power := 0.0
var defense := 0.0
var trust_max := 1
var trust := 0
var axis_value := 0.0 # New axis that has a value between {-axis_max; axis_max}
var axis_max := 1.0 # axis_max = tamed, while -axis_max = killed
var attack_patterns : Array[EnemyAttackPattern]
var visual_scene : PackedScene
var type : CombatTypes.EntityType # can be "Sky", "Earth" and "Water"
var minigame_id := ""

# Specific enemy variables
var spawned := false
var can_spawn := true


# Loads enemy info for entity via enemy_id string
# enemy_id string must be present on an enemy resource in the Data folder
func load_from_enemy_id(enemy_id: String) -> void:
	var data = EnemyDatabase.get_enemy(enemy_id)

	entity_name = data.name
	type = data.type
	max_hp = data.max_hp
	hp = max_hp # For some reason have to set this or else enemies break
	axis_max = max_hp
	attack_power = data.attack
	trust_max = data.trust_max
	minigame_id = data.minigame_id
	attack_patterns = data.attack_patterns
	visual_scene = data.visual_scene
	spawned = false
	can_spawn = true


# Loads player data from PlayerData object
func load_from_player() -> void:
	is_player = true
	max_hp = PlayerData.max_hp
	hp = PlayerData.hp
	attack_power = PlayerData.attack
	defense = PlayerData.defense

# Methods for checking enemy defeat conditions and axis ratio
func is_killed() -> bool:
	return axis_value <= -axis_max

func is_minigame_ready() -> bool:
	return axis_value >= axis_max

func is_tamed() -> bool:
	return trust >= trust_max

func axis_ratio() -> float:
	return axis_value / axis_max # Range is from -1.0 to 1.0
