extends Node

# Global script that loads all enemy info from Data folder resources

# FORMAT FOR ENEMY INFO
# Key: string like "monkey1", "monkey_basic" etc.
# Value: list of dictionaries with following values:
#	name: string, full name of enemy, like "Jungle Monkey"
#	type: either grounded, flying or special
#	max_hp: enemy's max HP value
#	attack: enemy's attack power, used for calculating damage to the player
#	defense: enemy's defense that negates/reduces damage taken, can be reduced
#	trust_max: max number of "trusts" for minigame victory condition, meaning how many minigame wins needed for victory
#	minigame_id: id for loading enemy's specific minigame
#	attack_patterns: all attack patterns for the enemy, more details in EnemyAttackPattern.gd
#	visual_scene: enemy's scene with its visuals and animations

# Data folder that contains resources of all enemies
var FOLDER = "res://Scripts/Data/Enemies/"

# List of enemies that gets filled by Data folder resources
var ENEMIES : Dictionary

# List of all enemy minigames
var MINIGAME_SCENES = {
	"base": preload("res://Scenes/Minigames/BaseMinigame.tscn"), # Default, only for testing
	"beetle_rush": preload("res://Scenes/Minigames/BeetleRush/BeetleRush.tscn"),
	"bat_flash": preload("res://Scenes/Minigames/BatFlash/BatFlash.tscn"),
	"frog_guess": preload("res://Scenes/Minigames/FrogGuess/FrogGuess.tscn"),
	"duck_flap": preload("res://Scenes/Minigames/DuckFlap/DuckFlap.tscn"),
	"tutorial": preload("res://Scenes/Minigames/Tutorial/Tutorial.tscn")
}

# List of all enemy specific attributes that don't fit into their resources
const DATA = {
	"beetle": {
		"attack_offset": Vector2(92.3, 3),
		"move_speed": 240.0,
		"drop_item_ids": ["beetlejuice", "ball", "soft_branch"]
	},
	"bat": {
		"attack_offset": Vector2(95, 0),
		"move_speed": 280.0,
		"drop_item_ids": ["hypno_bone", "soft_branch", "memory_chip"]
	},
	"frog": {
		"attack_offset": Vector2(98.6, 0),
		"move_speed": 200.0,
		"drop_item_ids": ["thick_jelly", "ice_cube", "ball"]
	},
	"duck": {
		"attack_offset": Vector2(109.85, 5),
		"move_speed": 260.0,
		"drop_item_ids": ["soft_branch", "memory_chip", "ball", "ice_cube"]
	},
	"dummy": {
		"attack_offset": Vector2(0, 0),
		"move_speed": 0.0,
		"drop_item_ids": []
	}
}

func _ready():
	_load_enemy_resources()

# Method that loads all enemies from the Data folder path on game startup
func _load_enemy_resources():
	ENEMIES.clear()
	
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		push_error("Enemy folder not found: %s" % FOLDER)
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var resource_file := _get_resource_file_name(file_name)
			if resource_file != "":
				var path : String = FOLDER + resource_file
				var enemy = load(path)
				
				# Checks correct type
				if enemy is EnemyInfo:
					ENEMIES[enemy.enemy_id] = enemy
					_warn_if_off_grid(enemy, path)
				else:
					push_warning("Not an EnemyInfo resource: %s" % path)

		file_name = dir.get_next()
		
	dir.list_dir_end()

# Dev-time check: enemy HP, attack and the damage of every hit (unblocked and blocked) should sit on the quarter grid
func _warn_if_off_grid(enemy: EnemyInfo, path: String):
	if not OS.is_debug_build():
		return
	
	var values := {"max_hp": enemy.max_hp, "attack": float(enemy.attack)}
	for pattern in enemy.attack_patterns:
		for hit in pattern.hits:
			var damage: float = enemy.attack * hit.damage_multiplier
			values["%s hit" % pattern.pattern_id] = damage
			values["%s blocked hit" % pattern.pattern_id] = damage * 0.5
	
	for label in values:
		var value: float = values[label]
		if not is_equal_approx(value, Utils.quantize(value)):
			push_warning("Off the 0.25 grid: %s on %s is %s" % [label, path, value])

func _get_resource_file_name(file_name: String) -> String:
	if file_name.ends_with(".tres"):
		return file_name
	if file_name.ends_with(".tres.remap"):
		return file_name.trim_suffix(".remap")
	return ""


func get_enemy(id: String):
	if not ENEMIES.has(id):
		push_warning("Enemy ID not found: %s" % id)
		return {}
	return ENEMIES[id]

func get_attack_offset(enemy_id: String) -> Vector2:
	return DATA[enemy_id].attack_offset

func get_move_speed(enemy_id: String) -> float:
	return DATA[enemy_id].move_speed

func get_drop_item_ids(enemy_id: String):
	return DATA[enemy_id].drop_item_ids
