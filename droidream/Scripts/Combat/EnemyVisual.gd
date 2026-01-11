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
@onready var flash: ColorRect = $DamageFlash
@onready var fx_root: Node2D = $DamageFX
@export var damage_number_scene: PackedScene

# HUD variables
@onready var hp_fill = $EnemyHUD/HPBar/Fill
@onready var hp_label = $EnemyHUD/HPBar/Label
@onready var def_fill = $EnemyHUD/DefenseBar/Fill
@onready var def_label = $EnemyHUD/DefenseBar/Label
@onready var snapped_container = $EnemyHUD/SnappedContainer

var hp_fill_max_width = 10.0
var def_fill_max_width = 10.0

# VFX variables, will change these in the future
@export var normal_flash_color = Color(0.904, 0.135, 0.214, 1.0)
@export var crit_flash_color = Color(1.0, 0.949, 0.2, 1.0)
@export var subdue_flash_color = Color(0.602, 0.181, 0.64, 1.0)
@export var shake_strength = 1.0
@export var crit_shake_strength = 3.0

# Position variables
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
	# Checking for damage number scene (must be added as export, otherwise won't load)
	assert(damage_number_scene, "EnemyVisual: damage_number_scene not assigned!")
	attack_position = home_position + Vector2(-320, 0)
	anim.animation_finished.connect(on_anim_finished)
	
	hp_fill_max_width = hp_fill.size.x
	def_fill_max_width = def_fill.size.x
	# Combat scene's process mode (pausing) for minigames
	process_mode = Node.PROCESS_MODE_PAUSABLE

# Unused for now
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
		icon.modulate = Color.WHITE if i < snapped else Color(1, 1, 1, 0.25)

# Universal VFX methods for all enemies to use (using tweens) 
func play_damage_vfx(damage: float, is_critical: bool):
	_flash(is_critical)
	_shake(is_critical)
	_spawn_damage_number(damage, is_critical)

# Light flash effect
func _flash(is_critical: bool):
	flash.modulate = crit_flash_color if is_critical else normal_flash_color
	flash.visible = true
	
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	tween.finished.connect(func():
		flash.visible = false
	)

# Creates light position shake for enemy
func _shake(is_critical: bool):
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

# Spawns a damage number from the DamageNumber scene and plays it based on given hit
func _spawn_damage_number(damage: float, is_critical: bool):
	# Failsafe check
	if not damage_number_scene:
		return
	
	var num = damage_number_scene.instantiate()
	fx_root.add_child(num)
	num.position = Vector2(randf_range(-3, 3), randf_range(-3, 3))
	num.play(damage, is_critical)

# Subduing VFX
func play_subdue_vfx():
	_flash_color(subdue_flash_color, 2.4)

# Refactored _flash that accepts color and duration
func _flash_color(color: Color, duration = 0.15):
	flash.modulate = color
	flash.visible = true
	
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.finished.connect(func():
		flash.visible = false
	)
