extends Node

# This class handles the entire combat system of Droidream
# I've tried to keep it as simple and well commented as possible, leaving in print statements for debugging (at least for now)

# -- HOW CAN THE PLAYER WIN? --
# The player can win battles in two ways, by either:
# 1. Defeating the enemy old-fashioned RPG style by attacking them (if enemy hp <= 0 -> player wins)
# 2. Lowering the enemy's defense <= 0 to play that enemy's minigame(s), increasing "snaps" on every win until the enemy is subdued

class_name CombatManager

# SCRIPT VARIABLES

# Exported variables
# TO-DO: change this to load on random depending on area
@export var enemy_ids: Array[String] = ["enemy_beetle", "enemy_beetle"] # Can not exceed 3

# Nodes to use for visual effects in the combat scene
@onready var camera : CombatCamera = get_parent().get_node("Camera2D")
@onready var tutorial_text: TutorialText = get_parent().get_node("UI/TutorialText")
@onready var minigame_layer = get_parent().get_node("Minigames")
@onready var vfx: VFXCombatManager = get_parent().get_node("VFX/VFXCombatManager")
@onready var enemy_positions := [
	get_parent().get_node("World/EnemyPosition1"),
	get_parent().get_node("World/EnemyPosition2"),
	get_parent().get_node("World/EnemyPosition3")
]

# The player and enemy's starting values
var player : CombatEntity
var enemies: Array[CombatEntity] = [] # Initially empty, TO-DO: make this load area-specific
var turn = "player" # Player always starts first, this variable is a failsafe check condition in case turn logic goes wrong
var selected_enemy : CombatEntity
var target_index = 0

# Signals for UI script to react + turn variables
signal player_turn_started 
signal enemy_turn_started
signal combat_end
var enemy_turn_active = false

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
var enemy_visuals: Dictionary = {} # Loads from CombatEntity and gives a dict of EnemyVisuals for enemies
var player_visual : PlayerVisual

# Minigame variables
var in_minigame = false # Default

# COMBAT SETUP FUNCTIONS
# These are functions that run before combat begins, i.e entity data and loading the first turn

# Prepares combat by loading entities (player and enemy(s)) and starting combat
func _ready():
	set_process_input(true)
	await _setup_entities()
	# Combat scene's process mode (pausing) for minigames
	process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_start_combat()

func _process(delta):
	# Pauses combat logic
	if in_minigame:
		return
	
	if attack_timer_running:
		attack_time += delta

# Sets up the player and enemy(s) battle data
func _setup_entities() -> void:
	# PLAYER SETUP
	# Data
	player = CombatEntity.new()
	player.load_from_player()
	
	# Visual
	player_visual = get_parent().get_node("World/PlayerVisual")
	player_visual.action_pressed.connect(_on_player_action_pressed)
	add_child(player)
	player_visual.position = Vector2(96, 283)
	player_visual.set_home_position()
	
	# UI
	await player_visual.ready
	player_visual.update_hp(player.hp, player.max_hp)
	player_visual.update_defense(player.defense, player.defense)
	
	# ENEMIES SETUP
	for i in enemy_ids.size():
		# Data
		var entity := CombatEntity.new()
		entity.load_from_enemy_id(enemy_ids[i])
		add_child(entity)
		enemies.append(entity)
		
		# Visual
		var visual := entity.visual_scene.instantiate()
		get_parent().get_node("World").add_child.call_deferred(visual)
		visual.global_position = enemy_positions[i].global_position # Moving to intended position
		visual.home_position = visual.global_position # Setting as home position
		enemy_visuals[entity] = visual # Adding to enemy_visuals
		
		# UI
		await visual.ready
		visual.update_hp(entity.hp, entity.max_hp)
		visual.update_defense(entity.defense, entity.defense_max)
		visual.update_snapped(entity.snapped, entity.snapped_max)
	
	
func _start_combat():
	_player_turn()

# TURN FUNCTIONS
# These functions play through the turn based combat logic based on entity actions

# Handles the player's turn
func _player_turn():
	turn = "player"
	camera.stop_follow() # Reseting from previous enemy turn (or defaulting it)
	emit_signal("player_turn_started")
	
	# Targeting only alive enemies
	var alive := _get_alive_enemies()
	if alive.is_empty():
		_end_combat(true)
		return
	
	selected_enemy = alive[0]
	print("Player turn: choose ATTACK or ITEMS")

# Handles the enemies turn
func _enemy_turn():
	# Prevents stacking turns, because this is called from multiple places
	if enemy_turn_active:
		return
	
	enemy_turn_active = true
	turn = "enemy"
	_set_camera_for_turn() # Setting camera for enemy turn
	emit_signal("enemy_turn_started")
	
	# 1) Turn order is decided
	var order := _get_enemy_turn_order()
	# 2) Turns are executed
	await _execute_enemy_turns(order)
	# 3) If player survived, player turn
	enemy_turn_active = false
	_player_turn()
	
	# TO-DO Enemy AI to identify possible moves

# Executes each individual enemy's turn based on the given order
func _execute_enemy_turns(order: Array):
	for enemy in order:
		if player.hp <= 0:
			return
		
		# Performs enemy attack
		await _enemy_attack_single(enemy)

func _end_combat(victory: bool):
	# Freeze turn logic (not necessary anymore but keeping just in case)
	turn = ""
	
	# TO-DO: make specific for victory/defeat (separate methods in CombatUI might be easiest)
	combat_end.emit()

	if victory:
		print("All enemies defeated or subdued.")
		# TO-DO Give rewards, XP based on if enemy is defeated/subdued
		# Defeated = more currency, less items + karma (makes enemies harder, will look into how)
		# Subdued = more items, medium currency
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
	
	# Extra check to see if there is a selected enemy
	if not selected_enemy:
		push_error("No selected enemy")
		return
	
	# Setting player's attack position to target enemy (relative to enemy_visual position)
	var enemy_visual = enemy_visuals[selected_enemy]
	player_visual.attack_position = _get_player_attack_position(enemy_visual)
	
	# Camera settings
	camera.follow(player_visual, 60)
	
	# Shows crit hint text for the player + allows inputs for crit
	tutorial_text.show_crit_hint()
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
			# Hides hint text
			tutorial_text.hide_text()
			
			# Calculates the hit damage
			_apply_player_attack_hit(selected_enemy, attack_type),
		CONNECT_ONE_SHOT
	)
	
	# End of the turn
	player_visual.attack_finished.connect(
		func():
			# Check if enemy defeated
			if _check_victory():
				_end_combat(true) # 1. Classic RPG win: enemy defeated
			else:
				# Else switch turn to enemy
				_enemy_turn(),
		CONNECT_ONE_SHOT
	)
	
	await player_visual.play_attack()
	
	# Empty print for visual clarity in terminal while debugging
	print("")

# Opens the player critical hit window during player's atack
func _start_player_critical_window():
	last_attack_press_time = -1.0
	critical_window = Vector2(1.80, 2.05) # TO-DO: tweak this for good hit feel
	attack_time = 0.0
	attack_timer_running = true

# Processes the player hit damage by checking for critical hits and applying necessary damage to either HP or defense
func _apply_player_attack_hit(enemy: CombatEntity, attack_type):
	# Selected player target
	var enemy_visual = enemy_visuals[enemy]
	
	# Only for enemies, so not necessary here
	attack_timer_running = false
	
	var critical = (
		last_attack_press_time >= critical_window.x
		and last_attack_press_time <= critical_window.y
	)
	
	var critical_multiplier = 1.5 if critical else 1.0
	if critical:
		# Freezing frame and shaking camera for good hit feel
		camera.shake(7.0, 0.15)
		freeze_frame(0.13)
		print("CRITICAL HIT!")
	
	# Checks player's attack type against enemy's type
	var type_multiplier := _get_type_multiplier(attack_type, enemy.type)
	
	# Reduce enemy defense if attacking type > defending type
	if enemy.defense > 0 and type_multiplier > 1.0:
		print("Effective type!")
		# Damage calculation for effective type
		var defense_damage = player.attack_power * type_multiplier * critical_multiplier
		enemy.defense -= defense_damage
		
		# Visual effects
		enemy_visual.update_defense(enemy.defense, enemy.defense_max)
		enemy_visual.shake(critical) # Shake
		vfx.play_damage_vfx(enemy_visual, defense_damage, critical) # Damage number, particles
		camera.shake(3.0, 0.1)
		print("Enemy defense reduced by %.2f → %.2f now" % [defense_damage, enemy.defense])
		
		# Checks if defense has been broken, minigame entering condition
		if enemy.defense <= 0:
			print("Enemy defense broken! Triggering minigame now.")
			_start_minigame(enemy)
		# If player loses... minigame's damage logic
		#	player.hp -= enemy.attack... in the future gear multiplier logic so player would take less damage
		#	enemy.defense = random value between 0.2-0.35 times initial max defense
		# else if player wins, increase enemy's snapped value
		#	if enemy's snapped == their max_snapped, then end combat
	else:
		# Regular damage to HP if not effective type
		var defense_factor = float(enemy.defense) / enemy.defense_max if enemy.defense_max > 0 else 0 # Calculates a defense multiplier (how much damage is negated) based on current defense
		var damage = player.attack_power * type_multiplier * critical_multiplier * (1.0 - defense_factor)
		enemy.hp -= damage
		
		# Visual effects
		enemy_visual.update_hp(enemy.hp, enemy.max_hp)
		vfx.play_damage_vfx(enemy_visual, damage, critical)
		
		# Checking if enemy has been defeated
		_resolve_enemy_state(selected_enemy)
		print("Enemy takes %.2f HP damage → %.2f left, current defense is %.2f" % [damage, enemy.hp, enemy.defense])

# Logic for starting enemy's minigame in combat
func _start_minigame(enemy: CombatEntity):
	if not EnemyDatabase.MINIGAME_SCENES.has(enemy.minigame_id):
		push_error("Missing minigame: " + enemy.minigame_id)
		return
	
	# Enemy visual with necessary minigame data
	var enemy_visual = enemy_visuals[enemy]
	
	in_minigame = true
	
	# Subduing visuals
	vfx.play_subdue(enemy_visual)
	await player_visual.play_subdue()
	
	# Minigame scene instantiation
	var minigame = EnemyDatabase.MINIGAME_SCENES[enemy.minigame_id].instantiate()
	minigame.process_mode = Node.PROCESS_MODE_ALWAYS
	_world_gray_out(true) # BG grays out as minigame appears
	minigame_layer.add_child(minigame)
	
	# Minigame on-screen position settings
	minigame.set_anchors_preset(Control.PRESET_FULL_RECT)
	minigame.size = get_viewport().size
	minigame.position = Vector2.ZERO
	
	# Minigame's damage signal
	minigame.damage_taken.connect(_on_minigame_damage_taken)
	
	minigame.completed.connect(
		func(success):
			# Minigame ease in transition
			get_tree().paused = false # Process mode state already set in BaseMinigame.gd, but just in case
			get_parent().process_mode = Node.PROCESS_MODE_INHERIT
			in_minigame = false
			on_minigame_complete(enemy, success)
			
			# Check for enemy defeat
			_resolve_enemy_state(enemy)
			
			# Visual reset
			_world_gray_out(false) # Back to normal focus
			await player_visual.return_to_home()
			
			# Enemy turn
			_enemy_turn(),
		CONNECT_ONE_SHOT
	)
	
	# Pausing all combat (turn) logic
	in_minigame = true
	await minigame.play()

# Connects BaseMinigame signal to give player damage based on minigame
func _on_minigame_damage_taken(amount: float, pos: Vector2):
	player.hp -= amount
	player_visual.update_hp(player.hp, player.max_hp)

# Decides minigame outcome on minigame end
func on_minigame_complete(enemy: CombatEntity, success: bool):
	# Getting enemy visual
	var enemy_visual = enemy_visuals[enemy]
	
	if success:
		var restore_ratio := randf_range(0.2, 0.35)
		enemy.defense = enemy.defense_max * restore_ratio
		enemy_visual.update_defense(enemy.defense, enemy.defense_max)
		enemy.snapped += 1
		enemy_visual.update_snapped(enemy.snapped, enemy.snapped_max)
		print("Minigame success! Snapped: %d / %d" % [enemy.snapped, enemy.snapped_max])
		if enemy.snapped >= enemy.snapped_max:
			if _check_victory():  # 2. Minigame win: enemy subdued
				_end_combat(true)
	else:
		# Restore enemy's defense by a random amount from 20-35%
		var restore_ratio := randf_range(0.2, 0.35)
		enemy.defense = enemy.defense_max * restore_ratio
		enemy_visual.update_defense(enemy.defense, enemy.defense_max)
		print("Minigame failed. Enemy defense restored to %.1f" % enemy.defense)

# Performs a single enemy's attack pattern based on existing logic
func _enemy_attack_single(enemy: CombatEntity):
	# Setting enemy attack
	var visual = enemy_visuals[enemy]
	visual.z_index = 3
	var pattern = enemy.attack_patterns.pick_random() # Picks random attack pattern assigned to the enemy
	
	# Setting attack position for enemy (relative to player)
	visual.attack_position = _get_enemy_attack_position(visual)
	
	# Camera controls + tutorial text visible
	camera.follow(visual, -60)
	tutorial_text.show_block_hint()
	await _play_enemy_attack_pattern(enemy, visual, pattern)


# Plays the given enemy attack pattern during the enemy turn
func _play_enemy_attack_pattern(enemy: CombatEntity, enemy_visual: EnemyVisual, pattern: EnemyAttackPattern):
	print("Enemy uses attack pattern: ", pattern.pattern_id)
	
	# Reseting block + setting hit index for block window timing
	_reset_enemy_attack_timing()
	var hit_index := 0
	
	# Set current block window
	current_block_window = pattern.hits[0].block_window
	# Setting up PlayerVisual for blocking
	player_visual.set_input_enabled(true)
	
	# Connecting with enemy visual script emitters
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
				# Hides hint text
				tutorial_text.hide_text()
				
				# Works the attack's hitting logic, including the player's blocking window
				_apply_enemy_hit(enemy, pattern.hits[hit_index])
				hit_index += 1, # If the attack has multiple hits, it'll process all of them
		CONNECT_ONE_SHOT
		)
	
	# Checks if combat has ended
	enemy_visual.attack_finished.connect(
		func():
			# DEBUG WHEN ATTACK HAS FINISHED
			attack_timer_running = false
			print("!!! DEBUG: attack finished at:", "%.3f" % attack_time)
			
			# Reset visual layering for player attack
			enemy_visual.z_index = 1
			
			# Cancels next enemy turns if player loses before all enemy turns are over (loop is quicker)
			if player.hp <= 0:
				_end_combat(false),
		CONNECT_ONE_SHOT
		)
	
	# Start animation
	enemy_visual.play_attack(pattern.animation_name)
	await enemy_visual.attack_finished
	_resolve_enemy_state(enemy)

# Logic for applying an enemy attack's damage that takes the enemy's attack pattern for blocking into consideration
func _apply_enemy_hit(enemy: CombatEntity, hit: Dictionary):
	current_block_window = hit.block_window
	print("!!! DEBUG: last block press time: ", last_block_press_time)
	
	# Attack pattern duration and timer, listens to _on_player_block_atempted here to check for block and calculates damage after
	var window_duration = hit.block_window.y - hit.block_window.x
	# Block can happen during this timer, calculates the enemy's damage
	get_tree().create_timer(window_duration, true, false).timeout.connect(
		func():
			_resolve_enemy_hit(enemy, hit),
		CONNECT_ONE_SHOT
	)

# Finalises the enemy hit after player blocks during the enemy turn
func _resolve_enemy_hit(enemy: CombatEntity, hit: Dictionary):
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
		camera.shake(2.0, 0.15)
		freeze_frame(0.09)
		print("Successful block!")
	else:
		player_visual.play_block_fail()
		camera.shake(5.0, 0.12)
		print("Failed block")

	print("Player HP is: ", player.hp)
	print("Damage is: ", damage)

	player.hp -= damage
	
	# Visual effects
	player_visual.update_hp(player.hp, player.max_hp)
	vfx.play_damage_vfx(player_visual, damage, false)
	print("Player takes %.1f damage → HP %.1f" % [damage, player.hp])
	
	# Reseting block press time for next enemy attack patterns
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
#func _enemy_attack():
	## If for some reason it is not the player's turn
	#if turn != "enemy":
		#print("Player turn in enemy_attack.")
		#return
		#
	#print("%s attacks!" % enemy.entity_name)
	#
	## Enemy's initial attack power
	#var damage := enemy.attack_power
	#
	## TO-DO Attack animation and timing here
	#
	## TO-DO Blocking logic for the player during enemy attack animation
	## This will be replaced with actual timing-based blocking like in Paper Mario
	#var player_blocked := false
	#
	#if player_blocked:
		## Upon successful block, enemy damage is reduced by half
		#
		## TO-DO Sprite animation here, right now block visual with cooldown of 1.5s
		#
		#
		## Damage calculation, i.e if damage is an uneven number like 5, blocked damage will be 2 -> creates incentive to block
		#damage = floor(damage * 0.5)
		#print("Player BLOCKED! Damage reduced to %.1f." % damage)
	#else:
		#print("Player failed to block. Taking full damage of %1.f." % damage)
	#
	#player.hp -= damage
	#print("Player HP: %.1f" % player.hp)
	#print("")
	#
	## Check if player has been defeated at the end of the turn
	#if player.hp <= 0:
		#_end_combat(false)
		#return
#
	## Switch back to player's turn
	#_player_turn()
	

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

# Filters from all existing enemies the ones that are not 1) defeated or 2) subdued
func _get_alive_enemies() -> Array:
	return enemies.filter(func(e):
		return e.hp > 0 and e.snapped < e.snapped_max
	)

# Gets the enemy turn order at the start of enemy turn
# This is decided by 1) which enemy has higher HP or (if some or all enemies have same HP) 2) by position to player
func _get_enemy_turn_order() -> Array:
	var alive := _get_alive_enemies()
	
	alive.sort_custom(func(a, b):
		if a.hp != b.hp:
			return a.hp > b.hp # Higher HP first
			
		# Distance
		var va = enemy_visuals[a]
		var vb = enemy_visuals[b]
		return va.global_position.distance_to(player_visual.global_position) \
			< vb.global_position.distance_to(player_visual.global_position)
	)
	
	return alive

# Checks if victory has been achieved by checking alive enemies list
func _check_victory():
	return _get_alive_enemies().is_empty()

# Resets enemy attack timing during start of _play_enemy_attack_pattern (to ensure correct block timing)
func _reset_enemy_attack_timing():
	attack_time = 0.0
	attack_timer_running = false
	last_block_press_time = -1.0
	block_on_cooldown = false

# Freezes the scene for a given parameter of time to show impact
func freeze_frame(time = 0.05):
	Engine.time_scale = 0.5
	await get_tree().create_timer(time, true).timeout
	Engine.time_scale = 1.0

# Getter for enemy attack position relative to player_visual position
func _get_enemy_attack_position(enemy_visual: EnemyVisual) -> Vector2:
	return player_visual.global_position + Vector2(90, 0) # for Beetle right now

# Getter for player attack position relative to enemy_visual position
func _get_player_attack_position(enemy_visual: EnemyVisual) -> Vector2:
	return enemy_visual.global_position + Vector2(-50, 0)

# Starts attack target selection during player turn
func start_target_selection():
	# Only alive enemies can be targeted
	var alive := _get_alive_enemies()
	if alive.is_empty():
		return
	
	# Targeting always starts at index 0 out of alive enemies
	target_index = 0
	_set_selected_enemy(alive[target_index])

# Cycling method for UI enemy selection
func cycle_target(dir: int):
	# Only alive enemies can be targeted, double checking just in case
	var alive := _get_alive_enemies()
	if alive.is_empty():
		return
	
	# Checks for enemy cycling limits (if only one enemy exists then it doesn't reset animation
	var new_index = wrapi(target_index + dir, 0, alive.size())
	if new_index == target_index:
		return
	
	# Finds index for the selected enemy based on dir
	target_index = wrapi(target_index + dir, 0, alive.size())
	_set_selected_enemy(alive[target_index])

# Setter for selected_enemy -> listens to UI and sets the currently selected enemy (and keeps it after selection is confirmed)
func _set_selected_enemy(enemy: CombatEntity):
	# Hides all enemy arrows
	for e in enemy_visuals.keys():
		enemy_visuals[e].hide_target_arrow()
	
	# Shows only one selected enemy arrow
	selected_enemy = enemy
	enemy_visuals[enemy].show_target_arrow()

# Finalizing target selection after _set_selected_enemy (hiding enemy_visual's target arrow)
func _confirm_target_selection():
	if selected_enemy:
		enemy_visuals[selected_enemy].hide_target_arrow()

# Decides if an enemy has been defeated by minigame or not
func _resolve_enemy_state(enemy: CombatEntity):
	var visual = enemy_visuals[enemy]

	if enemy.hp <= 0:
		await visual.play_defeat(false)
	elif enemy.snapped >= enemy.snapped_max:
		await visual.play_defeat(true)

# Sets camera follow state for the turn with the turn variable
func _set_camera_for_turn():
	if turn == "player":
		camera.follow(player_visual)
	elif turn == "enemy":
		var alive := _get_alive_enemies()
		if alive.is_empty():
			camera.follow(player_visual)
		else:
			camera.follow(enemy_visuals[alive[0]])

# ANIMATION/FX METHODS
# Smooth tween BG animation for minigame enter/exiting 
func _world_gray_out(gray_out: bool):
	var world_node = get_parent().get_node("World")
	if gray_out:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(world_node, "modulate:a", 0.6, 0.6)
	else:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(world_node, "modulate:a", 1.0, 0.6)
