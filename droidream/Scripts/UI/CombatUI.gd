extends Node

# This script acts as the frontend manager for the backend CombatManager script

@export var InventoryHudIconScene: PackedScene
@onready var manager: CombatManager
@onready var player_stats_hud := $PlayerStatsHUD
@onready var power_label: Label = $PlayerStatsHUD/PowerRow/Label
@onready var defense_label: Label = $PlayerStatsHUD/DefenseRow/Label
@onready var bolts_label: Label = $PlayerStatsHUD/BoltsRow/Label
@onready var abilities_label: Label = $PlayerStatsHUD/AbilitiesLabel
@onready var abilities_row: HBoxContainer = $PlayerStatsHUD/AbilitiesRow
@onready var items_label: Label = $PlayerStatsHUD/ItemsLabel
@onready var items_row: HBoxContainer = $PlayerStatsHUD/ItemsRow

signal turn_order_toggled(enabled: bool)
var turn_order_enabled := false

var selected_attack_type := CombatTypes.EntityType.SKY
var stats_hud_tween: Tween

func _ready():
	#player_stats_hud.visible = true
	#player_stats_hud.modulate.a = 1.0
	refresh_player_hud()

func setup(combat_manager: CombatManager):
	manager = combat_manager
	if not manager.combat_end.is_connected(_combat_end):
		manager.combat_end.connect(_combat_end)
	
	if not PlayerData.stats_changed.is_connected(_update_player_stats_hud):
		PlayerData.stats_changed.connect(_update_player_stats_hud)
	
	_update_player_stats_hud()

func _unhandled_input(event):
	if event.is_action_pressed("toggle_turn_order"):
		_toggle_turn_order()
		return

func _toggle_turn_order():
	turn_order_enabled = !turn_order_enabled
	emit_signal("turn_order_toggled", turn_order_enabled)

func _update_player_stats_hud():
	if power_label == null:
		return
	
	var shown_power := PlayerData.attack
	var shown_defense := PlayerData.defense
	
	if manager != null and manager.player != null:
		shown_power = manager.player.attack_power
		shown_defense = manager.player.defense
	
	power_label.text = "%s" % _format_quarter(shown_power)
	defense_label.text = "%s" % _format_quarter(shown_defense)
	bolts_label.text = "x%d" % PlayerData.currency

func _format_quarter(value: float) -> String:
	var rounded = round(value * 4.0) / 4.0
	if is_equal_approx(rounded, round(rounded)):
		return str(int(round(rounded)))
	return "%.2f" % rounded

func hide_player_stats_hud():
	if not is_node_ready():
		await ready
	if player_stats_hud == null:
		return

	if stats_hud_tween:
		stats_hud_tween.kill()
	stats_hud_tween = create_tween()
	stats_hud_tween.tween_property(player_stats_hud, "modulate:a", 0.0, 0.18)
	await stats_hud_tween.finished
	
	player_stats_hud.visible = false


func show_player_stats_hud():
	if not is_node_ready():
		await ready
	if player_stats_hud == null:
		return

	if stats_hud_tween:
		stats_hud_tween.kill()
	player_stats_hud.visible = true
	
	stats_hud_tween = create_tween()
	stats_hud_tween.tween_property(player_stats_hud, "modulate:a", 1.0, 0.18)
	await stats_hud_tween.finished

func _combat_end(_victory := true, _rewards := {}):
	_update_player_stats_hud()
	print("end from UI")

func refresh_player_hud():
	_update_player_stats_hud()
	_update_inventory_hud()

func _update_inventory_hud():
	_update_abilities_hud()
	_update_items_hud()

func _update_abilities_hud():
	for child in abilities_row.get_children():
		child.queue_free()
	
	var abilities = PlayerData.abilities
	abilities_label.text = "Abilities: (%d/6)" % abilities.size()
	
	for ability in abilities:
		var icon = InventoryHudIconScene.instantiate()
		abilities_row.add_child(icon)
		if ability.is_active() and ability.data.icon:
			icon.setup(ability.data.icon, 1, false)
		else: # Passive
			icon.setup(ItemDb.get_item(ability.data.id).icon, 1, false)

func _update_items_hud():
	for child in items_row.get_children():
		child.queue_free()
	
	var items = PlayerData.items
	items_label.text = "Items: (%d/6)" % items.size()
	
	for item in items:
		var icon = InventoryHudIconScene.instantiate()
		items_row.add_child(icon)
		if item.data.icon:
			icon.setup(item.data.icon, item.amount, true)
