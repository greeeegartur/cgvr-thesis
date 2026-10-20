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
const VICTORY_HOLD := 0.2 # Seconds the camera stays in the encounter after a Ball or Multi-Tame ends it
var victory_delay := 0.0 # How long the camera stays in the encounter before the victory camera (set after a Ball or Multi-Tame)
var current_target_reach := 0 # Creatures hit on each side of the main target by the action being targeted
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

# Player block window variables for handling blocking logic
var last_block_press_time = -1.0
var current_block_window = Vector2.ZERO
var block_on_cooldown = false
const BLOCK_COOLDOWN = 0.45
const BLOCK_INPUT_LOCKOUT_MSEC := 250 # Cooldown in-between blocks
var last_block_input_msec := -1000
var enemy_attack_started_handlers: Dictionary = {}
var enemy_attack_hit_handlers: Dictionary = {}
var enemy_attack_finished_handlers: Dictionary = {}

# Crit multipliers (for Recalibration effect)
const HIT_RETURN_DELAY := 0.4 # After a hit that did not tame, before the Droid walks home
var tame_sequence: TameSequence
var sequence_chip_roll := false

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

# Tutorial-specific variables
signal tutorial_attack_resolved(critical: bool, minigame_started: bool)
signal tutorial_minigame_started(minigame)
signal tutorial_minigame_finished(success: bool)

var tutorial_mode := false
var tutorial_inputs_locked := false
var last_attack_was_critical := false
var last_attack_started_minigame := false
var last_minigame_success := false

# Quick tame reward bonus (creature tamed before its first turn)
const QUICK_TAME_MAX_BONUS_CURRENCY := 3
const QUICK_TAME_BONUS_ITEMS := 1

# Creature-specific variables and constants
const DUCK_TYPE_REVEAL_DURATION := 1.45
const DUCK_TYPE_COLORS := {
	CombatTypes.EntityType.SKY: Color("f7ff3c"),
	CombatTypes.EntityType.EARTH: Color("8b5a2b"),
	CombatTypes.EntityType.WATER: Color("4da6ff")
}

# Ability/passive/item specific variables
# Heat Up effects
const HIT_STOP_SCALE := 0.05 # Time scale during a hit-stop
const HIT_STOP_NORMAL := 0.06
const HIT_STOP_CRIT := 0.12
const HIT_STOP_LANDING := 0.04 # A Perfect landing of a tame icon
const HIT_STOP_BLOCK := 0.10
const HIT_STOP_HURT := 0.10
var hit_stop_id := 0
const WORLD_DIM_ALPHA := 0.5 # How dark the world gets during a dream (black over it)
const SHOP_DIM_Z := 5 # Above the creatures (z 1 to 3), below the Droid during the shop
var shop_dim_rect: ColorRect
var player_base_z := 0
var dim_rect: ColorRect
var betrayal_visual: Node2D = null # Multi-hit: the creature furthest on the tame side that was just turned on
var betrayal_axis := 0.0
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
const MICROBOTS_HEAL_RATIO := 0.20
const MICROBOTS_CHIP_RESTORE_CHANCE := 0.30

# Reflexive Sensors effects
const REFLEXIVE_SENSORS_MISS_CHANCE := 0.1
const REFLEXIVE_SENSORS_BLOCK_BOOST_CHANCE := 0.35
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
	tame_sequence = TameSequence.new()
	add_child(tame_sequence)
	await _setup_ui()
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
		if not player_visual.is_node_ready():
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
	_check_slot_order()
	
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
	if not ui.is_node_ready():
		await ui.ready

	ui.setup(self)
	
	# PLAYER
	# Player turn signals
	_connect_once(player_turn_ui.attack_type_selected, _on_attack_selected)
	_connect_once(player_turn_ui.ability_selected, _on_ability_selected)
	_connect_once(player_turn_ui.item_selected, _on_item_selected)
	_connect_once(player_turn_ui.ability_tame_type_selected, _on_ability_tame_type_selected)
	_connect_once(player_turn_ui.cancel_ability_tame_select, _on_cancel_ability_tame_select)
	_connect_once(player_turn_ui.cycle_enemy, cycle_target)
	_connect_once(player_turn_ui.confirm_enemy, _confirm_target_selection)
	_connect_once(player_turn_ui.cancel_enemy, _cancel_target_selection)
	
	# TOP UI
	# Turn order button signal
	_connect_once(ui.turn_order_toggled, _on_turn_order_toggled)

# Connects a signal only if it is not connected yet (the UI is set up again when the player retries)
func _connect_once(signal_to_connect: Signal, target: Callable) -> void:
	if not signal_to_connect.is_connected(target):
		signal_to_connect.connect(target)

# Resets combat for new round
func _reset_combat_state():
	# Variables reset
	turn = ""
	selected_enemy = null
	current_target_reach = 0
	attack_timer_running = false
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
	enemy_attack_started_handlers.clear()
	enemy_attack_hit_handlers.clear()
	enemy_attack_finished_handlers.clear()
	
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

# If an enemy has a gimmick (like the duck, who has a new type every encounter), it will be loaded in here
func _apply_enemy_encounter_gimmicks():
	for enemy in enemies:
		if enemy.id != "duck":
			continue
		
		_randomize_duck_type(enemy)
		await _reveal_duck_type(enemy)

# Called from StageFlowController with stage specific area ids to setup entities and start turns
func _start_combat(enemy_ids):
	await _prepare_combat(enemy_ids, true)
	_start_turn_loop()

func prepare_combat_for_intro(enemy_ids):
	await _prepare_combat(enemy_ids, false)

func begin_combat_after_intro():
	await _play_enemy_intro()
	_start_turn_loop()

func _prepare_combat(enemy_ids, play_enemy_intro := true):
	# CORE BUILDING
	combat_has_ended = false
	await _setup_entities(enemy_ids)
	vfx._update_karma_overlay()
	
	if play_enemy_intro:
		await _play_enemy_intro()
	else:
		_set_enemy_visuals_visible(false)
	
	# PLAYER UI BUILDING
	_reset_ability_cooldowns()

func _play_enemy_intro():
	_set_enemy_visuals_visible(true)
	await animate_enemy_entry()
	_apply_enemy_encounter_gimmicks()
	await get_tree().create_timer(0.25).timeout

func _set_enemy_visuals_visible(value: bool):
	for visual in enemy_visuals.values():
		if not is_instance_valid(visual):
			continue
		
		visual.visible = value
		visual.modulate.a = 1.0 if value else 0.0

func start_tutorial_combat(enemy_ids: Array) -> CombatEntity:
	tutorial_mode = true
	combat_has_ended = false
	combat_paused = false
	print("tutorial combat: entered")
	
	print("tutorial combat: before setup entities")
	await _setup_entities(enemy_ids)
	print("tutorial combat: after setup entities")
	_reset_ability_cooldowns()
	
	locked_enemy_turn_order = _get_enemy_turn_order()
	player_turn_ui.lock_input()
	player_turn_ui.hide_player_turn_ui()
	tutorial_text.hide_text()
	
	print(enemies)
	if enemies.is_empty():
		return null
	
	return enemies[0]

# Starts the actual combat, keeping as method in case of future additions
func _start_turn_loop():
	# For checking if passives exist
	#for ability in PlayerData.abilities:
		#print(ability.data.id)
	#PlayerData.add_ability(AbilityDb.get_ability("multitame"))
	#PlayerData.add_ability(AbilityDb.get_ability("harden"))
	#PlayerData.add_ability(AbilityDb.get_ability("heatup"))
	#PlayerData.add_ability(AbilityDb.get_ability("repair"))
	#PlayerData.add_item(CombatItemDb.get_item("ball"), 2)
	#PlayerData.add_item(CombatItemDb.get_item("memory_chip"), 2)
	#PlayerData.add_item(CombatItemDb.get_item("soft_branch"), 2)
	#PlayerData.add_item(CombatItemDb.get_item("thick_jelly"), 2)
	#PlayerData.add_item(CombatItemDb.get_item("beetlejuice"), 2)
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
	victory_delay = 0.0
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
	if tutorial_mode:
		combat_has_ended = true
		turn = ""
		player_turn_ui.hide_player_turn_ui()
		tutorial_text.hide_text()
		player_turn_ui.lock_input()
		return
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

# The player's attacking logic: the Droid walks to the creature, the tame timing sequence runs (shadow icons, Z presses), then the damage is applied once
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
	
	var target := selected_enemy
	var enemy_visual = enemy_visuals[target]
	player_visual.attack_position = _get_player_attack_position(enemy_visual)
	
	# Camera settings
	camera.frame_group([player_visual, enemy_visual], 0.35, CombatCamera.ZOOM_ACTION.x, CombatCamera.ACTION_LOWER) # A little closer while taming, with the Droid and its target both in view
	
	# The sequence reads Z itself, so the Droid's own action signal stays off
	player_visual.set_input_enabled(false)
	await player_visual.walk_to_target()
	
	# The icons: every press makes the Droid strike a pose; the results decide the multiplier and the chip roll
	_connect_once(tame_sequence.pressed, player_visual.pose_on_press)
	_connect_once(tame_sequence.icon_judged, _on_tame_icon_judged)
	tutorial_text.show_hint(TutorialText.HintType.TAME_TIMING, enemy_visual)
	var results: Array = await tame_sequence.play(enemy_visual, player_visual, vfx.particle_layer, camera)
	tutorial_text.hide_text()
	var multiplier := TameSequence.multiplier(results, PlayerData.has_ability("recalibration"))
	sequence_chip_roll = TameSequence.roll_chip(results)
	last_attack_was_critical = results.count(TameSequence.Result.PERFECT) >= 2 # For the tutorial
	print("Tame sequence: ", results, " multiplier ", multiplier)
	if results.count(TameSequence.Result.MISS) == results.size():
		player_visual.play_shrug() # A full fail is met with a small shrug, no screen effects
	tame_sequence.clear() # The icons fade out while the damage and the feedback start at once
	
	var minigame_started = await _apply_axis_shift(target, attack_type, multiplier) # Calculates the hit damage
	tame_sequence.clear()
	if minigame_started:
		if combat_has_ended:
			return
		if _check_victory():
			_end_combat(true)
		else:
			_enemy_turn()
		return
	
	# No dream: a short beat, then the Droid walks home and the turn ends
	await get_tree().create_timer(HIT_RETURN_DELAY).timeout
	await player_visual.return_to_home()
	if in_minigame:
		return
	if tutorial_mode:
		tutorial_attack_resolved.emit(last_attack_was_critical, last_attack_started_minigame)
		player_visual.set_input_enabled(false)
		return
	if _check_victory():
		_end_combat(true)
	else:
		_enemy_turn()

# Every judged icon gets its feedback: a Perfect locks in with a small star burst, a tiny hit-stop and a stun jitter, the others only show their text
func _on_tame_icon_judged(_index: int, result: int, icon: TameIcon, _count: int) -> void:
	var enemy_visual: EnemyVisual = enemy_visuals[selected_enemy]
	var at := icon.spot + Vector2(-48, -26)
	match result:
		TameSequence.Result.PERFECT:
			StarBurst.play(vfx.particle_layer, icon.spot, StarBurst.Preset.LANDING)
			vfx.play_tier_feedback(at, ActionFeedback.Tier.PERFECT)
			_hit_impact(enemy_visual, HIT_STOP_LANDING)
		TameSequence.Result.GOOD:
			vfx.play_tier_feedback(at, ActionFeedback.Tier.GOOD)
		TameSequence.Result.TRY:
			vfx.play_tier_feedback(at, ActionFeedback.Tier.TRY)
		_:
			vfx.play_tier_feedback(at, ActionFeedback.Tier.MISS)

# Processes the player's hit to shift the enemy's axis bar in a specific direction (kill, left or tame, right)
func _apply_axis_shift(enemy: CombatEntity, guess_type: CombatTypes.EntityType, multiplier := 1.0):
	var enemy_visual = enemy_visuals[enemy]
	
	# The sequence's multiplier is applied once to the base; the shift is rounded once at the end
	var base = player.attack_power * multiplier
	var critical: bool = multiplier >= TameSequence.MULT_ALL_PERFECT # An all-perfect sequence gets the big impact
	last_attack_started_minigame = false
	
	if critical:
		# VFX effects 
		vfx.play_overlay_effects("crit", 0.4)
		vfx.play_crit_feedback(enemy_visual)
		# Freezing frame and shaking camera for good hit feel
		camera.impact(CombatCamera.Impact.LARGE)
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
		var value_shift = Utils.quantize_min(base / resistance) # Just base if previous change did not apply
		var before = enemy.axis_value
		enemy.set_axis(enemy.axis_value + value_shift) # Quantized, kept on the bar and snapped to tame when one step away
		var actual_shift = enemy.axis_value - before
		
		# Visual effects
		enemy_visual.shake(critical)
		enemy_visual.update_axis(enemy.axis_value, actual_shift)
		vfx.play_damage_vfx(enemy_visual, abs(actual_shift), critical, false, multiplier, true) # Damage number, particles
		if critical:
			_hit_impact(enemy_visual, HIT_STOP_CRIT) # The Perfect landings already gave the small hit-stops
		if multiplier >= TameSequence.MULT_TRIED:
			camera.impact(CombatCamera.Impact.MEDIUM)
		
		# Restores a chip when the sequence rolled one
		_restore_chip_after_sequence(guess_type)
		
		print("Enemy gets %.2f tame progress, now axis line is %.2f and %.2f away from tame." % [value_shift, enemy.axis_value, enemy.max_hp - value_shift])
		
		# Checks if enemy's axis value is at max, if it is, starts minigame
		if enemy.is_minigame_ready():
			print("Enemy trust level reached! Triggering minigame now.")
			last_attack_started_minigame = true
			await _start_minigame(enemy)
			return true
		return false
	else:
		# Moves towards kill side on the left based on how off guard the enemy is
		# Off guard is calculated for an exponential multiplier that increases axis movement the more "off guard" an enemy is
		# So 1) guessing correct once and 2) then guessing wrong will increase damage more than just guessing wrong
		var off_guard = max(0.0, enemy.axis_ratio())
		var kill_multiplier := 0.5 + pow(off_guard, 2.5) * 2.35
		
		# Damage calculation
		var value_shift = Utils.quantize_min(base * kill_multiplier) # Kill multiplier will just be 0.5 if off_guard is 0
		var before = enemy.axis_value
		enemy.set_axis(enemy.axis_value - value_shift)
		var actual_shift = enemy.axis_value - before
		
		if before > 0.0: # The creature was on the tame side
			_play_betrayal(enemy_visual)
		
		# Visual effects
		enemy_visual.shake(critical)
		enemy_visual.update_axis(enemy.axis_value, actual_shift)
		vfx.play_damage_vfx(enemy_visual, abs(actual_shift), critical, false, multiplier)
		if critical:
			_hit_impact(enemy_visual, HIT_STOP_CRIT)
		
		# Restores a chip when the sequence rolled one
		_restore_chip_after_sequence(guess_type)
		
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
		
		var value_shift = Utils.quantize_min(base / resistance)
		var before = enemy.axis_value
		enemy.set_axis(enemy.axis_value + value_shift)
		var actual_shift = enemy.axis_value - before
		
		enemy_visual.update_axis(enemy.axis_value, actual_shift)
		enemy_visual.shake(multiplier >= 1.5)
		#vfx.play_damage_vfx(enemy_visual, abs(actual_shift), multiplier >= 1.5)
		#vfx.play_crit_feedback(enemy_visual)
		
		_try_restore_chip(guess_type, true) # Always true for Multi-tame, but might change
		
	else:
		var off_guard = max(0.0, enemy.axis_ratio())
		var kill_multiplier := 0.5 + pow(off_guard, 2.5) * 2.25
		var value_shift = Utils.quantize_min(base * kill_multiplier)
		var before = enemy.axis_value
		enemy.set_axis(enemy.axis_value - value_shift)
		var actual_shift = enemy.axis_value - before
		
		if before > 0.0:
			_note_betrayal(enemy_visual, before)
		
		enemy_visual.update_axis(enemy.axis_value, actual_shift)
		enemy_visual.shake(multiplier >= 1.5)
		#vfx.play_damage_vfx(enemy_visual, abs(actual_shift), multiplier >= 1.5)
		_try_restore_chip(guess_type, true)
		
		await _resolve_enemy_state(enemy)

# Logic for starting enemy's minigame in combat
# play_explosion is false when the explosion VFX was already played for a group of creatures (consecutive minigames)
func _start_minigame(enemy: CombatEntity, play_explosion := true):
	if not EnemyDatabase.MINIGAME_SCENES.has(enemy.minigame_id):
		push_error("Missing minigame: " + enemy.minigame_id)
		return
	
	# Enemy visual with necessary minigame data
	var enemy_visual = enemy_visuals[enemy]
	in_minigame = true
	
	# Taming visuals
	if play_explosion:
		vfx.play_subdue(enemy_visual)
	var aura := TameAura.attach(enemy_visual, 0.5 if play_explosion else 0.2) # Neon light swirls up inside the creature
	await player_visual.play_subdue()
	enemy_visual.clear_minigame_highlight() # The highlight has done its job once the minigame starts
	
	# Minigame scene instantiation
	var minigame = EnemyDatabase.MINIGAME_SCENES[enemy.minigame_id].instantiate()
	minigame.process_mode = Node.PROCESS_MODE_ALWAYS
	_world_gray_out(true) # BG grays out as minigame appears
	minigame_layer.add_child(minigame)
	
	# Minigame on-screen position settings
	minigame.set_anchors_preset(Control.PRESET_FULL_RECT)
	minigame.size = get_viewport().size
	minigame.position = Vector2.ZERO
	var glow := MinigameGlow.attach(minigame) # Neon glow around the box until the minigame ends
	
	# Minigame's damage signal
	minigame.damage_taken.connect(_on_minigame_damage_taken)
	if tutorial_mode:
		tutorial_minigame_started.emit(minigame)
	
	if not tutorial_mode:
		await MinigameCountdown.play(self, "dream_" + enemy.minigame_id) # The first time this dream appears in the run
	
	minigame.play()
	var success = await minigame.completed
	in_minigame = false
	combat_paused = false
	last_minigame_success = success
	if aura:
		aura.finish()
	if glow:
		glow.finish()
	if tutorial_mode:
		tutorial_minigame_finished.emit(success)
	
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
	_change_player_hp(-Utils.quantize_min(amount))
	vfx.play_overlay_effects("normal")
	_hit_impact(player_visual, HIT_STOP_NORMAL)

# Decides minigame outcome on minigame end
func on_minigame_complete(enemy: CombatEntity, success: bool):
	# Getting enemy visual
	var enemy_visual = enemy_visuals[enemy]
	enemy_visual.clear_minigame_highlight()
	
	if success:
		var restore_ratio := randf_range(0.2, 0.35)
		enemy.set_axis(enemy.axis_max * restore_ratio)
		enemy.trust += 1
		enemy_visual.update_axis(enemy.axis_value)
		enemy_visual.update_axis_trust() 
		vfx.play_tame_payoff(enemy_visual, true)
		enemy_visual.hop(1)
		print("Minigame success! Trust: %d / %d" % [enemy.trust, enemy.trust_max])
		#if enemy.is_tamed():
			#await player_visual.return_to_home()
			#if _check_victory():
				#_end_combat(true)
			#_enemy_turn()
	else:
		# Restore enemy's defense by a random amount from 20-35%, rounds it somewhat though
		var restore_ratio := randf_range(0.2, 0.35)
		enemy.set_axis(enemy.axis_max * restore_ratio)
		enemy_visual.update_axis(enemy.axis_value)
		vfx.play_tame_payoff(enemy_visual, false)
		print("Minigame failed. Enemy axis restored to %.1f" % enemy.axis_value)
		#if not minigame_queue_ongoing and not combat_has_ended:
			#_enemy_turn()

# Performs a single enemy's attack pattern based on existing logic
func _enemy_attack_single(enemy: CombatEntity):
	enemy.turns_taken += 1
	
	# Setting enemy attack
	var visual = enemy_visuals[enemy]
	visual.z_index = 3
	var pattern = enemy.attack_patterns.pick_random() # Picks random attack pattern assigned to the enemy
	
	# Support patterns
	if pattern.is_support:
		camera.frame_group([visual], 0.35, CombatCamera.ZOOM_ACTION.x, CombatCamera.ACTION_LOWER) # The supporting creature gets the focus too
		await _handle_support_pattern(enemy, pattern)
		# Support patterns have no attack-finished handler, so the enemy's base layer is restored here (keeps the player above it)
		if is_instance_valid(visual):
			visual.z_index = 1
		return
	
	# Setting attack position for enemy (relative to player)
	visual.attack_position = _get_enemy_attack_position(visual)
	
	# Camera controls + tutorial text visible
	camera.frame_group([player_visual, visual], 0.35, CombatCamera.ZOOM_ACTION.x, CombatCamera.ACTION_LOWER) # A little closer while blocking, with the Droid and the attacker both in view
	camera.anticipate() # Slow push toward the attacker during its wind-up
	tutorial_text.show_hint(TutorialText.HintType.BLOCK, player_visual)
	await _play_enemy_attack_pattern(enemy, visual, pattern)

# Handles support patterns respectively for each enemy, TO-DO: edit for separate enemies so anyone can pass check
func _handle_support_pattern(enemy: CombatEntity, pattern: EnemyAttackPattern):
	# First play animation
	var visual = enemy_visuals[enemy]
	await visual.play_support(pattern.animation_name)
	
	match pattern.pattern_id:
		"frog_heal": # Frog healing
			await _support_frog_heal(enemy)
			return
		
		_: # Bat spawning
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
	
	# Cleans up and/or resets previous handlers
	_disconnect_enemy_attack_handlers(enemy_visual)
	
	# Reseting block + setting hit index for block window timing
	_reset_enemy_attack_timing()
	var hit_state = {"index": 0}
	
	# Set current block window
	current_block_window = pattern.hits[0]["block_window"]
	# Setting up PlayerVisual for blocking
	player_visual.set_input_enabled(true)
	
	# Connecting with enemy visual script emitters
	var on_attack_started = func(): # Marks start of the attacking animation for block timing
		attack_time = 0.0
		attack_timer_running = true
		print("!!! DEBUG: attack timer started")
		print("!!! DEBUG: pattern duration is ", pattern.total_duration)
	
	var on_attack_hit = func(): # Hit processing logic
		var id = hit_state["index"]
		if id >= pattern.hits.size():
			return
		
		var current_hit = pattern.hits[id].duplicate(true)
		tutorial_text.hide_text() # Hides hint text
		_apply_enemy_hit(enemy, current_hit) # Works the attack's hitting logic, including the player's blocking window
		hit_state["index"] = id + 1 # If the attack has multiple hits, it'll process all of them
		
		if hit_state["index"] < pattern.hits.size():
			current_block_window = pattern.hits[hit_state["index"]]["block_window"]
	
	var on_attack_finished = func(): # Checks if combat has ended
		attack_timer_running = false
		print("!!! DEBUG: attack finished at:", "%.3f" % attack_time)
		
		enemy_visual.z_index = 1
		player_visual.set_input_enabled(false) # Reset visual layering for player attack and setting input to false
		
		_disconnect_enemy_attack_handlers(enemy_visual)
	
	enemy_attack_started_handlers[enemy_visual] = on_attack_started
	enemy_attack_hit_handlers[enemy_visual] = on_attack_hit
	enemy_attack_finished_handlers[enemy_visual] = on_attack_finished
	
	enemy_visual.attack_started.connect(on_attack_started, CONNECT_ONE_SHOT)
	enemy_visual.attack_hit.connect(on_attack_hit)
	enemy_visual.attack_finished.connect(on_attack_finished)
	
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
			current_block_window = hit.block_window
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
		camera.impact(CombatCamera.Impact.LARGE)
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
		camera.impact(CombatCamera.Impact.LARGE)
		_hit_impact(player_visual, HIT_STOP_BLOCK)
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
		camera.impact(CombatCamera.Impact.SMALL)
		_hit_impact(player_visual, HIT_STOP_HURT)
		print("Failed block")

	print("Player HP is: ", player.hp)
	damage = Utils.hit_damage(damage, player.defense) # Rounded once at the end, at least one step for any hit that deals damage
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

# Listens for player block during an enemy's attack
func _on_player_block_attempted():
	# Failsafe to check if the function is running by accident
	if turn != "enemy":
		return
	
	# Ignores presses made right after the previous one
	var now := Time.get_ticks_msec()
	if now - last_block_input_msec < BLOCK_INPUT_LOCKOUT_MSEC:
		return
	last_block_input_msec = now
	
	# The block pose always plays on a press, even if the press does not count
	player_visual.play_block_press()
	
	# Checks if block is currently on cooldown
	if block_on_cooldown:
		return
	
	# If the current hit already recorded a valid press, do not overwrite it
	if last_block_press_time >= current_block_window.x and last_block_press_time <= current_block_window.y:
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

# Starts the player's block cooldown during the enemy turn
func _start_block_cooldown():
	block_on_cooldown = true
	player_visual.set_block_cooldown(true)
	
	# Actual cooldown timer
	await get_tree().create_timer(BLOCK_COOLDOWN).timeout
	
	# After cooldown resets previous changes
	block_on_cooldown = false
	player_visual.set_block_cooldown(false)

# A quick tame is a creature tamed before it got to take a single turn
func _is_quick_tame(enemy: CombatEntity) -> bool:
	return enemy.is_tamed() and enemy.turns_taken == 0

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

# After the tame sequence: the last chip is always restored; otherwise the sequence's roll decides (one chip at most)
func _restore_chip_after_sequence(used_type: CombatTypes.EntityType):
	if PlayerData._get_total_chips() == 0 or sequence_chip_roll:
		_restore_chip(used_type)
		player_visual.play_restore_chip()
	sequence_chip_roll = false

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
	camera.ability_frame_wide(player_visual) # The whole play area stays visible so the player can see where parts come from
	
	tutorial_text.show_hint(TutorialText.HintType.REPAIR, player_visual)
	await MinigameCountdown.play(self, "ability_repair")
	
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
			
			if not PauseMenu.active and Input.is_action_just_pressed(expected_input):
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
	var heal_amount = Utils.quantize_min(player.max_hp * heal_ratio)
	
	_change_player_hp(heal_amount)
	vfx.spawn_damage_number(player_visual, heal_amount, false, true)
	vfx.play_buff_particles(player_visual, BuffParticles.Kind.HEAL)
	
	await camera.reset_camera()
	await get_tree().create_timer(0.4).timeout

# Executes the multi-tame ability sequence
# Here the player must match shapes with their ghosts – the more matched makes the player deal more shift damage
func _ability_multi_tame_sequence(ability: InventoryAbility, target: CombatEntity):
	var multiplier := 1.0
	var minigame_scene = preload("res://Scenes/PlayerActions/MultiTameScene.tscn")
	var minigame = minigame_scene.instantiate()
	minigame_layer.add_child(minigame)
	for e in _get_action_targets(target, current_target_reach):
		if enemy_visuals.has(e):
			minigame.anchors.append(enemy_visuals[e])
	
	tutorial_text.show_hint(TutorialText.HintType.MULTITAME, enemy_visuals[target])
	await MinigameCountdown.play(self, "ability_multi_tame")
	minigame.play()
	multiplier = await minigame.finished
	minigame.queue_free()
	
	await _resolve_multi_tame_hit(target, multiplier)
	victory_delay = VICTORY_HOLD

# Executes the heat up ability sequence
# Here the player must press the correct keys that appear on screen at random locations; the more pressed, the more power buff the player gets
func _ability_heat_up_sequence(ability: InventoryAbility):
	var minigame_scene = preload("res://Scenes/PlayerActions/HeatUpMinigame.tscn")
	var minigame = minigame_scene.instantiate()
	minigame.anchor = player_visual
	minigame_layer.add_child(minigame)
	
	camera.follow(player_visual)
	await get_tree().create_timer(0.2).timeout
	tutorial_text.show_hint(TutorialText.HintType.HEATUP, player_visual)
	camera.ability_push_in(player_visual)

	minigame.prompt_hit.connect(
		func(pos: Vector2):
			# The key position is on screen, the particles live in the world
			vfx.emit_explosion_from_vector(get_viewport().get_canvas_transform().affine_inverse() * pos, "block"), # An explosion on every key that is hit
		CONNECT_DEFERRED
	)

	await MinigameCountdown.play(self, "ability_heat_up")
	minigame.play()
	var power_bonus: int = await minigame.finished
	tutorial_text.hide_text()
	
	if is_instance_valid(minigame):
		minigame.queue_free()
	
	heat_up_pending_power_bonus = power_bonus
	vfx.spawn_info(player_visual, "[color=#e72237]Heated up![/color]")
	vfx.spawn_damage_number(player_visual, power_bonus, true) # Power VFX
	vfx.spawn_damage_number(player_visual, HEAT_UP_DEFENSE_PENALTY, false, true) # Defense VFX
	await camera.reset_camera()
	await get_tree().create_timer(0.2).timeout

# Executes the harden ability sequence
# Here the player must press keys in a specific order; the more stages finished, the more defense boost gained
func _ability_harden_sequence(ability: InventoryAbility):
	var minigame_scene = preload("res://Scenes/PlayerActions/HardenMinigame.tscn")
	var minigame = minigame_scene.instantiate()
	minigame.anchor = player_visual
	minigame_layer.add_child(minigame)
	camera.ability_push_in(player_visual, Vector2(1.25, 1.25))
	tutorial_text.show_hint(TutorialText.HintType.HARDEN, player_visual)
	
	await MinigameCountdown.play(self, "ability_harden")
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
	
	vfx.spawn_info(player_visual, "[color=#3d9feb]Harden applied![/color]")
	vfx.spawn_damage_number(player_visual, defense_bonus, false, true)
	vfx.play_buff_particles(player_visual, BuffParticles.Kind.DEFENSE_UP)
	await camera.reset_camera()
	

# Processes the hit from the Multi-tame ability after the action sequence has been processed
func _resolve_multi_tame_hit(target: CombatEntity, multiplier: float):
	var affected = _get_action_targets(target, current_target_reach) # All adjacent targets (including the target itself)
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
			_hit_impact(visual, HIT_STOP_NORMAL)
			vfx.play_multihit_feedback(visual)
	
	await vfx.bounce_and_fade_ball(ball, target_visual.global_position) # After ball disappears, axis shifts are applied
	
	for enemy in affected:
		_apply_axis_shift_with_multiplier(enemy, selected_ability_tame_type, multiplier)
	_flush_betrayal()
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
	
		var heal_amount = Utils.quantize_min(max(1.0, player.max_hp * MICROBOTS_HEAL_RATIO))
		_change_player_hp(heal_amount)
		vfx.spawn_damage_number(player_visual, heal_amount, false, true)
		vfx.play_buff_particles(player_visual, BuffParticles.Kind.HEAL)
		print("Microbots healed player damage by ", heal_amount, ", player now at ", player.hp)
		
		if randf() <= MICROBOTS_CHIP_RESTORE_CHANCE:
			var available_types = [
				CombatTypes.EntityType.SKY,
				CombatTypes.EntityType.EARTH,
				CombatTypes.EntityType.WATER
			]
			var restored_type = available_types.pick_random()
			_restore_chip(restored_type)
			vfx.spawn_info(player_visual, "[color=#e8e8e8]Chip restored![/color]\n%s" % CombatTypes.type_bbcode(restored_type))

# Heals the player for a random amount between 20-50%
func _item_beetle_juice_sequence(inventory_item: InventoryItem, target = null):
	var heal_ratio := randf_range(0.20, 0.50)
	var heal_amount := Utils.quantize_min(player.max_hp * heal_ratio)
	_change_player_hp(heal_amount)
	print("Healed for ", heal_amount)
	vfx.spawn_damage_number(player_visual, heal_amount, false, true)
	vfx.play_buff_particles(player_visual, BuffParticles.Kind.HEAL)

# Restores 1 or 2 random chips for the player
func _item_memory_chip_sequence(item: InventoryItem, target):
	var restore_count := randi_range(1, 2)
	var restored_names: Array[String] = [] # Type names already colored as bbcode
	var possible_types = [
		CombatTypes.EntityType.SKY,
		CombatTypes.EntityType.EARTH,
		CombatTypes.EntityType.WATER
	]
	
	possible_types.shuffle()
	for i in range(min(restore_count, possible_types.size())):
		var restored_type = possible_types[i]
		_restore_chip(restored_type)
		restored_names.append(CombatTypes.type_bbcode(restored_type))
	
	# Shows which chips were restored, colored by type (e.g. "Chips restored!" over "Sky + Earth")
	vfx.spawn_info(
		player_visual,
		"[color=#e8e8e8]Chips restored![/color]\n%s" % " + ".join(restored_names)
	)

# Grants even more block power for the player for 3 turns
func _item_thick_jelly_sequence(item: InventoryItem, target):
	thick_jelly_active = true
	thick_jelly_turns_remaining = 4 # Actually 3 turns because of how combat reads effects
	vfx.spawn_info(player_visual, "[color=#8be9fd]Jelly applied![/color]")
	vfx.play_buff_particles(player_visual, BuffParticles.Kind.DEFENSE_UP)

# Gives the player +1 power for 2 turns
func _item_soft_branch_sequence(item: InventoryItem, target):
	soft_branch_active = true
	soft_branch_power_bonus = SOFT_BRANCH_POWER_BONUS
	soft_branch_turns_remaining = 3 # Because of how combat reads effects, actually 2
	_sync_player_stats()
	
	vfx.spawn_info(player_visual, "[color=#eff238]Power up![/color]")
	vfx.spawn_damage_number(player_visual, soft_branch_power_bonus, true)
	vfx.play_buff_particles(player_visual, BuffParticles.Kind.POWER)

# Throwable ball item that works like Multi-tame, but does not use chips to tame or kill: this is decided by the strength of the throw minigame
func _item_ball_sequence(item: InventoryItem, target: CombatEntity):
	var meter_scene = preload("res://Scenes/PlayerActions/BallMinigame.tscn")
	var meter = meter_scene.instantiate()
	meter.anchor = player_visual
	minigame_layer.add_child(meter)
	tutorial_text.show_hint(TutorialText.HintType.BALL, enemy_visuals[target])
	
	await MinigameCountdown.play(self, "item_ball")
	meter.play()
	var result = await meter.finished
	tutorial_text.hide_text()
	
	var intent: String = result[0]
	var multiplier: float = result[1]
	
	await player_visual.play_item_use()
	await _resolve_ball_hit(target, intent, multiplier)
	victory_delay = VICTORY_HOLD

# Heals 10% of player's max health for 3 turns
func _item_ice_cube_sequence(item: InventoryItem, target):
	ice_cube_active = true
	ice_cube_turns_remaining = 4
	vfx.spawn_info(player_visual, "[color=#8be9fd]Cooling[/color]")

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
		var min_value = -enemy.axis_max + Utils.AXIS_SAFE_MARGIN
		var max_value = enemy.axis_max - Utils.AXIS_SAFE_MARGIN
		var new_value := randf_range(min_value, max_value)
		
		enemy.set_axis(new_value) # Quantized; stays clear of the snap distance
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

# Debug check: the enemies list must stay in slot order, because target neighbors and cycling rely on it
func _check_slot_order():
	if not OS.is_debug_build():
		return
	for i in enemies.size():
		if i >= enemy_positions.size():
			continue
		var visual = enemy_visuals.get(enemies[i])
		if visual == null:
			continue
		if not visual.home_position.is_equal_approx(enemy_positions[i].global_position):
			push_warning("Enemy list is out of slot order at index %d" % i)

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
# Betrayal! feedback: plays once per player hit that pushes a tame-side creature toward kill
func _play_betrayal(visual: Node2D):
	vfx.play_betrayal_feedback(visual)
	freeze_frame(0.12)

# Multi-hit: remembers the creature that was furthest on the tame side, played once by _flush_betrayal
func _note_betrayal(visual: Node2D, axis_before: float):
	if betrayal_visual == null or axis_before > betrayal_axis:
		betrayal_visual = visual
		betrayal_axis = axis_before

func _flush_betrayal():
	if betrayal_visual != null and is_instance_valid(betrayal_visual):
		_play_betrayal(betrayal_visual)
	betrayal_visual = null

# A real hit-stop: the game almost stops for a moment (real seconds, so it is not stretched by its own slowdown)
func freeze_frame(time = 0.05):
	if PauseMenu.active:
		return
	hit_stop_id += 1
	var id := hit_stop_id
	Engine.time_scale = HIT_STOP_SCALE
	await get_tree().create_timer(time, true, false, true).timeout
	if id == hit_stop_id and not PauseMenu.active: # A newer hit-stop (or the pause menu) owns the time scale now
		Engine.time_scale = 1.0

# Hit-stop plus a stun jitter on whoever was hit
func _hit_impact(victim_visual: Node2D, duration: float):
	freeze_frame(duration)
	if victim_visual.has_method("stun"):
		victim_visual.stun(duration)

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
	
	# Remembers how wide the action reaches, so the preview and the hit use the same targets
	current_target_reach = _get_current_target_reach()
	_check_slot_order()
	
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
	_clear_target_markers()
	selected_enemy = enemy
	
	# Other creatures the action will hit get the small markers, the main target gets the big arrow and the count
	var affected := _get_action_targets(enemy, current_target_reach)
	for e in affected:
		if e != enemy and enemy_visuals.has(e):
			enemy_visuals[e].show_target_secondary()
	enemy_visuals[enemy].show_target_main(maxi(affected.size(), 1))
	
	# Camera frames the Droid and every creature the action affects
	var framed: Array = [player_visual]
	for e in affected:
		if enemy_visuals.has(e):
			framed.append(enemy_visuals[e])
	camera.frame_group(framed, 0.35, 0.0, CombatCamera.ACTION_LOWER)

# Hides every target preview marker on all creatures
func _clear_target_markers():
	for v in enemy_visuals.values():
		if is_instance_valid(v):
			v.clear_target_markers()

# Reach of the ability or item being targeted (0 for plain attacks)
func _get_current_target_reach() -> int:
	if ability_being_used:
		return ability_being_used.data.target_reach
	if item_being_used:
		return item_being_used.data.target_reach
	return 0

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
				_clear_target_markers()
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
	ui.refresh_player_hud() # Item amount update
	item_being_used = null
	
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
	item_being_used = null
	ability_being_used = null
	
	# Starts enemy targeting
	start_target_selection()

# Selects an ability and sets it to be used in the player turn
func _on_ability_selected(ability: InventoryAbility):
	if turn != "player":
		return
	ability_being_used = ability
	item_being_used = null
	
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
	
	ability_being_used = null
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
	
	# Hides all target markers and defaults selected enemy and index
	_clear_target_markers()
	camera.stop_follow()
	current_target_reach = 0
	player_visual.hide_target_arrow()
	
	_update_enemy_turn_order_display()
	tutorial_text.show_hint(TutorialText.HintType.PLAYER_TURN)
	if ability_being_used and selected_ability_tame_type != CombatTypes.EntityType.NONE:
		PlayerData.add_guesses(selected_ability_tame_type, 1)
	
	# Cancels out and resets accordingly 
	ability_being_used = null
	item_being_used = null
	selected_ability_tame_type = CombatTypes.EntityType.NONE
	ability_tame_select_active = false
	player_turn_ui.selecting_tame_for_ability = false
	player_turn_ui.cancel_enemy_selection()

# Decides if an enemy has been defeated by minigame or not
func _resolve_enemy_state(enemy: CombatEntity):
	var visual = enemy_visuals[enemy]

	if enemy.is_killed():
		visual.z_index = 1
		vfx.play_kill_burst(visual)
		await visual.play_defeat(false)
	elif enemy.is_tamed():
		visual.z_index = 1
		if _is_quick_tame(enemy):
			vfx.play_perfect_feedback(visual)
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
			min_currency = half_hp + 2
			max_currency = min_currency + 3
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
		
		# Quick tame bonus: taming a creature before its first turn gives up to +3 bolts
		if _is_quick_tame(enemy):
			gained_currency += randi_range(1, QUICK_TAME_MAX_BONUS_CURRENCY)
		
		total_currency += gained_currency

	PlayerData.add_currency(total_currency)
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
	
	if ui:
		ui._update_player_stats_hud()

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

# The creatures an action hits: the main target and the living creatures up to reach steps beside it in the list
# The list is in slot order (screen order); a defeated creature leaves a gap that is not skipped
# Used by both the target preview and the hit itself, so they always match
func _get_action_targets(main_target: CombatEntity, reach: int) -> Array[CombatEntity]:
	var result: Array[CombatEntity] = []
	var idx := enemies.find(main_target)
	if idx == -1:
		return result
	
	for i in range(idx - reach, idx + reach + 1):
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
	
	# When several creatures were tamed at once, all of their explosions go off before entering the dreams
	var group_explosion := ready.size() > 1
	if group_explosion:
		for enemy in ready:
			if enemy_visuals.has(enemy):
				vfx.play_subdue(enemy_visuals[enemy])
	
	for i in ready.size():
		var enemy: CombatEntity = ready[i]
		if enemy.is_killed() or enemy.is_tamed():
			continue
		if not enemy.is_minigame_ready():
			continue
		
		if group_explosion:
			# Creatures still waiting (not the completed ones) get their explosion again, then the next one is highlighted
			if i > 0:
				for j in range(i, ready.size()):
					var waiting: CombatEntity = ready[j]
					if not waiting.is_killed() and not waiting.is_tamed() and enemy_visuals.has(waiting):
						vfx.play_subdue(enemy_visuals[waiting])
			if enemy_visuals.has(enemy):
				await enemy_visuals[enemy].play_minigame_highlight()
		
		await _start_minigame(enemy, not group_explosion)
		
		if enemy_visuals.has(enemy):
			enemy_visuals[enemy].clear_minigame_highlight()
		
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
		vfx.play_buff_particles(player_visual, BuffParticles.Kind.POWER)
		vfx.play_buff_particles(player_visual, BuffParticles.Kind.DEFENSE_DOWN)
		print("Heat Up active! +%d power, -%.1f defense for %d turns"
			% [heat_up_power_bonus, HEAT_UP_DEFENSE_PENALTY, heat_up_turns_remaining])
	
	# Heat Up when active: starts decreasing until inactive
	elif heat_up_active:
		if heat_up_turns_remaining > 1:
			heat_up_turns_remaining -= 1
			print("Heat Up continues. %d turn left." % heat_up_turns_remaining)
		else:
			print("Heat Up ended.")
			vfx.spawn_info(player_visual, "[color=#3d9feb]Cooled down[/color]")
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
			vfx.spawn_info(player_visual, "[color=#e72237]Harden ended[/color]")
			_sync_player_stats()
	
		# Thick Jelly: grants temporary stronger blocks
	if thick_jelly_active:
		if thick_jelly_turns_remaining > 0:
			thick_jelly_turns_remaining -= 1
		
		if thick_jelly_turns_remaining <= 0:
			thick_jelly_active = false
			vfx.spawn_info(player_visual, "[color=#e72237]Jelly used up[/color]")
			_sync_player_stats()
	
	# Soft Branch: temporary +1 power for 2 turns
	if soft_branch_active:
		if soft_branch_turns_remaining > 0:
			soft_branch_turns_remaining -= 1
		
		if soft_branch_turns_remaining <= 0:
			soft_branch_active = false
			soft_branch_power_bonus = 0.0
			vfx.spawn_info(player_visual, "[color=#e72237]Branch broke[/color]")
			_sync_player_stats()
	
	# Ice Cube: heals 10% max HP every turn for 3 turns
	if ice_cube_active:
		if ice_cube_turns_remaining > 0:
			var heal_amount := Utils.quantize_min(player.max_hp * ICE_CUBE_HEAL_RATIO)
			_change_player_hp(heal_amount)
			vfx.spawn_damage_number(player_visual, heal_amount, false, true)
			vfx.play_buff_particles(player_visual, BuffParticles.Kind.HEAL)
			ice_cube_turns_remaining -= 1
		
		if ice_cube_turns_remaining <= 0:
			ice_cube_active = false
			vfx.spawn_info(player_visual, "[color=#8be9fd]Ice melted[/color]")

# Player HP changing methods for better interaction with PlayerData
func _set_player_hp(value: float):
	player.hp = clampf(Utils.quantize(value), 0.0, player.max_hp) # HP always sits on the quarter grid
	PlayerData.hp = player.hp
	player_visual.update_hp(player.hp, player.max_hp)

func _change_player_hp(amount: float):
	_set_player_hp(player.hp + amount)

# The amount of damage reflected back at the enemy with Scratchy Frame passive ability
func _get_scratchy_frame_reflect_amount(enemy: CombatEntity, incoming_damage: float) -> float:
	var margin := Utils.AXIS_SAFE_MARGIN # Reflect never reaches the snap distance, so it cannot tame or kill
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
		enemy.set_axis(min(enemy.axis_value + amount, enemy.axis_max - Utils.AXIS_SAFE_MARGIN)) # Prevents taming/killing with this ability
	else: # When on the kill side
		enemy.set_axis(max(enemy.axis_value - amount, -enemy.axis_max + Utils.AXIS_SAFE_MARGIN))

	var actual_shift = enemy.axis_value - before
	if is_zero_approx(actual_shift): # Does not update past damage where there is 0.25 HP left to an intent
		return
	
	enemy_visual.update_axis(enemy.axis_value, actual_shift)
	enemy_visual.shake(false)
	vfx.play_damage_vfx(enemy_visual, abs(actual_shift), false)

# Human At Heart passive ability effect method; counts enemies killed and heals the player + permanently increases power by 0.25
func _apply_human_at_heart(killed_count: int):
	if killed_count <= 0:
		return
	if not PlayerData.has_ability("human_at_heart"):
		return
	
	var total_heal := Utils.quantize_min(PlayerData.max_hp * HUMAN_AT_HEART_HEAL_RATIO * killed_count)
	var total_power_gain := HUMAN_AT_HEART_POWER_GAIN * killed_count
	PlayerData.attack += total_power_gain
	PlayerData.hp = min(Utils.quantize(PlayerData.hp + total_heal), PlayerData.max_hp)
	print("Human At Heart: Healed for: ", total_heal)
	print("Human At Heart: Power increased by: ", total_power_gain)
	
	_sync_player_stats()
	vfx.spawn_damage_number(player_visual, total_heal, false, true)
	vfx.play_buff_particles(player_visual, BuffParticles.Kind.HEAL)
	vfx.play_buff_particles(player_visual, BuffParticles.Kind.POWER)
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
	var amount = randi_range(1, 2)
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
		
		# Quick tame bonus: +1 of the dropped item
		var drop_amount: int = amount + (QUICK_TAME_BONUS_ITEMS if _is_quick_tame(enemy) else 0)
		var added := PlayerData.add_item(item_data, drop_amount)
		if added:
			_add_reward_item(item_rewards, item_data, drop_amount)
	
	return item_rewards

# Handles the ball item's hit logic: intent-specific, so even if two different types of creatures are hit, they will both move towards kill/tame at the same time
func _resolve_ball_hit(target: CombatEntity, intent: String, multiplier: float):
	var affected = _get_action_targets(target, current_target_reach)
	if affected.is_empty():
		return

	var target_visual = enemy_visuals[target]
	var ball = await vfx.play_multi_tame_ball(player_visual, target_visual, true)
	for enemy in affected:
		if enemy_visuals.has(enemy):
			var visual = enemy_visuals[enemy]
			visual.hop(2)
			vfx.play_multihit_feedback(visual)
			_hit_impact(visual, HIT_STOP_NORMAL)

	await vfx.bounce_and_fade_ball(ball, target_visual.global_position)
	for enemy in affected:
		var guess_type = _get_ball_guess_type_for_enemy(enemy, intent)
		await _apply_axis_shift_with_multiplier(enemy, guess_type, multiplier)

	_flush_betrayal()
	await _resolve_pending_minigames()

# Returns the type that the ball will apply to a creature after the ball minigame
func _get_ball_guess_type_for_enemy(enemy: CombatEntity, intent: String) -> CombatTypes.EntityType:
	if intent == "tame":
		return enemy.type
	
	return Utils._get_wrong_guess_type(enemy.type)

# For handling connected signals
func _disconnect_enemy_attack_handlers(enemy_visual: EnemyVisual):
	if enemy_attack_started_handlers.has(enemy_visual):
		var started_cb: Callable = enemy_attack_started_handlers[enemy_visual]
		if enemy_visual.attack_started.is_connected(started_cb):
			enemy_visual.attack_started.disconnect(started_cb)
		enemy_attack_started_handlers.erase(enemy_visual)
	
	if enemy_attack_hit_handlers.has(enemy_visual):
		var hit_cb: Callable = enemy_attack_hit_handlers[enemy_visual]
		if enemy_visual.attack_hit.is_connected(hit_cb):
			enemy_visual.attack_hit.disconnect(hit_cb)
		enemy_attack_hit_handlers.erase(enemy_visual)
	
	if enemy_attack_finished_handlers.has(enemy_visual):
		var finished_cb: Callable = enemy_attack_finished_handlers[enemy_visual]
		if enemy_visual.attack_finished.is_connected(finished_cb):
			enemy_visual.attack_finished.disconnect(finished_cb)
		enemy_attack_finished_handlers.erase(enemy_visual)

# Frog enemy's (or other enemies that might heal) healing method; moves the creature's axis toward 0
func _support_frog_heal(enemy: CombatEntity):
	if enemy == null:
		return
	if enemy.is_killed() or enemy.is_tamed():
		return
	
	var visual = enemy_visuals.get(enemy)
	if visual == null:
		return
	
	var heal_amount := Utils.quantize_min(randf_range(1.0, 3.0))
	var before := enemy.axis_value
	
	# Heal toward the center (0 axis)
	if enemy.axis_value < 0.0:
		enemy.set_axis(min(enemy.axis_value + heal_amount, 0.0))
	elif enemy.axis_value > 0.0:
		enemy.set_axis(max(enemy.axis_value - heal_amount, 0.0))
	else:
		# Already centered, so there's nothing to heal
		return
	var actual_shift := enemy.axis_value - before
	
	if is_zero_approx(actual_shift):
		return
	
	visual.update_axis(enemy.axis_value, actual_shift)
	visual.shake(false)
	vfx.spawn_damage_number(visual, abs(actual_shift), false, true)
	vfx.play_buff_particles(visual, BuffParticles.Kind.HEAL)
	
	print("Frog healed toward center by %.2f. Axis is now %.2f" % [abs(actual_shift), enemy.axis_value])

# Selects a type for the duck creature
func _randomize_duck_type(enemy: CombatEntity):
	var possible_types = [
		CombatTypes.EntityType.SKY,
		CombatTypes.EntityType.EARTH,
		CombatTypes.EntityType.WATER
	]
	
	enemy.type = possible_types.pick_random() # Applies the new type for the duck
	print("Duck type for this encounter is: ", CombatTypes.guess_type_to_string(enemy.type))

# Reveals the specific duck's type at the start of combat
func _reveal_duck_type(enemy: CombatEntity):
	var visual = enemy_visuals.get(enemy)
	if visual == null:
		return
	
	var color: Color = DUCK_TYPE_COLORS.get(enemy.type, Color.WHITE)
	vfx.spawn_info(visual, "%s" % CombatTypes.type_bbcode(enemy.type))
	await _flash_enemy_type_color(visual, color, DUCK_TYPE_REVEAL_DURATION)

func tutorial_begin_player_turn_locked():
	combat_paused = false
	turn = "player"
	selected_enemy = null
	is_targeting = false
	locked_enemy_turn_order = _get_enemy_turn_order()
	player_turn_ui.start_player_turn()
	player_turn_ui.update_guess_display()
	player_turn_ui.lock_input()

func tutorial_unlock_player_turn_ui():
	player_turn_ui.start_player_turn()

func tutorial_lock_player_turn_ui():
	player_turn_ui.lock_input()

func tutorial_get_dummy() -> CombatEntity:
	if enemies.is_empty():
		return null
	return enemies[0]

func tutorial_select_dummy():
	var dummy := tutorial_get_dummy()
	if dummy == null:
		return
	
	selected_enemy = dummy
	target_index = 0
	target_mode = TargetMode.ENEMY
	is_targeting = true
	_set_selected_enemy(dummy)


func tutorial_prepare_dummy_for_minigame():
	var dummy := tutorial_get_dummy()
	if dummy == null:
		return
	
	dummy.set_axis(max(0.0, dummy.axis_max - 1.0))
	var visual = enemy_visuals.get(dummy)
	if visual:
		visual.update_axis(dummy.axis_value)

# ANIMATION METHODS
# Smooth tween BG animation for minigame enter/exiting 
func _world_gray_out(gray_out: bool, spare_player := false):
	if spare_player:
		_shop_dim(gray_out)
		return
	# The world (background, creatures and the Droid) lives in several nodes, so a black layer between it and the UI dims it all
	if dim_rect == null:
		var dim_layer := CanvasLayer.new()
		dim_layer.layer = 1 # Same layer as the UI, but drawn before it
		dim_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		var parent := get_parent()
		parent.add_child(dim_layer)
		parent.move_child(dim_layer, parent.get_node("UI").get_index())
		dim_rect = ColorRect.new()
		dim_rect.color = Color(0, 0, 0, 0)
		dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim_layer.add_child(dim_rect)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(dim_rect, "color:a", WORLD_DIM_ALPHA if gray_out else 0.0, 0.5)

# The shop dims the background and the creatures but not the Droid: the dim sits in the world, between them and the Droid
func _shop_dim(dim: bool):
	if shop_dim_rect == null:
		shop_dim_rect = ColorRect.new()
		shop_dim_rect.color = Color(0, 0, 0, 0)
		shop_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shop_dim_rect.position = Vector2(-2000, -2000)
		shop_dim_rect.size = Vector2(4000, 4000)
		shop_dim_rect.z_index = SHOP_DIM_Z
		get_parent().get_node("World").add_child(shop_dim_rect)
	if dim:
		player_base_z = player_visual.z_index
		player_visual.z_index = SHOP_DIM_Z + 1
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(shop_dim_rect, "color:a", WORLD_DIM_ALPHA if dim else 0.0, 0.5)
	if not dim:
		tween.finished.connect(func(): player_visual.z_index = player_base_z)

func animate_enemy_entry():
	for visual in enemy_visuals.values():
		visual.visible = true
		visual.modulate.a = 1.0
		
		var target_pos = visual.position
		visual.position.x += 300
		
		var tween := create_tween()
		tween.tween_property(visual, "position", target_pos, 0.6)
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		
	await get_tree().create_timer(0.6).timeout

# Animates the duck type reveal at the start of combat
func _flash_enemy_type_color(visual: EnemyVisual, color: Color, duration: float):
	var original_modulate := visual.modulate
	var tween := create_tween()
	tween.tween_property(visual.visual, "modulate", color, 0.15)
	tween.tween_interval(duration)
	tween.tween_property(visual.visual, "modulate", original_modulate, 0.2)
	
	await tween.finished
