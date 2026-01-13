extends Node

# This script acts as the frontend manager for the backend CombatManager script, also leaving print statements here for debugging

# Nodes
@onready var manager := $CombatManager
@onready var main_menu := $UI/MainMenu
@onready var attack_menu := $UI/AttackTypeMenu
@onready var target_menu := $UI/TargetSelectMenu
@onready var arrows := $UI/TypeTriangle/Arrows
@onready var icons := $UI/TypeTriangle/Icons

# Node (or node specific) variables
@onready var arrow_default_color = $UI/TypeTriangle/Arrows/FlyingToGrounded.modulate

# Type triangle container logic
const TYPE_ADVANTAGE = {
	"Flying": {
		"strong": "Grounded",
		"weak": "Special"
	},
	"Grounded": {
		"strong": "Special",
		"weak": "Flying"
	},
	"Special": {
		"strong": "Flying",
		"weak": "Grounded"
	}
}

# Selection variables
var selected_attack_type := CombatTypes.EntityType.GROUNDED # Default first attack choice
var targeting := false

func _ready():
	manager.player_turn_started.connect(_show_ui)
	manager.enemy_turn_started.connect(_hide_ui)
	manager.combat_end.connect(_combat_end)
	
	$UI/MainMenu/AttackButton.pressed.connect(_on_attack_pressed)
	$UI/MainMenu/ItemsButton.pressed.connect(_on_items_pressed)
	$UI/MainMenu/RunButton.pressed.connect(_on_run_pressed)

	$UI/AttackTypeMenu/GroundedButton.pressed.connect(func(): _select_attack_type(CombatTypes.EntityType.GROUNDED))
	$UI/AttackTypeMenu/FlyingButton.pressed.connect(func(): _select_attack_type(CombatTypes.EntityType.FLYING))
	$UI/AttackTypeMenu/SpecialButton.pressed.connect(func(): _select_attack_type(CombatTypes.EntityType.SPECIAL))
	
	for icon in icons.get_children():
		icon.mouse_entered.connect(_on_mouse_entered.bind(icon))
		icon.mouse_exited.connect(_on_mouse_exited)

# Input handling for enemy visual selection
func _unhandled_input(event):
	if not targeting:
		return

	if event.is_action_pressed("ui_left"):
		manager.cycle_target(-1)
	elif event.is_action_pressed("ui_right"):
		manager.cycle_target(1)
	elif event.is_action_pressed("action"):
		_confirm_target()

# Shows attack menu
func _on_attack_pressed():
	main_menu.visible = false
	attack_menu.visible = true

# TO-DO: implement
func _on_items_pressed():
	print("Items not implemented yet")

func _on_run_pressed():
	print("Run not implemented yet")

# Starts targeting in CombatManager (EnemyVisual has separate targeting)
func _select_attack_type(atype):
	selected_attack_type = atype
	attack_menu.visible = false
	target_menu.visible = true 
	
	targeting = true
	manager.start_target_selection()

func _confirm_target():
	targeting = false
	target_menu.visible = false
	
	# Hiding arrow on selection
	manager._confirm_target_selection()

	print("Player attacks enemy with type:",
		CombatTypes.entity_type_to_string(selected_attack_type))

	manager.player_attack(selected_attack_type)

# Functions for type triangle icons
func _on_mouse_entered(icon : TextureRect):
	var type = icon.get_meta("type")
	var data = TYPE_ADVANTAGE[type]
	
	_clear_type_relations()
	_highlight_arrow(type, data.strong, Color.LAWN_GREEN)

func _on_mouse_exited():
	_clear_type_relations()

func _clear_type_relations():
	for arrow in arrows.get_children():
		arrow.modulate = arrow_default_color

func _highlight_arrow(from_type, to_type, color):
	var arrow_name = "%sTo%s" % [from_type, to_type]
	arrows.get_node(arrow_name).modulate = color

# UI appearing/disappearing signals in CombatManager
# TO-DO change this on UI update
func _show_ui():
	main_menu.visible = true
	attack_menu.visible = false
	target_menu.visible = false
	
func _hide_ui():
	main_menu.visible = false
	attack_menu.visible = false
	target_menu.visible = false

# When combat has ended
func _combat_end():
	_hide_ui()
	# TO-DO: make specific for victory or game over
