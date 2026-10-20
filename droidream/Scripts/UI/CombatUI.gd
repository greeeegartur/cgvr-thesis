extends Node

# This script acts as the frontend manager for the backend CombatManager script

@onready var manager: CombatManager
@onready var player_stats_hud := $PlayerStatsHUD
@onready var power_label: Label = $PlayerStatsHUD/PowerRow/Label
@onready var defense_label: Label = $PlayerStatsHUD/DefenseRow/Label
@onready var bolts_label: Label = $PlayerStatsHUD/BoltsRow/Label
@onready var abilities_row: HudSlotRow = $PlayerStatsHUD/AbilitiesRow
@onready var items_row: HudSlotRow = $PlayerStatsHUD/ItemsRow

const STAT_FONT_SIZE := 16
const STAT_FONT_SMALL := 12 # Used when a stat text such as +0.25 would reach the slot rows
const STAT_TEXT_MAX_WIDTH := 36.0 # Space between a stat icon and its slot row

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
	
	# Only what the player gained (or lost for now) is shown, e.g. +2; +0 while there is no difference
	_show_stat_gain(power_label, shown_power - PlayerData.BASE_ATTACK)
	_show_stat_gain(defense_label, shown_defense - PlayerData.BASE_DEFENSE)
	bolts_label.text = "x%d" % PlayerData.currency

# Shows a stat's difference from its base as a signed number; the text gets smaller if it would reach the slot rows
func _show_stat_gain(label: Label, gain: float) -> void:
	var rounded := Utils.quantize(gain)
	label.text = ("+" if rounded >= 0.0 else "") + _format_quarter(rounded)
	label.add_theme_color_override("font_color", Color("#ff8a80") if rounded < 0.0 else (Color.WHITE if rounded > 0.0 else Color(0.75, 0.75, 0.75)))
	
	var font := label.get_theme_font("font")
	var fits := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, STAT_FONT_SIZE).x <= STAT_TEXT_MAX_WIDTH
	label.add_theme_font_size_override("font_size", STAT_FONT_SIZE if fits else STAT_FONT_SMALL)

func _format_quarter(value: float) -> String:
	var rounded = round(value * 4.0) / 4.0
	if is_equal_approx(rounded, round(rounded)):
		return str(int(round(rounded)))
	return String.num(rounded, 2)

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

# Fills the ability slots (passives use their item icon)
func _update_abilities_hud():
	var entries := []
	for ability in PlayerData.abilities:
		var icon: Texture2D = ability.data.icon if ability.is_active() and ability.data.icon else ItemDb.get_item(ability.data.id).icon
		entries.append({ "id": ability.data.id, "name": ability.data.display_name, "icon": icon, "count": 1 })
	abilities_row.set_entries(entries)

# Fills the item slots with their stack counts
func _update_items_hud():
	var entries := []
	for item in PlayerData.items:
		entries.append({ "id": item.data.id, "name": item.data.display_name, "icon": item.data.icon, "count": item.amount })
	items_row.set_entries(entries)
