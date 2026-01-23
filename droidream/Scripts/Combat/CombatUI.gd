extends Node

# This script acts as the frontend manager for the backend CombatManager script, also leaving print statements here for debugging

# Nodes
@onready var manager : CombatManager
@onready var arrows := $TypeTriangle/Arrows
@onready var icons := $TypeTriangle/Icons
@onready var turn_order_toggle := $TurnOrder

# Node (or node specific) variables
@onready var arrow_default_color = Color(1.0, 1.0, 1.0, 1.0)

# Signals
signal turn_order_toggled(enabled: bool)
# Forwarded signals from PlayerTurnUI
signal attack_selected(type)
signal enemy_cycle(dir)
signal enemy_confirm
signal enemy_cancel


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
	
	# Turn order button toggle logic
	turn_order_toggle.toggled.connect(
		func(enabled):
			emit_signal("turn_order_toggled", enabled)
	)
	
	for icon in icons.get_children():
		icon.mouse_entered.connect(_on_mouse_entered.bind(icon))
		icon.mouse_exited.connect(_on_mouse_exited)

# CombatManager's setup method
func setup(combat_manager: CombatManager):
	manager = combat_manager
	manager.combat_end.connect(_combat_end)


# Input handling for enemy visual selection during player turn
func _unhandled_input(event):
	if not targeting:
		return

	if event.is_action_pressed("ui_left"):
		manager.cycle_target(-1)
	elif event.is_action_pressed("ui_right"):
		manager.cycle_target(1)
	elif event.is_action_pressed("action"):
		_confirm_target()

# Starts targeting in CombatManager (EnemyVisual has separate targeting)
func _select_attack_type(atype):
	selected_attack_type = atype
	
	targeting = true
	manager.start_target_selection()

func _confirm_target():
	targeting = false
	
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

# When combat has ended
func _combat_end():
	print("end from UI")
	#_hide_ui()
	# TO-DO: make specific for victory or game over
