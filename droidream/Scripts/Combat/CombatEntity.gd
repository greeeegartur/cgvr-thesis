extends Node
class_name CombatEntity

# This script is for handling entity data in combat, such as the player and enemy(s)

# Initial values for loading enemies
var entity_name := ""
var is_player := false
var max_hp := 0
var hp := 0
var attack_power := 0
var defense_max := 0
var defense := 0
var snapped_max := 1
var snapped := 0
var attack_patterns : Array[EnemyAttackPattern]
var visual_scene : PackedScene
var type : CombatTypes.EntityType # can be "GROUNDED", "FLYING" and "SPECIAL", never "PLAYER"
var minigame_id := ""

# Loads enemy info for entity via enemy_id string
# enemy_id string must be present on an enemy resource in the Data folder
func load_from_enemy_id(enemy_id: String) -> void:
	var data = EnemyDatabase.get_enemy(enemy_id)

	entity_name = data.name
	type = data.type
	hp = data.max_hp
	attack_power = data.attack
	defense_max = data.defense
	defense = defense_max
	snapped_max = data.snapped_max
	minigame_id = data.minigame_id
	attack_patterns = data.attack_patterns
	visual_scene = data.visual_scene

#Loads player data from PlayerData object
func load_from_player() -> void:
	is_player = true
	max_hp = PlayerData.max_hp
	hp = PlayerData.hp
	attack_power = PlayerData.attack
	defense = PlayerData.defense
