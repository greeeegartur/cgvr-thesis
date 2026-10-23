extends Node2D
class_name DamageNumber

# This script is for controlling and animating damage number visuals for EnemyVisual to use

enum Tier { NORMAL, STRONG, PERFECT } # Normal (0.75x / 1.0x), strong (1.25x: gold glow), perfect (all icons Perfect: gold, bigger, wave)

const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const SIZES := { Tier.NORMAL: 20, Tier.STRONG: 24, Tier.PERFECT: 30 }
const OVERSHOOT := { Tier.NORMAL: 1.4, Tier.STRONG: 1.55, Tier.PERFECT: 1.7 }
const BOX := Rect2(-18, -14, 36, 28) # The footprint around the position, used for keeping it visible
const RISE := 42.0
const DRIFT := 30.0

@onready var label : RichTextLabel = $Label

# Where a damage number should start so it stays visible and clear of other numbers and feedback texts
static func placed(layer: Node, at: Vector2) -> Vector2:
	return ActionFeedback.place(layer, at, BOX, RISE, DRIFT)

# Pops in with a white flash, holds a beat, floats up and fades; the tier and direction decide the look
func play(value: float, is_critical: bool, is_heal := false, tier := Tier.NORMAL, tame_side := false):
	value = Utils.quantize_min(absf(value)) # Every number on screen is a quarter step (11.625 shows as 11.75), and never "0"
	if value <= 0.0:
		queue_free()
		return
	if is_critical:
		tier = maxi(tier, Tier.PERFECT)
	var size: int = SIZES[tier]
	var color := Color("ff4a4a") # Toward kill and damage taken
	if is_heal:
		color = Color("5dff7a")
	elif tier != Tier.NORMAL:
		color = Color("fff27a")
	elif tame_side:
		color = Color("ff9ae8") # Toward tame
	
	var text := "[center]" + str(value) + "[/center]"
	if tier == Tier.PERFECT:
		text = "[center][wave amp=14 freq=10]" + str(value) + "![/wave][/center]"
	var width := FONT_BOLD.get_string_size(str(value) + "!", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 16.0
	label.add_theme_font_override("normal_font", FONT_BOLD)
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_constant_override("outline_size", 7 if tier != Tier.NORMAL else 6)
	label.text = text
	label.size = Vector2(width, size + 12)
	label.position = -label.size / 2.0
	label.pivot_offset = label.size / 2.0
	label.modulate = Color(3, 3, 3) # The white flash
	scale = Vector2.ZERO
	rotation_degrees = randf_range(-5, 5)
	
	# A glow behind the stronger numbers
	if tier != Tier.NORMAL:
		var glow: RichTextLabel = label.duplicate()
		glow.add_theme_color_override("font_outline_color", color)
		glow.add_theme_color_override("default_color", Color(color, 0.0))
		var glow_material := CanvasItemMaterial.new()
		glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = glow_material
		glow.modulate = Color(1, 1, 1, 0.55)
		add_child(glow)
		move_child(glow, 0)
	
	# Random direction, kept toward the middle of the screen when near an edge
	var dir := -1 if randf() < 0.5 else 1
	var x_offset := randf_range(14, DRIFT) * dir
	var y_offset := -randf_range(RISE - 12.0, RISE)
	
	var tween := create_tween()
	# Pop with overshoot, the flash settles into the color
	tween.tween_property(self, "scale", Vector2.ONE * OVERSHOOT[tier], 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate", color, 0.12)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# A beat of hold, then float up and fade
	tween.tween_interval(0.22)
	tween.tween_property(self, "position", position + Vector2(x_offset, y_offset), 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.1)
	
	await tween.finished
	queue_free()
