extends Node

# This class is responsible for all VFX being played in the combat scene
# This script controls the VFX layer (which follows the camera) in the combat scene to play effects in local position 

class_name VFXCombatManager

# Exported node variables
@export var DamageNumberScene: PackedScene
@export var ExplosionFXScene: PackedScene
@export var HitFeedbackScene: PackedScene
@export var RepairObjectScene: PackedScene
@export var MultiTameBallScene: PackedScene
@export var camera: Camera2D

# Layer node variables
@onready var damage_layer := $"../DamageNumbers"
@onready var particle_layer := $"../Particles"
@onready var vignette := $"../Vignette"
@onready var speedlines := $"../../Camera2D/Speedlines"
@onready var feedback_layer := $"../FeedbackText"
@onready var karma_overlay := $"../KarmaOverlay"


# Colors
@export var normal_flash_color = Color("e72237ff")
@export var crit_flash_color = Color("#eff238")
@export var subdue_flash_color = Color("9a2ea3ff")
@export var block_flash_color = Color("00d200ff")
var COLORS : Dictionary

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	vignette.modulate = crit_flash_color

# VFX method package for hits (both normal and critical)
func play_damage_vfx(target_visual: Node2D, damage: float, is_critical: bool, is_block = false):
	var color = crit_flash_color if is_critical else normal_flash_color
	color = block_flash_color if is_block else color
	spawn_damage_number(target_visual, damage, is_critical)
	emit_explosion(target_visual, color, false)

func play_subdue(target_visual: Node2D, is_subdue:= true):
	emit_explosion(target_visual, subdue_flash_color, is_subdue)

# Spawns a damage number near an entity visual that took damage
func spawn_damage_number(target_visual: Node2D, damage: float, is_critical: bool, is_heal := false):
	if not DamageNumberScene:
		print("No DamageNumber scene set in VFXCombatManager")
		return
	
	# Adding damage number to scene
	var num := DamageNumberScene.instantiate()
	damage_layer.add_child(num)
	# Rendering damage number in screen space
	num.position = target_visual.position

	num.play(damage, is_critical, is_heal)

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

func emit_explosion_from_vector(vector: Vector2, color: String):
	if not ExplosionFXScene:
		print("No Explosion scene set in VFXCombatManager")
		return
	
	# Adding explosion to scene
	var fx := ExplosionFXScene.instantiate()
	particle_layer.add_child(fx)
	
	# Base values
	fx.position = vector
	fx.modulate = get_vfx_color_from_string(color) # Crit, hit or subdue
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.scale = Vector2(1.5, 1.5)
	fx.emitting = true
	await get_tree().create_timer(fx.lifetime).timeout
	fx.queue_free()
	

func play_overlay_effects(color_name: String, alpha := 0.5):
	play_vignette(get_vfx_color_from_string(color_name), alpha)
	if (color_name == "crit"): 
		play_speedlines(get_vfx_color_from_string(color_name), 0.8) # Only plays when player crits

# Vignette player (reusable for all sorts of hits), TO-DO: replace with actual vignette, not ColorRect
func play_vignette(color: Color, max_alpha := 0.5, in_time := 0.05, out_time := 0.15):
	vignette.color = color
	vignette.visible = true
	vignette.modulate.a = 0.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(vignette, "modulate:a", max_alpha, in_time)
	tween.tween_property(vignette, "modulate:a", 0.0, out_time)

# Plays speedlines similar to vignette
func play_speedlines(color: Color, max_alpha := 0.5, in_time := 0.05, out_time := 0.25):
	speedlines.modulate = color
	speedlines.visible = true
	speedlines.modulate.a = 0.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(speedlines, "modulate:a", max_alpha, in_time)
	tween.tween_property(speedlines, "modulate:a", 0.0, out_time)

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

func spawn_feedback(target_visual: Node2D, text: String):
	if not HitFeedbackScene:
		return
	
	var feedback := HitFeedbackScene.instantiate()
	feedback_layer.add_child(feedback)
	feedback.position = target_visual.position + Vector2(randf_range(-18, 18), randf_range(-8, 8))
	feedback.play(text)

func play_crit_feedback(target_visual):
	var texts = [
		"[color=#9a2ea3ff][wave freq=14]Awesome![/wave][/color]",
		"[color=#3d9feb][shake rate=18]Great![/shake][/color]",
	    "[color=#eff238][wave freq=14]Nice![/wave][/color]"
	]
	spawn_feedback(target_visual, texts.pick_random())

func play_block_feedback(target_visual):
	var texts = [
		"[color=#17e84f][wave freq=14]Blocked![/wave][/color]",
	    "[color=#06d63e][shake rate=18]Negated![/shake][/color]"
	]
	spawn_feedback(target_visual, texts.pick_random())

func play_multihit_feedback(target_visual):
	var texts = [
	"[color=#eff238][wave freq=14]Hit![/wave][/color]",
	"[color=#06d63e][shake rate=18]Wow![/shake][/color]",
	"[color=#3d9feb][shake rate=18]Yeah![/shake][/color]"
	]
	spawn_feedback(target_visual, texts.pick_random())

func play_human_at_heart_feedback(target_visual, amount_of_times_triggered):
	var texts = {
		0: "[color=#e72237ff][wave freq=14]Powered up![/wave][/color]",
		1: "[color=#c70000][wave freq=14]More.. power[/wave][/color]",
		2: "[color=#690101][wave freq=14]...[/wave][/color]",
		3: "[color=#4d0000][wave freq=14]Enjoying yourself?[/wave][/color]",
		4: "[color=#2e0000][wave freq=14]I am[/wave][/color]"
	}
	spawn_feedback(target_visual, texts.get(amount_of_times_triggered, texts[4]))

# Used in the repair ability game
func _spawn_repair_object(target, dir: String) -> Node2D:
	var obj = RepairObjectScene.instantiate() # TO-DO replace with scene
	var offset = Utils.DIR_MAP[dir] * 30
	obj.global_position = target.global_position + offset
	obj.scale = Vector2.ZERO
	get_parent().add_child(obj)
	
	# Object spawn tween
	var tween = create_tween()
	tween.tween_property(obj, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK)
	
	return obj

# Used in the repair ability game
func _absorb_object(target, obj: Node2D):
	var tween = create_tween()
	tween.tween_property(
		obj,
		"global_position",
		target.global_position,
		0.25
	).set_trans(Tween.TRANS_CUBIC)
	
	tween.parallel().tween_property(obj, "scale", Vector2.ZERO, 0.25)
	
	await tween.finished
	obj.queue_free()

# Used in the multi-tame ability game
func play_multi_tame_ball(player_visual: Node2D, target_visual: Node2D, texture := false):
	var ball = MultiTameBallScene.instantiate()
	feedback_layer.add_child(ball)
	ball.global_position = player_visual.global_position + Vector2(28, -8)
	if texture:
		ball.set_to_ball_texture()
	await ball.fly_to(target_visual.global_position + Vector2(-8, -8))
	return ball

func bounce_and_fade_ball(ball, target_pos: Vector2):
	await ball.bounce_and_fade(target_pos + Vector2(-8, -8))
	ball.reset_after_ball_texture()

# Karma overlay updates
func _update_karma_overlay():
	if karma_overlay == null:
		return
	
	var target_alpha := PlayerData.get_karma_overlay_alpha()
	var tween := create_tween()
	tween.tween_property(karma_overlay, "modulate:a", target_alpha, 0.35)
