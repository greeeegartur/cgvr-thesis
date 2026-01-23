extends Node

# This class is responsible for all VFX being played in the combat scene
# This script controls the VFX layer (which follows the camera) in the combat scene to play effects in local position 

class_name VFXCombatManager

# Exported node variables
@export var DamageNumberScene: PackedScene
@export var ExplosionFXScene: PackedScene
@export var camera: Camera2D

# Layer node variables
@onready var damage_layer := $"../DamageNumbers"
@onready var particle_layer := $"../Particles"
@onready var vignette := $"../Vignette"

# Colors
@export var normal_flash_color = Color(0.904, 0.135, 0.214, 1.0)
@export var crit_flash_color = Color(1.0, 0.949, 0.2, 1.0)
@export var subdue_flash_color = Color(0.602, 0.181, 0.64, 1.0)
@export var block_flash_color = Color(0.0, 0.825, 0.0, 1.0)
var COLORS : Dictionary

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	vignette.modulate = crit_flash_color

# VFX method package for hits (both normal and critical)
func play_damage_vfx(target_visual: Node2D, damage: float, is_critical: bool, is_block: bool = false):
	var color = crit_flash_color if is_critical else normal_flash_color
	color = block_flash_color if is_block else color
	spawn_damage_number(target_visual, damage, is_critical)
	emit_explosion(target_visual, color, false)

func play_subdue(target_visual: Node2D, is_subdue:= true):
	emit_explosion(target_visual, subdue_flash_color, is_subdue)

# Spawns a damage number near an entity visual that took damage
func spawn_damage_number(target_visual: Node2D, damage: float, is_critical: bool):
	if not DamageNumberScene:
		print("No DamageNumber scene set in VFXCombatManager")
		return
	
	# Adding damage number to scene
	var num := DamageNumberScene.instantiate()
	damage_layer.add_child(num)
	# Rendering damage number in screen space
	num.position = target_visual.position

	num.play(damage, is_critical)

# Explosion VFX for hits and subduing
func emit_explosion(target_visual: Node2D, color: Color, is_subdue := false):
	if not ExplosionFXScene:
		print("No Explosion scene set in VFXCombatManager")
		return
	
	# Adding explosion to scene
	var fx := ExplosionFXScene.instantiate()
	particle_layer.add_child(fx)
	
	# Base values
	fx.position = target_visual.position
	fx.modulate = color # Crit, hit or subdue
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.scale = Vector2(1.5, 1.5)
	
	# Minigame specific values
	if is_subdue:
		fx.scale = Vector2(2.75, 2.75)
		if fx.process_material:
			fx.process_material.orbit_velocity_min = 0.51
			fx.process_material.orbit_velocity_max = 1.276
	
	fx.emitting = true
	await get_tree().create_timer(fx.lifetime).timeout
	fx.queue_free()

# Vignette player (reusable for all sorts of hits), TO-DO: replace with actual vignette, not ColorRect
func play_vignette(color: Color, max_alpha := 0.5, in_time := 0.05, out_time := 0.15):
	vignette.color = color
	vignette.visible = true
	vignette.modulate.a = 0.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(vignette, "modulate:a", max_alpha, in_time)
	tween.tween_property(vignette, "modulate:a", 0.0, out_time)

# Very arbitrary method for CombatManager to get VFX colors for vignette player, TO-DO: change this if more colors
func get_vfx_color_from_string(color: String): 
	if color == "normal":
		return normal_flash_color
	elif color == "crit":
		return crit_flash_color
	elif color == "subdue":
		return subdue_flash_color
	elif color == "block":
		return block_flash_color
