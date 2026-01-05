extends Node2D

# Universal attack pattern logic for all enemies, uses emitters for connecting animations in CombatManager

class_name EnemyVisual

signal attack_started
signal attack_hit
signal attack_finished

@onready var anim := $AnimationPlayer
@onready var visual: Node2D = $Visual
@onready var hud := $EnemyHUD

# HUD variables
@onready var hp_fill = $EnemyHUD/HPBar/Fill
@onready var hp_label = $EnemyHUD/HPBar/Label
@onready var def_fill = $EnemyHUD/DefenseBar/Fill
@onready var def_label = $EnemyHUD/DefenseBar/Label
@onready var snapped_container = $EnemyHUD/SnappedContainer

var hp_fill_max_width = 10.0
var def_fill_max_width = 10.0

var home_position : Vector2 # The enemy's original position
var attack_position : Vector2 # The position where the enemy's pattern will connect to the (intended) player sprite

# Enemy moves to position, attacks, returns back to original position
func play_attack(animation_name: String):
	await _move_to_attack_position()
	attack_started.emit()
	anim.play(animation_name)

func on_attack_hit():
	attack_hit.emit()

func _ready():
	attack_position = home_position + Vector2(-320, 0)
	anim.animation_finished.connect(on_anim_finished)
	
	hp_fill_max_width = hp_fill.size.x
	def_fill_max_width = def_fill.size.x

func on_anim_finished(name: String):
	if name == "idle":
		return
	await _move_to_home_position()
	attack_finished.emit()

# Movement methods for connecting patterns using tweens (same methods just in reverse)
func _move_to_attack_position():
	var tween := create_tween()
	tween.tween_property(self, "global_position", attack_position, 1.5)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished

func _move_to_home_position():
	var tween := create_tween()
	tween.tween_property(self, "global_position", home_position, 1.5)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN)
	await tween.finished

# Sets the home position in CombatManager
func set_home_position():
	home_position = global_position
	attack_position = home_position + Vector2(-320, 0)

# Updates UI for player/enemy stats with helper functions
func update_hp(current: float, max_hp):
	var ratio = clamp(current / max_hp, 0.0, 1.0)
	hp_fill.size.x = hp_fill_max_width * ratio
	hp_label.text = "%d / %d" % [current, max_hp]

func update_defense(current: float, max_def: float):
	var ratio = clamp(current / max_def, 0.0, 1.0)
	def_fill.size.x = def_fill_max_width * ratio
	def_label.text = "%d / %d" % [current, max_def]

func update_snapped(snapped: int, snapped_max: int):
	for i in range(snapped_container.get_child_count()):
		var icon := snapped_container.get_child(i)
		icon.visible = i < snapped_max
		icon.modulate = Color.WHITE if i < snapped else Color(1, 1, 1, 0.25)
