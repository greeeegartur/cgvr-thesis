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

const EDGE_VIGNETTE_SHADER := preload("res://Scenes/VFX/EdgeVignette.gdshader")
const EDGE_VIGNETTE_ALPHA := 0.32
const INFO_ABOVE_HEAD := Vector2(-48, -66) # From a character's feet to a text box centered just above its head

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	vignette.modulate = crit_flash_color

# VFX method package for hits; the multiplier of a tame sequence picks the burst and number tier (below 1: small, 1.25 and up: strong, all perfect: critical)
# show_number false plays only the burst (the number follows once the real meter change is known)
func play_damage_vfx(target_visual: Node2D, damage: float, is_critical: bool, is_block = false, multiplier := 1.0, tame_side := false, show_number := true):
	var color = crit_flash_color if is_critical else normal_flash_color
	color = block_flash_color if is_block else color
	var tier := DamageNumber.Tier.STRONG if multiplier >= TameSequence.MULT_ANY_PERFECT and not is_critical else DamageNumber.Tier.NORMAL
	if show_number:
		spawn_damage_number(target_visual, damage, is_critical, false, tier, tame_side)
	var strength := HitBurst.Strength.NORMAL
	if is_critical:
		strength = HitBurst.Strength.CRIT
	elif is_block:
		strength = HitBurst.Strength.BLOCK
	elif multiplier < 1.0:
		strength = HitBurst.Strength.SMALL
	elif tier == DamageNumber.Tier.STRONG:
		strength = HitBurst.Strength.STRONG
	HitBurst.burst(particle_layer, target_visual.position, color, strength)

# A killed creature bursts into red stars (waits a moment so the hit that killed it lands first)
func play_kill_burst(target_visual: Node2D):
	StarBurst.play(particle_layer, target_visual.position, StarBurst.Preset.KILL, Color(0, 0, 0, 0), 0.12)

# The end of a dream: stars, sparkles and rings for a success, a dull ring and falling sparks for a failure
func play_tame_payoff(target_visual: Node2D, success: bool):
	if success:
		StarBurst.play(particle_layer, target_visual.position, StarBurst.Preset.TAME)
		play_vignette(subdue_flash_color, 0.35, 0.1, 0.5)
		play_speedlines(subdue_flash_color, 0.4, 0.08, 0.35)
	else:
		StarBurst.play(particle_layer, target_visual.position, StarBurst.Preset.TAME_FAIL)

# Taming starts: neon pixels spiral into the creature
func play_subdue(target_visual: Node2D, _is_subdue := true):
	TameSpiral.play(particle_layer, target_visual.position)

# Spawns a damage number near an entity visual that took damage
func spawn_damage_number(target_visual: Node2D, damage: float, is_critical: bool, is_heal := false, tier := DamageNumber.Tier.NORMAL, tame_side := false):
	if not DamageNumberScene:
		print("No DamageNumber scene set in VFXCombatManager")
		return
	
	# Adding damage number to scene
	var num := DamageNumberScene.instantiate()
	damage_layer.add_child(num)
	# Kept inside the camera and clear of other numbers
	num.position = DamageNumber.placed(damage_layer, target_visual.position)

	num.play(damage, is_critical, is_heal, tier, tame_side)

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

# A soft dark vignette at the screen edges while a block window is open
var edge_vignette: ColorRect
var edge_tween: Tween
func set_edge_vignette(on: bool) -> void:
	if edge_vignette == null:
		var layer := CanvasLayer.new()
		layer.layer = 1 # Over the world, under the UI
		add_child(layer)
		edge_vignette = ColorRect.new()
		edge_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		edge_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = EDGE_VIGNETTE_SHADER
		edge_vignette.material = material
		edge_vignette.modulate.a = 0.0
		layer.add_child(edge_vignette)
	if edge_tween:
		edge_tween.kill()
	edge_tween = create_tween()
	edge_tween.tween_property(edge_vignette, "modulate:a", EDGE_VIGNETTE_ALPHA if on else 0.0, 0.1 if on else 0.18)

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
	feedback.position = ActionFeedback.place(feedback_layer, target_visual.position + Vector2(randf_range(-18, 18), randf_range(-8, 8)), ActionFeedback.FEEDBACK_BOX, 40.0, 14.0)
	feedback.play(text)

# Item, ability and reveal texts: smaller and longer than combat feedback so they are easy to read
func spawn_info(target_visual: Node2D, text: String, extra_time := 0.0):
	if not HitFeedbackScene:
		return
	
	var feedback := HitFeedbackScene.instantiate()
	feedback_layer.add_child(feedback)
	feedback.position = ActionFeedback.place(feedback_layer, target_visual.position + Vector2(0, -20), ActionFeedback.FEEDBACK_BOX, 24.0, 14.0)
	Sfx.play("modifier_indicator", target_visual) # Ability, item and status texts
	feedback.play_info(text, feedback.INFO_LIFETIME + extra_time)

# An info text right above a character's head (not moved aside by other texts, only kept on screen)
func spawn_info_above(target_visual: Node2D, text: String):
	if not HitFeedbackScene:
		return
	
	var feedback := HitFeedbackScene.instantiate()
	feedback_layer.add_child(feedback)
	var at: Vector2 = target_visual.position + INFO_ABOVE_HEAD
	feedback.position = ActionFeedback.place(feedback_layer, at, ActionFeedback.FEEDBACK_BOX, 24.0, 0.0, false)
	feedback.play_info(text)
	Sfx.play("modifier_indicator", target_visual)

# One of the tier texts (Perfect, Good, Try, Miss, Block...) at a world position, kept inside the camera
func play_tier_feedback(at: Vector2, tier: ActionFeedback.Tier) -> void:
	ActionFeedback.show(HitFeedbackScene, feedback_layer, at, tier)

# When taming a creature before its first turn
func play_perfect_feedback(target_visual: Node2D):
	play_tier_feedback(target_visual.position + Vector2(0, -30), ActionFeedback.Tier.TAME)
	
	emit_explosion(target_visual, crit_flash_color, true)

# When the player turns on a creature they were taming: harsh text, red vignette (the caller adds the hit-stop)
func play_betrayal_feedback(target_visual: Node2D):
	if HitFeedbackScene:
		var feedback := HitFeedbackScene.instantiate()
		feedback_layer.add_child(feedback)
		feedback.position = target_visual.position + Vector2(0, -30)
		feedback.play_flair("[color=#b00d0d][shake rate=24 level=10]Betrayal![/shake][/color]", Color("#4d0000"), 30)
	
	play_vignette(Color("#7a0000"), 0.7, 0.05, 0.4)

# Small one-shot particles around an entity for heals, power and defense changes
func play_buff_particles(target_visual: Node2D, kind: BuffParticles.Kind):
	BuffParticles.burst(particle_layer, target_visual.position, kind)
	# Heals have their own sound; power and defense changes share the stat sound (a drop is lower)
	match kind:
		BuffParticles.Kind.HEAL:
			Sfx.play("healing", target_visual)
		BuffParticles.Kind.DEFENSE_DOWN:
			Sfx.play("stat_change", target_visual, { "pitch": 0.8, "volume": -3.0 })
		_:
			Sfx.play("stat_change", target_visual)

func play_crit_feedback(target_visual):
	play_tier_feedback(target_visual.position + Vector2(0, -20), ActionFeedback.Tier.PERFECT)

func play_block_feedback(target_visual):
	play_tier_feedback(target_visual.position + Vector2(0, -20), ActionFeedback.Tier.BLOCK)

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

# Used in the repair ability game: the part flies in from the edge of the play area (it handles its own pop-in, trail and chevron)
func _spawn_repair_object(target, dir: String) -> Node2D:
	var obj: RepairObject = RepairObjectScene.instantiate()
	get_parent().add_child(obj)
	obj.launch(target, dir)
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
	tween.parallel().tween_property(obj, "rotation", obj.rotation + PI * 0.5, 0.25)
	
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
