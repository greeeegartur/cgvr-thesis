extends CanvasLayer

# THis script is responsible for the player UI during combat

# Node variables
@onready var gear_menu := $GearMenu
@onready var gear_sprite := $GearMenu/GearSprite
@onready var gear_options_root := $GearMenu/Options
@onready var attack_panel := $AttackTypeMenu/Panel
@onready var attack_list := $AttackTypeMenu/Panel/VBox
@onready var abilities_panel := $AbilitiesMenu/Panel
@onready var items_panel := $ItemsMenu/Panel
# Count labels for tame UI
@onready var sky_count = $AttackTypeMenu/Panel/VBox/SkyOption/Count
@onready var earth_count = $AttackTypeMenu/Panel/VBox/EarthOption/Count
@onready var water_count = $AttackTypeMenu/Panel/VBox/WaterOption/Count

# Signals to use with CombatManager
signal attack_type_selected(type)
signal cycle_enemy(dir)
signal confirm_enemy
signal cancel_enemy

# All turn states
enum State {
	NONE,
	OPTION_SELECT,
	ATTACK_TYPE_SELECT,
	ABILITIES_SELECT,
	ITEMS_SELECT,
	ENEMY_SELECT,
	LOCKED
}

# Default state
var state := State.NONE

# All base options during player turn and starting index
var gear_options := ["attack", "items", "abilities"]
var gear_index := 0 # Default index
var option_slots := [ # Intended option positions in scene
	Vector2(-3.077, -76.513), # Top
	Vector2(44.615, -59.59), # Left
	Vector2(-50.769, -59.59) # Right
]
var gear_scale_in_scene = 0.75 # In scene intended scale

# Attack options and base index
const ATTACK_OPTIONS := [
	{
		"id": CombatTypes.EntityType.SKY,
		"label": "Sky"
	},
	{
		"id": CombatTypes.EntityType.EARTH,
		"label": "Earth"
	},
	{
		"id": CombatTypes.EntityType.WATER,
		"label": "Water"
	}
]
var attack_index := 0 # Default index
var last_selected_attack_type : CombatTypes.EntityType

# TO-DO: Abilities options
var abilities_index := 0 # Default index

# TO-DO: Items options
var items_index := 0 # Default index

# Animation options
var gear_spin_tween: Tween

func _ready():
	set_process_unhandled_input(true)

# Starts the player turn, reveals the gear menu and starts allowing input
func start_player_turn():
	state = State.OPTION_SELECT
	_show_gear_menu()

# Applies next state based on current state input by player
func _unhandled_input(event):
	if state == State.OPTION_SELECT:
		_handle_gear_input(event)
	elif state == State.ATTACK_TYPE_SELECT:
		_handle_attack_type_input(event)
	elif state == State.ABILITIES_SELECT:
		_handle_abilities_input(event)
	elif state == State.ITEMS_SELECT:
		_handle_items_input(event)
	elif state == State.ENEMY_SELECT:
		_handle_enemy_select_input(event)

# Moves options in the OPTION_SELECT state based on player inputs
func _handle_gear_input(event):
	if event.is_action_pressed("ui_left"):
		_move_gear(-1)
	elif event.is_action_pressed("ui_right"):
		_move_gear(1)
	elif event.is_action_pressed("ui_accept"): # Player presses Z
		_confirm_gear_option()
	elif event.is_action_pressed("ui_cancel"): # Player presses X
		pass

# Moves options in the ATTACK_TYPE_SELECT state based on player inputs
func _handle_attack_type_input(event):
	if event.is_action_pressed("ui_up"):
		_move_attack_type(-1)
	elif event.is_action_pressed("ui_down"):
		_move_attack_type(1)
	elif event.is_action_pressed("ui_accept"):
		_confirm_attack_type()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_select(gear_options[gear_index])

# TO-DO: Abilities inputs
func _handle_abilities_input(event):
	if event.is_action_pressed("ui_cancel"):
		_cancel_select(gear_options[gear_index])

# TO-DO: Items inputs
func _handle_items_input(event):
	if event.is_action_pressed("ui_cancel"):
		_cancel_select(gear_options[gear_index])

# Emits signals to CombatManager methods which in turn moves enemy options and confirms them
func _handle_enemy_select_input(event):
	if event.is_action_pressed("ui_left"):
		emit_signal("cycle_enemy", -1)
	elif event.is_action_pressed("ui_right"):
		emit_signal("cycle_enemy", 1)
	elif event.is_action_pressed("ui_accept"):
		emit_signal("confirm_enemy")
	elif event.is_action_pressed("ui_cancel"):
		emit_signal("cancel_enemy")

# Moves the attack type in the attack type select state and animates the change
func _move_attack_type(dir: int):
	var count := attack_list.get_child_count()
	attack_index = wrapi(attack_index + dir, 0, count)
	
	_update_attack_type_visuals()

# Animation for hiding the attack option menu when canceling attack or starting enemy select state
func _hide_menu(selected_option: String):
	var panel = _correct_panel(selected_option)
	
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ZERO, 0.15)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	await tween.finished
	panel.visible = false

# Backing out of enemy selection to attack select state (pressing X)
func cancel_enemy_selection():
	# TO-DO: Make dependant on state so always returns to previous intended state
	state = State.ATTACK_TYPE_SELECT
	PlayerData.add_guesses(last_selected_attack_type, 1) # Returns consumed guess
	_show_menu()

# Hides all player turn UI when enemy has been selected and confirmed, after which the player turn is executed
func hide_all():
	state = State.NONE
	visible = false

# Moves the gear sprite and its options according to new index
func _move_gear(dir: int):
	gear_index = wrapi(gear_index + dir, 0, gear_options.size())
	
	# Tween logic
	_animate_gear_change(gear_index, dir)
	_update_gear_visuals()
	_update_gear_positions(dir)

# Animates the gear menu and its options with tweens
func _animate_gear_change(to: int, dir: int):
	# Gear sprite rotation tween with transition
	var tween := create_tween()
	tween.tween_property(
		gear_sprite,
		"rotation",
		gear_sprite.rotation + dir * PI / 4,
		0.2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Highlighting/darkening options with scale and modulate tweens
	for i in gear_options.size():
		var option = _get_gear_option_node(i)
		var selected := i == to
		
		var option_scale := Vector2.ONE * (1.4 if selected else 0.9)
		var color := Color.WHITE if selected else Color(0.5, 0.5, 0.5)
		create_tween().tween_property(option, "scale", option_scale, 0.1)
		create_tween().tween_property(option, "modulate", color, 0.1)

# Animates the gear menu at start of turn/when backing out of an option
func _show_gear_menu():
	visible = true
	gear_menu.visible = true
	gear_menu.scale = Vector2.ZERO
	gear_menu.modulate = Color.WHITE
	gear_sprite.rotation = 0.0

	create_tween().tween_property(
		gear_menu,
		"scale",
		Vector2.ONE * 0.75,
		0.4
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_update_gear_visuals()

func hide_player_turn_ui():
	var tween = create_tween()
	tween.tween_property(
		gear_menu,
		"scale",
		Vector2.ZERO,
		0.4
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		gear_menu,
		"modulate:a",
		0.0,
		0.4
	)
	
	await tween.finished
	_stop_gear_spin()
	gear_menu.visible = false
	visible = false

# Animation logic for preparing player options after OPTION_SELECT state
func _start_action_transition():
	# Darkens gear UI
	create_tween().tween_property(
		gear_menu,
		"modulate",
		Color(0.6, 0.6, 0.6),
		0.2
	)
	
	# Starts spinning gear (preparing for attack)
	_start_gear_spin()
	
	# Shows the attack menu after a small delay
	await get_tree().create_timer(0.05).timeout
	_show_menu()

# Gear spinning loop animation during attack menu selection
func _start_gear_spin():
	_stop_gear_spin() # Default just in case

	gear_spin_tween = create_tween()
	gear_spin_tween.set_loops()
	gear_spin_tween.tween_property(
		gear_sprite,
		"rotation",
		TAU,
		3.5
	).set_trans(Tween.TRANS_LINEAR).as_relative()


# Stops gear spinning if active (when exiting back to option selection)
func _stop_gear_spin():
	if gear_spin_tween:
		gear_spin_tween.kill()
		gear_spin_tween = null
		create_tween().tween_property(
			gear_sprite,
			"rotation",
			round(gear_sprite.rotation / PI) * PI,
			0.12
		).set_trans(Tween.TRANS_LINEAR)

# Animates gear visual options with tweens based on player input
func _update_gear_visuals():
	var count := gear_options_root.get_child_count()
	for i in count:
		var option = _get_gear_option_node(i)
		var selected := i == gear_index
		var label = option.get_node("Label")
		
		var tween := create_tween()
		# Option (node) properties
		tween.tween_property(
			option,
			"position:y",
			-85 if selected else option.position.y,
			0.15
		).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(
			option,
			"scale",
			Vector2.ONE * (1.3 if selected else 0.85),
			0.15
		)
		tween.parallel().tween_property(
			option,
			"modulate",
			Color.WHITE if selected else Color(0.5, 0.5, 0.5),
			0.12
		)
		
		# Label properties
		label.visible = selected
		var target_alpha := 1.0 if selected else 0.0
		tween.parallel().tween_property(
			label,
			"modulate:a",
			target_alpha,
			0.12
		)

# Changes gear positions depending on the direction the gear moved in to have a sort of spinning/shuffling effect (Mario & Luigi, Paper Mario inspiration)
func _update_gear_positions(dir: int):
	for i in gear_options_root.get_child_count():
		var option = _get_gear_option_node(i)
		var slot_index := wrapi(i - gear_index, 0, option_slots.size())
		var selected := i == gear_index
		# Offset up if selected
		var target_pos = option_slots[slot_index] + Vector2(0, -5) if selected else option_slots[slot_index]
		
		var tween := create_tween()
		# Icon moves to target_pos and fades out
		tween.tween_property(option, "position", target_pos, 0.18)\
			.set_trans(Tween.TRANS_CUBIC)\
			.set_ease(Tween.EASE_OUT)
		
		if slot_index == 1 and dir > 0:
			option.modulate.a = 0.0
			tween.parallel().tween_property(option, "modulate:a", 1.0, 0.1)

# Confirms option and sets the current state to locked so no more player inputs can be given
func _confirm_gear_option():
	if gear_options[gear_index] not in gear_options:
		return
	
	state = State.LOCKED
	_start_action_transition()

# Getter for the specific node option that the player selects
func _get_gear_option_node(index: int):
	return gear_options_root.get_child(index) as Node2D

# Tween animation for moving back to the option selection
func _restore_gear_menu():
	var tween = create_tween()
	tween.tween_property(
		gear_menu,
		"modulate",
		Color.WHITE,
		0.15
	)

# Shows the corresponding menu panel after an option has been selected
func _show_menu():
	var selected_option = gear_options[gear_index]
	var panel = _correct_panel(selected_option)
	if selected_option == "attack":
		state = State.ATTACK_TYPE_SELECT
		attack_index = 0
	elif selected_option == "abilities":
		state = State.ABILITIES_SELECT
		abilities_index = 0
	elif selected_option == "items":
		state = State.ITEMS_SELECT
		items_index = 0
	
	panel.visible = true
	panel.scale = Vector2.ZERO
	panel.modulate.a = 0.0
	if selected_option == "attack":
		_update_attack_type_visuals()
	# TO-DO: add other panel update methods here or make _update_attack_type_visuals universal
	
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.15)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.15)
	await tween.finished

# Updates the attack options visuals in the attack menu so they stay centered and get highlighted
func _update_attack_type_visuals():
	var count := attack_list.get_child_count()
	for i in count:
		var option := attack_list.get_child(i)
		var selected := i == attack_index
		
		var tween := create_tween()
		tween.tween_property(
			option,
			"scale",
			Vector2.ONE * (1.2 if selected else 0.95),
			0.12
		)
		
		tween.parallel().tween_property(
			option,
			"modulate",
			Color.WHITE if selected else Color(0.6, 0.6, 0.6),
			0.1
		)
		
		# Other options move slightly away from the selecte done
		var y_offset := 0
		if selected:
			y_offset = -10
		else:
			y_offset = 0
		
		tween.parallel().tween_property(
			option,
			"position:y",
			y_offset,
			0.12
		)

func update_guess_display():
	var g = PlayerData.guesses
	sky_count.text = "x%d" % g[CombatTypes.EntityType.SKY]
	earth_count.text = "x%d" % g[CombatTypes.EntityType.EARTH]
	water_count.text = "x%d" % g[CombatTypes.EntityType.WATER]

# Backing out of attack type select state to option select (pressing X)
func _cancel_select(selected_option: String):
	if selected_option == "attack":
		attack_index = 0
	if selected_option == "abilities":
		abilities_index = 0
	if selected_option == "items":
		items_index = 0
	_hide_menu(selected_option)
	_stop_gear_spin()
	
	state = State.OPTION_SELECT
	_restore_gear_menu()

# Selecting attack type and starting enemy select state
func _confirm_attack_type():
	var chosen_type: CombatTypes.EntityType = ATTACK_OPTIONS[attack_index].id
	if not PlayerData.has_guess(chosen_type):
		shake_panel()
		return
	
	_hide_menu(gear_options[gear_index])
	PlayerData.consume_guess(chosen_type)
	last_selected_attack_type = chosen_type
	
	state = State.ENEMY_SELECT
	emit_signal("attack_type_selected", chosen_type)

# For locking player inputs in the combat scene
func lock_input():
	state = State.LOCKED

# Shakes panel when invalid option is selected (i.e guess type that has no guesses)
func shake_panel(strength: float = 1):
	var panel = _correct_panel(gear_options[gear_index])
	var original_pos = panel.position
	
	var tween := create_tween()
	tween.tween_property(
		panel,
		"position",
		original_pos + Vector2(randf_range(strength * -8.0, strength * 8.0),
		 randf_range(strength * -8.0, strength * 8.0)),
		0.05
	)
	tween.tween_property(panel, "position", original_pos, 0.2)

# Finds the correct panel depending on the selected option
func _correct_panel(selected_option: String):
	var panel : Panel
	if selected_option == "attack":
		panel = attack_panel
	if selected_option == "abilities":
		panel = abilities_panel
	if selected_option == "items":
		panel = items_panel
	return panel

# Checking if tame type option can be used
func _is_option_available(t: CombatTypes.EntityType) -> bool:
	return PlayerData.has_guess(t)
