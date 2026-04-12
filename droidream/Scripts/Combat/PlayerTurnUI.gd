extends CanvasLayer

# This script is responsible for the player UI during combat; second iteration of this

# Node variables
@onready var gear_menu := $GearMenu
@onready var gear_sprite := $GearMenu/GearSprite
@onready var gear_options_root := $GearMenu/Options
@onready var attack_panel := $AttackTypeMenu/Panel
@onready var attack_list := $AttackTypeMenu/Panel/VBox
@onready var abilities_panel := $AbilitiesMenu/Panel
@onready var abilities_list := $AbilitiesMenu/Panel/ScrollContainer/VBox
@onready var abilities_scroll := $AbilitiesMenu/Panel/ScrollContainer
@onready var items_panel := $ItemsMenu/Panel
@onready var items_list := $ItemsMenu/Panel/ScrollContainer/VBox
@onready var items_scroll := $ItemsMenu/Panel/ScrollContainer
@onready var item_popup := $ItemsMenu/ItemInfoContainer
# Count labels for tame UI
@onready var sky_count = $AttackTypeMenu/Panel/Counts/SkyCount
@onready var earth_count = $AttackTypeMenu/Panel/Counts/EarthCount
@onready var water_count = $AttackTypeMenu/Panel/Counts/WaterCount

@export var AbilityRowScene : PackedScene
@export var ItemRowScene : PackedScene

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
	{ "id": CombatTypes.EntityType.SKY, "label": "Sky" },
	{ "id": CombatTypes.EntityType.EARTH, "label": "Earth" },
	{ "id": CombatTypes.EntityType.WATER, "label": "Water" }
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

var menu_indices := {
	MENU_ATTACK: 0,
	MENU_ABILITIES: 0,
	MENU_ITEMS: 0
}
var target_return_menu := ""
var refund_guess_on_target_cancel := false
var pending_tame_type_for_ability := false

# Animation options
var gear_spin_tween: Tween

func _ready():
	set_process_unhandled_input(true)

# Starts the player turn, reveals the gear menu and starts allowing input
func start_player_turn():
	state = State.OPTION_SELECT
	gear_index = 0
	
	selecting_tame_for_ability = false
	pending_tame_type_for_ability = false
	target_return_menu = ""
	refund_guess_on_target_cancel = false
	
	menu_indices[MENU_ATTACK] = 0
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
		_move_menu_index(MENU_ATTACK, -1, attack_list.get_child_count())
		_update_attack_type_visuals()
	elif event.is_action_pressed("ui_down"):
		_move_menu_index(MENU_ATTACK, 1, attack_list.get_child_count())
		_update_attack_type_visuals()
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
		_move_menu_index(MENU_ABILITIES, -1, abilities.size())
		_update_abilities_visuals()
	elif event.is_action_pressed("ui_down"):
		_move_menu_index(MENU_ABILITIES, 1, abilities.size())
		_update_abilities_visuals()
	elif event.is_action_pressed("ui_accept"):
		var idx = menu_indices[MENU_ABILITIES]
		var ability = abilities[idx]
		
		# Does not allow it to be used if the ability does not have a cooldown of 0
		if ability.cooldown > 0:
			shake_panel()
			return
		
		emit_signal("ability_selected", ability)
	elif event.is_action_pressed("ui_cancel"):
		_cancel_to_gear(MENU_ABILITIES)

# TO-DO: Items inputs
func _handle_items_input(event):
	var items = PlayerData.get_combat_items()
	if items.is_empty():
		if event.is_action_pressed("ui_cancel"):
			_cancel_to_gear(MENU_ITEMS)
		return
	
	if event.is_action_pressed("ui_up"):
		_move_menu_index(MENU_ITEMS, -1, items.size())
		_update_items_visuals()
	elif event.is_action_pressed("ui_down"):
		_move_menu_index(MENU_ITEMS, 1, items.size())
		_update_items_visuals()
	elif event.is_action_pressed("ui_accept"):
		var idx = menu_indices[MENU_ITEMS]
		item_popup.visible = false
		emit_signal("item_selected", items[idx])
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
func _get_panel(menu_name: String) -> Panel:
	match menu_name:
		MENU_ATTACK:
			return attack_panel
		MENU_ABILITIES:
			return abilities_panel
		MENU_ITEMS:
			return items_panel
	return null

func _open_menu(menu_name: String, reset_index := false):
	var panel := _get_panel(menu_name)
	if panel == null:
		return
	
	if reset_index:
		menu_indices[menu_name] = 0
	
	# Lets containers with children exist visually before refreshing list contents
	panel.visible = true
	panel.scale = Vector2.ZERO
	panel.modulate.a = 0.0
	await get_tree().process_frame
	
	match menu_name:
		MENU_ATTACK:
			state = State.ATTACK_TYPE_SELECT
		MENU_ABILITIES:
			state = State.ABILITIES_SELECT
			await _refresh_abilities_ui()
		MENU_ITEMS:
			state = State.ITEMS_SELECT
			await _refresh_items_ui()
	
	panel.visible = true
	panel.scale = Vector2.ZERO
	panel.modulate.a = 0.0
	
	_refresh_menu_visuals(menu_name)
	
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
	
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.12)
	await tween.finished
	panel.visible = false

func _refresh_menu_visuals(menu_name: String):
	match menu_name:
		MENU_ATTACK:
			_update_attack_type_visuals()
		MENU_ABILITIES:
			_update_abilities_visuals()
		MENU_ITEMS:
			_update_items_visuals()

func _move_menu_index(menu_name: String, dir: int, count: int):
	if count <= 0:
		menu_indices[menu_name] = 0
		return
	menu_indices[menu_name] = wrapi(menu_indices[menu_name] + dir, 0, count)

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

# Updates the attack options visuals in the attack menu so they stay centered and get highlighted
func _update_attack_type_visuals():
	var selected_index = menu_indices[MENU_ATTACK]
	var count := attack_list.get_child_count()

	for i in count:
		var option := attack_list.get_child(i)
		var selected = i == selected_index

		var tween := create_tween()
		tween.tween_property(option, "scale", Vector2.ONE * (1.2 if selected else 0.95), 0.12)
		tween.parallel().tween_property(option, "modulate", Color.WHITE if selected else Color(0.6, 0.6, 0.6), 0.1)
		tween.parallel().tween_property(option, "position:y", -10 if selected else 0, 0.12) # Other options move slightly away from the selected ones

func _build_abilities_ui():
	await _build_list_ui(
		MENU_ABILITIES,
		PlayerData.get_active_abilities(),
		AbilityRowScene
	)

func _refresh_abilities_ui():
	await _refresh_list_ui(
		MENU_ABILITIES,
		PlayerData.get_active_abilities()
	)

func _update_abilities_visuals():
	_update_list_visuals(MENU_ABILITIES)

func _build_items_ui():
	await _build_list_ui(
		MENU_ITEMS,
		PlayerData.get_combat_items(),
		ItemRowScene
	)

func _refresh_items_ui():
	await _refresh_list_ui(
		MENU_ITEMS,
		PlayerData.get_combat_items()
	)

func _update_items_visuals():
	_update_list_visuals(MENU_ITEMS)
	_update_item_info_popup()

func _update_item_info_popup():
	var items = PlayerData.get_combat_items()
	if items.is_empty():
		item_popup.visible = false
		return
	
	var selected_index = menu_indices[MENU_ITEMS]
	if selected_index < 0 or selected_index >= items.size():
		item_popup.visible = false
		return
	
	if selected_index >= items_list.get_child_count():
		item_popup.visible = false
		return
	
	var selected_item = items[selected_index]
	var row = items_list.get_child(selected_index)
	item_popup.setup_from_inventory_item(selected_item)
	item_popup.move_to_row(row, Vector2(0, 134))

func update_guess_display():
	var g = PlayerData.guesses
	sky_count.text = "x%d" % g[CombatTypes.EntityType.SKY]
	earth_count.text = "x%d" % g[CombatTypes.EntityType.EARTH]
	water_count.text = "x%d" % g[CombatTypes.EntityType.WATER]

# Selecting attack type and starting enemy select state
func _confirm_attack_type():
	var idx = menu_indices[MENU_ATTACK]
	var chosen_type: CombatTypes.EntityType = ATTACK_OPTIONS[idx].id
	
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
	menu_indices[MENU_ATTACK] = 0
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
	var panel : Panel
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
	menu_indices[MENU_ATTACK] = 0
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

# UNIVERSAL HELPERS
# For ability/item children scaling
func _get_list_row_scale(child_count: int, menu_name := "") -> float:
	var base = 1.0
	if child_count >= 6:
		base = 0.72
	elif child_count >= 5:
		base = 0.80
	elif child_count >= 4:
		base = 0.85
	
	if menu_name == MENU_ITEMS:
		base *= 0.95
		
	return base

func _get_menu_list(menu_name: String) -> VBoxContainer:
	match menu_name:
		MENU_ABILITIES:
			return abilities_list
		MENU_ITEMS:
			return items_list
	return null

func _get_menu_scroll(menu_name: String) -> ScrollContainer:
	match menu_name:
		MENU_ABILITIES:
			return abilities_scroll
		MENU_ITEMS:
			return items_scroll
	return null

func _get_menu_row_scene(menu_name: String) -> PackedScene:
	match menu_name:
		MENU_ABILITIES:
			return AbilityRowScene
		MENU_ITEMS:
			return ItemRowScene
	return null

func _build_list_ui(menu_name: String, entries: Array, row_scene: PackedScene):
	var list := _get_menu_list(menu_name)
	if list == null:
		return
	
	for child in list.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	var row_scale := _get_list_row_scale(entries.size(), menu_name)
	for entry in entries:
		var row = row_scene.instantiate()
		list.add_child(row)
		if row.has_method("setup"):
			row.setup(entry, row_scale)
			
	menu_indices[menu_name] = 0
	
	list.queue_sort()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_update_list_visuals(menu_name)

func _refresh_list_ui(menu_name: String, entries: Array):
	var list := _get_menu_list(menu_name)
	if list == null:
		return
	
	var row_scale := _get_list_row_scale(entries.size(), menu_name)
	var child_count := list.get_child_count()
	var entry_count := entries.size()
	var shared_count = min(child_count, entry_count)
	
	for i in range(shared_count):
		var row = list.get_child(i)
		if row.has_method("setup"):
			row.setup(entries[i], row_scale)
	
	if entry_count < child_count:
		for i in range(child_count - 1, entry_count - 1, -1):
			list.get_child(i).queue_free()
	elif entry_count > child_count:
		var row_scene := _get_menu_row_scene(menu_name)
		if row_scene == null:
			return

		for i in range(child_count, entry_count):
			var row = row_scene.instantiate()
			list.add_child(row)
			if row.has_method("setup"):
				row.setup(entries[i], row_scale)
	
	if entries.is_empty():
		menu_indices[menu_name] = 0
	else:
		menu_indices[menu_name] = clamp(menu_indices[menu_name], 0, entries.size() - 1)
	
	list.queue_sort()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_update_list_visuals(menu_name)

func _update_list_visuals(menu_name: String):
	var list := _get_menu_list(menu_name)
	var scroll := _get_menu_scroll(menu_name)
	if list == null:
		return
	
	var selected_index = menu_indices[menu_name]
	var count = list.get_child_count()
	var base_scale := _get_list_row_scale(count, menu_name)
	
	for i in count:
		var row = list.get_child(i)
		var visual = row.get_node("VisualRoot")
		var selected = i == selected_index
		var target_scale := base_scale * (1.0 if selected else 0.82)
		
		var tween := create_tween()
		tween.tween_property(visual, "scale", Vector2.ONE * target_scale, 0.12)
		tween.parallel().tween_property(
			visual,
			"modulate",
			Color.WHITE if selected else Color(0.6, 0.6, 0.6),
			0.1
		)
	
	if scroll and selected_index < count:
		var row = list.get_child(selected_index)
		scroll.ensure_control_visible(row)
