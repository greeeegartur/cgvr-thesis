extends Node

# This class handles the entire combat system of Droidream
# I've tried to keep it as simple and well commented as possible, leaving in print statements for debugging (at least for now)

# -- HOW CAN THE PLAYER WIN? --
# The player can win battles in two ways, by either:
# 1. Defeating the enemy old-fashioned RPG style by attacking them (if enemy hp <= 0 -> player wins)
# 2. Lowering the enemy's defense <= 0 to play that enemy's minigame(s), increasing "snaps" on every win until the enemy is subdued

class_name CombatManager

# SCRIPT VARIABLES
@export var enemy_id = "enemy_beetle"

# The player and enemy's starting values
var player : CombatEntity
var enemy : CombatEntity
var turn = "player" # Player always starts first, this variable is a failsafe check condition in case turn logic goes wrong

# Signals for UI script to react
signal player_turn_started 
signal enemy_turn_started
signal combat_end

# Attack time trackers for player blocking and critical hits
var attack_time = 0.0
var attack_timer_running = false
var critical_window = Vector2.ZERO
var last_attack_press_time = -1.0

# Player block window variables for handling blocking logic
var last_block_press_time = -1.0
var current_block_window = Vector2.ZERO
var block_on_cooldown = false
const BLOCK_COOLDOWN = 0.7

# Entity visual scenes to load for animations and UI
var enemy_visual : EnemyVisual
var player_visual : PlayerVisual

# Minigame variables
var in_minigame = false # Default
var MINIGAME_SCENES = {
	"base": preload("res://Scenes/Minigames/BaseMinigame.tscn")
}

# COMBAT SETUP FUNCTIONS
# These are functions that run before combat begins, i.e entity data and loading the first turn

# Prepares combat by loading entities (player and enemy(s)) and starting combat
func _ready():
	set_process_input(true)
	_setup_entities()
	_start_combat()
	# Combat scene's process mode (pausing) for minigames
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta):
	# Pauses combat logic
	if in_minigame:
		return
	
	if attack_timer_running:
		attack_time += delta

# Sets up the player and enemy(s) battle data
func _setup_entities():
	# PLAYER
	player = CombatEntity.new()
	player.load_from_player()
	player_visual = get_parent().get_node("PlayerVisual")
	player_visual.action_pressed.connect(_on_player_action_pressed)
	add_child(player)
	get_parent().get_node("PlayerSprite").texture = load("res://Graphics/Placeholders/Combat/PlayerIdle.png")
	
	player_visual.position = Vector2(96, 271)
	player_visual.set_home_position()
	
	# Player UI setup
	await player_visual.ready
	player_visual.update_hp(player.hp, player.max_hp)
	player_visual.update_defense(player.defense, player.defense)
	
	# ENEMY
	enemy = CombatEntity.new()
	enemy.load_from_enemy_id(enemy_id)
	add_child(enemy)
	enemy_visual = enemy.visual_scene.instantiate()
	get_parent().add_child.call_deferred(enemy_visual)
	
	# Enemy UI setup
	await enemy_visual.ready
	enemy_visual.update_hp(enemy.hp, enemy.max_hp)
	enemy_visual.update_defense(enemy.defense, enemy.defense_max)
	enemy_visual.update_snapped(enemy.snapped, enemy.snapped_max)
	
	# TO-DO Adjust this automatically somehow (later will add multiple enemies at once so it can't just be set like so)
	enemy_visual.position = Vector2(524, 272)
	enemy_visual.set_home_position()
	
	
func _start_combat():
	_player_turn()

# TURN FUNCTIONS
# These functions play through the turn based combat logic based on entity actions

# Handles the player's turn
func _player_turn():
	turn = "player"
	emit_signal("player_turn_started")
	# TO-DO Show buttons in UI, use corresponding action function to progress turn
	print("Player turn: choose ATTACK, ITEMS or RUN")


func _enemy_turn():
	turn = "enemy"
	emit_signal("enemy_turn_started")
	print("Enemy attacks!")
	# TO-DO Enemy AI to identify possible moves
	
	last_block_press_time = -1.0
	block_on_cooldown = false
	
	# Picks a random pattern of the current enemy
	var pattern = enemy.attack_patterns.pick_random()
	_play_enemy_attack_pattern(pattern)
	# _enemy_attack() # For now – ideally I want enemy AIs to act in specific ways, not just attack all the time
	
	# For now tutorial text
	# TO-DO: remove/tweak this
	$"../UI/TempIndicator".visible = false

func _end_combat(victory: bool):
	# Freeze turn logic (not necessary anymore but keeping just in case)
	turn = ""
	
	# TO-DO: make specific for victory/defeat (separate methods in CombatUI might be easiest)
	combat_end.emit()

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
		player_visual.play_defeat()
		
		# TO-DO: Implement fallback (retry, save and quit.)
	
	# emit_signal("combat_ended", victory)


# ACTION FUNCTIONS
# These functions progress the turn in some way

# The player's attacking logic, takes the player's attack type as a parameter for damage calculation
func player_attack(attack_type: CombatTypes.EntityType):
	# If for some reason it is not the player's turn
	if turn != "player":
		print("Enemy turn in player_attack.")
		return
	
	player_visual.set_input_enabled(true)
	
	# Communication with PlayerVisual to calculate hit damage (check for critical hits) and play attack animations
	player_visual.attack_started.connect(
		func():
			# Opens the critical window for the player to hit the opponent for additional damage
			_start_player_critical_window(),
		CONNECT_ONE_SHOT
	)
	
	player_visual.attack_hit.connect(
		func():
			# Calculates the hit damage
			_apply_player_attack_hit(attack_type),
		CONNECT_ONE_SHOT
	)
	
	# End of the turn
	player_visual.attack_finished.connect(
		func():
			# Check if enemy defeated
			if enemy.hp <= 0:
				_end_combat(true) # 1. Classic RPG win: enemy defeated
			else:
				# Else switch turn to enemy
				_enemy_turn(),
		CONNECT_ONE_SHOT
	)
	
	player_visual.play_attack()
	
	# Empty print for visual clarity in terminal while debugging
	print("")

# Opens the player critical hit window during player's atack
func _start_player_critical_window():
	last_attack_press_time = -1.0
	critical_window = Vector2(1.80, 2.05) # TO-DO: tweak this for good hit feel
	attack_time = 0.0
	attack_timer_running = true

# Processes the player hit damage by checking for critical hits and applying necessary damage to either HP or defense
func _apply_player_attack_hit(attack_type):
	attack_timer_running = false
	
	var critical = (
		last_attack_press_time >= critical_window.x
		and last_attack_press_time <= critical_window.y
	)
	
	var critical_multiplier = 1.5 if critical else 1.0
	if critical:
		print("CRITICAL HIT!")
	
	# Checks player's attack type against enemy's type
	var type_multiplier := _get_type_multiplier(attack_type, enemy.type)
	
	# Reduce enemy defense if attacking type > defending type
	if enemy.defense > 0 and type_multiplier > 1.0:
		print("Effective type!")
		var defense_damage = player.attack_power * type_multiplier * critical_multiplier
		enemy.defense -= defense_damage
		enemy_visual.update_defense(enemy.defense, enemy.defense_max)
		enemy_visual.play_damage_vfx(defense_damage, critical)
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
		var defense_factor = float(enemy.defense) / enemy.defense_max if enemy.defense_max > 0 else 0 # Calculates a defense multiplier (how much damage is negated) based on current defense
		var damage = player.attack_power * type_multiplier * critical_multiplier * (1.0 - defense_factor)
		enemy.hp -= damage
		enemy_visual.update_hp(enemy.hp, enemy.max_hp)
		enemy_visual.play_damage_vfx(damage, critical)
		print("Enemy takes %.2f HP damage → %.2f left, current defense is %.2f" % [damage, enemy.hp, enemy.defense])

# Logic for starting enemy's minigame in combat
func _start_minigame(minigame_id: String):
	if not MINIGAME_SCENES.has(minigame_id):
		push_error("Missing minigame: " + minigame_id)
		return
		
	in_minigame = true
	
	# Subduing visuals
	enemy_visual.play_subdue_vfx()
	await player_visual.play_subdue()
	
	# Pausing all combat (turn) logic
	get_tree().paused = true
	
	# Minigame scene instantiation
	var minigame = MINIGAME_SCENES[minigame_id].instantiate()
	get_parent().add_child(minigame)
	minigame.global_position = Vector2(320, 190)
	
	minigame.completed.connect(
		func(success):
			# Minigame ease in transition
			get_tree().paused = false # Process mode state already set in BaseMinigame.gd, but just in case
			in_minigame = false
			on_minigame_complete(success)
			await player_visual.return_to_home()
			_enemy_turn(),
		CONNECT_ONE_SHOT
	)
	
	await minigame.play()

# Decides minigame outcome on minigame end
func on_minigame_complete(success: bool):
	if success:
		var restore_ratio := randf_range(0.2, 0.35)
		enemy.defense = enemy.defense_max * restore_ratio
		enemy_visual.update_defense(enemy.defense, enemy.defense_max)
		enemy.snapped += 1
		enemy_visual.update_snapped(enemy.snapped, enemy.snapped_max)
		print("Minigame success! Snapped: %d / %d" % [enemy.snapped, enemy.snapped_max])
		if enemy.snapped >= enemy.snapped_max:
			_end_combat(true)  # 2. Minigame win: enemy subdued 
	else:
		# Restore enemy's defense by a random amount from 20-35%
		var restore_ratio := randf_range(0.2, 0.35)
		enemy.defense = enemy.defense_max * restore_ratio
		enemy_visual.update_defense(enemy.defense, enemy.defense_max)
		# Also deal damage to player
		# player.hp -= enemy.attack_power # TO-DO Make minigame specific and take into account defense
		print("Minigame failed. Enemy defense restored to %.1f" % enemy.defense)

# Plays the given enemy attack pattern during the enemy turn
# TO-DO: make enemy-specific so a specific enemy performs the attack (when multiple enemies are added into combat)
func _play_enemy_attack_pattern(pattern: EnemyAttackPattern):
	print("Enemy uses attack pattern:", pattern.pattern_id)
	var hit_index := 0
	
	# Set current block window
	current_block_window = pattern.hits[0].block_window
	
	# Blocking, so setting up PlayerVisual for blocking
	player_visual.set_input_enabled(true)
	
	# Lambda functions for connecting with enemy visual script emitters
	enemy_visual.attack_started.connect(
		# Marks start of the attacking animation for block timing
		func():
			attack_time = 0.0
			attack_timer_running = true
			print("!!! DEBUG: attack timer started"),
		CONNECT_ONE_SHOT
		)
	
	enemy_visual.attack_hit.connect(
		# Hit processing logic
		func():
			if hit_index < pattern.hits.size():
				# Works the attack's hitting logic, including the player's blocking window
				_apply_enemy_hit(pattern.hits[hit_index])
				hit_index += 1, # If the attack has multiple hits, it'll process all of them
		CONNECT_ONE_SHOT
		)
	
	# Checks if combat has ended
	enemy_visual.attack_finished.connect(
		func():
			# DEBUG WHEN ATTACK HAS FINISHED
			attack_timer_running = false
			print("!!! DEBUG: attack finished at:", "%.3f" % attack_time)
			
			if player.hp <= 0:
				_end_combat(false)
			else:
				_player_turn(),
		CONNECT_ONE_SHOT
		)
	
	enemy_visual.play_attack(pattern.animation_name)
	$"../UI/TempIndicator".visible = false


# Logic for applying an enemy attack's damage that takes the enemy's attack pattern for blocking into consideration
func _apply_enemy_hit(hit: Dictionary):
	current_block_window = hit.block_window
	print("!!! DEBUG: last block press time: ", last_block_press_time)
	
	# Attack pattern duration and timer, listens to _on_player_block_atempted here to check for block and calculates damage after
	var window_duration = hit.block_window.y - hit.block_window.x
	# Block can happen during this timer, calculates the enemy's damage
	get_tree().create_timer(window_duration).timeout.connect(
		func():
			_resolve_enemy_hit(hit),
		CONNECT_ONE_SHOT
	)

# Finalises the enemy hit after player blocks during the enemy turn
func _resolve_enemy_hit(hit: Dictionary):
	var window_start = hit.block_window.x
	var window_end = hit.block_window.y
	
	var blocked = (
		last_block_press_time >= window_start
		and last_block_press_time <= window_end
	)
	
	var base_damage = enemy.attack_power
	var hit_mult = hit.damage_multiplier
	# TO-DO Check if "- player.defense" is fair, maybe multiplier based negation is better
	var damage = max(0.0, base_damage * hit_mult - player.defense)
	
	if blocked:
		damage *= 0.5
		player_visual.play_block_success()
		print("Successful block!")
	else:
		player_visual.play_block_fail()
		print("Failed block")

	print("Player HP is: ", player.hp)
	print("Damage is: ", damage)

	player.hp -= damage
	player_visual.update_hp(player.hp, player.max_hp)
	player_visual.play_damage_number(damage)
	print("Player takes %.1f damage → HP %.1f" % [damage, player.hp])
	
	last_block_press_time = -1.0


# UNUSED, but keeping as reference
# Logic for checking if the player has blocked an enemy attack, here "window" is the block_window parameter of an enemy (time frame when the block registers)
# func _check_player_block(window: Vector2):
	# Here:
	# window.x = start time
	# window.y = end time
	
# Block variables reset, block window opens
	#block_success = false
	#block_window_open = true
#
	## Waits until the window is open
	#await get_tree().create_timer(window.x).timeout
	#
	## Block must happen between these two lines (_input must be triggered here)
	#
	## Close window after block window is finished
	#await get_tree().create_timer(window.y - window.x).timeout
	#block_window_open = false

	# return block_success

# Listens for player attack presses for critical hit logic
func _on_player_attack_pressed():
	# Failsafe to check if the function is running by accident
	if turn != "player":
		return
	last_attack_press_time = attack_time

# Listens for player block during an enemy's attack
func _on_player_block_attempted():
	# Failsafe to check if the function is running by accident
	if turn != "enemy":
		return
	
	# Checks if block is currently on cooldown
	if block_on_cooldown:
		return
	
	# Records block press time
	last_block_press_time = attack_time
	
	# DEBUG CHECK
	print("!!! DEBUG: Block pressed at:", "%.3f" % attack_time)
	
	# If all previous checks passed then block was triggered -> cooldown starts here
	_start_block_cooldown()

# Decides if action is player block or critical hit
func _on_player_action_pressed():
	# Does not allow combat actions in minigames, only minigame centered logic handled by another script
	if in_minigame:
		return
	if turn == "enemy":
		_on_player_block_attempted()
	elif turn == "player":
		_on_player_attack_pressed()

# Starts the player's block cooldown during the enemy turn
func _start_block_cooldown():
	block_on_cooldown = true
	player_visual.set_block_cooldown(true)
	
	# Actual cooldown timer
	await get_tree().create_timer(BLOCK_COOLDOWN).timeout
	
	# After cooldown resets previous changes
	block_on_cooldown = false
	player_visual.set_block_cooldown(false)

# LEGACY (not used): The enemy's attacking logic, doesn't take any parameters as the player is not affected by type attacks
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
		
		
		# Damage calculation, i.e if damage is an uneven number like 5, blocked damage will be 2 -> creates incentive to block
		damage = floor(damage * 0.5)
		print("Player BLOCKED! Damage reduced to %.1f." % damage)
	else:
		print("Player failed to block. Taking full damage of %1.f." % damage)
	
	player.hp -= damage
	print("Player HP: %.1f" % player.hp)
	print("")
	
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
