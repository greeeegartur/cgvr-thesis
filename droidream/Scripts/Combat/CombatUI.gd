extends Node

# This script acts as the frontend manager for the backend CombatManager script, also leaving print statements here for debugging

@onready var manager := $CombatManager
@onready var main_menu := $UI/MainMenu
@onready var attack_menu := $UI/AttackTypeMenu
@onready var target_menu := $UI/TargetSelectMenu

# Always as the first option
var selected_attack_type := CombatTypes.EntityType.GROUNDED

func _ready():
	manager.player_turn_started.connect(_show_ui)
	manager.enemy_turn_started.connect(_hide_ui)
	
	$UI/MainMenu/AttackButton.pressed.connect(_on_attack_pressed)
	$UI/MainMenu/ItemsButton.pressed.connect(_on_items_pressed)
	$UI/MainMenu/RunButton.pressed.connect(_on_run_pressed)

	$UI/AttackTypeMenu/GroundedButton.pressed.connect(func(): _select_attack_type(CombatTypes.EntityType.GROUNDED))
	$UI/AttackTypeMenu/FlyingButton.pressed.connect(func(): _select_attack_type(CombatTypes.EntityType.FLYING))
	$UI/AttackTypeMenu/SpecialButton.pressed.connect(func(): _select_attack_type(CombatTypes.EntityType.SPECIAL))

	$UI/TargetSelectMenu/EnemyButton.pressed.connect(_on_enemy_target_selected)

func _on_attack_pressed():
	main_menu.visible = false
	attack_menu.visible = true

func _on_items_pressed():
	print("Items not implemented yet")

func _on_run_pressed():
	print("Run not implemented yet")

func _select_attack_type(atype):
	selected_attack_type = atype
	attack_menu.visible = false
	target_menu.visible = true  # now choose target

func _on_enemy_target_selected():
	target_menu.visible = false
	print("Player attacks enemy with type: %s" % CombatTypes.entity_type_to_string(selected_attack_type))
	manager.player_attack(selected_attack_type)
	
	# After attack animation return to main menu if player’s turn again
	main_menu.visible = true

# Functions for CombatManager signals
# TO-DO change this on UI update
func _show_ui():
	main_menu.visible = true
	attack_menu.visible = false
	target_menu.visible = false
	
func _hide_ui():
	main_menu.visible = false
	attack_menu.visible = false
	target_menu.visible = false
