extends Node2D

# Universal attack pattern logic for all enemies, uses emitters for connecting animations in CombatManager

class_name EnemyVisual

signal attack_started
signal attack_hit
signal attack_finished

# Node variables
@onready var anim := $AnimationPlayer
@onready var visual: Node2D = $Visual
@onready var target_arrow := $TargetArrow
@onready var target_arrow_anim := $TargetArrow/AnimationPlayer
@onready var turn_order_label: Label = $TurnOrder
@onready var axis_bar := $EnemyAxisBar

# Target preview markers (created in code, so every creature scene gets them)
const OUTLINE_SHADER := preload("res://Scenes/VFX/TargetOutline.gdshader")
const SECONDARY_ARROW_SCALE := 0.6 # Secondary arrows are 60% of the main arrow
const SECONDARY_STRENGTH := 0.3 # Secondary targets pop and tint much less than the main target
const SECONDARY_OUTLINE_ALPHA := 0.55 # ...and have a fainter outline
const SECONDARY_ARROW_ALPHA := 0.6 # ...and a fainter arrow
const OUTLINE_WIDTH_MAIN := 1.5
const OUTLINE_WIDTH_SECONDARY := 1.0
var secondary_arrow: Node2D
var target_count_label: Label
var selection_pulse: SelectionPulse

# Shake variables
@export var shake_strength = 3.0
@export var crit_shake_strength = 6.0
var attack_animation_name: String
var support_animation_name: String

# Position variables + defeated check
var home_position : Vector2 # The enemy's original position
var attack_position : Vector2 # The position where the enemy's pattern will connect to the (intended) player sprite
var attack_offset := Vector2.ZERO # The attack position's offset for the enemy (different for every enemy)
var move_speed := 0 # Pixels per second, different for every enemy
var is_defeated := false # Checks if visual can play any other animations

# Enemy moves to position, attacks, returns back to original position
func play_attack(animation_name: String):
	attack_animation_name = animation_name
	await _move_to_attack_position(attack_position)
	attack_started.emit()
	anim.play(animation_name)

# Enemy support animation (attack method but not moving to attack position)
func play_support(animation_name: String):
	support_animation_name = animation_name
	attack_started.emit()
	anim.play(animation_name)
	await anim.animation_finished
	attack_finished.emit()

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
	_setup_target_markers()
	
	# Combat scene's process mode (pausing) for minigames
	process_mode = Node.PROCESS_MODE_PAUSABLE

# When animation has finished
func on_anim_finished(name: String):
	if is_defeated:
		return
	if name == "RESET":
		return
	if name == attack_animation_name or name == support_animation_name:
		anim.play("idle")
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

# Sets up axis UI info for CombatManager
func setup_axis(axis_max: float, trust_max: int):
	axis_bar.axis_max = axis_max
	axis_bar.setup_trust(trust_max)

# Updates axis UI info for enemy with EnemyAxisBar functions
func update_axis(value: float, delta_value := 0):
	axis_bar.update_axis(value, delta_value)

func update_axis_trust():
	axis_bar.gain_trust()

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

# Hopping animation
func hop(times := 1):
	var orig := position
	var tween := create_tween()
	for i in range(times):
		tween.tween_property(self, "position:y", orig.y - 18, 0.16)
		tween.tween_property(self, "position:y", orig.y, 0.2)

# Marks the creature whose minigame is up next: target arrow, a double pop and a warm flash
var highlight_tween: Tween
var highlight_active := false
var base_visual_scale := Vector2.ONE
var base_visual_modulate := Color.WHITE

func play_minigame_highlight():
	show_target_arrow()
	
	if highlight_tween:
		highlight_tween.kill()
	if not highlight_active:
		base_visual_scale = visual.scale
		base_visual_modulate = visual.modulate
	highlight_active = true
	
	highlight_tween = create_tween()
	for i in 2:
		highlight_tween.tween_property(visual, "scale", base_visual_scale * 1.3, 0.1)
		highlight_tween.parallel().tween_property(visual, "modulate", Color(1.0, 1.0, 0.55), 0.1)
		highlight_tween.tween_property(visual, "scale", base_visual_scale, 0.14)
		highlight_tween.parallel().tween_property(visual, "modulate", base_visual_modulate, 0.14)
	await highlight_tween.finished

# Removes the minigame highlight (arrow, scale and tint); defeat animations keep control of a defeated creature's look
func clear_minigame_highlight():
	if highlight_tween:
		highlight_tween.kill()
	
	if highlight_active and not is_defeated:
		visual.scale = base_visual_scale
		visual.modulate = base_visual_modulate
	highlight_active = false
	
	# Hides the arrow directly (hide_target_arrow ignores defeated creatures)
	target_arrow.visible = false
	target_arrow_anim.play("RESET")

# Builds the secondary arrow, the count label and the shared selection effect once
func _setup_target_markers():
	# Secondary arrow: a copy of the main arrow; it is driven by the selection effect (60% of the main arrow's size)
	secondary_arrow = target_arrow.duplicate()
	secondary_arrow.name = "SecondaryArrow"
	secondary_arrow.visible = false
	secondary_arrow.get_node("AnimationPlayer").queue_free()
	add_child(secondary_arrow)
	
	# Count label: sits above the main arrow and bobs with it
	var main_sprite: Sprite2D = target_arrow.get_node("Sprite2D")
	var arrow_height := main_sprite.texture.get_height() * main_sprite.scale.y
	target_count_label = Label.new()
	target_count_label.visible = false
	target_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_count_label.add_theme_font_override("font", load("res://Graphics/Fonts/PixelOperator-Bold.ttf"))
	target_count_label.add_theme_font_size_override("font_size", 16)
	target_count_label.add_theme_color_override("font_color", Color("#fff27a"))
	target_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	target_count_label.add_theme_constant_override("outline_size", 4)
	target_count_label.size = Vector2(48, 20)
	target_count_label.position = Vector2(-24, -arrow_height / 2.0 - 22) # Above the arrow, relative to the arrow sprite
	main_sprite.add_child(target_count_label)
	
	# Selection effect shared with the player
	selection_pulse = SelectionPulse.new(self, visual, visual.get_node_or_null("Sprite2D") as Sprite2D)

# Main target of the previewed action: big arrow, pop, tint, outline and the count of creatures that will be hit
func show_target_main(affected_count := 1):
	if is_defeated:
		return
	secondary_arrow.visible = false
	target_arrow_anim.stop()
	target_arrow.visible = true
	target_count_label.text = "x%d" % affected_count
	target_count_label.visible = affected_count >= 2
	selection_pulse.start(1.0, OUTLINE_WIDTH_MAIN, target_arrow.get_node("Sprite2D"))

# Another creature affected by the previewed action: small pale arrow, a lighter pop and a thin outline
func show_target_secondary():
	if is_defeated:
		return
	target_arrow_anim.stop()
	target_arrow.visible = false
	target_count_label.visible = false
	secondary_arrow.visible = true
	selection_pulse.start(SECONDARY_STRENGTH, OUTLINE_WIDTH_SECONDARY, secondary_arrow.get_node("Sprite2D"), SECONDARY_ARROW_SCALE, SECONDARY_OUTLINE_ALPHA, SECONDARY_ARROW_ALPHA)

# Removes every target preview marker (arrows, count, outline, pop and tint)
func clear_target_markers():
	if selection_pulse:
		selection_pulse.stop()
	target_arrow.visible = false
	if secondary_arrow:
		secondary_arrow.visible = false
	if target_count_label:
		target_count_label.visible = false

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

# Turn order UI elements
func show_turn_order(n: int):
	turn_order_label.text = str(n)
	turn_order_label.visible = true

func hide_turn_order():
	turn_order_label.visible = false
