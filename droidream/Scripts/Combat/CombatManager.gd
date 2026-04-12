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
var target_mode := TargetMode.NONE
enum TargetMode {
	NONE,
	ENEMY,
	SELF
}

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

# Crit multipliers (for Recalibration effect)
const BASE_CRIT_MULTIPLIER := 1.5
const RECALIBRATION_CRIT_MULTIPLIER := 1.75

# Entity visual scenes to load for animations and UI
var enemy_visuals: Dictionary = {} # Loads from CombatEntity and gives a dict of EnemyVisuals for enemies
var player_visual : PlayerVisual

# Minigame and combat-specific variables
var in_minigame = false # Default
var combat_paused := false
var combat_has_ended := false
var ability_being_used : InventoryAbility
var item_being_used: InventoryItem
var selected_ability_tame_type: CombatTypes.EntityType
var ability_tame_select_active := false
var minigame_queue_ongoing := false

# Ability/passive/item specific variables
# Heat Up effects
var heat_up_pending_power_bonus := 0
var heat_up_active := false
var heat_up_power_bonus := 0
var heat_up_turns_remaining := 0
const HEAT_UP_DEFENSE_PENALTY := 0.5

# Harden effects
var harden_active := false
var harden_defense_bonus := 0.0
var harden_turns_remaining := 0

# Microbots effects
var microbots_turn_counter := -1
const MICROBOTS_HEAL_RATIO := 0.10
const MICROBOTS_CHIP_RESTORE_CHANCE := 0.20

# Reflexive Sensors effects
const REFLEXIVE_SENSORS_MISS_CHANCE := 0.075
const REFLEXIVE_SENSORS_BLOCK_BOOST_CHANCE := 0.30
const REFLEXIVE_SENSORS_BLOCK_MULTIPLIER := 0.5

# Enamor constant
const ENAMOR_DOUBLE_REWARD_CHANCE := 0.75

# Human At Heart constants
const HUMAN_AT_HEART_HEAL_RATIO := 0.10
const HUMAN_AT_HEART_POWER_GAIN := 0.25
var human_at_heart_trigger_counter := 0

# Thick Jelly effects
var thick_jelly_active := false
var thick_jelly_turns_remaining := 0
const THICK_JELLY_BLOCK_MULTIPLIER := 0.5

# Soft Branch effects
var soft_branch_active := false
var soft_branch_power_bonus := 0.0
var soft_branch_turns_remaining := 0
const SOFT_BRANCH_POWER_BONUS := 1.0

# Ice Cube effects
var ice_cube_active := false
var ice_cube_turns_remaining := 0
const ICE_CUBE_HEAL_RATIO := 0.10

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
		PlayerData.stats_changed.connect(_sync_player_stats)
		add_child(player)
		player_visual.position = Vector2(96, 277)
		player_visual.set_home_position()
		
		# UI
		await player_visual.ready
		player_visual.update_hp(player.hp, player.max_hp)
	_sync_player_stats() # From possible previous instances
	
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
			# Turning invisible if creatures are tamed (if they are then they remain in battle)
			var v = enemy_visuals[e]
			var fade_tween := create_tween()
			fade_tween.tween_property(
				v,
				"modulate:a",
				0.0,
				0.35
			)
			await fade_tween.finished
			v.visible = false
	spawner.can_spawn = false
	
	# Data
	var entity := CombatEntity.new()
	entity.load_from_enemy_id(enemy_id)
	entity.spawned = true
	entity.can_spawn = false # Spawned enemy cannot spawn more enemies
	add_child(entity)
	enemies.append(entity)
	
	# New enemy gets applied correct visual index (if a creature occupied it before, it will get its index)
	var new_index := enemies.size() - 1
	if slot_index < enemies.size():
		var displaced = enemies[slot_index]
		
		enemies[slot_index] = entity
		enemies[new_index] = displaced
	
	# Visual
	var visual := entity.visual_scene.instantiate()
	get_parent().get_node("World").add_child.call_deferred(visual)
	var target_pos = enemy_positions[slot_index].global_position
	visual.global_position = target_pos + Vector2(0, -260)
	visual.home_position = target_pos
	visual.attack_offset = EnemyDatabase.get_attack_offset(enemy_id)
	visual.move_speed = EnemyDatabase.get_move_speed(enemy_id)
	visual.z_index = 1
	enemy_visuals[entity] = visual
	
	await visual.ready
	visual.setup_axis(entity.axis_max, entity.trust_max)
	
	# Separate entry animation (this specific one is for bats)
	await get_tree().create_timer(0.15).timeout
	var tween := create_tween()
	tween.tween_property(visual, "position", target_pos, 0.8)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	await tween.finished


func _setup_ui():
	ui.setup(self)
	
	# PLAYER
	# Player turn signals
	player_turn_ui.attack_type_selected.connect(_on_attack_selected)
	player_turn_ui.ability_selected.connect(_on_ability_selected)
	player_turn_ui.item_selected.connect(_on_item_selected)
	player_turn_ui.ability_tame_type_selected.connect(_on_ability_tame_type_selected)
	player_turn_ui.cancel_ability_tame_select.connect(_on_cancel_ability_tame_select)
	player_turn_ui.cycle_enemy.connect(cycle_target)
	player_turn_ui.confirm_enemy.connect(_confirm_target_selection)
	player_turn_ui.cancel_enemy.connect(_cancel_target_selection)
	
	# TOP UI
	# Turn order button signal
	ui.turn_order_toggled.connect(_on_turn_order_toggled)
	
	await ui.ready

# Resets combat for new round
func _reset_combat_state():
	# Variables reset
	turn = ""
	selected_enemy = null
	attack_timer_running = false
	last_attack_press_time = 0.0
	heat_up_pending_power_bonus = 0
	heat_up_active = false
	heat_up_power_bonus = 0
	heat_up_turns_remaining = 0
	harden_active = false
	harden_defense_bonus = 0.0
	harden_turns_remaining = 0
	microbots_turn_counter = -1
	thick_jelly_active = false
	thick_jelly_turns_remaining = 0
	soft_branch_active = false
	soft_branch_power_bonus = 0.0
	soft_branch_turns_remaining = 0
	ice_cube_active = false
	ice_cube_turns_remaining = 0
	
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
	# CORE BUILDING
	combat_has_ended = false
	await _setup_entities(enemy_ids)
	vfx._update_karma_overlay()
	await animate_enemy_entry()
	
	# PLAYER UI BUILDING
	await player_turn_ui._build_abilities_ui()
	await player_turn_ui._build_items_ui()
	_reset_ability_cooldowns()
	
	# COMBAT STARTS
	_start_turn_loop()

# Starts the actual combat, keeping as method in case of future additions
func _start_turn_loop():
	# For checking if passives exist
	#for ability in PlayerData.abilities:
		#print(ability.data.id)
	PlayerData.add_item(CombatItemDb.get_item("memory_chip"), 6)
	PlayerData.add_item(CombatItemDb.get_item("beetlejuice"), 6)
	PlayerData.add_item(CombatItemDb.get_item("thick_jelly"), 6)
	PlayerData.add_item(CombatItemDb.get_item("soft_branch"), 6)
	PlayerData.add_item(CombatItemDb.get_item("ball"), 6)
	PlayerData.add_item(CombatItemDb.get_item("hypno_bone"), 6)
	_player_turn()

# TURN FUNCTIONS
# These functions play through the turn based combat logic based on entity actions

# Handles the player's turn
func _player_turn():
	# State check controlled by StageFlowController
	if combat_paused or combat_has_ended:
		return
	turn = "player"
	tutorial_text.show_hint(TutorialText.HintType.PLAYER_TURN)
	
	# Turn order button visbility settings
	is_targeting = false
	selected_enemy = null
	locked_enemy_turn_order = _get_enemy_turn_order()
	_update_enemy_turn_order_display()
	_update_turn_start_effects()
	_trigger_passives("player_turn_started", null)
	
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
	if combat_paused or combat_has_ended:
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
	_tick_ability_cooldowns() # TO-DO: check if this is best place for it
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
	if combat_has_ended:
		return
	combat_has_ended = true
	
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
		await get_tree().create_timer(0.1).timeout
		combat_end.emit(victory, rewards)
		# TO-DO Give rewards, XP based on if enemy is defeated/subdued
		# Defeated = more currency, less items + karma (makes enemies harder, will look into how)
		# Subdued = more items, medium currency
	else:
		# Player lost
		print("Player defeated! Game over.")
		
		tutorial_text.hide_text()
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
			var minigame_started = await _apply_axis_shift(selected_enemy, attack_type) # Calculates the hit damage
			if minigame_started:
				if combat_has_ended:
					return
				
				if _check_victory():
					_end_combat(true)
				else:
					_enemy_turn(),
		CONNECT_ONE_SHOT
	)
	
	# End of the turn
	player_visual.attack_finished.connect(
		func():
			if in_minigame:
				return
			
			# Check if enemy defeated
			if _check_victory():
				_end_combat(true)
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
		base *= _get_crit_multiplier() # Either 1.5 or 1.75
		# VFX effects 
		camera.pop_zoom()
		vfx.play_overlay_effects("crit", 0.4)
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
			await _start_minigame(enemy)
			return true
		return false
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
		
		return false

# Previous method reworked to use a given multiplier parameter (compact and for use with abilities/items)
func _apply_axis_shift_with_multiplier(enemy: CombatEntity, guess_type: CombatTypes.EntityType, multiplier: float):
	var enemy_visual = enemy_visuals[enemy]
	var base = player.attack_power * multiplier
	var correct = _is_correct_guess(guess_type, enemy.type)
	
	if correct:
		var resistance := 1.0
		if enemy.axis_value < 0:
			resistance = lerp(1.5, 2.5, abs(enemy.axis_ratio()))
		
		var value_shift = round_quarter(base / resistance)
		var before = enemy.axis_value
		enemy.axis_value += value_shift
		enemy.axis_value = round_quarter(min(enemy.axis_value, enemy.axis_max))
		var actual_shift = enemy.axis_value - before
		
		enemy_visual.update_axis(enemy.axis_value, actual_shift)
		enemy_visual.shake(multiplier >= 1.5)
		#vfx.play_damage_vfx(enemy_visual, abs(actual_shift), multiplier >= 1.5)
		#vfx.play_crit_feedback(enemy_visual)
		
	else:
		var off_guard = max(0.0, enemy.axis_ratio())
		var kill_multiplier := 0.5 + pow(off_guard, 2.5) * 2.0
		var value_shift = round_quarter(base * kill_multiplier)
		var before = enemy.axis_value
		enemy.axis_value -= value_shift
		enemy.axis_value = round_quarter(max(enemy.axis_value, -enemy.axis_max))
		var actual_shift = enemy.axis_value - before
		
		enemy_visual.update_axis(enemy.axis_value, actual_shift)
		enemy_visual.shake(multiplier >= 1.5)
		#vfx.play_damage_vfx(enemy_visual, abs(actual_shift), multiplier >= 1.5)
		await _resolve_enemy_state(enemy)

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
	
	minigame.play()
	var success = await minigame.completed
	in_minigame = false
	combat_paused = false
	
	await on_minigame_complete(enemy, success)
	_world_gray_out(false)
	if combat_has_ended:
		return
	
	if success and enemy.is_tamed():
		await _resolve_enemy_state(enemy)
		await player_visual.return_to_home()
		
		if _check_victory():
			_end_combat(true)
	
	await player_visual.return_to_home()
	
	#if is_instance_valid(minigame):
		#minigame.queue_free()

# Connects BaseMinigame signal to give player damage based on minigame
func _on_minigame_damage_taken(amount: float, pos: Vector2):
	_change_player_hp(-amount)
	vfx.play_overlay_effects("normal")

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
		#if enemy.is_tamed():
			#await player_visual.return_to_home()
			#if _check_victory():
				#_end_combat(true)
			#_enemy_turn()
	else:
		# Restore enemy's defense by a random amount from 20-35%, rounds it somewhat though
		var restore_ratio := randf_range(0.2, 0.35)
		enemy.axis_value = round(enemy.axis_max * restore_ratio)
		enemy_visual.update_axis(enemy.axis_value)
		print("Minigame failed. Enemy axis restored to %.1f" % enemy.axis_value)
		#if not minigame_queue_ongoing and not combat_has_ended:
			#_enemy_turn()

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
	var damage = max(0.0, base_damage * hit_mult)
	var enemy_crit = randf() <= PlayerData.get_enemy_crit_chance()
	
	# Reflexive sensors check
	var has_reflexive_sensors = PlayerData.has_ability("reflexive_sensors")
	var missed_attack = false
	
	if enemy_crit:
		damage *= 1.5
		camera.pop_zoom()
		vfx.play_overlay_effects("crit", 0.35)
		vfx.play_crit_feedback(player_visual)
		print("Enemy CRITICAL HIT!")
	
	# Reflexive sensors miss chance first
	if has_reflexive_sensors and randf() <= REFLEXIVE_SENSORS_MISS_CHANCE and not enemy_crit:
		missed_attack = true
		damage = 0.0
		vfx.spawn_feedback(player_visual, "[color=#8be9fd][wave freq=14]Miss![/wave][/color]")
		print("Enemy creature missed the attack!")
	
	# Normal block logic
	elif blocked:
		damage *= 0.5
		player_visual.play_block_success()
		camera.shake(8.0, 0.15)
		freeze_frame(0.11)
		if not enemy_crit:
			vfx.play_overlay_effects("block", 0.2)
		vfx.play_block_feedback(player_visual)
		print("Successful block!")
		# If lands 30% chance with reflexive sensors, blocks damage even more (overall damage: damage * 0.5 * 0.5)
		if has_reflexive_sensors and randf() <= REFLEXIVE_SENSORS_BLOCK_BOOST_CHANCE:
			damage *= REFLEXIVE_SENSORS_BLOCK_MULTIPLIER
			print("Player blocked damage even more!")
		
		if thick_jelly_active:
			damage *= THICK_JELLY_BLOCK_MULTIPLIER
			print("Thick Jelly reduced blocked damage even more!")
	
	# No block happened
	else:
		player_visual.play_block_fail()
		vfx.play_overlay_effects("normal")
		camera.shake(5.0, 0.12)
		freeze_frame(0.08)
		print("Failed block")

	print("Player HP is: ", player.hp)
	damage = max(0.0, damage - player.defense)
	print("Damage is: ", damage)
	_change_player_hp(-damage)

	_trigger_passives("player_damaged_by_enemy", {
		"enemy": enemy,
		"damage": damage
	})
	
	# Visual effects
	if not missed_attack:
		vfx.play_damage_vfx(player_visual, damage, false, blocked)
	if enemy_crit:
		vfx.play_damage_vfx(player_visual, damage, true)
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
	if total_chips == 0:
		_restore_chip(used_type)
		player_visual.play_restore_chip()
		return
	# 2. Random crit chance
	if randf() <= 0.10:
		_restore_chip(used_type)
		player_visual.play_restore_chip()

# ABILITY, PASSIVE & ITEM-SPECIFIC FUNCTIONS
# These functions are inherently ACTION functions, but categorised because of their niche uses

# Executes the repair ability sequence
# Here the player must collect metal objects to repair itself
func _ability_repair_sequence(ability: InventoryAbility):
	if ability.data.display_name != "Repair":
		return
	
	var collected := 0
	var max_collect := 5
	var duration := 3.5
	var timer := 0.0
	var spawn_cooldown := 0.0
	var active_objects: Array = []
	
	# Camera focus
	camera.follow(player_visual)
	await get_tree().create_timer(0.2).timeout
	camera.ability_focus_on_player(player_visual, Vector2(1.4, 1.4), 3.5)
	
	tutorial_text.show_hint(TutorialText.HintType.REPAIR)
	
	# Repair game logic
	while timer < duration:
		await get_tree().process_frame
		var delta = get_process_delta_time()
		timer += delta
		spawn_cooldown -= delta
		
		# Spawn objects
		if active_objects.is_empty() && spawn_cooldown <= 0.0:
			var dir = Utils.DIR_MAP.keys().pick_random()
			var obj = vfx._spawn_repair_object(player_visual, dir)
			active_objects.append({ "node": obj, "dir": dir })
			spawn_cooldown = 0.2 * min(collected + 1, max_collect)
		
		# Input check
		for data in active_objects:
			var expected_input = Utils.OPPOSITE_INPUT[data.dir]
			
			if Input.is_action_just_pressed(expected_input):
				collected += 1
				vfx.play_overlay_effects("block")
				vfx.play_speedlines(vfx.get_vfx_color_from_string("block"))
				await vfx._absorb_object(player_visual, data.node)
				active_objects.erase(data)
				break
	
	tutorial_text.hide_text()
	for data in active_objects:
		if is_instance_valid(data.node):
			data.node.queue_free()
	
	# Healing logic after game
	collected = min(collected, max_collect)
	var heal_ratio = collected * 0.1
	var heal_amount = player.max_hp * heal_ratio
	
	_change_player_hp(heal_amount)
	vfx.spawn_damage_number(player_visual, heal_amount, false, true)
	
	await camera.reset_camera()
	await get_tree().create_timer(0.4).timeout

# Executes the multi-tame ability sequence
# Here the player must match shapes with their ghosts – the more matched makes the player deal more shift damage
func _ability_multi_tame_sequence(ability: InventoryAbility, target: CombatEntity):
	var multiplier := 1.0
	var minigame_scene = preload("res://Scenes/VFX/MultiTameScene.tscn")
	var minigame = minigame_scene.instantiate()
	minigame_layer.add_child(minigame)
	
	tutorial_text.show_hint(TutorialText.HintType.MULTITAME)
	minigame.play()
	multiplier = await minigame.finished
	minigame.queue_free()
	
	await _resolve_multi_tame_hit(target, multiplier)

# Executes the heat up ability sequence
# Here the player must press the correct keys that appear on screen at random locations; the more pressed, the more power buff the player gets
func _ability_heat_up_sequence(ability: InventoryAbility):
	var minigame_scene = preload("res://Scenes/VFX/HeatUpMinigame.tscn")
	var minigame = minigame_scene.instantiate()
	minigame_layer.add_child(minigame)
	
	camera.follow(player_visual)
	await get_tree().create_timer(0.2).timeout
	tutorial_text.show_hint(TutorialText.HintType.HEATUP)
	camera.ability_focus_on_player(player_visual, Vector2(1.3, 1.3), 5.0)

	minigame.prompt_hit.connect(
		func(pos: Vector2):
			vfx.emit_explosion_from_vector(pos, "block"),
		CONNECT_ONE_SHOT | CONNECT_DEFERRED
	)

	minigame.play()
	var power_bonus: int = await minigame.finished
	tutorial_text.hide_text()
	
	if is_instance_valid(minigame):
		minigame.queue_free()
	
	heat_up_pending_power_bonus = power_bonus
	vfx.spawn_feedback(player_visual, "[color=#e72237ff][wave freq=14]Heated up![/wave][/color]")
	vfx.spawn_damage_number(player_visual, power_bonus, true) # Power VFX
	vfx.spawn_damage_number(player_visual, HEAT_UP_DEFENSE_PENALTY, false, true) # Defense VFX
	await camera.reset_camera()
	await get_tree().create_timer(0.2).timeout

# Executes the harden ability sequence
# Here the player must press keys in a specific order; the more stages finished, the more defense boost gained
func _ability_harden_sequence(ability: InventoryAbility):
	var minigame_scene = preload("res://Scenes/VFX/HardenMinigame.tscn")
	var minigame = minigame_scene.instantiate()
	minigame_layer.add_child(minigame)
	tutorial_text.show_hint(TutorialText.HintType.HARDEN)
	
	minigame.play()
	var defense_bonus: float = await minigame.finished
	tutorial_text.hide_text()
	
	if is_instance_valid(minigame):
		minigame.queue_free()
	
	# Activates immediately after use
	harden_active = true
	harden_defense_bonus = defense_bonus
	harden_turns_remaining = 1
	_sync_player_stats()
	
	vfx.spawn_feedback(player_visual, "[color=#3d9feb][wave freq=14]Harden applied![/wave][/color]")
	vfx.spawn_damage_number(player_visual, defense_bonus, false, true)
	

# Processes the hit from the Multi-tame ability after the action sequence has been processed
func _resolve_multi_tame_hit(target: CombatEntity, multiplier: float):
	var affected = _get_multi_tame_targets(target) # All adjacent targets (including the target itself)
	if affected.is_empty():
		return
	
	tutorial_text.hide_text()
	var target_visual = enemy_visuals[target]
	var ball = await vfx.play_multi_tame_ball(player_visual, target_visual) # Ball hits the target
	for enemy in affected:
		if enemy_visuals.has(enemy): # Check just in case visuals are inactive or not
			var visual = enemy_visuals[enemy]
			visual.hop(2)
			vfx.play_damage_vfx(visual, player.attack_power * multiplier, multiplier >= 1.5)
			vfx.play_multihit_feedback(visual)
	
	await vfx.bounce_and_fade_ball(ball, target_visual.global_position) # After ball disappears, axis shifts are applied
	
	for enemy in affected:
		_apply_axis_shift_with_multiplier(enemy, selected_ability_tame_type, multiplier)
	await _resolve_pending_minigames()

# Scratchy frame passive ability: damages the creature for the same amount of damage they dealt to the player (on one side of the axis)
func _passive_scratchy_frame(event: String, context):
	var enemy: CombatEntity = context.get("enemy")
	var damage: float = context.get("damage", 0.0)
	
	if enemy == null:
		return
	if damage <= 0.0:
		return
	if enemy.is_killed() or enemy.is_tamed():
		return
	if is_zero_approx(enemy.axis_value):
		return
	
	var reflect_amount = _get_scratchy_frame_reflect_amount(enemy, damage)
	if reflect_amount <= 0.0:
		return
	
	_apply_scratchy_frame_reflect(enemy, reflect_amount)

# Microbots passive ability: every two turns heals the player for 10% max hp + rolls a 20% chance to restore a random chip
func _passive_microbots():
	microbots_turn_counter += 1
	if microbots_turn_counter >= 2:
		microbots_turn_counter = 0
	
		var heal_amount = max(1.0, player.max_hp * MICROBOTS_HEAL_RATIO)
		_change_player_hp(heal_amount)
		vfx.spawn_damage_number(player_visual, heal_amount, false, true)
		print("Microbots healed player damage by ", heal_amount, ", player now at ", player.hp)
		
		if randf() <= MICROBOTS_CHIP_RESTORE_CHANCE:
			var available_types = [
				CombatTypes.EntityType.SKY,
				CombatTypes.EntityType.EARTH,
				CombatTypes.EntityType.WATER
			]
			var restored_type = available_types.pick_random()
			_restore_chip(restored_type)
			vfx.spawn_feedback(player_visual, "[color=#eff238][wave freq=14]%s restored![/wave][/color]" % CombatTypes.guess_type_to_string(restored_type))

# Heals the player for a random amount between 20-50%
func _item_beetle_juice_sequence(inventory_item: InventoryItem, target = null):
	var heal_ratio := randf_range(0.20, 0.50)
	var heal_amount := round_quarter(player.max_hp * heal_ratio)
	_change_player_hp(heal_amount)
	print("Healed for ", heal_amount)
	vfx.spawn_damage_number(player_visual, heal_amount, false, true)

# Restores 1 or 2 random chips for the player
func _item_memory_chip_sequence(item: InventoryItem, target):
	var restore_count := randi_range(1, 2)
	var restored_type
	var possible_types = [
		CombatTypes.EntityType.SKY,
		CombatTypes.EntityType.EARTH,
		CombatTypes.EntityType.WATER
	]
	
	possible_types.shuffle()
	for i in range(min(restore_count, possible_types.size())):
		restored_type = possible_types[i]
		_restore_chip(restored_type)
	
	vfx.spawn_feedback(
		player_visual,
		"[color=#eff238][wave freq=14]%s restored![/wave][/color]" % CombatTypes.guess_type_to_string(restored_type)
	)

# Grants even more block power for the player for 3 turns
func _item_thick_jelly_sequence(item: InventoryItem, target):
	thick_jelly_active = true
	thick_jelly_turns_remaining = 4 # Actually 3 turns because of how combat reads effects
	vfx.spawn_feedback(player_visual, "[color=#8be9fd][wave freq=14]Jelly applied![/wave][/color]")

# Gives the player +1 power for 2 turns
func _item_soft_branch_sequence(item: InventoryItem, target):
	soft_branch_active = true
	soft_branch_power_bonus = SOFT_BRANCH_POWER_BONUS
	soft_branch_turns_remaining = 3 # Because of how combat reads effects, actually 2
	_sync_player_stats()
	
	vfx.spawn_feedback(player_visual, "[color=#eff238][wave freq=14]Power up![/wave][/color]")
	vfx.spawn_damage_number(player_visual, soft_branch_power_bonus, true)

# Throwable ball item that works like Multi-tame, but does not use chips to tame or kill: this is decided by the strength of the throw minigame
func _item_ball_sequence(item: InventoryItem, target: CombatEntity):
	var meter_scene = preload("res://Scenes/VFX/BallMinigame.tscn")
	var meter = meter_scene.instantiate()
	minigame_layer.add_child(meter)
	tutorial_text.show_hint(TutorialText.HintType.BALL)
	
	meter.play()
	var result = await meter.finished
	tutorial_text.hide_text()
	
	var intent: String = result[0]
	var multiplier: float = result[1]
	
	await player_visual.play_item_use()
	await _resolve_ball_hit(target, intent, multiplier)

# Heals 10% of player's max health for 3 turns
func _item_ice_cube_sequence(item: InventoryItem, target):
	ice_cube_active = true
	ice_cube_turns_remaining = 4
	vfx.spawn_feedback(player_visual, "[color=#8be9fd][wave freq=14]Cooling[/wave][/color]")

# Hypnotizes enemies into a random axis value, never fully tames any enemies
func _item_hypno_bone_sequence(item: InventoryItem, target):
	var alive_enemies = _get_alive_enemies()
	if alive_enemies.is_empty():
		return
	
	for enemy in alive_enemies:
		var enemy_visual = enemy_visuals.get(enemy)
		if enemy_visual == null:
			continue
		
		var old_value = enemy.axis_value
		var min_value = -enemy.axis_max + 0.25
		var max_value = enemy.axis_max - 0.25
		var new_value := randf_range(min_value, max_value)
		new_value = round_quarter(new_value)
		
		enemy.axis_value = new_value
		var actual_shift = enemy.axis_value - old_value
		enemy_visual.update_axis(enemy.axis_value, actual_shift)
		enemy_visual.shake(false)
		vfx.play_damage_vfx(enemy_visual, abs(actual_shift), false)

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
	target_mode = TargetMode.ENEMY
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

# Starts targeting the player during player turn
func start_self_targeting():
	is_targeting = true
	target_mode = TargetMode.SELF
	player_visual.show_target_arrow()
	tutorial_text.show_hint(TutorialText.HintType.PLAYER_SELECT)

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
	is_targeting = false # Reseting for next turn
	
	# Hiding UI and locking input from it
	_clear_enemy_turn_order_visuals()
	player_turn_ui.hide_player_turn_ui()
	player_turn_ui.lock_input()
	
		# Matches targeting state for UI
	match target_mode:
		TargetMode.ENEMY: # Player is targeting creature(s)
			if selected_enemy:
				enemy_visuals[selected_enemy].hide_target_arrow()
				if item_being_used:
					_execute_item(selected_enemy)
					return
				if ability_being_used:
					_execute_ability(selected_enemy)
					return
				
				player_attack(selected_attack_type)
				return
		
		TargetMode.SELF: # Player is targeting itself
			player_visual.hide_target_arrow()
			if item_being_used:
				_execute_item(player)
				return
			if ability_being_used:
				_execute_ability(player)
				return
	
	target_mode = TargetMode.NONE

# Executes the ability when target has been selected
func _execute_ability(target):
	var ability = ability_being_used
	_use_ability(ability) # Sets cooldown variables
	await player_visual.play_ability_start()
	await ability.data.execute.call(self, ability, target) # Calls the ability's function inside CombatManager
	await player_visual.play_ability_end()
	ability_being_used = null
	
	if combat_has_ended:
		return
	
	if _check_victory():
		_end_combat(true)
		return
	
	_enemy_turn()

func _execute_item(target):
	tutorial_text.hide_text()
	var item = item_being_used
	if item == null:
		return
	
	if item.data.id == "ball":
		await item.data.use_effect.call(self, item, target)
	else:
		await player_visual.play_item_use()
		await item.data.use_effect.call(self, item, target)
	
	var item_index := PlayerData.items.find(item)
	if item_index != -1:
		PlayerData.use_item(item_index, self)
	item_being_used = null
	await player_turn_ui._build_items_ui()
	
	if combat_has_ended:
		return
	
	if _check_victory():
		_end_combat(true)
		return
	
	_enemy_turn()

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

# Selects an ability and sets it to be used in the player turn
func _on_ability_selected(ability: InventoryAbility):
	if turn != "player":
		return
	ability_being_used = ability
	
	match ability.data.use_mode:
		AbilityData.UseMode.STANDARD:
			player_turn_ui._hide_menu("abilities")
			_start_ability_logic(ability) # Ability's cooldown is set after use and enemy turn starts
		
		AbilityData.UseMode.TAME_STYLE:
			ability_tame_select_active = true
			player_turn_ui.selecting_tame_for_ability = true
			player_turn_ui.start_ability_tame_select()

func _on_ability_tame_type_selected(tame_type: CombatTypes.EntityType):
	if not ability_being_used:
		return
	
	selected_ability_tame_type = tame_type
	PlayerData.consume_guess(tame_type)
	player_turn_ui.stop_ability_tame_select()
	player_turn_ui._hide_menu("attack")
	
	player_turn_ui._start_targeting()
	start_target_selection()

func _on_cancel_ability_tame_select():
	ability_being_used = null
	selected_ability_tame_type = CombatTypes.EntityType.NONE
	ability_tame_select_active = false
	target_mode = TargetMode.NONE
	is_targeting = false

func _on_item_selected(item: InventoryItem):
	if turn != "player":
		return
	
	item_being_used = item
	match item.data.target_type:
		ItemData.TargetType.ENEMY:
			player_turn_ui._hide_menu("items")
			player_turn_ui._start_targeting("items")
			start_target_selection()
		
		ItemData.TargetType.SELF:
			player_turn_ui._hide_menu("items")
			player_turn_ui._start_self_targeting("items")
			start_self_targeting()

# Moves back from target selection to previous state (handled by PlayerTurnUI)
func _cancel_target_selection():
	if not is_targeting:
		return
	
	is_targeting = false
	target_mode = TargetMode.NONE
	selected_enemy = null
	target_index = 0
	
	# Hides all enemy arrows and defaults selected enemy and index
	for v in enemy_visuals.values():
		v.hide_target_arrow()
	player_visual.hide_target_arrow()
	
	_update_enemy_turn_order_display()
	tutorial_text.show_hint(TutorialText.HintType.PLAYER_TURN)
	if ability_being_used and selected_ability_tame_type != CombatTypes.EntityType.NONE:
		PlayerData.add_guesses(selected_ability_tame_type, 1)
	
	# Cancels out and resets accordingly 
	ability_being_used = null
	selected_ability_tame_type = CombatTypes.EntityType.NONE
	ability_tame_select_active = false
	player_turn_ui.selecting_tame_for_ability = false
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
	var total_currency = 0
	var killed_count := 0
	var has_enamor = PlayerData.has_ability("enamor")
	
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
			killed_count += 1
			max_currency = half_hp
			min_currency = max(0, max_currency + 2)
		elif enemy.is_tamed():
			min_currency = half_hp
			max_currency = min_currency + 2
		else:
			continue # Should not be possible to reach this point
		
		var gained_currency := randi_range(min_currency, max_currency)
		var enamor_chance = enemy.is_tamed() and has_enamor and randf() <= ENAMOR_DOUBLE_REWARD_CHANCE
		
		# Enamor chance to double a tamed creature's rewards
		if enamor_chance:
			gained_currency *= 2
		
		total_currency += gained_currency
	
	PlayerData.currency += total_currency
	var item_rewards := _roll_tamed_enemy_drops()
	_apply_human_at_heart(killed_count)
	_apply_karma_and_outcome_tracking()
	vfx._update_karma_overlay()
	print("Currency right now: ", PlayerData.currency)
	
	return {
		"currency": total_currency,
		"items": item_rewards
		}

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

	print("Chip restored for: ", type, "!")
	player_turn_ui.update_guess_display()

# Resyncing player stats from possible previous combats
func _sync_player_stats():
	player.load_from_player()
	
	if heat_up_active:
		player.attack_power += heat_up_power_bonus
		player.defense -= HEAT_UP_DEFENSE_PENALTY
	
	if harden_active:
		player.defense += harden_defense_bonus
	
	if soft_branch_active:
		player.attack_power += soft_branch_power_bonus
	
	player.hp = clamp(player.hp, 0.0, player.max_hp)
	PlayerData.hp = clamp(PlayerData.hp, 0.0, PlayerData.max_hp)
	player_visual.update_hp(player.hp, player.max_hp)

# Progresses all player ability cooldowns
func _tick_ability_cooldowns():
	for ability in PlayerData.abilities:
		if ability.just_used:
			ability.just_used = false
			continue
		
		if ability.cooldown > 0:
			ability.cooldown -= 1

# Uses the player's passive abilities in specific places
# Always triggers passives at correct places in combat, but only actually uses them if the player has that passive
func _trigger_passives(event: String, context):
	for ability in PlayerData.abilities:
		if not ability.is_passive():
			continue
		
		var passive: PassiveData = ability.data
		_handle_passive_trigger(passive, event, context)

# Calls the respective passive ability's function based on event and context
func _handle_passive_trigger(passive: PassiveData, event: String, context):
	match passive.id:
		"scratchy_frame":
			if event == "player_damaged_by_enemy":
				_passive_scratchy_frame(event, context)
		"microbots":
			if event == "player_turn_started":
				_passive_microbots()

# Sets the player's ability by given AbilityData (makes it used)
func _use_ability(ability):
	ability.cooldown = ability.data.cooldown_max
	ability.just_used = true

# Once an ability has been selected, its specific targeting logic will be used
func _start_ability_logic(ability: InventoryAbility):
	if turn != "player":
		return
	
	ability_being_used = ability
	
	match ability.data.target_type:
		AbilityData.TargetType.ENEMY:
			player_turn_ui._start_targeting()
			start_target_selection()
		AbilityData.TargetType.SELF:
			player_turn_ui._start_self_targeting()
			start_self_targeting()

# Resets all of the player's cooldowns at the start of combat
func _reset_ability_cooldowns():
	for ability in PlayerData.abilities:
		ability.cooldown = 0
		ability.just_used = false

# Gets and returns targets for Multi-tame (including adjacent ones)
func _get_multi_tame_targets(main_target: CombatEntity) -> Array[CombatEntity]:
	var result: Array[CombatEntity] = []
	var idx := enemies.find(main_target)
	if idx == -1:
		return result
	
	for i in range(idx - 1, idx + 2):
		if i < 0 or i >= enemies.size():
			continue
	
		var e = enemies[i]
		if e.is_killed() or e.is_tamed():
			continue
		
		result.append(e)
	
	return result

# Consecutive minigame logic for abilities like Multi-tame
func _resolve_pending_minigames():
	minigame_queue_ongoing = true
	var ready: Array[CombatEntity] = []
	for enemy in locked_enemy_turn_order:
		if enemy.is_minigame_ready() and not enemy.is_tamed() and not enemy.is_killed():
			ready.append(enemy)
	
	for enemy in ready:
		if enemy.is_killed() or enemy.is_tamed():
			continue
		if not enemy.is_minigame_ready():
			continue
		await _start_minigame(enemy)
		
		if combat_has_ended:
			minigame_queue_ongoing = false
			return
	
	minigame_queue_ongoing = false
	
	if combat_has_ended:
		return
	
	if _check_victory():
		_end_combat(true)
		return
	_enemy_turn()

func _update_turn_start_effects():
	# Heat Up start: activates on the next player turn
	if heat_up_pending_power_bonus > 0:
		heat_up_active = true
		heat_up_power_bonus = heat_up_pending_power_bonus
		heat_up_pending_power_bonus = 0
		heat_up_turns_remaining = 2
		_sync_player_stats()
		print("Heat Up active! +%d power, -%.1f defense for %d turns"
			% [heat_up_power_bonus, HEAT_UP_DEFENSE_PENALTY, heat_up_turns_remaining])
	
	# Heat Up when active: starts decreasing until inactive
	elif heat_up_active:
		if heat_up_turns_remaining > 1:
			heat_up_turns_remaining -= 1
			print("Heat Up continues. %d turn left." % heat_up_turns_remaining)
		else:
			print("Heat Up ended.")
			vfx.spawn_feedback(player_visual, "[color=#3d9feb][wave freq=14]Cooled down[/wave][/color]")
			heat_up_active = false
			heat_up_power_bonus = 0
			heat_up_turns_remaining = 0
			_sync_player_stats()
	
	# Harden: already active on use, so here is just the tick/removal
	if harden_active:
		if harden_turns_remaining > 0:
			harden_turns_remaining -= 1
		if harden_turns_remaining <= 0:
			print("Harden ended.")
			harden_active = false
			harden_defense_bonus = 0.0
			harden_turns_remaining = 0
			vfx.spawn_feedback(player_visual, "[color=#e72237ff][wave freq=14]Harden ended[/wave][/color]")
			_sync_player_stats()
	
		# Thick Jelly: grants temporary stronger blocks
	if thick_jelly_active:
		if thick_jelly_turns_remaining > 0:
			thick_jelly_turns_remaining -= 1
		
		if thick_jelly_turns_remaining <= 0:
			thick_jelly_active = false
			vfx.spawn_feedback(player_visual, "[color=#e72237ff][wave freq=14]Jelly used up[/wave][/color]")
			_sync_player_stats()
	
	# Soft Branch: temporary +1 power for 2 turns
	if soft_branch_active:
		if soft_branch_turns_remaining > 0:
			soft_branch_turns_remaining -= 1
		
		if soft_branch_turns_remaining <= 0:
			soft_branch_active = false
			soft_branch_power_bonus = 0.0
			vfx.spawn_feedback(player_visual, "[color=#e72237ff][wave freq=14]Branch broke[/wave][/color]")
			_sync_player_stats()
	
	# Ice Cube: heals 10% max HP every turn for 3 turns
	if ice_cube_active:
		if ice_cube_turns_remaining > 0:
			var heal_amount := round_quarter(player.max_hp * ICE_CUBE_HEAL_RATIO)
			_change_player_hp(heal_amount)
			vfx.spawn_damage_number(player_visual, heal_amount, false, true)
			ice_cube_turns_remaining -= 1
		
		if ice_cube_turns_remaining <= 0:
			ice_cube_active = false
			vfx.spawn_feedback(player_visual, "[color=#8be9fd][wave freq=14]Ice melted[/wave][/color]")

# Player HP changing methods for better interaction with PlayerData
func _set_player_hp(value: float):
	player.hp = clamp(value, 0.0, player.max_hp)
	PlayerData.hp = player.hp
	player_visual.update_hp(player.hp, player.max_hp)

func _change_player_hp(amount: float):
	_set_player_hp(player.hp + amount)

# The amount of damage reflected back at the enemy with Scratchy Frame passive ability
func _get_scratchy_frame_reflect_amount(enemy: CombatEntity, incoming_damage: float) -> float:
	var margin := 0.25
	if enemy.axis_value > 0.0: # When enemy is on the tame side
		var max_allowed := (enemy.axis_max - margin) - enemy.axis_value
		return max(0.0, min(incoming_damage, max_allowed))
	
	elif enemy.axis_value < 0.0: # When enemy is on the kill side
		var max_allowed := enemy.axis_value - (-enemy.axis_max + margin)
		return max(0.0, min(incoming_damage, max_allowed))
	
	return 0.0

# Applies Scratchy Frame's damage to the enemy
func _apply_scratchy_frame_reflect(enemy: CombatEntity, amount: float):
	var enemy_visual = enemy_visuals.get(enemy)
	if enemy_visual == null:
		return
	
	var before := enemy.axis_value
	if enemy.axis_value > 0.0: # When on the tame side
		enemy.axis_value += amount
		enemy.axis_value = min(enemy.axis_value, enemy.axis_max - 0.25) # Prevents taming/killing with this ability
	else: # When on the kill side
		enemy.axis_value -= amount
		enemy.axis_value = max(enemy.axis_value, -enemy.axis_max + 0.25)
	
	enemy.axis_value = round_quarter(enemy.axis_value) # Applies damage
	var actual_shift = enemy.axis_value - before
	if is_zero_approx(actual_shift): # Does not update past damage where there is 0.25 HP left to an intent
		return
	
	enemy_visual.update_axis(enemy.axis_value, actual_shift)
	enemy_visual.shake(false)
	vfx.play_damage_vfx(enemy_visual, abs(actual_shift), false)

# Checks if the player has the Recalibration passive or not, decides multiplier based on it (1.75 with, 1.5 without)
func _get_crit_multiplier() -> float:
	return RECALIBRATION_CRIT_MULTIPLIER if PlayerData.has_ability("recalibration") else BASE_CRIT_MULTIPLIER

# Human At Heart passive ability effect method; counts enemies killed and heals the player + permanently increases power by 0.25
func _apply_human_at_heart(killed_count: int):
	if killed_count <= 0:
		return
	if not PlayerData.has_ability("human_at_heart"):
		return
	
	var total_heal := PlayerData.max_hp * HUMAN_AT_HEART_HEAL_RATIO * killed_count
	var total_power_gain := HUMAN_AT_HEART_POWER_GAIN * killed_count
	PlayerData.attack += total_power_gain
	PlayerData.hp = min(PlayerData.hp + total_heal, PlayerData.max_hp)
	print("Human At Heart: Healed for: ", total_heal)
	print("Human At Heart: Power increased by: ", total_power_gain)
	
	_sync_player_stats()
	vfx.spawn_damage_number(player_visual, total_heal, false, true)
	vfx.play_human_at_heart_feedback(player_visual, human_at_heart_trigger_counter)
	human_at_heart_trigger_counter += 1

# Tracks all player karma and outcomes for creatures for difficulty modifiers and game ending
func _apply_karma_and_outcome_tracking():
	var gained_karma := 0
	for enemy in enemies:
		if enemy.is_killed():
			gained_karma += int(enemy.max_hp * enemy.trust_max)
			PlayerData.record_killed_creature(enemy.id)
		elif enemy.is_tamed():
			PlayerData.record_tamed_creature(enemy.id)
	
	PlayerData.karma += gained_karma
	
	if gained_karma > 0:
		print("Karma gained: ", gained_karma)
		print("Total karma: ", PlayerData.karma)

# Adds a reward item to the _generate_rewards return dictionary
func _add_reward_item(result: Array, item_data: ItemData, amount := 1):
	for entry in result:
		if entry.id == item_data.id:
			entry.amount += amount
			return
	
	result.append({
		"id": item_data.id,
		"name": item_data.display_name,
		"icon": item_data.icon,
		"amount": amount
	})

# Rolls specific item drops for creatures with help from previous method
func _roll_tamed_enemy_drops() -> Array:
	var item_rewards: Array = []
	for enemy in enemies:
		if not enemy.is_tamed():
			continue
		
		var drop_pool: Array = EnemyDatabase.get_drop_item_ids(enemy.id)
		if drop_pool.is_empty():
			continue
		
		var picked_id: String = drop_pool.pick_random()
		var item_data: ItemData = CombatItemDb.get_item(picked_id)
		if item_data == null:
			continue
		
		var added := PlayerData.add_item(item_data, 1)
		if added:
			_add_reward_item(item_rewards, item_data, 1)
	
	return item_rewards

# Handles the ball item's hit logic: intent-specific, so even if two different types of creatures are hit, they will both move towards kill/tame at the same time
func _resolve_ball_hit(target: CombatEntity, intent: String, multiplier: float):
	var affected = _get_multi_tame_targets(target)
	if affected.is_empty():
		return

	var target_visual = enemy_visuals[target]
	var ball = await vfx.play_multi_tame_ball(player_visual, target_visual, true)
	for enemy in affected:
		if enemy_visuals.has(enemy):
			var visual = enemy_visuals[enemy]
			visual.hop(2)
			vfx.play_multihit_feedback(visual)

	await vfx.bounce_and_fade_ball(ball, target_visual.global_position)
	for enemy in affected:
		var guess_type = _get_ball_guess_type_for_enemy(enemy, intent)
		await _apply_axis_shift_with_multiplier(enemy, guess_type, multiplier)

	await _resolve_pending_minigames()

# Returns the type that the ball will apply to a creature after the ball minigame
func _get_ball_guess_type_for_enemy(enemy: CombatEntity, intent: String) -> CombatTypes.EntityType:
	if intent == "tame":
		return enemy.type
	
	return Utils._get_wrong_guess_type(enemy.type)

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
