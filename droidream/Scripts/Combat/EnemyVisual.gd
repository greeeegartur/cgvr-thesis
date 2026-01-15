extends Node2D

# Universal attack pattern logic for all enemies, uses emitters for connecting animations in CombatManager

class_name EnemyVisual

signal attack_started
signal attack_hit
signal attack_finished

# Node variables
@onready var anim := $AnimationPlayer
@onready var visual: Node2D = $Visual
@onready var hud := $EnemyHUD
@onready var fx_root: Node2D = $DamageFX
@export var explosion_fx_scene: PackedScene
@onready var target_arrow := $TargetArrow
@onready var hit_anchor := $HitAnchor
@onready var target_arrow_anim := $TargetArrow/AnimationPlayer

# HUD variables
@onready var hp_fill = $EnemyHUD/HPBar/Fill
@onready var hp_label = $EnemyHUD/HPBar/Label
@onready var def_fill = $EnemyHUD/DefenseBar/Fill
@onready var def_label = $EnemyHUD/DefenseBar/Label
@onready var snapped_container = $EnemyHUD/SnappedContainer

var hp_fill_max_width = 10.0
var def_fill_max_width = 10.0

# Shake variables
@export var shake_strength = 2.0
@export var crit_shake_strength = 4.0

# Position variables + defeated check
var home_position : Vector2 # The enemy's original position
var attack_position : Vector2 # The position where the enemy's pattern will connect to the (intended) player sprite
@export var move_speed := 260.0 # Pixels per second, TO-DO: make adjustable for different enemies
var is_defeated := false # Checks if visual can play any other animations

# Enemy moves to position, attacks, returns back to original position
func play_attack(animation_name: String):
	await _move_to_attack_position(attack_position)
	attack_started.emit()
	anim.play(animation_name)

# Plays from CombatManager to decide defeat animation
func play_defeat(subdued: bool):
	is_defeated = true
	anim.play("subdue" if subdued else "death")

func on_attack_hit():
	attack_hit.emit()

func _ready():
	# Making visual visible (for some reason does not render otherwise)
	top_level = true
	visible = true
	z_index = 1
	
	anim.animation_finished.connect(on_anim_finished)
	
	hp_fill_max_width = hp_fill.size.x
	def_fill_max_width = def_fill.size.x
	
	# Combat scene's process mode (pausing) for minigames
	process_mode = Node.PROCESS_MODE_PAUSABLE

# When animation has finished
func on_anim_finished(name: String):
	if is_defeated:
		return
	if name == "RESET":
		return
	await _move_to_home_position()
	attack_finished.emit()

# Movement methods for connecting patterns using tweens (same methods just in reverse)
func _move_to_attack_position(target: Vector2):
	var dist = global_position.distance_to(target)
	var duration = dist / move_speed # t = d/v
	
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, duration)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished

func _move_to_home_position():
	var dist = global_position.distance_to(home_position)
	var duration = dist / move_speed # t = d/v
	
	var tween := create_tween()
	tween.tween_property(self, "global_position", home_position, duration)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN)
	await tween.finished

# Updates UI for enemy stats with helper functions
func update_hp(current: float, max_hp):
	var ratio = clamp(current / max_hp, 0.0, 1.0)
	hp_fill.size.x = hp_fill_max_width * ratio
	hp_label.text = "%.1f / %.1f" % [current, max_hp]

func update_defense(current: float, max_def: float):
	var ratio = clamp(current / max_def, 0.0, 1.0)
	def_fill.size.x = def_fill_max_width * ratio
	def_label.text = "%.1f / %.1f" % [current, max_def]

func update_snapped(snapped: int, snapped_max: int):
	for i in range(snapped_container.get_child_count()):
		var icon := snapped_container.get_child(i)
		icon.visible = i < snapped_max
		icon.modulate = Color(0.632, 0.316, 0.781, 1.0) if i < snapped else Color("ffffffff")

# Creates light position shake for enemy
func shake(is_critical: bool):
	var strength = crit_shake_strength if is_critical else shake_strength
	var original_pos = visual.position
	
	var tween := create_tween()
	tween.tween_property(
		visual,
		"position",
		original_pos + Vector2(randf_range(-strength, strength), randf_range(-strength, strength)),
		0.05
	)
	tween.tween_property(visual, "position", original_pos, 0.1)

# Target arrow UI elements
func show_target_arrow():
	if target_arrow.visible:
		return
	target_arrow.visible = true
	target_arrow_anim.play("idle")

func hide_target_arrow():
	if is_defeated:
		return
	target_arrow.visible = false
	target_arrow_anim.play("RESET")
