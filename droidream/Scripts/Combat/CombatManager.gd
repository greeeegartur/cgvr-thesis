extends Node

# This class handles the entire combat system of Droidream
# I've tried to keep it as simple and well commented as possible, leaving in print statements for debugging (at least for now)

# -- HOW CAN THE PLAYER WIN? --
# The player can win battles in two ways, by either:
# 1. Defeating the enemy old-fashioned RPG style by attacking them (if enemy hp <= 0 -> player wins)
# 2. Lowering the enemy's defense <= 0 to play that enemy's minigame(s), increasing "snaps" on every win until the enemy is subdued

class_name CombatManager

@export var enemy_id := "enemy_beetle"

# The player and enemy's starting values
var player: CombatEntity
var enemy: CombatEntity
var turn := "player" # Player always starts first, this variable is a failsafe check condition in case turn logic goes wrong

# COMBAT SETUP FUNCTIONS
# These are functions that run before combat begins, i.e entity data and loading the first turn

# Prepares combat by loading entities (player and enemy(s)) and starting combat
func _ready():
	_setup_entities()
	_start_combat()

func _setup_entities():
	player = CombatEntity.new()
	player.load_from_player()
	add_child(player)
	get_parent().get_node("PlayerSprite").texture = load("res://Graphics/Placeholders/Combat/PlayerIdle.png")

	
	enemy = CombatEntity.new()
	enemy.load_from_enemy_id(enemy_id)
	add_child(enemy)
	get_parent().get_node("EnemySprite").texture = load("res://Graphics/Placeholders/Combat/Enemy.png")

func _start_combat():
	print("Combat started: PLAYER vs %s" % enemy.entity_name)
	_player_turn()

# TURN FUNCTIONS
# These functions play through the turn based combat logic based on entity actions

# Handles the player's turn
func _player_turn():
	turn = "player"
	# TO-DO Show buttons in UI, use corresponding action function to progress turn
	print("Player turn: choose ATTACK, ITEMS or RUN")


func _enemy_turn():
	turn = "enemy"
	print("Enemy attacks!")
	# TO-DO Enemy AI to identify possible moves
	
	# Picks a random pattern of the current enemy
	var pattern = enemy.attack_patterns.pick_random()
	_play_enemy_attack_pattern(pattern)
	# _enemy_attack() # For now – ideally I want enemy AIs to act in specific ways, not just attack all the time

func _end_combat(victory: bool):
	# Freeze turn logic (not necessary anymore)
	turn = ""

	if victory:
		# Player won, checks whether win is by kill or snaps
		if enemy.hp <= 0:
			print("Enemy defeated! Classic RPG victory.")
			# TO-DO Give rewards, XP
		else:
			print("Enemy subdued via minigames! Victory without killing.")
			# TO-DO Give rewards, XP
	else:
		# Player lost
		print("Player defeated! Game over.")
		# TO-DO Sprite animation here, right now defeated visual with cooldown of 1.5s
		_load_sprite_for_testing("defeated")
		
		# TO-DO: Implement fallback (retry, save and quit.)

	# TO-DO emit signal to UI or overworld
	# emit_signal("combat_ended", victory)


# ACTION FUNCTIONS
# These functions progress the turn in some way

# The player's attacking logic, takes the player's attack type as a parameter for damage calculation
func player_attack(attack_type: CombatTypes.EntityType):
	# If for some reason it is not the player's turn
	if turn != "player":
		print("Enemy turn in player_attack.")
		return

	# Checks player's attack type against enemy's type
	var type_multiplier := _get_type_multiplier(attack_type, enemy.type)
	print("It's the player's %s against the enemy's %s" % [CombatTypes.entity_type_to_string(attack_type), CombatTypes.entity_type_to_string(enemy.type)])
	
	# Reduce enemy defense if attacking type > defending type
	if enemy.defense > 0 and type_multiplier > 1.0:
		print("Effective type!")
		var defense_damage := player.attack_power * type_multiplier
		enemy.defense -= defense_damage
		print("Enemy defense reduced by %.2f → %.2f now" % [defense_damage, enemy.defense])
		
		# Checks if defense has been broken, minigame entering condition
		if enemy.defense <= 0:
			print("Enemy defense broken! Triggering minigame now.")
			_start_minigame(enemy.minigame_id)
		# If player loses... minigame's damage logic
		#	player.hp -= enemy.attack... in the future gear multiplier logic so player would take less damage
		#	enemy.defense = random value between 0.2-0.35 times initial max defense
		# else if player wins, increase enemy's snapped value
		#	if enemy's snapped == their max_snapped, then end combat
	else:
		# Regular damage to HP if attacking type !> enemy type
		var defense_factor = float(enemy.defense) / enemy.defense_max if enemy.defense_max > 0 else 0 # Calculates a defense multiplier based on current defense
		var damage = player.attack_power * type_multiplier * (1.0 - defense_factor)
		enemy.hp -= damage
		print("Enemy takes %.2f HP damage → %.2f left, current defense is %.2f" % [damage, enemy.hp, enemy.defense])
	
	# Empty print for visual clarity in terminal while debugging and TO-DO Animation, sprite set to attack with visual cooldown of 1.5s
	print("")
	_load_sprite_for_testing("attack")
	await get_tree().create_timer(1.5).timeout
	
	# Check if enemy defeated
	if enemy.hp <= 0:
		_end_combat(true) # 1. Classic RPG win: enemy defeated
	else:
		# Switch turn to enemy
		_enemy_turn()

func _start_minigame(minigame_id: String):
	# ... TO-DO minigame appears on screen
	var is_success: bool # TO-DO make the minigame's result carry over to a bool value. separate for each minigame?
	
	# If successful win in minigame
	is_success = true
	# Else
	is_success = false
	
	on_minigame_complete(is_success)
	
func on_minigame_complete(success: bool):
	if success:
		enemy.snapped += 1
		print("Minigame success! Snapped: %d / %d" % [enemy.snapped, enemy.snapped_max])
		if enemy.snapped >= enemy.snapped_max:
			_end_combat(true)  # 2. Minigame win: enemy subdued 
	else:
		# When failed, restore enemy's defense by a random amount from 20-35%
		var restore_ratio := randf_range(0.2, 0.35)
		enemy.defense = enemy.defense_max * restore_ratio
		# Also deal damage to player
		player.hp -= enemy.attack_power # TO-DO Adjust for player gear reducing damage in the future
		print("Minigame failed. Enemy defense restored to %.1f" % enemy.defense)

func _play_enemy_attack_pattern(pattern: EnemyAttackPattern):
	print("Enemy uses attack pattern:", pattern.pattern_id)

	var elapsed := 0.0
	var hit_index := 0

	# TO-DO Be driven by AnimationPlayer
	while elapsed < pattern.total_duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

		# Hit processing logic
		if hit_index < pattern.hits.size(): # Checks for how many times the attack will hit, also is a failsafe for checking if the pattern is valid/exists at all
			var hit := pattern.hits[hit_index]
			if elapsed >= hit.time:
				# Works the attack's hitting logic, including the player's blocking window
				_apply_enemy_hit(hit)
				hit_index += 1 # If the attack has multiple hits, it'll process all of them

	# End of attack
	if player.hp <= 0:
		_end_combat(false)
	else:
		_player_turn()


# Logic for applying an enemy attack's damage
func _apply_enemy_hit(hit: Dictionary):
	var base_damage := enemy.attack_power
	var hit_mult = hit.damage_multiplier
	
	# TO-DO Check if "- player.defense" is fair, maybe multiplier based negation is better
	var damage = max(0, base_damage * hit_mult - player.defense)
	var block_window: Vector2 = hit.block_window
	
	# Checks if the player blocked the attack
	var blocked = _check_player_block(block_window)
	
	if blocked:
		damage *= 0.5
		print("Blocked! Damage reduced.")
		
	player.hp -= damage
	print("Player takes %.1f damage → HP %.1f" % [damage, player.hp])
	
# Logic for checking if the player has blocked an enemy attack
func _check_player_block(window: Vector2) -> bool:
	# window.x = block start time
	# window.y = block end time

	# TO-DO:
	# - Show UI prompt
	# - Listen for input
	# - Check if input happened within window

	return false

	
# The enemy's attacking logic, doesn't take any parameters as the player is not affected by type attacks
func _enemy_attack():
	# If for some reason it is not the player's turn
	if turn != "enemy":
		print("Player turn in enemy_attack.")
		return
		
	print("%s attacks!" % enemy.entity_name)
	
	# Enemy's initial attack power
	var damage := enemy.attack_power
	
	# TO-DO Attack animation and timing here
	
	# TO-DO Blocking logic for the player during enemy attack animation
	# This will be replaced with actual timing-based blocking like in Paper Mario
	var player_blocked := false

	if player_blocked:
		# Upon successful block, enemy damage is reduced by half
		
		# TO-DO Sprite animation here, right now block visual with cooldown of 1.5s
		_load_sprite_for_testing("block")
		
		# Damage calculation, i.e if damage is an uneven number like 5, blocked damage will be 2 -> creates incentive to block
		damage = floor(damage * 0.5)
		print("Player BLOCKED! Damage reduced to %.1f." % damage)
	else:
		print("Player failed to block. Taking full damage of %1.f." % damage)

	player.hp -= damage
	print("Player HP: %.1f" % player.hp)
	print("")
	
	# TO-DO Sprite animation here, right now damaged visual with cooldown of 1.5s
	_load_sprite_for_testing("damaged")

	# Check if player has been defeated at the end of the turn
	if player.hp <= 0:
		_end_combat(false)
		return

	# Switch back to player's turn
	_player_turn()
	

# HELPER FUNCTIONS
# These functions help ACTION functions with calculations and more

# Calculates the damage multiplier based on the player's attacking type and the entity's type
# It follows the logic of rock-paper-scissors in the order of flying-grounded-special
# Effective moves give a 2.0 multiplier while anything else is 1.0
func _get_type_multiplier(player_type: CombatTypes.EntityType, enemy_type: CombatTypes.EntityType) -> float:
	if player_type == CombatTypes.EntityType.FLYING and enemy_type == CombatTypes.EntityType.GROUNDED:
		return 2.0
	elif player_type == CombatTypes.EntityType.GROUNDED and enemy_type == CombatTypes.EntityType.SPECIAL:
		return 2.0
	elif player_type == CombatTypes.EntityType.SPECIAL and enemy_type == CombatTypes.EntityType.FLYING:
		return 2.0
	else:
		return 1.0  # Normal damage multiplier

# For testing purposes to check if sprites are loaded properly
func _load_sprite_for_testing(sprite: String):
	if (sprite == "attack"):
		get_parent().get_node("PlayerSprite").texture = load("res://Graphics/Placeholders/Combat/PlayerAttacked.png")
	elif (sprite == "block"):
		get_parent().get_node("PlayerSprite").texture = load("res://Graphics/Placeholders/Combat/PlayerBlocked.png")
	elif (sprite == "damaged"):
		get_parent().get_node("PlayerSprite").texture = load("res://Graphics/Placeholders/Combat/PlayerDamaged.png")
	elif (sprite == "defeated"):
		get_parent().get_node("PlayerSprite").texture = load("res://Graphics/Placeholders/Combat/PlayerDefeated.png")
	await get_tree().create_timer(1.5).timeout
	get_parent().get_node("PlayerSprite").texture = load("res://Graphics/Placeholders/Combat/PlayerIdle.png")
