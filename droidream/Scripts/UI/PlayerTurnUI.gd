extends CanvasLayer

# This script is responsible for the player UI during combat; second iteration of this

# Node variables
@onready var gear_menu := $GearMenu
@onready var gear_sprite := $GearMenu/GearSprite
@onready var gear_options_root := $GearMenu/Options
@onready var attack_panel: UIPanel = $AttackTypeMenu/Panel
@onready var attack_list: UIList = $AttackTypeMenu/Panel/List
@onready var abilities_panel: UIPanel = $AbilitiesMenu/Panel
@onready var abilities_list: UIList = $AbilitiesMenu/Panel/List
@onready var ability_popup := $AbilitiesMenu/AbilityInfoContainer
@onready var items_panel: UIPanel = $ItemsMenu/Panel
@onready var items_list: UIList = $ItemsMenu/Panel/List
@onready var item_popup := $ItemsMenu/ItemInfoContainer

# Signals to use with CombatManager
signal attack_type_selected(type)
signal ability_selected(ability)
signal item_selected(item)
signal ability_tame_type_selected(type)
signal cancel_ability_tame_select
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
	SELF_SELECT,
	LOCKED
}

const MENU_ATTACK := "attack"
const MENU_ABILITIES := "abilities"
const MENU_ITEMS := "items"

# Attack options and base index
const ATTACK_OPTIONS := [
	{ "id": CombatTypes.EntityType.SKY, "label": "Sky", "icon": preload("res://Graphics/Sprites/Items/sky_chip.png") },
	{ "id": CombatTypes.EntityType.EARTH, "label": "Earth", "icon": preload("res://Graphics/Sprites/Items/earth_chip.png") },
	{ "id": CombatTypes.EntityType.WATER, "label": "Water", "icon": preload("res://Graphics/Sprites/Items/water_chip.png") }
]

# Default state
var state := State.NONE
var previous_state : State
var selecting_tame_for_ability := false
var last_selected_attack_type: CombatTypes.EntityType

# All base options during player turn and starting index
var gear_options := ["attack", "abilities", "items"]
var gear_index := 0 # Default index
var option_slots := [ # Intended option positions in scene
	Vector2(-3.077, -76.513), # Top
	Vector2(44.615, -59.59), # Left
	Vector2(-50.769, -59.59) # Right
]

var target_return_menu := ""
var refund_guess_on_target_cancel := false
var pending_tame_type_for_ability := false

# Animation options
var gear_spin_tween: Tween

func _ready():
	set_process_unhandled_input(true)
	
	# The info boxes follow the selected row
	abilities_list.selected_changed.connect(func(_index): _update_ability_info_popup())
	items_list.selected_changed.connect(func(_index): _update_item_info_popup())

# Starts the player turn, reveals the gear menu and starts allowing input
func start_player_turn():
	state = State.OPTION_SELECT
	gear_index = 0
	
	selecting_tame_for_ability = false
	pending_tame_type_for_ability = false
	target_return_menu = ""
	refund_guess_on_target_cancel = false
	
	_show_gear_menu()

# Applies next state based on current state input by player
func _unhandled_input(event):
	match state:
		State.OPTION_SELECT:
			_handle_gear_input(event)
		State.ATTACK_TYPE_SELECT:
			_handle_attack_type_input(event)
		State.ABILITIES_SELECT:
			_handle_abilities_input(event)
		State.ITEMS_SELECT:
			_handle_items_input(event)
		State.ENEMY_SELECT, State.SELF_SELECT:
			_handle_target_input(event)

# Moves options in the OPTION_SELECT state based on player inputs
func _handle_gear_input(event):
	if event.is_action_pressed("ui_left"):
		_move_gear(-1)
	elif event.is_action_pressed("ui_right"):
		_move_gear(1)
	elif event.is_action_pressed("ui_accept"): # Player presses Z
		_confirm_gear_option()

func _handle_target_input(event):
	if state == State.ENEMY_SELECT:
		if event.is_action_pressed("ui_left"):
			emit_signal("cycle_enemy", -1)
		elif event.is_action_pressed("ui_right"):
			emit_signal("cycle_enemy", 1)

	if event.is_action_pressed("ui_accept"):
		emit_signal("confirm_enemy")
	elif event.is_action_pressed("ui_cancel"):
		emit_signal("cancel_enemy")

# Moves options in the ATTACK_TYPE_SELECT state based on player inputs
func _handle_attack_type_input(event):
	if event.is_action_pressed("ui_up"):
		attack_list.move(-1)
	elif event.is_action_pressed("ui_down"):
		attack_list.move(1)
	elif event.is_action_pressed("ui_accept"):
		_confirm_attack_type()
	elif event.is_action_pressed("ui_cancel"):
		if selecting_tame_for_ability:
			_cancel_ability_tame_select()
		else:
			_cancel_to_gear(MENU_ATTACK)

func _handle_abilities_input(event):
	var abilities = PlayerData.get_active_abilities()
	if abilities.is_empty():
		if event.is_action_pressed("ui_cancel"):
			_cancel_to_gear(MENU_ABILITIES)
		return
	
	if event.is_action_pressed("ui_up"):
		abilities_list.move(-1)
	elif event.is_action_pressed("ui_down"):
		abilities_list.move(1)
	elif event.is_action_pressed("ui_accept"):
		var ability = abilities[abilities_list.selected_index]
		
		# Does not allow it to be used if the ability does not have a cooldown of 0
		if ability.cooldown > 0:
			shake_panel()
			return
		
		ability_popup.visible = false
		emit_signal("ability_selected", ability)
	elif event.is_action_pressed("ui_cancel"):
		_cancel_to_gear(MENU_ABILITIES)

func _handle_items_input(event):
	var items = PlayerData.get_combat_items()
	if items.is_empty():
		if event.is_action_pressed("ui_cancel"):
			_cancel_to_gear(MENU_ITEMS)
		return
	
	if event.is_action_pressed("ui_up"):
		items_list.move(-1)
	elif event.is_action_pressed("ui_down"):
		items_list.move(1)
	elif event.is_action_pressed("ui_accept"):
		item_popup.visible = false
		emit_signal("item_selected", items[items_list.selected_index])
	elif event.is_action_pressed("ui_cancel"):
		_cancel_to_gear(MENU_ITEMS)

func _cancel_to_gear(menu_name: String):
	_close_menu(menu_name)
	_stop_gear_spin()
	state = State.OPTION_SELECT
	_restore_gear_menu()

# Backing out of enemy selection to attack select state (pressing X)
func cancel_enemy_selection():
	state = State.LOCKED
	
	if refund_guess_on_target_cancel:
		PlayerData.add_guesses(last_selected_attack_type, 1) # Returns consumed guess
		
	if pending_tame_type_for_ability:
		state = State.ABILITIES_SELECT
		await _open_menu(MENU_ABILITIES, false)
		return
		
	match target_return_menu:
		MENU_ATTACK:
			await _open_menu(MENU_ATTACK, false)
		MENU_ABILITIES:
			await _open_menu(MENU_ABILITIES, false)
		MENU_ITEMS:
			await _open_menu(MENU_ITEMS, false)
		_:
			state = State.OPTION_SELECT
			_restore_gear_menu()

# HELPERS
# MENU NAVIGATION & PANEL METHODS
func _get_panel(menu_name: String) -> UIPanel:
	match menu_name:
		MENU_ATTACK:
			return attack_panel
		MENU_ABILITIES:
			return abilities_panel
		MENU_ITEMS:
			return items_panel
	return null

func _get_list(menu_name: String) -> UIList:
	match menu_name:
		MENU_ATTACK:
			return attack_list
		MENU_ABILITIES:
			return abilities_list
		MENU_ITEMS:
			return items_list
	return null

# Builds the rows of a menu from the current game data and resizes its panel around them
func _refresh_menu_rows(menu_name: String):
	var list := _get_list(menu_name)
	var entries: Array
	match menu_name:
		MENU_ATTACK:
			entries = _attack_entries()
		MENU_ABILITIES:
			entries = _ability_entries()
		MENU_ITEMS:
			entries = _item_entries()
	list.set_rows(entries)
	
	var panel := _get_panel(menu_name)
	list.position = panel.content_origin()
	panel.fit_to(list.size)

# Row data for the attack types: chip icon, name and how many guesses are left
func _attack_entries() -> Array:
	var entries := []
	for option in ATTACK_OPTIONS:
		entries.append({ "icon": option.icon, "text": option.label, "right": "x%d" % PlayerData.guesses[option.id] })
	return entries

func _ability_entries() -> Array:
	var entries := []
	for ability in PlayerData.get_active_abilities():
		entries.append({
			"text": ability.data.display_name,
			"pips": ability.data.cooldown_max,
			"pips_dim": ability.cooldown
		})
	if entries.is_empty():
		entries.append({ "text": "No abilities" })
	return entries

func _item_entries() -> Array:
	var entries := []
	for item in PlayerData.get_combat_items():
		entries.append({ "icon": item.data.icon, "text": item.data.display_name, "right": "x%d" % item.amount })
	if entries.is_empty():
		entries.append({ "text": "No items" })
	return entries

func _open_menu(menu_name: String, reset_index := false):
	var panel := _get_panel(menu_name)
	if panel == null:
		return
	
	var list := _get_list(menu_name)
	if reset_index:
		list.selected_index = 0
		list.scroll_row = 0.0
	
	match menu_name:
		MENU_ATTACK:
			state = State.ATTACK_TYPE_SELECT
		MENU_ABILITIES:
			state = State.ABILITIES_SELECT
		MENU_ITEMS:
			state = State.ITEMS_SELECT
	
	_refresh_menu_rows(menu_name)
	_update_popup(menu_name)
	
	panel.visible = true
	panel.scale = Vector2.ZERO
	panel.modulate.a = 0.0
	
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.15)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.15)
	await tween.finished

func _close_menu(menu_name: String):
	var panel := _get_panel(menu_name)
	if panel == null:
		return
	
	if menu_name == MENU_ITEMS:
		item_popup.visible = false
	elif menu_name == MENU_ABILITIES:
		ability_popup.visible = false
	
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.12)
	await tween.finished
	panel.visible = false

# Shows the info box of the selected row (only abilities and items have one)
func _update_popup(menu_name: String):
	match menu_name:
		MENU_ABILITIES:
			_update_ability_info_popup()
		MENU_ITEMS:
			_update_item_info_popup()

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

func _handle_self_select_input(event):
	if event.is_action_pressed("ui_accept"):
		emit_signal("confirm_enemy")
	elif event.is_action_pressed("ui_cancel"):
		emit_signal("cancel_enemy")

# Animation for hiding the attack option menu when canceling attack or starting enemy select state
func _hide_menu(selected_option: String):
	var panel = _correct_panel(selected_option)
	
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.12)
	
	await tween.finished
	panel.visible = false

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
	
	_reset_gear_layout()
	
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

# Animation logic for preparing player options after OPTION_SELECT state
func _start_action_transition():
	# Darkens gear UI
	create_tween().tween_property(
		gear_menu,
		"modulate",
		Color(0.6, 0.6, 0.6),
		0.2
	)
	
	_start_gear_spin() # Starts spinning gear (preparing for attack)
	await get_tree().create_timer(0.05).timeout # Shows the attack menu after a small delay
	await _open_menu(gear_options[gear_index], true)

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

# Preselects an attack type in the attack menu (used by the tutorial)
func set_attack_index(index: int):
	if attack_list.count() == 0:
		_refresh_menu_rows(MENU_ATTACK)
	attack_list.select(index, false)

# Updates the guess counts shown in the attack menu
func update_guess_display():
	if attack_list.count() != ATTACK_OPTIONS.size():
		return # The rows are built when the menu opens
	for i in ATTACK_OPTIONS.size():
		attack_list.rows[i].set_right_text("x%d" % PlayerData.guesses[ATTACK_OPTIONS[i].id])

# Places an info box next to the selected row of its list; its tail points at the row
func _place_popup(popup: UIPanel, panel: UIPanel, list: UIList):
	var row_center := panel.position.y + list.position.y + list.get_selected_row_y() + UIRow.ROW_HEIGHT / 2.0
	var target_y := row_center - 16.5 # The tail sits 16.5 px below the top of the box
	var was_visible: bool = popup.visible
	popup.position.x = panel.position.x + panel.size.x + 4
	if was_visible:
		popup.move_to_y(target_y)
	else:
		popup.position.y = target_y

func _update_item_info_popup():
	var items = PlayerData.get_combat_items()
	if items.is_empty():
		item_popup.visible = false
		return
	
	_place_popup(item_popup, items_panel, items_list)
	item_popup.setup_from_inventory_item(items[items_list.selected_index])

func _update_ability_info_popup():
	var abilities = PlayerData.get_active_abilities()
	if abilities.is_empty():
		ability_popup.visible = false
		return
	
	_place_popup(ability_popup, abilities_panel, abilities_list)
	ability_popup.setup_from_inventory_ability(abilities[abilities_list.selected_index])

# Selecting attack type and starting enemy select state
func _confirm_attack_type():
	var chosen_type: CombatTypes.EntityType = ATTACK_OPTIONS[attack_list.selected_index].id
	
	if not PlayerData.has_guess(chosen_type):
		shake_panel()
		return
	
	if selecting_tame_for_ability:
		await _close_menu(MENU_ATTACK)
		emit_signal("ability_tame_type_selected", chosen_type)
		return
	
	await _close_menu(MENU_ATTACK)
	PlayerData.consume_guess(chosen_type)
	last_selected_attack_type = chosen_type
	target_return_menu = MENU_ATTACK
	refund_guess_on_target_cancel = true 
	pending_tame_type_for_ability = false
	
	state = State.ENEMY_SELECT
	emit_signal("attack_type_selected", chosen_type)

func _cancel_ability_tame_select():
	selecting_tame_for_ability = false
	pending_tame_type_for_ability = false
	refund_guess_on_target_cancel = true
	emit_signal("cancel_ability_tame_select")

	await _close_menu(MENU_ATTACK)
	await _open_menu(MENU_ABILITIES, false)

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

# HELPERS
# Finds the correct panel depending on the selected option
func _correct_panel(selected_option: String):
	var panel : UIPanel
	if selected_option == "attack":
		panel = attack_panel
	if selected_option == "abilities":
		panel = abilities_panel
	if selected_option == "items":
		panel = items_panel
	return panel

func _start_targeting(from_menu := "", refund_guess := false):
	previous_state = state
	target_return_menu = from_menu
	refund_guess_on_target_cancel = refund_guess
	state = State.ENEMY_SELECT

func _start_self_targeting(from_menu := ""):
	previous_state = state
	target_return_menu = from_menu
	refund_guess_on_target_cancel = false
	state = State.SELF_SELECT

func start_ability_tame_select():
	selecting_tame_for_ability = true
	pending_tame_type_for_ability = true
	await _close_menu(MENU_ABILITIES)
	await _open_menu(MENU_ATTACK, true)

func stop_ability_tame_select():
	selecting_tame_for_ability = false

func _reset_gear_layout():
	for i in gear_options_root.get_child_count():
		var option = _get_gear_option_node(i)
		var slot_index := wrapi(i - gear_index, 0, option_slots.size())
		var selected := i == gear_index
		
		option.position = option_slots[slot_index] + (Vector2(0, -5) if selected else Vector2.ZERO)
		option.scale = Vector2.ONE * (1.3 if selected else 0.85)
		option.modulate = Color.WHITE if selected else Color(0.5, 0.5, 0.5)
		
		var label = option.get_node("Label")
		label.visible = selected
		label.modulate.a = 1.0 if selected else 0.0
