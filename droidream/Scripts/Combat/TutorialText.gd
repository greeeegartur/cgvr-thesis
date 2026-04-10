extends CanvasLayer

# This script is responsible for tutorial texts during turns like "Press Z to block" etc.

class_name TutorialText

# Nodes that appear during the following circumstances:
# Turn nodes
@onready var panel := $Control/BattlePanel
@onready var label := $Control/BattlePanel/HBoxContainer/Label
@onready var z_icon := $Control/BattlePanel/HBoxContainer/ZIcon

# Selection nodes
@onready var x_icon := $Control/ControlsHint/XIcon
@onready var controls_hint_node := $Control/ControlsHint
@onready var controls_hint_label := $Control/ControlsHint/Label
@onready var anim := $Control/AnimationPlayer

@onready var select_hint_node := $Control/SelectHint
@onready var select_hint_label := $Control/SelectHint/Label

var hint_types_in_battle_panel = [HintType.CRIT, HintType.BLOCK, HintType.REPAIR, HintType.MULTITAME, HintType.HEATUP, HintType.HARDEN]

# Different states for it to react accordingly
enum HintType {
	PLAYER_TURN,
	PLAYER_SELECT,
	SHOP,
	CRIT,
	BLOCK,
	REPAIR,
	MULTITAME,
	HEATUP,
	HARDEN
}
var current_state

func show_hint(type: HintType):
	match type:
		HintType.PLAYER_TURN:
			current_state = HintType.PLAYER_TURN
			panel.visible = false
			select_hint_node.visible = false
			controls_hint_node.visible = true
			x_icon.visible = true
			show_text("Move           / Confirm     / Cancel", controls_hint_label, controls_hint_node)

		HintType.PLAYER_SELECT:
			current_state = HintType.PLAYER_SELECT
			panel.visible = false
			controls_hint_node.visible = false
			select_hint_node.visible = true
			x_icon.visible = false
			show_text("Select a target entity!", select_hint_label, select_hint_node)

		HintType.SHOP:
			current_state = HintType.SHOP
			panel.visible = false
			select_hint_node.visible = false
			controls_hint_node.visible = true
			x_icon.visible = false
			show_text("Move           / Confirm     ", controls_hint_label, controls_hint_node)

		HintType.CRIT:
			current_state = HintType.CRIT
			panel.visible = true
			select_hint_node.visible = false
			controls_hint_node.visible = false
			z_icon.visible = true
			z_icon.position = Vector2(69, 10)
			show_text("Press      right before hitting to crit!", label, panel)

		HintType.BLOCK:
			current_state = HintType.BLOCK
			panel.visible = true
			select_hint_node.visible = false
			controls_hint_node.visible = false
			z_icon.visible = true
			z_icon.position = Vector2(62.3, 10)
			show_text("Press      before a hit to block!", label, panel)

		HintType.REPAIR:
			current_state = HintType.REPAIR
			panel.visible = true
			select_hint_node.visible = false
			controls_hint_node.visible = false
			z_icon.visible = false
			show_text("Press towards yourself to absorb parts!", label, panel)
		
		HintType.MULTITAME:
			current_state = HintType.MULTITAME
			panel.visible = true
			select_hint_node.visible = false
			controls_hint_node.visible = false
			z_icon.visible = true
			z_icon.position = Vector2(57.9, 10)
			show_text("Press     when the shapes are aligned!", label, panel)
		
		HintType.HEATUP:
			current_state = HintType.HEATUP
			panel.visible = true
			select_hint_node.visible = false
			controls_hint_node.visible = false
			z_icon.visible = false
			show_text("Press keys to power up!", label, panel)
		
		HintType.HARDEN:
			current_state = HintType.HARDEN
			panel.visible = true
			select_hint_node.visible = false
			controls_hint_node.visible = false
			z_icon.visible = false
			show_text("Press keys in the correct order for greater defense!", label, panel)

# Methods for turns
func show_text(text: String, settable_label: Label, node):
	settable_label.text = text
	node.visible = true
	node.modulate.a = 0.0
	
	# Press Z
	if panel.visible:
		anim.play("press")
	elif controls_hint_node.visible:
		anim.play("idle")
	
	
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 1.0, 0.25)

func hide_text():
	var node
	if current_state in hint_types_in_battle_panel:
		node = panel
	elif current_state == HintType.PLAYER_TURN or current_state == HintType.SHOP:
		node = controls_hint_node
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func():
		anim.stop()
	)
