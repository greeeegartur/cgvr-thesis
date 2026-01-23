extends CanvasLayer

# THis script is responsible for the player UI during combat

# Node variables
@onready var gear_menu := $GearMenu
@onready var gear_sprite := $GearMenu/GearSprite
@onready var gear_options_root := $GearMenu/Options
@onready var attack_menu := $AttackTypeMenu
@onready var attack_panel := $AttackTypeMenu/Panel
@onready var attack_list := $AttackTypeMenu/Panel/VBox

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
	ENEMY_SELECT,
	LOCKED
}

# Default state
var state := State.NONE

# All base options during player turn and starting index
var gear_options := ["attack", "items", "abilities"]
var gear_index := 0 # Default index

# Attack options and base index
var attack_types := ["flying", "grounded", "special"]
var attack_index := 0 # Default index

# Animation options
var gear_spin_tween: Tween

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
		pass # nothing to go back to

# Moves options in the ATTACK_TYPE_SELECT state based on player inputs
func _handle_attack_type_input(event):
	if event.is_action_pressed("ui_up"):
		_move_attack_type(-1)
	elif event.is_action_pressed("ui_down"):
		_move_attack_type(1)
	elif event.is_action_pressed("ui_accept"):
		_confirm_attack_type()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_attack_type()

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

# Moves the attack type in the option select state and animates the change
func _move_attack_type(dir: int):
	var count := attack_list.get_child_count()
	attack_index = wrapi(attack_index + dir, 0, count)
	
	for i in count:
		var node := attack_list.get_child(i)
		var selected := i == attack_index
		
		create_tween().tween_property(
			node,
			"scale",
			Vector2.ONE * (1.15 if selected else 1.0),
			0.1
		)
		create_tween().tween_property(
			node,
			"modulate",
			Color.WHITE if selected else Color(0.6, 0.6, 0.6),
			0.1
		)


# Backing out of attack type select state to option select (pressing X)
func _cancel_attack_type():
	_hide_attack_type_menu()
	_stop_gear_spin()
	
	state = State.OPTION_SELECT
	_restore_gear_menu()

# Animation for hiding the attack option menu when canceling attack or starting enemy select state
func _hide_attack_type_menu():
	var tween := create_tween()
	tween.tween_property(attack_menu, "scale", Vector2.ZERO, 0.15)
	tween.tween_property(attack_menu, "modulate:a", 0.0, 0.15)
	await tween.finished
	attack_menu.visible = false

# Backing out of enemy selection to attack select state (pressing X)
func cancel_enemy_selection():
	state = State.ATTACK_TYPE_SELECT
	_show_attack_type_menu()

# Hides all player turn UI when enemy has been selected and confirmed, after which the player turn is executed
func hide_all():
	state = State.NONE
	visible = false

# Moves the base gear with its options to the new index
func _move_gear(dir: int):
	var prev := gear_index
	gear_index = wrapi(gear_index + dir, 0, gear_options.size())
	
	# Tween logic
	_animate_gear_change(prev, gear_index)

# Animates the gear menu and its options with tweens
func _animate_gear_change(from: int, to: int):
	# Gear rotation tween with transition
	var tween := create_tween()
	tween.tween_property(
		$GearMenu,
		"rotation",
		$GearMenu.rotation + sign(to - from) * PI / 3,
		0.15
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Highlighting/darkening options with scale and modulate tweens
	for i in gear_options.size():
		var option = _get_gear_option_node(i)
		var selected := i == to
		
		var scale := Vector2.ONE * (1.2 if selected else 0.9)
		var color := Color.WHITE if selected else Color(0.5, 0.5, 0.5)
		
		create_tween().tween_property(option, "scale", scale, 0.1)
		create_tween().tween_property(option, "modulate", color, 0.1)

# Animates the gear menu at start of turn/when backing out of an option
func _show_gear_menu():
	visible = true
	gear_menu.visible = true
	gear_menu.scale = Vector2.ZERO
	gear_menu.modulate = Color.WHITE

	create_tween().tween_property(
		gear_menu,
		"scale",
		Vector2.ONE,
		0.2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_update_gear_visuals()

# Animates new gear visuals with tweens based on player input
func _update_gear_visuals():
	var count := gear_options_root.get_child_count()
	
	for i in count:
		var option = _get_gear_option_node(i)
		var selected := i == gear_index
		
		var target_scale := Vector2.ONE * (1.25 if selected else 0.85)
		var target_color := (
			Color.WHITE
			if selected
			else Color(0.5, 0.5, 0.5, 1.0)
		)
		
		var tween := create_tween()
		tween.tween_property(option, "scale", target_scale, 0.12)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
		
		tween.parallel().tween_property(
			option,
			"modulate",
			target_color,
			0.1
		)
		# Offset polish, to be tested if looks good
		var target_y := -6 if selected else 0
		tween.parallel().tween_property(option, "position:y", target_y, 0.12)


# Confirms option and sets the current state to locked so no more player inputs can be given
func _confirm_gear_option():
	if gear_options[gear_index] != "attack":
		return
	
	state = State.LOCKED
	_start_attack_transition()

# Getter for the specific node option that the player selects
func _get_gear_option_node(index: int):
	return gear_options_root.get_child(index) as Node2D

# Tween animation for moving back to the option selection
func _restore_gear_menu():
	create_tween().tween_property(
		gear_menu,
		"modulate",
		Color.WHITE,
		0.15
	)

# Animation logic for preparing attacks in ATTACK_TYPE_SELECT state
func _start_attack_transition():
	# Darkens everything
	create_tween().tween_property(
		$GearMenu,
		"modulate",
		Color(0.6, 0.6, 0.6),
		0.2
	)
	
	# Starts spinning gear (preparing for attack)
	_start_gear_spin()
	
	# Shows the attack menu after a small delay
	await get_tree().create_timer(0.2).timeout
	_show_attack_type_menu()

# Gear spinning loop animation during attack menu selection
func _start_gear_spin():
	gear_spin_tween = create_tween().set_loops()
	gear_spin_tween.tween_property(
		gear_menu,
		"rotation",
		gear_menu.rotation + TAU,
		1.0
	)

# Stops gear spinning if active (when exiting back to option selection)
func _stop_gear_spin():
	if gear_spin_tween and gear_spin_tween.is_running():
		gear_spin_tween.kill()


# Shows the attack menu after the attack option has been selected
func _show_attack_type_menu():
	state = State.ATTACK_TYPE_SELECT
	attack_menu.visible = true
	attack_menu.scale = Vector2.ZERO
	attack_menu.modulate.a = 0.0
	
	create_tween().tween_property(attack_menu, "scale", Vector2.ONE, 0.15)
	create_tween().tween_property(attack_menu, "modulate:a", 1.0, 0.15)

# Selecting attack type and starting enemy select state
func _confirm_attack_type():
	var chosen = attack_types[attack_index]

	_hide_attack_type_menu()

	state = State.ENEMY_SELECT
	emit_signal("attack_type_selected", chosen)
