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
const METER_LABEL_HEIGHT := 12.0 # The meter's labels and tame balls stick out this far above its bar
const ARROW_GAP := 4.0 # Space between them and the target arrow
const SECONDARY_ARROW_SCALE := 0.6 # Secondary arrows are 60% of the main arrow
const SECONDARY_STRENGTH := 0.3 # Secondary targets pop and tint much less than the main target
const SECONDARY_OUTLINE_ALPHA := 0.55 # ...and have a fainter outline
const SECONDARY_ARROW_ALPHA := 0.6 # ...and a fainter arrow
const OUTLINE_WIDTH_MAIN := 1.5
const OUTLINE_WIDTH_SECONDARY := 1.0
var secondary_arrow: Node2D
var target_count_label: Label
var selection_pulse: SelectionPulse

# Sound variables
@export var step_sound := "" # Its steps (or flaps) while it moves across the scene
@export var step_interval := 0.2 # Seconds between two of them
const IDLE_SOUND_GAP := 600 # Msec; idle sounds of different creatures never come closer, so only one idle creature is heard at a time
const IDLE_VOLUME := -14.0 # Idle sounds (a frog hopping in place) are much quieter than the same sound in an attack
static var last_idle_sound := 0
const WINDOW_BOOST_DB := 3.0 # Its attack sounds are this much louder while a hit's block window is open

# Shake variables
@export var shake_strength = 3.0
@export var crit_shake_strength = 6.0
var attack_animation_name: String
var support_animation_name: String

# Position variables + defeated check
var home_position : Vector2 # The enemy's original position
var attack_position : Vector2 # The position where the enemy's pattern will connect to the (intended) player sprite
var attack_offset := Vector2.ZERO # The attack position's offset for the enemy (different for every enemy)
var move_time := Vector2(0.85, 0.78) # Seconds to reach the Droid (x) and to walk back home (y), set per creature
var is_defeated := false # Checks if visual can play any other animations

# Enemy moves to position, attacks, returns back to original position
func play_attack(animation_name: String):
	attack_animation_name = animation_name
	_pin_meter() # The meter stays above the home slot during the lunge, so it never slides over the neighbors' meters or the Droid's UI
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
	# Selection pulse and minigame highlight must not fight the defeat animation over scale and modulate
	clear_target_markers()
	clear_minigame_highlight()
	is_defeated = true
	anim.play("subdue" if subdued else "death")

func on_attack_hit():
	attack_hit.emit()

func _ready():
	Utils.ignore_mouse($EnemyAxisBar) # The meter never swallows a click meant for targeting this creature
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
	_unpin_meter()
	attack_finished.emit()

var meter_home_local := Vector2.ZERO
var meter_pinned := false # Only a meter that was pinned for a lunge is put back (animations that do not lunge, like spawning, leave it alone)

func _pin_meter() -> void:
	if meter_pinned:
		return
	meter_pinned = true
	meter_home_local = axis_bar.position
	var pinned_at: Vector2 = axis_bar.global_position
	axis_bar.top_level = true
	axis_bar.global_position = pinned_at

func _unpin_meter() -> void:
	if not meter_pinned:
		return
	meter_pinned = false
	axis_bar.top_level = false
	axis_bar.position = meter_home_local

# Movement methods for connecting patterns using tweens (same methods just in reverse)
func _move_to_attack_position(target: Vector2):
	var duration := move_time.x
	
	play_steps(duration)
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, duration)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished

func _move_to_home_position():
	var duration := move_time.y
	
	play_steps(duration)
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

# SOUNDS
# Plays a sound from an animation's method track: volume in dB on top of its level, from = seconds into the file, length cuts it
func sfx(id: String, volume := 0.0, from := 0.0, pitch := 1.0, length := 0.0) -> void:
	if is_defeated:
		return
	var options := { "volume": volume, "from": from, "pitch": pitch }
	if length > 0.0:
		options["length"] = length
	Sfx.play(id, self, options)

# While a hit's block window is open its sounds are a little louder (the playing ones rise smoothly, new ones start louder)
func set_block_window(open: bool) -> void:
	Sfx.set_owner_level(self, WINDOW_BOOST_DB if open else 0.0)

# A quiet sound from the idle loop (a frog hopping in place); only one idle creature is heard at a time
func idle_sfx(id: String) -> void:
	var now := Time.get_ticks_msec()
	if is_defeated or now - last_idle_sound < IDLE_SOUND_GAP:
		return
	last_idle_sound = now
	Sfx.play(id, self, { "volume": IDLE_VOLUME })

# Its steps (or flaps) for a move of the given length
func play_steps(duration: float) -> void:
	if step_sound == "":
		return
	var walked := 0.0
	while walked < duration - 0.05 and not is_defeated:
		Sfx.play(step_sound, self)
		await get_tree().create_timer(step_interval).timeout
		walked += step_interval

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

# Stun jitter while a hit-stop lasts: a few whole pixels at 30 Hz in real time (off with the Camera shake setting)
func stun(duration: float) -> void:
	if not Settings.camera_shake or is_defeated:
		return
	var base := visual.position
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	for i in int(duration * 30.0):
		tween.tween_property(visual, "position", base + Vector2(randi_range(-2, 2), randi_range(-2, 2)), 1.0 / 30.0)
	tween.tween_property(visual, "position", base, 0.0)

# Hopping animation
func hop(times := 1):
	var orig := position
	var tween := create_tween()
	for i in range(times):
		tween.tween_callback(func(): Sfx.play("hop", self))
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
	# The arrow is drawn in code and always hovers above the intent meter's tame balls, whatever height the meter sits at (the bob and the beat stay as they were)
	var arrow_sprite: Sprite2D = target_arrow.get_node("Sprite2D")
	arrow_sprite.texture = TargetArrowArt.texture()
	arrow_sprite.scale = Vector2(2.4, 2.4)
	var meter_center_x: float = axis_bar.position.x + axis_bar.bar.size.x * 0.5
	var meter_top: float = axis_bar.position.y - METER_LABEL_HEIGHT # The Kill / Tame labels and the balls reach this high
	var rest := Vector2(meter_center_x, meter_top - ARROW_GAP - arrow_sprite.texture.get_height() * arrow_sprite.scale.y * 0.5)
	target_arrow.position = rest - Vector2(2, -80) # The scene's arrow sprite sits at (2, -80) in this node; its bob animation is relative to it
	
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
