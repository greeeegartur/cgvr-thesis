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

# Nodes to use for visual effects in the combat scene
@onready var camera : CombatCamera = get_parent().get_node("Camera2D")
@onready var ui := get_parent().get_node("UI/CombatUI")
@onready var player_turn_ui := get_parent().get_node("UI/CombatUI/PlayerTurnUi")
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
signal combat_end(victory: bool, rewards: Dictionary)
signal player_died
var enemy_turn_active := false
var is_targeting := false # Check to see if targeting is allowed or not
var selected_attack_type : CombatTypes.EntityType # Currently selected attack type in enemy targeting
var turn_order_toggle_enabled := false # UI variable for turn showing enemy visual turn orders
var locked_enemy_turn_order: Array

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

# Minigame and combat-specific variables
var in_minigame = false # Default
var combat_paused := false

# COMBAT SETUP FUNCTIONS
# These are functions that run before combat begins, i.e entity data and loading the first turn

# Prepares combat by loading entities (player and enemy(s)) and starting combat
func _ready():
	set_process_input(true)
	_setup_ui()
	# Combat scene's process mode (pausing) for minigames
	process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta):
	# Pauses combat logic
	if in_minigame:
		return
	
	if attack_timer_running:
		attack_time += delta

# Sets up the player and enemy(s) battle data
func _setup_entities(enemy_ids):
	# PLAYER SETUP
	# Data, only setting up when loading in
	if player == null:
		player = CombatEntity.new()
		player.load_from_player()
		
		# Visual
		player_visual = get_parent().get_node("World/PlayerVisual")
		player_visual.action_pressed.connect(_on_player_action_pressed)
		add_child(player)
		player_visual.position = Vector2(96, 277)
		player_visual.set_home_position()
		
		# UI
		await player_visual.ready
		player_visual.update_hp(player.hp, player.max_hp)
	# Resyncing from possible previous combats
	player_visual.update_hp(player.hp, player.max_hp)
	
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
		visual.attack_offset = EnemyDatabase.get_attack_offset(enemy_ids[i]) # Setting offset for attack position
		visual.move_speed = EnemyDatabase.get_move_speed(enemy_ids[i]) # Setting move speed for enemy during attacks
		enemy_visuals[entity] = visual # Adding to enemy_visuals
		
		# UI
		await visual.ready
		visual.setup_axis(entity.axis_max, entity.trust_max)

# Enemy spawning method for enemies that appear mid-combat (essentially reused logic from setup_entities, but has to be in the context of a separate method)
func _spawn_enemy(enemy_id: String, slot_index: int, spawner: CombatEntity):
	# Making defeated enemies invisible if they exist
	for e in enemies:
		if e.is_killed() or e.is_tamed():
			#var tween := create_tween()
			#tween.tween_property(e, "modulate:a", 0.0, 1.0)
			#await tween.finished
			enemy_visuals[e].visible = false # Turning invisible if creatures are tamed (if they are then they remain in battle)
	spawner.can_spawn = false
	
	# Data
	var entity := CombatEntity.new()
	entity.load_from_enemy_id(enemy_id)
	entity.spawned = true
	entity.can_spawn = false # Spawned enemy cannot spawn more enemies
	add_child(entity)
	enemies.append(entity)
	
	# Visual
	var visual := entity.visual_scene.instantiate()
	get_parent().get_node("World").add_child.call_deferred(visual)
	visual.global_position = enemy_positions[slot_index].global_position
	visual.home_position = visual.global_position
	visual.attack_offset = EnemyDatabase.get_attack_offset(enemy_id)
	visual.move_speed = EnemyDatabase.get_move_speed(enemy_id)
	visual.z_index = 1
	enemy_visuals[entity] = visual
	
	await visual.ready
	visual.setup_axis(entity.axis_max, entity.trust_max)
	
	# Separate entry animation (this specific one is for bats)
	visual.position.y += -240
	var tween := create_tween()
	tween.tween_property(visual, "position", visual.home_position, 0.8)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	await tween.finished


func _setup_ui():
	ui.setup(self)
	
	# PLAYER
	# Player turn signals
	player_turn_ui.attack_type_selected.connect(_on_attack_selected)
	player_turn_ui.cycle_enemy.connect(cycle_target)
	player_turn_ui.confirm_enemy.connect(_confirm_target_selection)
	player_turn_ui.cancel_enemy.connect(_cancel_target_selection)
	
	# TOP UI
	# Turn order button signal
	ui.turn_order_toggled.connect(_on_turn_order_toggled)
	
	await ui.ready

# Resets combat for new round
func _reset_combat_state():
	# Global variables reset
	turn = ""
	selected_enemy = null
	attack_timer_running = false
	last_attack_press_time = 0.0
	
	# Freeing old enemy visuals and entities
	for visual in enemy_visuals.values():
		if is_instance_valid(visual):
			visual.queue_free()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	enemies.clear()
	enemy_visuals.clear()

# Absolute reset for after death (reset to very first stage)
func _force_full_reset():
	# Base reset
	_reset_combat_state()
	
	# Turn system reset
	enemy_turn_active = false
	target_index = 0
	is_targeting = false

	# Timing + minigame reset
	attack_time = 0.0
	last_block_press_time = -1.0
	block_on_cooldown = false
	in_minigame = false

	# UI reset
	player_turn_ui.lock_input()
	player_turn_ui.hide_player_turn_ui()

	combat_paused = false
	set_process_input(true)

func _pause_combat():
	combat_paused = true
	set_process_input(false)

func _resume_combat():
	combat_paused = false
	set_process_input(true)


# Called from StageFlowController with stage specific area ids to setup entities and start turns
func _start_combat(enemy_ids):
	await _setup_entities(enemy_ids)
	await animate_enemy_entry()
	_start_turn_loop()

# Starts the actual combat
func _start_turn_loop():
	_player_turn()

# TURN FUNCTIONS
# These functions play through the turn based combat logic based on entity actions

# Handles the player's turn
func _player_turn():
	# State check controlled by StageFlowController
	if combat_paused:
		return
	turn = "player"
	tutorial_text.show_hint(TutorialText.HintType.PLAYER_TURN)
	
	# Turn order button visbility settings
	is_targeting = false
	selected_enemy = null
	locked_enemy_turn_order = _get_enemy_turn_order()
	_update_enemy_turn_order_display()
	
	# Player turn base defaults, signal emit and guess display update
	await camera.stop_follow() # Reseting from previous enemy turn (or defaulting it)
	player_turn_ui.start_player_turn()
	player_turn_ui.update_guess_display()
	player_turn_started.emit()
	
	# Targeting only alive enemies
	var alive := _get_alive_enemies()
	if alive.is_empty():
		_end_combat(true)
		return
	
	print("Player turn: choose ATTACK or ITEMS")

# Handles the enemies turn
func _enemy_turn():
	# State check controlled by StageFlowController
	if combat_paused:
		return
	# Turn order visuals settings
	_clear_enemy_turn_order_visuals()
	# Prevents stacking turns, because this method is called from multiple places
	if enemy_turn_active:
		return
	
	enemy_turn_active = true
	turn = "enemy"
	_set_camera_for_turn() # Setting camera for enemy turn
	enemy_turn_started.emit()
	
	# 1) Turn order is decided
	var order := locked_enemy_turn_order.duplicate()
	# 2) Turns are executed
	await _execute_enemy_turns(order)
	# 3) If player survived, player turn
	enemy_turn_active = false
	_player_turn()
	
	# TO-DO Enemy AI to identify possible moves

# Executes each individual enemy's turn based on the given order
func _execute_enemy_turns(order: Array):
	for enemy in order:
		# Skipping invalid enemies (turn order is locked during player turn)
		if enemy.is_killed() or enemy.is_tamed():
			continue
		if player.hp <= 0:
			_end_combat(false)
			return
		
		# Performs enemy attack
		await _enemy_attack_single(enemy)

func _end_combat(victory: bool):
	# Freeze turn logic (not necessary anymore but keeping just in case)
	turn = ""
	player_turn_ui.hide_player_turn_ui()
	tutorial_text.hide_text()
	player_turn_ui.lock_input()

	if victory:
		print("All enemies defeated or subdued.")
		tutorial_text.hide_text()
		var rewards = _generate_rewards()
		_reset_combat_state()
		combat_end.emit(victory, rewards)
		# TO-DO Give rewards, XP based on if enemy is defeated/subdued
		# Defeated = more currency, less items + karma (makes enemies harder, will look into how)
		# Subdued = more items, medium currency
	else:
		# Player lost
		print("Player defeated! Game over.")
		
		tutorial_text.visible = false
		_pause_combat()
		_reset_combat_state()
		player_died.emit()
		
		# TO-DO: Implement fallback (retry, save and quit.)


# ACTION FUNCTIONS
# These functions progress the turn in some way

# The player's attacking logic, takes the player's attack type as a parameter for damage calculation
func player_attack(attack_type: CombatTypes.EntityType):
	tutorial_text.hide_text()
	
	# If for some reason it is not the player's turn
	if turn != "player":
		print("Enemy turn in player_attack.")
		return
	
	# Extra check to see if there is a selected enemy
	if not selected_enemy:
		push_error("No selected enemy")
		return
	
	print("Player attacks with: ", attack_type)
	
	# Setting player's attack position to target enemy (relative to enemy_visual position)
	var enemy_visual = enemy_visuals[selected_enemy]
	player_visual.attack_position = _get_player_attack_position(enemy_visual)
	
	# Camera settings
	camera.follow(player_visual, 60)
	
	# Shows crit hint text for the player + allows inputs for crit
	tutorial_text.show_hint(TutorialText.HintType.CRIT)
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
			_apply_axis_shift(selected_enemy, attack_type),
		CONNECT_ONE_SHOT
	)
	
	# End of the turn
	player_visual.attack_finished.connect(
		func():
			await player_visual._move_to_home_position()
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

# Processes the player's hit to shift the enemy's axis bar in a specific direction (kill, left or tame, right)
func _apply_axis_shift(enemy: CombatEntity, guess_type: CombatTypes.EntityType):
	var enemy_visual = enemy_visuals[enemy]
	
	# Only for enemies, so not necessary here
	attack_timer_running = false
	
	# Base damage calculation based on if crit or not
	var base = player.attack_power
	
	var critical = (
		last_attack_press_time >= critical_window.x
		and last_attack_press_time <= critical_window.y
	)
	
	if critical:
		base *= 1.5
		# VFX effects 
		camera.pop_zoom()
		vfx.play_vignette(vfx.get_vfx_color_from_string("crit"), 0.4)
		vfx.play_crit_feedback(enemy_visual)
		# Freezing frame and shaking camera for good hit feel
		camera.shake(10.0, 0.15)
		freeze_frame(0.14)
		print("CRITICAL HIT!")
	
	var correct = _is_correct_guess(guess_type, enemy.type) # Checks if correct guess type
	
	# Moves towards tame side on the right based on resistance
	# If axis_value is on kill side, enemy resistance is up and correct guess will move axis_value less
	if correct:
		var resistance := 1.0 # Base resistance
		if enemy.axis_value < 0:
			# Enemy is hostile again and is harder to tame, so resistance increases
			resistance = lerp(1.5, 2.5, abs(enemy.axis_ratio()))
		
		# Damage calculation
		var value_shift = round_quarter(base / resistance) # Just base if previous change did not apply
		var before = enemy.axis_value
		enemy.axis_value += value_shift
		enemy.axis_value = round_quarter(min(enemy.axis_value, enemy.axis_max)) # Ensures the bar does not go beyond axis bar limits (to look good)
		var actual_shift = enemy.axis_value - before
		
		# Visual effects
		enemy_visual.shake(critical)
		enemy_visual.update_axis(enemy.axis_value, actual_shift)
		vfx.play_damage_vfx(enemy_visual, abs(actual_shift), critical) # Damage number, particles
		camera.shake(7.0, 0.1)
		
		# Restores chip if matches conditions inside method
		_try_restore_chip(guess_type, critical)
		
		print("Enemy gets %.2f tame progress, now axis line is %.2f and %.2f away from tame." % [value_shift, enemy.axis_value, enemy.max_hp - value_shift])
		
		# Checks if enemy's axis value is at max, if it is, starts minigame
		if enemy.is_minigame_ready():
			print("Enemy trust level reached! Triggering minigame now.")
			_start_minigame(enemy)
	else:
		# Moves towards kill side on the left based on how off guard the enemy is
		# Off guard is calculated for an exponential multiplier that increases axis movement the more "off guard" an enemy is
		# So 1) guessing correct once and 2) then guessing wrong will increase damage more than just 1) guessing wrong
		var off_guard = max(0.0, enemy.axis_ratio())
		var kill_multiplier := 0.5 + pow(off_guard, 2.5) * 2.0
		
		# Damage calculation
		var value_shift = round_quarter(base * kill_multiplier) # Kill multiplier will just be 0.5 if off_guard is 0
		var before = enemy.axis_value
		enemy.axis_value -= value_shift
		enemy.axis_value = round_quarter(max(enemy.axis_value, -enemy.axis_max)) # Ensures the bar does not go beyond axis bar limits (to look good)
		var actual_shift = enemy.axis_value - before
		
		# Visual effects
		enemy_visual.shake(critical)
		enemy_visual.update_axis(enemy.axis_value, actual_shift)
		vfx.play_damage_vfx(enemy_visual, abs(actual_shift), critical)
		
		# Restores chip if matches conditions inside method
		_try_restore_chip(guess_type, critical)
		
		# Checking if enemy has been defeated
		_resolve_enemy_state(enemy)
		print("Enemy takes %.2f damage, now is %.2f and %.2f left for kill." % [value_shift, enemy.axis_value, enemy.max_hp - value_shift])

# Logic for starting enemy's minigame in combat
func _start_minigame(enemy: CombatEntity):
	if not EnemyDatabase.MINIGAME_SCENES.has(enemy.minigame_id):
		push_error("Missing minigame: " + enemy.minigame_id)
		return
	
	# Enemy visual with necessary minigame data
	var enemy_visual = enemy_visuals[enemy]
	
	in_minigame = true
	
	# Taming visuals
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
	vfx.play_vignette(vfx.get_vfx_color_from_string("normal"))

# Decides minigame outcome on minigame end
func on_minigame_complete(enemy: CombatEntity, success: bool):
	# Getting enemy visual
	var enemy_visual = enemy_visuals[enemy]
	
	if success:
		var restore_ratio := randf_range(0.2, 0.35)
		enemy.axis_value = enemy.axis_max * restore_ratio
		enemy.trust += 1
		enemy_visual.update_axis(enemy.axis_value)
		enemy_visual.update_axis_trust() 
		print("Minigame success! Trust: %d / %d" % [enemy.trust, enemy.trust_max])
		if enemy.is_tamed():
			await player_visual._move_to_home_position()
			if _check_victory():  # 2. Minigame win: enemy tamed
				_end_combat(true) # If last enemy
	else:
		# Restore enemy's defense by a random amount from 20-35%, rounds it somewhat though
		var restore_ratio := randf_range(0.2, 0.35)
		enemy.axis_value = round(enemy.axis_max * restore_ratio)
		enemy_visual.update_axis(enemy.axis_value)
		print("Minigame failed. Enemy axis restored to %.1f" % enemy.axis_value)

# Performs a single enemy's attack pattern based on existing logic
func _enemy_attack_single(enemy: CombatEntity):
	# Setting enemy attack
	var visual = enemy_visuals[enemy]
	visual.z_index = 3
	var pattern = enemy.attack_patterns.pick_random() # Picks random attack pattern assigned to the enemy
	
	# Support patterns
	if pattern.is_support:
		await _handle_support_pattern(enemy, pattern)
		return
	
	# Setting attack position for enemy (relative to player)
	visual.attack_position = _get_enemy_attack_position(visual)
	
	# Camera controls + tutorial text visible
	camera.follow(visual, -60)
	tutorial_text.show_hint(TutorialText.HintType.BLOCK)
	await _play_enemy_attack_pattern(enemy, visual, pattern)

# Handles support patterns respectively for each enemy, TO-DO: edit for separate enemies so anyone can pass check
func _handle_support_pattern(enemy: CombatEntity, pattern: EnemyAttackPattern):
	# First play animation
	var visual = enemy_visuals[enemy]
	await visual.play_support(pattern.animation_name)
	
	if not enemy.can_spawn:
		return
	
	# Does nothing if spawn chance does not happen
	if randf() > pattern.spawn_chance:
		return
	
	var free_index := _get_free_enemy_slot()
	# If no free position found for enemy to spawn
	if free_index == -1:
		return
	
	# Spawns enemy with available slot
	await _spawn_enemy(pattern.spawn_enemy_id, free_index, enemy)


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
			
			# Reset visual layering for player attack and setting input to false
			enemy_visual.z_index = 1
			player_visual.set_input_enabled(false),
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
		camera.shake(8.0, 0.15)
		freeze_frame(0.11)
		vfx.play_vignette(vfx.get_vfx_color_from_string("block"), 0.2)
		vfx.play_block_feedback(player_visual)
		print("Successful block!")
	else:
		player_visual.play_block_fail()
		camera.shake(5.0, 0.12)
		freeze_frame(0.08)
		print("Failed block")

	print("Player HP is: ", player.hp)
	print("Damage is: ", damage)

	player.hp -= damage
	
	# Visual effects
	player_visual.update_hp(player.hp, player.max_hp)
	vfx.play_damage_vfx(player_visual, damage, false, blocked)
	print("Player takes %.1f damage → HP %.1f" % [damage, player.hp])
	
	# Reseting block press time for next enemy attack patterns
	last_block_press_time = -1.0
	
	# Cancels next enemy turns if player loses before all enemy turns are over
	if player.hp <= 0:
		_end_combat(false)

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

# Chip restoring function for the player to gain back chips with crits; also acts as a softlock prevention method
func _try_restore_chip(used_type: CombatTypes.EntityType, critical: bool):
	var total_chips = PlayerData._get_total_chips()
	# 1. Player uses last chip, so that chip is always restored regardless of crit
	print("here")
	if total_chips == 0:
		_restore_chip(used_type)
		player_visual.play_restore_chip()
		print("restored")
		return
	# 2. Random crit chance
	if randf() <= 0.10:
		_restore_chip(used_type)
		player_visual.play_restore_chip()

# HELPER FUNCTIONS
# These functions help ACTION functions with calculations and more

# Decides correct guess type by comparing the player's guessing type with the enemy's type
# If the two types are the same, the player has made a correct guess
# Types are Sky, Earth and Water
func _is_correct_guess(player_type: CombatTypes.EntityType, enemy_type: CombatTypes.EntityType) -> bool:
	return player_type == enemy_type

# Filters from all existing enemies the ones that are not 1) defeated or 2) subdued
func _get_alive_enemies() -> Array:
	return enemies.filter(func(e):
		return !e.is_killed() and !e.is_tamed()
	)

# Gets the enemy turn order at the start of enemy turn
# This is decided by 1) which enemy has higher axis value (is more tamed) or (if some or all enemies have same axis value) 2) by position to player
func _get_enemy_turn_order() -> Array:
	var alive := _get_alive_enemies()
	
	alive.sort_custom(func(a, b):
		if a.axis_value != b.axis_value:
			return a.axis_value > b.axis_value # Higher axis value first
			
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
	return player_visual.global_position + enemy_visual.attack_offset

# Getter for player attack position relative to enemy_visual position
func _get_player_attack_position(enemy_visual: EnemyVisual) -> Vector2:
	return enemy_visual.global_position + Vector2(-50, 0) # for now

# Starts attack target selection during player turn
func start_target_selection():
	is_targeting = true
	_clear_enemy_turn_order_visuals()
	# Only alive enemies can be targeted
	var alive := _get_alive_enemies()
	if alive.is_empty():
		return
	
	tutorial_text.show_hint(TutorialText.HintType.PLAYER_SELECT)
	
	# Targeting always starts at index 0 out of alive enemies
	target_index = 0
	selected_enemy = alive[target_index]
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

# Finalizing target selection after _set_selected_enemy (hiding enemy_visual's target arrow) and starting player attack
func _confirm_target_selection():
	if not is_targeting:
		return
	is_targeting = false
	if selected_enemy:
		enemy_visuals[selected_enemy].hide_target_arrow()
	_clear_enemy_turn_order_visuals()
	
	# Hiding player UI and locking input from it
	player_turn_ui.hide_player_turn_ui()
	player_turn_ui.lock_input()
	player_attack(selected_attack_type) # Starting player attack

# Selects an attack type and sets it during enemy selection
func _on_attack_selected(attack_type: CombatTypes.EntityType):
	if turn != "player":
		return
	if is_targeting:
		return
	
	# Sets selected attack type as the selected one and hides player turn UI
	selected_attack_type = attack_type
	
	# Starts enemy targeting
	start_target_selection()

# Moves back from target selection to previous state (handled by PlayerTurnUI)
func _cancel_target_selection():
	if not is_targeting:
		return
	is_targeting = false
	
	# Hides all enemy arrows and defaults selected enemy and index
	for v in enemy_visuals.values():
		v.hide_target_arrow()
	selected_enemy = null
	target_index = 0
	
	tutorial_text.show_hint(TutorialText.HintType.PLAYER_TURN)
	
	_update_enemy_turn_order_display()
	player_turn_ui.cancel_enemy_selection()

# Decides if an enemy has been defeated by minigame or not
func _resolve_enemy_state(enemy: CombatEntity):
	var visual = enemy_visuals[enemy]

	if enemy.is_killed():
		visual.z_index = 1
		await visual.play_defeat(false)
	elif enemy.is_tamed():
		visual.z_index = 1
		await visual.play_defeat(true)

# Sets camera follow state for the turn with the turn variable
func _set_camera_for_turn():
	if turn == "enemy":
		var alive := _get_alive_enemies()
		if alive.is_empty():
			camera.follow(player_visual)
		else:
			camera.follow(enemy_visuals[alive[0]])

# Reacts to CombatUI signal to turn on turn order UI elements by button
func _on_turn_order_toggled(enabled: bool):
	turn_order_toggle_enabled = enabled
	_update_enemy_turn_order_display()

# Updates turn order visibility based on combat situation
func _update_enemy_turn_order_display():
	# Clearing all current displays before applying new ones
	for v in enemy_visuals.values():
		v.hide_turn_order()
	
	# Constraints to limit turn order number visibility in specific circumstances
	if not turn_order_toggle_enabled: # Obvious one being if the toggle is disabled
		return
	if turn != "player": # During enemy attacks
		return
	if is_targeting: # While targeting
		return
	
	var index := 1
	for enemy in locked_enemy_turn_order:
		# Skips invalid enemies visually
		if enemy.is_killed() or enemy.is_tamed():
			continue
		
		enemy_visuals[enemy].show_turn_order(index)
		index += 1

# Hides enemy turn order from visuals (to apply new turn order visuals at the start of player turn)
func _clear_enemy_turn_order_visuals():
	for v in enemy_visuals.values():
		v.hide_turn_order()

# Rounds damage number by quarters, so no damage will ever be something like "2.584", but rather just "2.5"
func round_quarter(value: float) -> float:
	return round(value * 4.0) / 4.0

func _generate_rewards():
	var total_currency := 0
	
	for enemy in enemies:
		var effective_hp = enemy.max_hp
		if enemy.spawned:
			effective_hp *= 0.5
		
		# For currency (and XP generation in future)
		var half_hp = round(effective_hp * 0.5)
		var min_currency: int
		var max_currency: int
		
		# Rewards based on how the enemy was defeated
		if enemy.is_killed():
			max_currency = half_hp
			min_currency = max(0, max_currency - 2)
		elif enemy.is_tamed():
			min_currency = half_hp
			max_currency = min_currency + 2
		else:
			continue # Should not be possible to reach this point
		
		var gained_currency := randi_range(min_currency, max_currency)
		total_currency += gained_currency
	
	PlayerData.currency += total_currency
	print("Currency right now: ", PlayerData.currency)
	
	return {"currency": total_currency}

# Searches for available enemy slots and returns the respective slot where an enemy can potentially spawn
func _get_free_enemy_slot() -> int:
	for i in enemy_positions.size():
		var alive_in_slot := false
		for e in enemies:
			if enemy_visuals.has(e):
				var visual = enemy_visuals[e]
				if visual.global_position == enemy_positions[i].global_position:
					if not e.is_killed() and not e.is_tamed():
						alive_in_slot = true
		if not alive_in_slot:
			return i
	return -1

# Restores the players chip when 1) landing a critical hit with 10% chance or 2) last chip used
func _restore_chip(type: CombatTypes.EntityType):
	match type:
		CombatTypes.EntityType.SKY:
			PlayerData.add_guesses(CombatTypes.EntityType.SKY, 1)
		CombatTypes.EntityType.EARTH:
			PlayerData.add_guesses(CombatTypes.EntityType.EARTH, 1)
		CombatTypes.EntityType.WATER:
			PlayerData.add_guesses(CombatTypes.EntityType.WATER, 1)

	print("Chip restored for:", type, "!")
	player_turn_ui.update_guess_display()


# ANIMATION METHODS
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

func animate_enemy_entry():
	for visual in enemy_visuals.values():
		var target_pos = visual.position
		visual.position.x += 300
		
		var tween := create_tween()
		tween.tween_property(visual, "position", target_pos, 0.6)
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		
	await get_tree().create_timer(0.6).timeout
